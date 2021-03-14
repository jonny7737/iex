import 'dart:convert';

class JSONObject {
  Map<String, dynamic> jsonContents;
  List<Map<String, dynamic>> jsonListContents;

  JSONObject(String jsonString) {
    var respJSON = json.decode(jsonString);

    // print('JSONObject: ${respJSON.runtimeType}[${respJSON.length}]');

    if (respJSON is List<dynamic>) {
      jsonListContents = [];
      respJSON.forEach((map) {
        this.jsonListContents.add(map);
      });
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
