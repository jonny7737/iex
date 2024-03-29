import 'package:iex/src/BaseAPI.dart';
import 'package:iex/src/JSONObject.dart';

class IEX extends BaseAPI {
  IEX(String key) : super(key);

  Future<List<String>> inventory() async {
    // if (this.getAPIKey() == null) return null;

    List<String> tsInventory = [];

    JSONObject json = await this.getRequest(function: 'time-series');
    // print('${json.getJSONMap()}');
    json.jsonListContents.forEach((element) {
      if (!element['id'].toString().startsWith('PREMIUM')) {
        tsInventory.add(element['id']);
        // print('${element['id']}');
      }
    });

    return tsInventory;
  }

  Future<JSONObject> nextMarketOpen() async {
    //  GET /ref-data/us/dates/{type}/{direction}/{last?}/{startDate?}
    //  /ref-data/us/dates/trade/next/1

    JSONObject jsonObject = await this.getRequest(
        function: 'ref-data',
        market: 'us',
        types: 'trade',
        period: 'next',
        range: '1');
    return jsonObject;
  }

  Future<JSONObject> getSymbolList() async {
    JSONObject jsonObject =
        await this.getRequest(function: 'ref-data', symbol: 'symbols');
    return jsonObject;
  }

  Future<JSONObject> currentPrice({required String symbol}) async {
    JSONObject jsonObject =
        await this.getRequest(function: 'price', symbol: symbol);
    // await this.getRequest(function: 'latestPrice', symbol: symbol);
    // print('ts currentPrice: ${jsonObject.jsonContents}');
    return jsonObject;
  }

  Future<JSONObject> latestPrice({required String symbol}) async {
    JSONObject jsonObject =
        await this.getRequest(function: 'latestPrice', symbol: symbol);
    return jsonObject;
  }

  Future<JSONObject> previousClose({required String symbol}) async {
    JSONObject jsonObject =
        await this.getRequest(function: 'previousClose', symbol: symbol);
    return jsonObject;
  }

  Future<JSONObject> intraDay({required String symbol}) async {
    JSONObject jsonObject =
        await this.getRequest(function: 'intraday-prices', symbol: symbol);
    return jsonObject;
  }

  Future<JSONObject> stockBatch(
      {String symbol = '',
      String symbols = '',
      String types = 'chart',
      String range = '', // date, 5d, 1m, 3m, 6m, ytd, 1y, 2y, 5y
      String filter = '',
      bool chartCloseOnly = true}) async {
    JSONObject jsonObject = await this.getRequest(
        function: 'stock',
        symbol: symbol != '' ? symbol : 'market',
        symbols: symbols,
        types: types,
        filter: filter,
        range: range,
        closeOnly: chartCloseOnly);

    return jsonObject;
  }

  Future<JSONObject> ti(
      {String symbol = '',
      String ti = '',
      String range = '',
      String period = ''}) async {
    // if (this.getAPIKey() == null)
    //   return JSONObject('{"ERROR": "API key not set."}');
    JSONObject jsonObject = await this.getRequest(
      function: 'stock',
      symbol: symbol,
      indicator: ti,
      range: range,
      period: period,
      indicatorOnly: true,
    );
    return jsonObject;
  }
}
