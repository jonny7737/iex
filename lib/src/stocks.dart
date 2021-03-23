import 'dart:io';

import 'package:iex/iex.dart';
import 'package:objectdb/objectdb.dart';
// ignore: implementation_imports
import 'package:objectdb/src/objectdb_storage_filesystem.dart';
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

  int numSymbols;

  _init(String serviceEndPoint) async {
    ts = IEX(serviceEndPoint);

    // await Future.microtask(() async {
    //   db = ObjectDB(InMemoryStorage());
    // });

    await Future.microtask(() async {
      Directory appDocDir = await getApplicationDocumentsDirectory();
      String dbFilePath = [appDocDir.path, 'symbols.db'].join('/');
      db = ObjectDB(FileSystemStorage(dbFilePath));
    });

    initED = true;
  }

  Future<bool> get dbIsOpen async {
    while (db == null) {
      await Future.delayed(Duration(milliseconds: 100));
    }

    return true;
  }

  Future clearDB() async {
    await db?.remove({}); //  Remove all entries from the database.
  }

  Future<void> _symbolDBReady() async {
    await dbIsOpen;
    int numSymbols = await numberOfSymbols;
    if (numSymbols == 0) {
      // print('No symbols in list [$numSymbols]');
      await _getSymbolList(true);
    }
    return;
  }

  Future<int> get numberOfSymbols async {
    await dbIsOpen;
    if (numSymbols == null || numSymbols == 0) {
      // DateTime start = DateTime.now();
      int s = (await db.find({})).length;
      // int duration = DateTime.now().difference(start).inMilliseconds;
      // print('Time to # of symbols: $duration mS');
      numSymbols = s;
      // print('s = $s');
    }
    return numSymbols ?? 0;
  }

  Future<String> getNameBySymbol(String symbol) async {
    // DateTime start = DateTime.now();
    await _symbolDBReady();
    // int runTime = DateTime.now().difference(start).inMilliseconds;
    // print('Time to symbol DB ready[includes time to #symbols: $runTime mS');

    // start = DateTime.now();
    var coList = await db.find({'symbol': symbol.toUpperCase()});
    // runTime = DateTime.now().difference(start).inMilliseconds;
    // print('Time to find [$symbol]: $runTime mS');

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
