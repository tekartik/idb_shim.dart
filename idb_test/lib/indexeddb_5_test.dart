library idb_shim.test.indexeddb_5_test;

//import 'dart:async';
import 'package:idb_shim/idb_client.dart';

import 'idb_test_common.dart';
// so that this can be run directly

void main() {
  defineTests(idbMemoryContext);
}

void defineTests(TestContext ctx) {
  final idbFactory = ctx.factory;
  group('indexeddb_5', () {
    //useHtmlConfiguration();

    if (!IdbFactory.supported) {
      return;
    }

    var dbName = 'test_db_5';
    var storeName = 'test_store';
    var indexName = 'name_index';
    Database db;

    setUp(() {
      return idbFactory.deleteDatabase(dbName).then((_) {
        return idbFactory.open(dbName, version: 1, onUpgradeNeeded: (e) {
          var db = e.database;
          var objectStore =
              db.createObjectStore(storeName, autoIncrement: true);
          objectStore.createIndex(indexName, 'name_index', unique: false);
        });
      }).then((database) {
        db = database;
      });
    });

    tearDown(() {
      db.close();
    });

    if (idbFactory.supportsDatabaseNames) {
      test('getDatabaseNames', () {
        return idbFactory.getDatabaseNames().then((names) {
          //print(names);
          //print(dbName);
          var found = false;
          for (final name in names) {
            if (name == dbName) {
              found = true;
            }
          }
          expect(found, isTrue);
          // expect(names.contains(dbName), isTrue);
        });
      });
    }

    var value = {'name_index': 'one', 'value': 'add_value'};
    test('add/delete', () {
      //var done = expectAsync0(() {});
      var done = () {};
      var transaction = db.transaction(storeName, 'readwrite');
      var key;
      return transaction.objectStore(storeName).add(value).then((addedKey) {
        key = addedKey;
      }).then((_) {
        return transaction.completed;
      }).then((_) {
        transaction = db.transaction(storeName, 'readonly');
        return transaction.objectStore(storeName).getObject(key);
      }).then((readValue) {
        expect(readValue['value'], value['value']);
        return transaction.completed;
      }).then((_) {
        transaction = db.transactionList([storeName], 'readwrite');
        return transaction.objectStore(storeName).delete(key);
      }).then((_) {
        return transaction.completed;
      }).then((_) {
        var transaction = db.transactionList([storeName], 'readonly');

        // count() crashes on ie
        if (!ctx.isIdbIe) {
          return transaction.objectStore(storeName).count();
        } else {
          return 0;
        }
      }).then((count) {
        expect(count, 0);
      }).then((_) {
        done();
      });
    });

    test('clear/count', () {
      //var done = expectAsync0(() {});
      var done = () {};
      var transaction = db.transaction(storeName, 'readwrite');
      transaction.objectStore(storeName).add(value);

      return transaction.completed.then((_) {
        transaction = db.transaction(storeName, 'readonly');
        // count() crashes on ie
        if (!ctx.isIdbIe) {
          return transaction.objectStore(storeName).count();
        } else {
          return 1;
        }
      }).then((count) {
        expect(count, 1);
      }).then((_) {
        return transaction.completed;
      }).then((_) {
        transaction = db.transactionList([storeName], 'readwrite');
        transaction.objectStore(storeName).clear();
        return transaction.completed;
      }).then((_) {
        var transaction = db.transactionList([storeName], 'readonly');
        // count() crashes on ie
        if (!ctx.isIdbIe) {
          return transaction.objectStore(storeName).count();
        } else {
          return 0;
        }
      }).then((count) {
        expect(count, 0);
      }).then((_) {
        done();
      });
    });

    test('index', () {
      //var done = expectAsync0(() {});
      var done = () {};
      var transaction = db.transaction(storeName, 'readwrite');
      //transaction.objectStore(storeName).index(indexName);
      transaction.objectStore(storeName).add(value);
      transaction.objectStore(storeName).add(value);
      transaction.objectStore(storeName).add(value);
      transaction.objectStore(storeName).add(value);

      return transaction.completed.then((_) async {
        transaction = db.transactionList([storeName], 'readonly');
        var index = transaction.objectStore(storeName).index(indexName);

        // count() crashes on ie
        if (!ctx.isIdbIe) {
          return await index.count();
        } else {
          return 4;
        }
      }).then((int count) {
        expect(count, 4);
        return transaction.completed;
      }).then((_) {
        transaction = db.transaction(storeName, 'readonly');
        var index = transaction.objectStore(storeName).index(indexName);
        return index.openCursor(autoAdvance: true).length;
      }).then((cursorsLength) {
        expect(cursorsLength, 4);
        return transaction.completed;
      }).then((_) {
        transaction = db.transaction(storeName, 'readonly');
        var index = transaction.objectStore(storeName).index(indexName);
        return index.openKeyCursor(autoAdvance: true).length;
      }).then((cursorsLength) {
        expect(cursorsLength, 4);
        return transaction.completed;
      }).then((_) {
        transaction = db.transaction(storeName, 'readonly');
        var index = transaction.objectStore(storeName).index(indexName);
        return index.get('one');
      }).then((readValue) {
        expect(readValue['value'], value['value']);
        return transaction.completed;
      }).then((_) {
        transaction = db.transaction(storeName, 'readwrite');
        transaction.objectStore(storeName).clear();
        return transaction.completed;
      }).then((_) {
        done();
      });
    });

    var deleteValue = {'name_index': 'two', 'value': 'delete_value'};
    var updateValue = {'name_index': 'three', 'value': 'update_value'};
    var updatedValue = {'name_index': 'three', 'value': 'updated_value'};

    test('cursor', () {
      //var done = expectAsync0(() {});
      var done = () {};
      var transaction = db.transaction(storeName, 'readwrite');
      transaction.objectStore(storeName).add(value);
      transaction.objectStore(storeName).add(deleteValue);
      transaction.objectStore(storeName).add(updateValue);

      return transaction.completed.then((_) {
        transaction = db.transactionList([storeName], 'readwrite');
        var index = transaction.objectStore(storeName).index(indexName);
        var cursors = index.openCursor().asBroadcastStream();

        cursors.listen((cursor) {
          //print("cursor $cursor");
          var value = cursor.value as Map;
          if (value['value'] == 'delete_value') {
            cursor.delete().then((_) {
              cursor.next();
            });
          } else if (value['value'] == 'update_value') {
            cursor.update(updatedValue).then((_) {
              cursor.next();
            });
          } else {
            cursor.next();
          }
        });
        return cursors.last;
      }).then((_) {
        return transaction.completed;
      }).then((_) {
        transaction = db.transaction(storeName, 'readonly');
        var index = transaction.objectStore(storeName).index(indexName);
        return index.get('three');
      }).then((readValue) {
        expect(readValue['value'], 'updated_value');
        return transaction.completed;
      }).then((_) {
        transaction = db.transaction(storeName, 'readonly');
        var index = transaction.objectStore(storeName).index(indexName);
        return index.get('two');
      }).then((readValue) {
        expect(readValue, isNull);
        return transaction.completed;
      }).then((_) {
        done();
      });
    });
  });
}
