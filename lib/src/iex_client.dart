import 'dart:async';
import 'dart:convert';
import 'dart:io';

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

  /// Technical Indicators
  ///

  // Client _client = Client();
  HttpClient _client = HttpClient();

  static final IEXClient _iexClient = IEXClient.internal();

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
      (function != 'intraday-prices' && function != 'price') ? function : 'stock',
      symbol,
      indicator != null ? 'indicator' : null,
      indicator != null ? '$indicator' : null,
      market,
      (function == 'stock' && indicator == null) ? 'batch' : null,
      function == 'intraday-prices' ? function : null,
      function == 'price' ? function : null,
    ];

    pathSegments.removeWhere((element) => element == null);

    Uri uriRequest;
    uriRequest = Uri(
        scheme: "https",
        host: _useSandBox ? this._sandboxURL : this._baseURL,
        pathSegments: pathSegments,
        queryParameters: queryParams);
    // print("Calling client with URL: " + uriRequest.toString());

    // var request = await HttpClient().getUrl(uriRequest);
    // // sends the request
    // HttpClientResponse response = await request.close();
    // print('Response status code: ${response.statusCode}');

    var response = await getUrlWithRetry(_client, uriRequest);
    // print('Response string[${await response.length} bytes]');
    String respStr = '';
    // transforms and prints the response
    await for (var contents in response.transform(Utf8Decoder())) {
      // print('content length: ${contents.length}');
      respStr += contents;
    }

    // print('Response string: \n$respStr');

    // Future<Response> response =
    // Future<String> responseStr;
    // this._client.getUrl(uriRequest).then((HttpClientRequest request) {
    //   // Optionally set up headers...
    //   // Optionally write to the request object...
    //   // Then call close.
    //   return request.close();
    // }).then((HttpClientResponse response) async {
    //   responseStr = readResponse(response);
    // });

    // response.then((Response response) {
    //   // print("Response from server: " +
    //   //     response.body.length.toString() +
    //   //     ' bytes');
    // });
    // print('$resp');
    return respStr;
  }

  Future<HttpClientResponse> getUrlWithRetry(HttpClient httpClient, Uri url,
      {int maxRetries = 5}) async {
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

  _updateQueryMap(Map<String, String> currentHeaders, String param, String paramValue) {
    if (paramValue != null) {
      currentHeaders[param] = paramValue;
    }
  }
}
