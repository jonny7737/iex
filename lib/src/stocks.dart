import 'package:iex/iex.dart';
import 'package:iex/src/remote_logger.dart';
import 'package:objectdb/objectdb.dart';
// ignore: implementation_imports
import 'package:objectdb/src/objectdb_storage_in_memory.dart';

class StockInfo {
  StockInfo(this.symbol, this.exchange, this.name, this.region, this.currency);
  final String symbol;
  final String exchange;
  final String name;
  final String region;
  final String currency;
}

late ObjectDB db;

class StockMeta {
  StockMeta(String serviceEndPoint) {
    _init(serviceEndPoint);
  }

  RemoteLogger r = RemoteLogger();
  late IEX ts;
  bool initED = false;

  int numSymbols = 0;

  _init(String serviceEndPoint) async {
    ts = IEX(serviceEndPoint);

    await Future.microtask(() async {
      db = ObjectDB(InMemoryStorage());
      initED = true;
    });

    // await Future.microtask(() async {
    //   Directory appDocDir = await getApplicationDocumentsDirectory();
    //   String dbFilePath = [appDocDir.path, 'symbols.db'].join('/');
    //   db = ObjectDB(FileSystemStorage(dbFilePath));
    // });
  }

  Future<bool> get dbIsOpen async {
    // while (db == null) {
    //   await Future.delayed(Duration(milliseconds: 100));
    // }

    return initED;
  }

  Future clearDB() async {
    await db.remove({}); //  Remove all entries from the database.
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

  // static Future<int> numRecordsInDB(_) async {
  //   int s;
  //
  //   // r.log('s(0): $s [${db.hashCode}]');
  //
  //   List sList = await db.find({});
  //   s = sList.length;
  //
  //   // r.log('s(1): $s');
  //
  //   return s;
  // }

  Future<int> get numberOfSymbols async {
    await dbIsOpen;
    if (numSymbols == 0) {
      DateTime start = DateTime.now();

      List sList = await db.find({});
      int s = sList.length;

      if (s != 0) {
        int duration = DateTime.now().difference(start).inMilliseconds;
        r.log('Time to count $s symbols: $duration mS', StackTrace.current);
      }
      numSymbols = s;
    }
    return numSymbols;
  }

  Future<String> getNameBySymbol(String symbol) async {
    await _symbolDBReady();

    var coList = await db.find({'symbol': symbol.toUpperCase()});

    if (coList.isEmpty) return 'UnKnown';
    return coList[0]['name'];
  }

  Future<void> _getSymbolList(bool checkExpired) async {
    await dbIsOpen;

    int updatedDaysAgo = -1;
    int len = (await db.find({})).length;

    if (checkExpired && len > 0)
      updatedDaysAgo = DateTime.now()
          .difference(DateTime.parse((await db.first({}))['date']))
          .inDays;

    if (updatedDaysAgo >= 0 && updatedDaysAgo < 7) return;

    clearDB();

    var jsonObject = await ts.getSymbolList();

    dynamic jsonMap = jsonObject.getJSONMap();
    if (jsonMap is List) if (jsonMap[0]['error'] != null)
      r.log(jsonMap.toString());
    // else if (jsonMap['error'] != null) r.log(jsonMap.toString());

    await db.insertMany(jsonObject.getJSONMap());
  }

  Future<JSONObject> nextMarketOpen() async {
    return await ts.nextMarketOpen();
  }
}
