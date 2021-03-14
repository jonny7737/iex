import 'dart:async';

import 'package:http/http.dart';

class IEXClient {
  String _sandboxURL = 'sandbox.iexapis.com';
  String _baseURL = 'cloud.iexapis.com';
  String _apiVersion = 'stable';

  bool _useSandBox = true;
  String url;

  // ignore: non_constant_identifier_names
  final _SYMBOLS = "symbols";
  // ignore: non_constant_identifier_names
  final _PERIOD = "period";
  // ignore: non_constant_identifier_names
  final _APIKEY = "token";

  // ignore: non_constant_identifier_names
  final _TYPES = "types";

  // ignore: non_constant_identifier_names
  final _FILTER = "filter";

  // ignore: non_constant_identifier_names
  final _RANGE = "range";

  // ignore: non_constant_identifier_names
  final _CLOSE_ONLY = 'chartCloseOnly';
  // ignore: non_constant_identifier_names
  final _INDICATOR_ONLY = 'indicatorOnly';

  /// Technical Indicators
  ///

  Client _client = Client();
  static final IEXClient _iexClient = IEXClient.internal();

  IEXClient.internal({bool sandbox: true}) {
    _useSandBox = sandbox;
  }

  factory IEXClient() {
    return _iexClient;
  }

  Future<Response> get(
      {String function = "time-series",
      String symbol,
      String symbols,
      String apiKey,
      String market,
      String indicator,
      String range,
      String period,
      String types,
      String filter,
      bool closeOnly,
      bool indicatorOnly}) {
    Map<String, String> queryParams = _buildQueryParams(
        symbols: symbols,
        apiKey: apiKey,
        range: range,
        period: period,
        types: types,
        filter: filter,
        closeOnly: closeOnly,
        indicatorOnly: indicatorOnly);

    List<String> pathSegments;
    pathSegments = [
      _apiVersion,
      function != 'intraday-prices' ? function : 'stock',
      symbol,
      indicator != null ? 'indicator' : null,
      indicator != null ? '$indicator' : null,
      market,
      (function == 'stock' && indicator == null) ? 'batch' : null,
      function == 'intraday-prices' ? function : null,
    ];

    pathSegments.removeWhere((element) => element == null);

    // print(pathSegments);

    Uri uriRequest = Uri(
        scheme: "https",
        host: _useSandBox ? this._sandboxURL : this._baseURL,
        // path: '/stable/' + function,
        pathSegments: pathSegments,
        queryParameters: queryParams);

    print("Calling client with URL: " + uriRequest.toString());

    Future<Response> response = this._client.get(uriRequest);
    response.then((Response response) {
      // print("Response from server: " +
      //     response.body.length.toString() +
      //     ' bytes');
    });

    return response;
  }

  Map<String, String> _buildQueryParams(
      {String symbols,
      String apiKey,
      String range,
      String period,
      String types,
      String filter,
      bool closeOnly,
      bool indicatorOnly}) {
    Map<String, String> queryParams = new Map();
    _updateQueryMap(queryParams, this._SYMBOLS, symbols);
    _updateQueryMap(queryParams, this._RANGE, range);
    _updateQueryMap(queryParams, this._PERIOD, period);
    _updateQueryMap(queryParams, this._TYPES, types);
    _updateQueryMap(queryParams, this._FILTER, filter);
    if (types != null) if (types.contains('chart') && closeOnly ?? false)
      _updateQueryMap(queryParams, this._CLOSE_ONLY, 'true');
    if (indicatorOnly != null && indicatorOnly)
      _updateQueryMap(queryParams, this._INDICATOR_ONLY, 'true');
    _updateQueryMap(queryParams, this._APIKEY, apiKey);
    return queryParams;
  }

  _updateQueryMap(
      Map<String, String> currentHeaders, String param, String paramValue) {
    if (paramValue != null) {
      currentHeaders[param] = paramValue;
    }
  }
}
