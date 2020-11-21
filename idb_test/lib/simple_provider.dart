library simple_provider;

import 'dart:async';

import 'package:idb_shim/idb_client.dart';

const String dbName = 'com.tekartik.simple_provider';
const String storeName = 'test_store';

//const String testStoreName = 'test_store';
const String nameIndex = 'name_index';
const String nameField = 'name';

class SimpleRow {
  SimpleRow(CursorWithValue cwv) {
    final map = cwv.value as Map;
    name = map[nameField] as String?;
    id = cwv.primaryKey as int;
  }

  int? id;
  String? name;
}

class SimpleProvider {
  IdbFactory? idbFactory;
  Database? db;

  SimpleProvider(this.idbFactory);

  void _initializeDatabase(VersionChangeEvent e) {
    final db = (e.target as Request).result;

    var objectStore = db.createObjectStore(storeName, autoIncrement: true);
    objectStore.createIndex(nameIndex, nameField, unique: true);
  }

  Future add(String name) {
    var trans = db!.transaction(storeName, idbModeReadWrite);
    var store = trans.objectStore(storeName);

    var obj = {nameField: name};
    store.put(obj);
    //store.openCursor(key: NAME_FIELD).then((_) {
    return trans.completed;
    //});
  }

  Future<List<SimpleRow>> cursorToList(Stream<CursorWithValue> stream) {
    var completer = Completer<List<SimpleRow>>();
    final list = <SimpleRow>[];
    stream.listen((CursorWithValue cwv) {
      final row = SimpleRow(cwv);

      list.add(row);
      //cwv.advance(1);
    }).onDone(() {
      completer.complete(list);
    });
    return completer.future;
  }

  void close() {
    db!.close();
    db = null;
  }

  Future openEmpty() {
    return idbFactory!.deleteDatabase(dbName).then((_) {
      //done();
      return idbFactory!
          .open(dbName, version: 1, onUpgradeNeeded: _initializeDatabase)
          .then((Database db) {
        this.db = db;
      });
    });
  }

  Future openWith3SampleRows() {
    return openEmpty().then((_) {
      return add('test2').then((_) {
        return add('test1').then((_) {
          return add('test3');
        });
      });
    });
  }
}
