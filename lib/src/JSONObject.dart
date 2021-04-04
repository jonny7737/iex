import 'dart:convert';

class JSONObject {
  Map<String, dynamic> jsonContents;
  List<Map<String, dynamic>> jsonListContents;

  JSONObject(String jsonString) {
    // print('JSONObject: $jsonString');

    var respJSON;
    if (jsonString.startsWith('\{'))
      respJSON = "{'ERROR':$jsonString}";
    else if (jsonString.startsWith('<html>'))
      respJSON = "{'ERROR':$jsonString}";
    else
      respJSON = json.decode(jsonString);

    // print('JSONObject: ${respJSON.runtimeType}[${respJSON.length}]');

    if (respJSON is double || respJSON is int) {
      this.jsonContents = {'price': respJSON.toDouble()};
    } else if (respJSON is List<dynamic>) {
      jsonListContents = [];
      respJSON.forEach((map) {
        this.jsonListContents.add(map);
      });
    } else if (respJSON is String) {
      this.jsonContents = {'error': respJSON};
    } else
      this.jsonContents = respJSON;
  }

  dynamic _get(String key, Map<String, dynamic> json) {
    if (json == null) return null;
    if (json.containsKey(key)) {
      return json[key];
    } else {
      Iterable<dynamic> values = json.values;
      for (dynamic jsonValue in values) {
        try {
          return _get(key, jsonValue);
        } catch (e) {}
      }
    }

    return null;
  }

  dynamic get(String key) {
    return _get(key, this.jsonContents);
  }

  String getString(String key) {
    return _get(key, this.jsonContents);
  }

  dynamic getJSONMap() {
    return this.jsonContents ?? this.jsonListContents;
  }
}
