import 'dart:io';

// import 'package:iex/globals.dart';
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
    // print('File path: $dbFilePath');

    db = ObjectDB(dbFilePath);
    await db.open();
    //  Update StockInfo DB.
    _getSymbolList(await numberOfSymbols != 0);

    print('StockMeta inited');
    initED = true;
  }

  Future<bool> get isDBOpen async {
    int maxLoops = 10; // wait no more than 5 seconds for open db.
    while (db == null) {
      await Future.delayed(Duration(milliseconds: 500));
      maxLoops--;
      if (maxLoops < 0) return false;
    }
    return true;
  }

  Future clearDB() async {
    await db.remove({}); //  Remove all entries from the database.
  }

  Future<int> get numberOfSymbols async {
    if (!(await isDBOpen)) return null;
    return (await db?.first({})).length;
    // return (await db?.find({}))?.length;
  }

  Future<String> getNameBySymbol(String symbol) async {
    if (!(await isDBOpen)) return null;
    var coList = await db.find({'symbol': symbol.toUpperCase()});
    if (coList.isEmpty) return null;
    return coList[0]['name'];
  }

  void _getSymbolList(bool checkExpired) async {
    int updatedDaysAgo = -1;
    if (checkExpired)
      updatedDaysAgo = DateTime.now()
          .difference(DateTime.parse((await db.first({}))['date']))
          .inDays;

    // print('Days since last symbol list update: $updatedDaysAgo');
    if (updatedDaysAgo >= 0 && updatedDaysAgo < 7) return;

    // print('Getting symbol list from IEX.');
    var jsonObject = await ts.getSymbolList();
    // print('IEX symbols request returned.');
    await db.insertMany(jsonObject.getJSONMap());
    // print('Symbols inserted into DB: ${(await db.find({})).length}');

    // jsonObject.jsonListContents.forEach((s) {
    //   symbols.add(Symbols(
    //     s['symbol'],
    //     s['exchangeName'],
    //     s['name'],
    //     s['region'],
    //     s['currency'],
    //   ));
    // });

    // db?.close();
  }
}
