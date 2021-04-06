import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:iex/src/remote_logger.dart';
import 'package:intl/intl.dart';

class IEXClient {
  final String _sandboxURL = 'sandbox.iexapis.com';
  final String _baseURL = 'cloud.iexapis.com';
  final String _apiVersion = 'stable';

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

  String get now => DateFormat("Hms").format(DateTime.now());

  /// Technical Indicators
  ///

  // Client _client = Client();
  HttpClient _client = HttpClient();

  static final IEXClient _iexClient = IEXClient.internal();
  RemoteLogger r = RemoteLogger();

  IEXClient.internal({bool sandbox: true}) {
    _useSandBox = sandbox;
  }

  factory IEXClient() {
    return _iexClient;
  }

  Future<String> get(
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
      bool indicatorOnly}) async {
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
      (function != 'intraday-prices' && function != 'price' && function != 'latestPrice')
          ? function
          : 'stock',
      symbol,
      indicator != null ? 'indicator' : null,
      indicator != null ? '$indicator' : null,
      market,
      (function == 'stock' && indicator == null) ? 'batch' : null,
      function == 'intraday-prices' ? function : null,
      function == 'price' ? function : null,
      function == 'latestPrice' ? 'quote' : null,
      function == 'latestPrice' ? function : null,
      types == 'trade' ? 'dates' : null,
      types == 'trade' ? 'trade' : null,
      period == 'next' ? 'next' : null,
      types == 'trade' ? range : null,
    ];

    pathSegments.removeWhere((element) => element == null);

    Uri uriRequest;
    uriRequest = Uri(
        scheme: "https",
        host: _useSandBox ? this._sandboxURL : this._baseURL,
        pathSegments: pathSegments,
        queryParameters: queryParams);

    r.log("Calling client with URL: " + uriRequest.toString(), StackTrace.current);

    HttpClientResponse response;

    try {
      response = await getUrlWithRetry(_client, uriRequest);
    } catch (e) {
      print('HTTP get failed...Retrying.');
      response = await getUrlWithRetry(_client, uriRequest);
    }

    // print('Response string[${response.length} bytes]');
    String respStr = '';
    // transforms and prints the response
    await for (var contents in response.transform(Utf8Decoder())) {
      // print('content length: ${contents.length}');
      respStr += contents;
    }

    // if (types == 'trade') print('Response string: \n$respStr');

    return respStr;
  }

  Future<HttpClientResponse> getUrlWithRetry(HttpClient httpClient, Uri url,
      {int maxRetries = 2}) async {
    for (var attempt = 0; attempt < maxRetries; attempt++) {
      final request = await httpClient.openUrl('GET', url);
      final response = await request.close();
      return response;
    }
    return null;
  }

  Future<String> readResponse(HttpClientResponse response) {
    final completer = Completer<String>();
    final contents = StringBuffer();
    response.transform(utf8.decoder).listen((data) {
      contents.write(data);
    }, onDone: () => completer.complete(contents.toString()));
    return completer.future;
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

    if (types == 'trade' && period == 'next') {
      _updateQueryMap(queryParams, this._APIKEY, apiKey);
      return queryParams;
    }

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

  _updateQueryMap(Map<String, String> currentParams, String param, String paramValue) {
    if (paramValue != null) {
      currentParams[param] = paramValue;
    }
  }
}
