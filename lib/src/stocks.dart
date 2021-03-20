import 'dart:io';

import 'package:iex/iex.dart';
import 'package:objectdb/objectdb.dart';
import 'package:path_provider/path_provider.dart';

class StockInfo {
  StockInfo(this.symbol, this.exchange, this.name, this.region, this.currency);
  final String symbol;
  final String exchange;
  final String name;
  final String region;
  final String currency;
}

class StockMeta {
  StockMeta(String serviceEndPoint) {
    _init(serviceEndPoint);
  }

  IEX ts;
  ObjectDB db;
  bool initED = false;

  _init(String serviceEndPoint) async {
    ts = IEX(serviceEndPoint);

    Directory appDocDir = await getApplicationDocumentsDirectory();

    String dbFilePath = [appDocDir.path, 'symbols.db'].join('/');

    // if (await File(dbFilePath).exists()) File(dbFilePath).deleteSync();

    db = ObjectDB(dbFilePath);
    await db.open();
    initED = true;
  }

  Future<bool> get dbIsOpen async {
    while (db == null) {
      await Future.delayed(Duration(milliseconds: 200));
    }

    return true;
  }

  Future clearDB() async {
    await db?.remove({}); //  Remove all entries from the database.
  }

  Future<void> _symbolDBReady() async {
    if ((await numberOfSymbols) == 0) {
      await _getSymbolList(true);
    }
    var numSymbols = await this.numberOfSymbols;
    while (numSymbols < 1000) {
      Future.delayed(Duration(milliseconds: 200));
      numSymbols = await this.numberOfSymbols;
    }
    return;
  }

  Future<int> get numberOfSymbols async {
    int s = (await db?.find({}))?.length;
    return s ?? 0;
  }

  Future<String> getNameBySymbol(String symbol) async {
    await _symbolDBReady();
    var coList = await db.find({'symbol': symbol.toUpperCase()});
    if (coList.isEmpty) return null;
    return coList[0]['name'];
  }

  Future<void> _getSymbolList(bool checkExpired) async {
    await dbIsOpen;

    int updatedDaysAgo = -1;
    int len = (await db?.find({}))?.length;

    if (checkExpired && len > 0)
      updatedDaysAgo = DateTime.now()
          .difference(DateTime.parse((await db.first({}))['date']))
          .inDays;

    if (updatedDaysAgo >= 0 && updatedDaysAgo < 7) return;

    clearDB();

    var jsonObject = await ts.getSymbolList();
    await db.insertMany(jsonObject.getJSONMap());
  }
}
