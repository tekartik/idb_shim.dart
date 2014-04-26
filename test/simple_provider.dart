library simple_provider;

import 'dart:async';
import 'package:idb_shim/idb_client.dart';


const String DB_NAME = 'com.tekartik.simple_provider';
const String STORE_NAME = 'test_store';

const String STORE = 'test_store';
const String NAME_INDEX = 'name_index';
const String NAME_FIELD = 'name';


class SimpleRow {
  SimpleRow(CursorWithValue cwv) {
    Object value = cwv.value;
    name = (value as Map)[NAME_FIELD];
    id = cwv.primaryKey;
  }
  int id;
  String name;
}

class SimpleProvider {
  IdbFactory idbFactory;
  Database db;
  
  SimpleProvider(this.idbFactory);
  
  void _initializeDatabase(VersionChangeEvent e) {
    Database db = (e.target as Request).result;
    
    var objectStore = db.createObjectStore(STORE,
        autoIncrement: true);
    Index index = objectStore.createIndex(NAME_INDEX, NAME_FIELD,
        unique: true);
  }
  
  Future add(String name) {
    var trans = db.transaction(STORE, IDB_MODE_READ_WRITE);
    var store = trans.objectStore(STORE);
    
    var obj = {
      NAME_FIELD: name
    };
    store.put(obj);
    //store.openCursor(key: NAME_FIELD).then((_) {
    return trans.completed;         
    //});
  }
  
  Future<List<SimpleRow>> cursorToList(Stream<CursorWithValue> stream) {
    Completer completer = new Completer();
    List<SimpleRow> list = new List();
    stream.listen((CursorWithValue cwv) {
      SimpleRow row = new SimpleRow(cwv);
     
      list.add(row);
      //cwv.advance(1);
    }).onDone(() {
      completer.complete(list);
    });
    return completer.future;
  }
  
  void close() {
    db.close();
    db = null;
  }
  
  Future openEmpty() {
    return idbFactory.deleteDatabase(DB_NAME).then((_) {
      //done();
      return idbFactory.open(DB_NAME, version: 1,
          onUpgradeNeeded: _initializeDatabase)
            .then((Database db) {
              this.db = db;
            });
    });
  }
  
  Future openWith3SampleRows() {
    return openEmpty()
        .then((_) {
          return add('test2')
              .then((_) {
                return add('test1')
                    .then((_) {
                      return add('test3');
                    });
              });
        });
  }
}
