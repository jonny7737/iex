import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:iex/src/JSONObject.dart';
import 'package:iex/src/stocks.dart';

import '../iex.dart';

class ChartData {
  ChartData(this.date, this.open, this.high, this.low, this.close, this.volume);
  final DateTime date;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;
}

class DataRequestProcessor with ChangeNotifier {
  /// Queue entries are Map<String, Map<String, String>>
  ///
  /// Map of function name and Map of function parameters
  ///
  /// Poll the request queue every 500 milliseconds, process all queue entries.
  ///
  DataRequestProcessor(String serviceEndPoint) {
    _init(serviceEndPoint);
    processing = false;
    timer = Timer.periodic(
        Duration(milliseconds: 500), (Timer t) => _processQueue());
  }

  _init(String serviceEndPoint) async {
    ts = IEX(serviceEndPoint);
    sm = StockMeta(serviceEndPoint);
  }

  StockMeta sm;
  IEX ts;

  final ListQueue queue = ListQueue();
  Timer timer;
  bool processing;

  Map<String, dynamic> dataSets = {};
  List<ChartData> chartData = [];
  double minY;
  double maxY;

  @override
  dispose() {
    timer?.cancel();
    super.dispose();
  }

  double _zoomLevel = 1.0;

  void resetZoomLevel() => _zoomLevel = 1.0;

  double get incZoomLevel {
    _zoomLevel += 0.1;
    if (_zoomLevel > 1.0) _zoomLevel = 1.0;
    // print('inc : $_zoomLevel');
    return _zoomLevel;
  }

  double get decZoomLevel {
    _zoomLevel -= 0.1;
    if (_zoomLevel < 0.0) _zoomLevel = 0.0;
    // print('dec : $_zoomLevel');
    return _zoomLevel;
  }

  DateTime minimumDate;

  void clearAll() => chartData.clear();

  String get keys => dataSets.keys.toString();

  void setMinMaxY() {
    if (chartData.isEmpty) return;
    minY = 10000000;
    maxY = -10000000;

    // zoomLevel = chartData.length - 90;
    // if (zoomLevel < 0) zoomLevel = 0;

    for (int i = 0; i < chartData.length; i++) {
      if (minY > chartData[i].low) minY = chartData[i].low;
      if (maxY < chartData[i].high) maxY = chartData[i].high;
    }
    minY = (minY * 0.98) - (minY * 0.98) % 5;
    maxY = (maxY * 1.05) - (maxY * 1.05) % 5;

    minimumDate = chartData[0].date;
  }

  List<ChartData> buildChartData(String symbol) {
    if (chartData.isNotEmpty) return chartData;
    chartData.clear();
    _getChartData(symbol)
      // ..removeWhere((key, value) => 180 < DateTime.now().difference(key).inDays)
      ..forEach((key, value) {
        chartData.add(ChartData(
          key,
          value['open'],
          value['high'],
          value['low'],
          value['close'],
          value['volume'],
        ));
      });
    if (chartData.isNotEmpty) {
      minimumDate = chartData[0].date;
    }
    // print('Days of ChartData ${chartData.length}');
    return chartData;
  }

  /// * fOpen	: number	Fully adjusted for historical dates.
  /// * fClose	: number	Fully adjusted for historical dates.
  /// * fHigh	: number	Fully adjusted for historical dates.
  /// * fLow	: number	Fully adjusted for historical dates.
  /// * fVolume	: number	Fully adjusted for historical dates.
  ///
  Map<DateTime, Map<String, double>> _getChartData(String symbol) {
    Map<DateTime, Map<String, double>> c = {};

    dataSets.forEach((key, value) {
      // print(value.last['minute']);
      if (!key.startsWith(symbol)) return;
      String dataSetType = key.split(RegExp(r'[\[\]]'))[1];
      if (dataSetType.contains('chart') || dataSetType.contains('intraDay')) {
        value.forEach((e) {
          DateTime date;
          if (e['minute'] != null) {
            date = DateTime.parse(e['date'] + ' ${e["minute"]}');
          } else
            date = DateTime.parse(e['date']);
          double open = e['fOpen']?.toDouble() ?? e['open'].toDouble();
          double high = e['fHigh']?.toDouble() ?? e['high'].toDouble();
          double low = e['fLow']?.toDouble() ?? e['low'].toDouble();
          double close = e['fClose']?.toDouble() ?? e['close'].toDouble();
          double volume = e['fVolume']?.toDouble() ?? e['volume'].toDouble();
          Map<String, double> _c = {
            'open': open,
            'high': high,
            'low': low,
            'close': close,
            'volume': volume,
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
      List<dynamic> chart = jsonMap['chart'];
      List<dynamic> indicator = jsonMap['indicator'];
      if (chart != null) {
        dataSets.update(name, (value) => chart, ifAbsent: () => chart);
        return;
      }
      if (indicator != null) {
        dataSets.update(name, (value) => indicator.first,
            ifAbsent: () => indicator.first);
        return;
      }
    }

    if (jsonMap is List) {
      // print(jsonMap[0]);
      dataSets.update(name, (value) => jsonMap, ifAbsent: () => jsonMap);
    } else
      print(jsonMap);
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
  void requestData(List<Map<String, dynamic>> request) {
    queue.add(request);
  }

  void _processQueue() async {
    if (queue.isEmpty || processing) return;
    processing = true;
    // IEX Cloud does not allow multiple simultaneous
    // API calls with a non-Business account.
    while (queue.isNotEmpty) {
      //  Process IEX API calls one at a time.
      if (await _processRequest(queue.first)) queue.removeFirst();
    }
    processing = false;
    notifyListeners();
  }

  Map<Symbol, dynamic> _paramsBuilder(Map<String, dynamic> requestParams) {
    Map<Symbol, dynamic> params = {};
    requestParams.forEach((key, value) {
      if (key != 'fn') params[Symbol(key)] = value;
    });
    return params;
  }

  Future<bool> _processRequest(List<Map<String, dynamic>> request) async {
    JSONObject resp;

    // print(request.first);

    while (request.length > 0) {
      Map<Symbol, dynamic> params = _paramsBuilder(request.first);
      Map<String, dynamic> req = request.first;
      String techIndicator = req['ti'];
      String tiPeriod = req['period'];
      String dataSetName;

      if (req['fn'] == 'intra') {
        resp = await Function.apply(_intraDay, null, params);
        dataSetName = '${req['symbol']}[intraDay]';
        // print('_intraDay: ${resp.jsonListContents}');
      }
      if (req['fn'] == 'ti') {
        resp = await Function.apply(_techInd, null, params);
        dataSetName = '${req['symbol']}[ti: $techIndicator $tiPeriod]';
      }
      if (req['fn'] == 'chart') {
        resp = await Function.apply(_stockBatch, null, params);
        dataSetName = '${req['symbol']}[${req['range']} chart]';
      }
      // print('Response: $resp');
      if (resp.get('ERROR') != null) {
        // showMyDialog('${resp.jsonContents.toString()}');
        return false;
      }
      if (resp != null) _updateDataSets(dataSetName, resp);
      request.remove(request.first);
    }
    return true;
  }

  Future<String> getCoNameBySymbol(String symbol) async {
    print('Company name lookup started...');
    return await sm.getNameBySymbol(symbol);
  }

  Future<JSONObject> _intraDay({String symbol}) async {
    return await ts.intraDay(symbol: symbol);
  }

  Future<JSONObject> _stockBatch({
    String symbol,
    String range,
    String types,
    bool closeOnly = false,
  }) async {
    String symbols;

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
  Future<JSONObject> _techInd(
      {String symbol, String ti, String range, String period}) async {
    return await ts.ti(symbol: symbol, ti: ti, range: range, period: period);
  }

  // bool dialogActive = false;
  // Future<void> showMyDialog(String message) async {
  //   if (dialogActive == true) return;
  //   dialogActive = true;
  //   await showDialog(
  //     useSafeArea: true,
  //     barrierDismissible: true,
  //     context: navigatorKey.currentContext,
  //     builder: (context) => Center(
  //       child: Container(
  //         padding: EdgeInsets.all(6),
  //         width: Platform.isMacOS ? 500 : 300,
  //         child: Text(
  //           message,
  //           style: TextStyle(fontSize: 14),
  //           textAlign: TextAlign.center,
  //         ),
  //         decoration: BoxDecoration(
  //             color: Colors.yellow,
  //             borderRadius: BorderRadius.all(
  //               Radius.circular(12.0),
  //             )),
  //       ),
  //     ),
  //   ).timeout(Duration(seconds: 30));
  //   dialogActive = false;
  // }
}