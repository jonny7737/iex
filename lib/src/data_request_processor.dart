import 'dart:async';
import 'dart:collection';

import 'package:iex/iex.dart';
import 'package:iex/src/JSONObject.dart';
import 'package:iex/src/remote_logger.dart';
import 'package:iex/src/stocks.dart';
import 'package:timezone/timezone.dart' as tz;

class ChartData {
  ChartData(this.date, this.open, this.high, this.low, this.close, this.volume);
  final tz.TZDateTime? date;
  final double? open;
  final double? high;
  final double? low;
  final double? close;
  final double? volume;
}

class DataRequestProcessor {
  /// Queue entries are Map<String, Map<String, String>>.
  ///
  /// Map of function name and Map of function parameters.
  ///
  /// Poll the request queue every 500 milliseconds, process all queue entries.
  ///
  /// serviceEndPoint parameter string is either
  /// 'IEX' for production or 'IEX_SB' for sandbox.
  DataRequestProcessor(String serviceEndPoint) {
    _init(serviceEndPoint);
    processing = false;
    timer = Timer.periodic(Duration(milliseconds: 500), (Timer t) => _processQueue());
  }

  _init(String serviceEndPoint) async {
    ts = IEX(serviceEndPoint);
    sm = StockMeta(serviceEndPoint);
  }

  final tz.Location eastern = tz.getLocation('US/Eastern');
  final tz.Location central = tz.getLocation('US/Central');
  late StockMeta sm;
  late IEX ts;
  RemoteLogger r = RemoteLogger();

  final ListQueue queue = ListQueue();
  late Timer timer;
  bool processing = false;

  Map<String, dynamic> dataSets = {};
  List<ChartData> chartData = [];
  late double minY;
  late double maxY;
  late DateTime minimumDate;

  void clearAll() => chartData.clear();

  Future<String> nextMarketOpen() async {
    JSONObject jsonObject = await sm.nextMarketOpen();
    // if (jsonObject.jsonListContents == null) return null;
    return jsonObject.jsonListContents[0]['date'].toString();
  }

  List<ChartData> buildChartData(String symbol) {
    if (chartData.isNotEmpty) return chartData;
    chartData.clear();
    _getChartData(symbol)
      // ..removeWhere((key, value) => 180 < DateTime.now().difference(key).inDays)
      ..forEach((key, value) {
        chartData.add(ChartData(
          key,
          value['open'] != -double.infinity ? value['open'] : null,
          value['high'] != -double.infinity ? value['high'] : null,
          value['low'] != -double.infinity ? value['low'] : null,
          value['close'] != -double.infinity ? value['close'] : null,
          value['volume'] != -double.infinity ? value['volume'] : null,
        ));
      });
    if (chartData.isNotEmpty) {
      minimumDate = chartData[0].date!;
    }
    return chartData;
  }

  Future<double> getCurrentPrice(String symbol) async {
    double? price;

    await Future.doWhile(() async {
      dataSets.forEach((key, value) {
        if (key.startsWith(symbol + '[currentPrice]')) {
          for (int i = 0; i < value.length; i++) {
            if (value[i]['price'] != null) price = value[i]['price'].toDouble();
          }
        }
      });
      if (price == null) await Future.delayed(Duration(milliseconds: 50));
      return price == null;
    });

    return price ?? double.nan;
  }

  /// * fOpen	: number	Fully adjusted for historical dates.
  /// * fClose	: number	Fully adjusted for historical dates.
  /// * fHigh	: number	Fully adjusted for historical dates.
  /// * fLow	: number	Fully adjusted for historical dates.
  /// * fVolume	: number	Fully adjusted for historical dates.
  ///
  Map<tz.TZDateTime, Map<String, double>> _getChartData(String symbol) {
    Map<tz.TZDateTime, Map<String, double>> c = {};

    dataSets.forEach((key, value) {
      if (!key.startsWith(symbol)) return;
      String dataSetType = key.split(RegExp(r'[\[\]]'))[1];
      if (dataSetType.contains('chart') || dataSetType.contains('intraDay')) {
        value.forEach((e) {
          tz.TZDateTime date;
          if (e['minute'] != null) {
            date = tz.TZDateTime.parse(eastern, e['date'] + ' ${e["minute"]}');
          } else
            date = tz.TZDateTime.parse(eastern, e['date']);
          double? open = e['fOpen']?.toDouble() ?? e['open']?.toDouble();
          double? high = e['fHigh']?.toDouble() ?? e['high']?.toDouble();
          double? low = e['fLow']?.toDouble() ?? e['low']?.toDouble();
          double? close = e['fClose']?.toDouble() ?? e['close']?.toDouble();
          double? volume = e['fVolume']?.toDouble() ?? e['volume']?.toDouble();
          Map<String, double> _c = {
            'open': open ?? -double.infinity,
            'high': high ?? -double.infinity,
            'low': low ?? -double.infinity,
            'close': close ?? -double.infinity,
            'volume': volume ?? -double.infinity,
          };
          c.addAll({date: _c});
        });
      }
    });
    return c;
  }

  void _updateDataSets(String name, JSONObject jsonObject) {
    var jsonMap = jsonObject.getJSONMap();

    if (jsonMap is Map<String, dynamic>) {
      List<dynamic>? chart = jsonMap['chart'];
      List<dynamic>? indicator = jsonMap['indicator'];
      if (chart != null) {
        dataSets.update(name, (value) => chart, ifAbsent: () => chart);
        return;
      }
      if (indicator != null) {
        dataSets.update(name, (value) => indicator.first, ifAbsent: () => indicator.first);
        return;
      }
    }

    if (jsonMap is List) {
      dataSets.update(name, (value) => jsonMap, ifAbsent: () => jsonMap);
    } else {
      print('drp._updateDataSets[162]: ' + jsonMap.runtimeType.toString());
      print('drp._updateDataSets[163]: ${jsonMap.toString()}');
    }
  }

  /// Example usage:
  ///```dart
  ///    drp.requestData([{'fn': 'chart', 'symbol': 'fb', 'range': '3m', 'types': 'chart'}]);
  ///
  ///    // Order of entries is irrelevant
  ///    drp.requestData([
  ///        {'fn': 'chart', 'symbol': 'aapl', 'range': '3m', 'types': 'chart'},
  ///        {'fn': 'ti', 'ti': 'sma', 'symbol': 'aapl', 'range': '3m', 'period': '5'},
  ///        {'fn': 'ti', 'ti': 'sma', 'symbol': 'aapl', 'range': '3m', 'period': '50'},
  ///        {'fn': 'ti', 'ti': 'sma', 'symbol': 'aapl', 'range': '3m', 'period': '200'},
  ///        {'fn': 'ti', 'ti': 'macd', 'symbol': 'aapl', 'range': '3m', 'period': '12,26,9'},
  ///        {'fn': 'ti', 'ti': 'stoch', 'symbol': 'aapl', 'range': '3m', 'period': '5,3,3'},
  ///    ]);
  ///```
  ///-
  void requestData(List<Map<String, dynamic>> request, [Function? callback]) {
    if (queue.contains(request)) return;
    queue.add(request);
    queue.add(callback);
    // r.log('New request queued: ${request.toString()}', StackTrace.current);
    // print(StackTrace.current.toString());
  }

  void _processQueue() async {
    if (queue.isEmpty || processing) return;
    processing = true;
    // IEX Cloud does not allow multiple simultaneous
    // API calls with a non-Business account.
    while (queue.isNotEmpty) {
      //  Process IEX API calls one at a time.
      if (await _processRequest(queue.first)) {
        queue.removeFirst();
        Function? callBack = queue.removeFirst();
        if (callBack != null) callBack();
      }
    }
    processing = false;
  }

  Map<Symbol, dynamic> _paramsBuilder(Map<String, dynamic> requestParams) {
    Map<Symbol, dynamic> params = {};
    requestParams.forEach((key, value) {
      if (key != 'fn') params[Symbol(key)] = value;
    });
    return params;
  }

  Future<bool> _processRequest(List<Map<String, dynamic>> request) async {
    JSONObject? resp;

    while (request.length > 0) {
      Map<Symbol, dynamic> params = _paramsBuilder(request.first);
      Map<String, dynamic> req = request.first;
      String techIndicator = req['ti'] ?? '';
      String tiPeriod = req['period'] ?? '';
      String dataSetName = 'unknown';

      // r.log('Processing : ${req.toString()}', StackTrace.current);

      if (req['fn'] == 'price') {
        resp = await Function.apply(_currentPrice, null, params);
        String json = '[{"symbol": "${req['symbol']}"},{"price": ${resp!.jsonContents['price']}}]';
        resp = JSONObject(json);
        dataSetName = '${req['symbol']}[currentPrice]';
      } else if (req['fn'] == 'intra') {
        resp = await Function.apply(_intraDay, null, params);
        dataSetName = '${req['symbol']}[intraDay]';
      } else if (req['fn'] == 'ti') {
        resp = await Function.apply(_techInd, null, params);
        dataSetName = '${req['symbol']}[ti: $techIndicator $tiPeriod]';
      } else if (req['fn'] == 'chart') {
        resp = await Function.apply(_stockBatch, null, params);
        dataSetName = '${req['symbol']}[${req['range']} chart]';
      }

      if (resp!.get('ERROR') != null) {
        return false;
      }
      _updateDataSets(dataSetName, resp);
      request.remove(request.first);
    }
    return true;
  }

  Future<String> getCoNameBySymbol(String symbol) async {
    String coName = await sm.getNameBySymbol(symbol);
    return coName;
  }

  Future<List<Map<String, String>>> symbolListMatches(String searchString) async {
    List<Map<String, String>> matchList = await sm.listOfMatches(searchString);
    return matchList;
  }

  Future<JSONObject> _currentPrice({required String symbol}) async {
    // DateTime start = DateTime.now();

    JSONObject j = await ts.currentPrice(symbol: symbol);

    // int duration = DateTime.now().difference(start).inMilliseconds;
    // print('Time to retrieve $symbol price: $duration mS');

    return j;
  }

  Future<double> currentPrice({required String symbol}) async {
    JSONObject j = await ts.currentPrice(symbol: symbol);
    return j.getJSONMap()['price'] ?? -double.infinity;
  }

  Future<double> previousClose({required String symbol}) async {
    JSONObject j = await ts.previousClose(symbol: symbol);
    return j.getJSONMap()['price'] ?? -double.infinity;
  }

  Future<JSONObject> _intraDay({required String symbol}) async {
    return await ts.intraDay(symbol: symbol);
  }

  Future<List<ChartData>> intraDay(String symbol) async {
    Map<tz.TZDateTime, Map<String, double>> c = {};
    List<ChartData> chartData = [];

    JSONObject resp = await ts.intraDay(symbol: symbol);
    var jsonMap = resp.getJSONMap();

    if (jsonMap is List) {
      jsonMap.forEach((e) {
        tz.TZDateTime date;
        if (e['minute'] != null) {
          date = tz.TZDateTime.parse(central, e['date'] + ' ${e["minute"]}');
        } else
          date = tz.TZDateTime.parse(central, e['date']);

        double? open = e['marketOpen']?.toDouble() ?? e['open']?.toDouble();
        double? high = e['marketHigh']?.toDouble() ?? e['high']?.toDouble();
        double? low = e['marketLow']?.toDouble() ?? e['low']?.toDouble();
        double? close = e['marketClose']?.toDouble() ?? e['close']?.toDouble();
        double? volume = e['marketVolume']?.toDouble() ?? e['volume']?.toDouble();
        Map<String, double> _c = {
          'open': open ?? -double.infinity,
          'high': high ?? -double.infinity,
          'low': low ?? -double.infinity,
          'close': close ?? -double.infinity,
          'volume': volume ?? -double.infinity,
        };

        // double open = (e['fOpen']?.toDouble() ?? e['open']?.toDouble()) ??
        //     -double.infinity;
        // double high = (e['fHigh']?.toDouble() ?? e['high']?.toDouble()) ??
        //     -double.infinity;
        // double low =
        //     (e['fLow']?.toDouble() ?? e['low']?.toDouble()) ?? -double.infinity;
        // double close = (e['fClose']?.toDouble() ?? e['close']?.toDouble()) ??
        //     -double.infinity;
        // double volume = (e['fVolume']?.toDouble() ?? e['volume']?.toDouble()) ??
        //     -double.infinity;

        // Map<String, double> _c = {
        //   'open': open,
        //   'high': high,
        //   'low': low,
        //   'close': close,
        //   'volume': volume,
        // };
        c.addAll({date: _c});
      });
    } else //  return an empty list if the response was not a list
      return chartData;

    c.forEach((key, value) {
      chartData.add(ChartData(
        key,
        value['open'],
        value['high'],
        value['low'],
        value['close'],
        value['volume'],
      ));
    });

    // print('iex = $symbol : ${chartData.last.date}');
    return chartData;
  }

  Future<JSONObject> _stockBatch({
    required String symbol,
    required String range,
    required String types,
    bool closeOnly = false,
  }) async {
    String symbols = '';

    JSONObject jsonObject = await ts.stockBatch(
      symbol: symbol,
      symbols: symbols,
      types: types,
      range: range,
      chartCloseOnly: closeOnly,
    );
    return jsonObject;
  }

  ///  Technical Indicator: SMA,MACD,Stoch
  ///
  Future<JSONObject> _techInd({
    required String symbol,
    required String ti,
    required String range,
    required String period,
  }) async {
    return await ts.ti(symbol: symbol, ti: ti, range: range, period: period);
  }
}
