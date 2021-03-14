import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart';
import 'package:iex/src/JSONObject.dart';
import 'package:iex/src/iex_client.dart';

class BaseAPI {
  var client;

  String _apiKey;
  Map<String, String> queryParams;

  BaseAPI(String key) {
    if (Platform.isMacOS)
      this._apiKey = Platform.environment[key];
    else
      this._apiKey = key;
    // print(this._apiKey);
    if (_apiKey == null) throw Exception('API key not set.');

    client = IEXClient.internal(sandbox: key.endsWith('IEX_SB'));
    this.queryParams = new Map();
  }

  void setAPIKey(String key) => _apiKey = key;

  String getAPIKey() {
    return this._apiKey;
  }

  Future<JSONObject> getRequest({
    String function,
    String symbol,
    String symbols,
    String market,
    String range,
    String period,
    String indicator,
    String types,
    String filter,
    bool closeOnly,
    bool indicatorOnly,
  }) async {
    Response response = await this.client.get(
          function: function,
          symbol: symbol,
          symbols: symbols,
          apiKey: this.getAPIKey(),
          market: market,
          indicator: indicator,
          range: range,
          period: period,
          types: types,
          filter: filter,
          closeOnly: closeOnly,
          indicatorOnly: indicatorOnly,
        );

    // print('[BaseAPI] ${response.body.toString()}');
    if (_validateResponse(response)) return JSONObject(response.body);
    return JSONObject('{ERROR:"${response.body}"}');
  }

  bool _validateResponse(Response response) {
    if (response.statusCode != 200) return false;
    return true;
  }

  Map<String, dynamic> toJson(Response response) {
    if (response.statusCode == 200) {
      // print(response.body);
      return json.decode(response.body);
    } else {
      throw Exception(
          "Failed to get data from iex server. Response from server:" +
              response.body.toString());
    }
  }
}
