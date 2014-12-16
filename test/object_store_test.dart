library object_store_test;

import 'package:idb_shim/idb_client.dart';
import 'package:idb_shim/src/common/common_value.dart';
import 'idb_test_common.dart';
//import 'idb_test_factory.dart';


// so that this can be run directly
//void main() {
//  testMain(new IdbMemoryFactory());
//}

void testMain(IdbFactory idbFactory) {

  group('object_store', () {
    group('failure', () {

      setUp(() {
        return idbFactory.deleteDatabase(DB_NAME);
      });

      test('create object store not in initialize', () {

        return idbFactory.open(DB_NAME).then((Database database) {
          try {
            ObjectStore objectStore = database.createObjectStore(STORE_NAME, autoIncrement: true);
          } catch (e) {
            //print(e.runtimeType);
            database.close();
            return;
          }
          fail("should fail");
        });
      });


    });

    group('non auto', () {

      Database db;
      Transaction transaction;
      ObjectStore objectStore;

      _createTransaction() {
        transaction = db.transaction(STORE_NAME, IDB_MODE_READ_WRITE);
        objectStore = transaction.objectStore(STORE_NAME);
      }

      setUp(() {
        return idbFactory.deleteDatabase(DB_NAME).then((_) {
          void _initializeDatabase(VersionChangeEvent e) {
            Database db = e.database;
            ObjectStore objectStore = db.createObjectStore(STORE_NAME);
          }
          return idbFactory.open(DB_NAME, version: 1, onUpgradeNeeded: _initializeDatabase).then((Database database) {
            db = database;
            _createTransaction();
            return db;

          });
        });
      });

      tearDown(() {
        runZoned(() {});
        if (db != null) {
          if (transaction != null) {
            return transaction.completed.then((_) {
              db.close();
            });
          } else {
            db.close();
          }
        }

      });


      // Good first test
      //          test('add', () {
      //            Map value = {};
      //            return objectStore.add(value).then((key) {
      //              expect(key, 1);
      //            });
      //          });
      //
      //          test('add2', () {
      //            Map value = {};
      //            return objectStore.add(value).then((key) {
      //              expect(key, 1);
      //            }).then((_) {
      //              return objectStore.add(value).then((key) {
      //                expect(key, 2);
      //              });
      //            });
      //          });
      //
      //          test('add with key and next', () {
      //            Map value = {};
      //            return objectStore.add(value, 1234).then((key) {
      //              expect(key, 1234);
      //            }).then((_) {
      //              return objectStore.add(value).then((key) {
      //                expect(key, 1235);
      //              });
      //            });
      //          });
      //
      //          // limitation, this crashes everywhere
      //          skip_test('add with same key', () {
      //            Map value = {};
      //            return objectStore.add(value, 1234).then((key) {
      //              expect(key, 1234);
      //            }).then((_) {
      //              return objectStore.add(value, 1234).then((key) {
      //                fail("should fail");
      //              }, onError: (e) {
      //                print(e.message);
      //              });
      //            });
      //          });
      //
      //          test('add with key then back', () {
      //            Map value = {};
      //            return objectStore.add(value, 1234).then((key) {
      //              expect(key, 1234);
      //            }).then((_) {
      //              return objectStore.add(value, 1232).then((key) {
      //                expect(key, 1232);
      //              });
      //            }).then((_) {
      //              return objectStore.add(value).then((key) {
      //                expect(key, 1235);
      //              });
      //            });
      //          });
      //
      //
      //          // limitation
      //          skip_test('add with text number key and next', () {
      //            Map value = {};
      //            return objectStore.add(value, "2").then((key) {
      //              expect(key, "2");
      //            }).then((_) {
      //              return objectStore.add(value).then((key) {
      //                expect(key, 1);
      //              });
      //            });
      //          });
      //
      //          // limitation
      //          skip_test('add with text key and next', () {
      //            Map value1 = {
      //              'test': 1
      //            };
      //            Map value2 = {
      //              'test': 2
      //            };
      //            return objectStore.add(value1, "test").then((key) {
      //              expect(key, "test");
      //            }).then((_) {
      //              return objectStore.add(value2).then((key) {
      //                expect(key, 1);
      //              });
      //            }).then((_) {
      //              return objectStore.getObject(1).then((valueRead) {
      //                expect(valueRead, value2);
      //              });
      //            }).then((_) {
      //              return objectStore.getObject('test').then((valueRead) {
      //                expect(valueRead, value1);
      //              });
      //            });
      //          });
      test('properties', () {
        expect(objectStore.keyPath, null);
        expect(objectStore.autoIncrement, false);
      });

      test('add/get map', () {
        Map value = {};
        return objectStore.add(value, 123).then((key) {
          expect(key, 123);
          return objectStore.getObject(key).then((Map readValue) {
            expect(readValue, value);
          });
        });
      });

      // not working in js firefox
      test('add_twice_same_key', () {
        Map value = {};
        return objectStore.add(value, 123).then((key) {
          expect(key, 123);
          return transaction.completed.then((_) {
            _createTransaction();
            return objectStore.add(value, 123).then((_) {}, onError: (DatabaseError e) {
              transaction = null;
            }).then((_) {
              expect(transaction, null);
            });
          });

        });

      });

      test('add/get string', () {
        String value = "4567";
        return objectStore.add(value, 123).then((key) {
          expect(key, 123);
          return objectStore.getObject(key).then((String readValue) {
            expect(readValue, value);
          });
        });
      });
    });
    group('auto', () {

      Database db;
      Transaction transaction;
      ObjectStore objectStore;

      setUp(() {
        return idbFactory.deleteDatabase(DB_NAME).then((_) {
          void _initializeDatabase(VersionChangeEvent e) {
            Database db = e.database;
            ObjectStore objectStore = db.createObjectStore(STORE_NAME, autoIncrement: true);
          }
          return idbFactory.open(DB_NAME, version: 1, onUpgradeNeeded: _initializeDatabase).then((Database database) {
            db = database;
            transaction = db.transaction(STORE_NAME, IDB_MODE_READ_WRITE);
            objectStore = transaction.objectStore(STORE_NAME);
            return db;

          });
        });
      });

      tearDown(() {
        db.close();
      });


      test('properties', () {
        expect(objectStore.keyPath, null);
        expect(objectStore.autoIncrement, true);
      });

      // Good first test
      test('add', () {
        Map value = {};
        return objectStore.add(value).then((key) {
          expect(key, 1);
        });
      });

      test('add2', () {
        Map value = {};
        return objectStore.add(value).then((key) {
          expect(key, 1);
        }).then((_) {
          return objectStore.add(value).then((key) {
            expect(key, 2);
          });
        });
      });

      test('add with key and next', () {
        Map value = {};
        return objectStore.add(value, 1234).then((key) {
          expect(key, 1234);
        }).then((_) {
          return objectStore.add(value).then((key) {
            expect(key, 1235);
          });
        });
      });

      // limitation, this crashes everywhere
      tk_skip_test('add with same key', () {
        Map value = {};
        return objectStore.add(value, 1234).then((key) {
          expect(key, 1234);
        }).then((_) {
          return objectStore.add(value, 1234).then((key) {
            fail("should fail");
          }, onError: (e) {
            print(e.message);
          });
        });
      });

      test('add with key then back', () {
        Map value = {};
        return objectStore.add(value, 1234).then((key) {
          expect(key, 1234);
        }).then((_) {
          return objectStore.add(value, 1232).then((key) {
            expect(key, 1232);
          });
        }).then((_) {
          return objectStore.add(value).then((key) {
            expect(key, 1235);
          });
        });
      });


      // limitation
      tk_skip_test('add with text number key and next', () {
        Map value = {};
        return objectStore.add(value, "2").then((key) {
          expect(key, "2");
        }).then((_) {
          return objectStore.add(value).then((key) {
            expect(key, 1);
          });
        });
      });

      // limitation
      tk_skip_test('add with text key and next', () {
        Map value1 = {
          'test': 1
        };
        Map value2 = {
          'test': 2
        };
        return objectStore.add(value1, "test").then((key) {
          expect(key, "test");
        }).then((_) {
          return objectStore.add(value2).then((key) {
            expect(key, 1);
          });
        }).then((_) {
          return objectStore.getObject(1).then((valueRead) {
            expect(valueRead, value2);
          });
        }).then((_) {
          return objectStore.getObject('test').then((valueRead) {
            expect(valueRead, value1);
          });
        });
      });

      test('get', () {
        Map value = {};
        return objectStore.add(value).then((key) {
          return objectStore.getObject(key).then((Map value) {
            expect(value.length, 0);
          });
        });
      });

      test('simple get', () {
        Map value = {
          'test': 'test_value'
        };
        return objectStore.add(value).then((key) {
          return objectStore.getObject(key).then((Map valueRead) {
            expect(value, valueRead);
          });
        });
      });

      test('get dummy', () {
        Map value = {};
        return objectStore.add(value).then((key) {
          return objectStore.getObject(key + 1).then((value) {
            expect(value, null);
          });
        });
      });

      test('get empty', () {
        Map value = {};
        return objectStore.getObject(1234).then((value) {
          expect(value, null);
        });
      });

      test('count', () {
        Map value = {};
        return objectStore.add(value).then((_) {
          return objectStore.count().then((int count) {
            print(count);
            expect(count, 1);
          });
        });
      });

      test('count by key', () {
        Map value = {};
        return objectStore.add(value).then((key1) {
          return objectStore.add(value).then((key2) {
            return objectStore.count(key1).then((int count) {
              expect(count, 1);
              return objectStore.count(key2).then((int count) {
                expect(count, 1);
              });
            });
          });
        });
      });


      test('count by range', () {
        Map value = {};
        return objectStore.add(value).then((key1) {
          return objectStore.add(value).then((key2) {
            return objectStore.count(new KeyRange.lowerBound(key1, true)).then((int count) {
              expect(count, 1);
              return objectStore.count(new KeyRange.lowerBound(key1)).then((int count) {
                expect(count, 2);
              });
            });
          });
        });
      });

      test('count empty', () {
        return objectStore.count().then((int count) {
          expect(count, 0);
        });
      });

      test('delete', () {
        Map value = {};
        return objectStore.add(value).then((key) {
          return objectStore.delete(key).then((_) {
            return objectStore.getObject(key).then((value) {
              expect(value, null);
            });
          });
        });
      });

      test('delete empty', () {
        return objectStore.getObject(1234).then((value) {
          expect(value, null);
        });
      });

      test('delete dummy', () {
        Map value = {
          'test': 'test_value'
        };
        return objectStore.add(value).then((key) {
          return objectStore.delete(key + 1).then((delete_result) {
            // check fist one still here
            return objectStore.getObject(key).then((Map valueRead) {
              expect(value, valueRead);
            });
          });
        });
      });

      test('simple update', () {
        Map value = {
          'test': 'test_value'
        };
        return objectStore.add(value).then((key) {
          return objectStore.getObject(key).then((Map valueRead) {
            expect(value, valueRead);
            value['test'] = 'new_value';
            return objectStore.put(value, key).then((putResult) {
              expect(putResult, key);
              return objectStore.getObject(key).then((Map valueRead2) {
                expect(valueRead2, value);
                expect(valueRead2, isNot(equals(valueRead)));
              });
            });
          });
        });
      });

      test('update empty', () {
        Map value = {};
        return objectStore.put(value, 1234).then((value) {
          expect(value, 1234);
        });
      });

      test('update dummy', () {
        Map value = {
          'test': 'test_value'
        };
        return objectStore.add(value).then((key) {
          Map newValue = cloneValue(value);
          newValue['test'] = 'new_value';
          return objectStore.put(newValue, key + 1).then((delete_result) {
            // check fist one still here
            return objectStore.getObject(key).then((Map valueRead) {
              expect(value, valueRead);
            });
          });
        });
      });

      test('clear', () {
        Map value = {};
        return objectStore.add(value).then((key) {
          return objectStore.clear().then((clearResult) {
            expect(clearResult, null);

            return objectStore.getObject(key).then((value) {
              expect(value, null);
            });
          });
        });
      });

      test('clear empty', () {
        return objectStore.clear().then((clearResult) {
          expect(clearResult, null);
        });
      });
    });

    group('readonly', () {

      Database db;
      Transaction transaction;
      ObjectStore objectStore;

      setUp(() {
        return idbFactory.deleteDatabase(DB_NAME).then((_) {
          void _initializeDatabase(VersionChangeEvent e) {
            Database db = e.database;
            ObjectStore objectStore = db.createObjectStore(STORE_NAME, autoIncrement: true);
          }
          return idbFactory.open(DB_NAME, version: 1, onUpgradeNeeded: _initializeDatabase).then((Database database) {
            db = database;
            transaction = db.transaction(STORE_NAME, IDB_MODE_READ_ONLY);
            objectStore = transaction.objectStore(STORE_NAME);
            return db;

          });
        });
      });

      tearDown(() {
        return transaction.completed.then((_) {
          db.close();
        });
      });

      test('add', () {
        return objectStore.add({}, 1).catchError((e) {
          // There must be an error!
          return e;
        }).then((e) {
          expect(isTransactionReadOnlyError(e), isTrue);
        });
      });

      test('put', () {
        return objectStore.put({}, 1).catchError((e) {
          // There must be an error!
          return e;
        }).then((e) {
          expect(isTransactionReadOnlyError(e), isTrue);
        });
      });

      test('clear', () {
        return objectStore.clear().catchError((e) {
          // There must be an error!
          return e;
        }).then((e) {
          expect(isTransactionReadOnlyError(e), isTrue);
        });
      });

      test('delete', () {
        return objectStore.delete(1).catchError((e) {
          // There must be an error!
          return e;
        }).then((e) {
          expect(isTransactionReadOnlyError(e), isTrue);
        });
      });


    });

    group('key_path_auto', () {

      const String keyPath = "my_key";
      Database db;
      Transaction transaction;
      ObjectStore objectStore;

      setUp(() {
        return idbFactory.deleteDatabase(DB_NAME).then((_) {
          void _initializeDatabase(VersionChangeEvent e) {
            Database db = e.database;
            ObjectStore objectStore = db.createObjectStore(STORE_NAME, keyPath: keyPath, autoIncrement: true);
          }
          return idbFactory.open(DB_NAME, version: 1, onUpgradeNeeded: _initializeDatabase).then((Database database) {
            db = database;
            transaction = db.transaction(STORE_NAME, IDB_MODE_READ_WRITE);
            objectStore = transaction.objectStore(STORE_NAME);

          });
        });
      });

      tearDown(() {
        return transaction.completed.then((_) {
          db.close();
        });
      });

      test('properties', () {
        expect(objectStore.keyPath, keyPath);
        expect(objectStore.autoIncrement, true);
      });

      test('simple get', () {
        Map value = {
          'test': 'test_value'
        };
        return objectStore.add(value).then((key) {
          expect(key, 1);
          return objectStore.getObject(key).then((Map valueRead) {
            Map expectedValue = cloneValue(value);
            expectedValue[keyPath] = 1;
            expect(valueRead, expectedValue);
          });
        });
      });

      test('simple add with keyPath and next', () {
        Map value = {
          'test': 'test_value',
          keyPath: 123
        };
        return objectStore.add(value).then((key) {
          expect(key, 123);
          return objectStore.getObject(key).then((Map valueRead) {
            expect(value, valueRead);
          });
        }).then((_) {
          Map value = {
            'test': 'test_value',
          };
          return objectStore.add(value).then((key) {
            expect(key, 124);
          });

        });
      });

      test('put with keyPath', () {
        Map value = {
          'test': 'test_value',
          keyPath: 123
        };
        return objectStore.put(value).then((key) {
          expect(key, 123);
          return objectStore.getObject(key).then((Map valueRead) {
            expect(value, valueRead);
          });
        });
      });

      test('add key and keyPath', () {
        Map value = {
          'test': 'test_value',
          keyPath: 123
        };
        return objectStore.add(value, 123).then((_) {
          fail("should fail");
        }, onError: (e) {
          // "both key 123 and inline keyPath 123 are specified
          //devPrint(e);
        });
      });

      test('put key and keyPath', () {
        Map value = {
          'test': 'test_value',
          keyPath: 123
        };
        return objectStore.put(value, 123).then((_) {
          fail("should fail");
        }, onError: (e) {
          //print(e);
        });
      });
    });

    group('key path non auto', () {

      const String keyPath = "my_key";
      Database db;
      Transaction transaction;
      ObjectStore objectStore;

      setUp(() {
        return idbFactory.deleteDatabase(DB_NAME).then((_) {
          void _initializeDatabase(VersionChangeEvent e) {
            Database db = e.database;
            ObjectStore objectStore = db.createObjectStore(STORE_NAME, keyPath: keyPath);
          }
          return idbFactory.open(DB_NAME, version: 1, onUpgradeNeeded: _initializeDatabase).then((Database database) {
            db = database;
            transaction = db.transaction(STORE_NAME, IDB_MODE_READ_WRITE);
            objectStore = transaction.objectStore(STORE_NAME);

          });
        });
      });

      tearDown(() {
        if (transaction != null) {
          return transaction.completed.then((_) {
            db.close();
          });
        } else {
          db.close();
        }
      });

      test('properties', () {
        expect(objectStore.keyPath, keyPath);
        expect(objectStore.autoIncrement, false);
      });

      test('simple add_get', () {
        Map value = {
          keyPath: 'test_value'
        };
        return objectStore.add(value).then((key) {
          expect(key, 'test_value');
          return objectStore.getObject(key).then((Map valueRead) {
//               Map expectedValue = cloneValue(value);
//               expectedValue[keyPath] = 1;
            expect(valueRead, value);
          });
        });
      });

      test('simple put_get', () {
        Map value = {
          keyPath: 'test_value'
        };
        return objectStore.put(value).then((key) {
          expect(key, 'test_value');
          return objectStore.getObject(key).then((Map valueRead) {
//               Map expectedValue = cloneValue(value);
//               expectedValue[keyPath] = 1;
            expect(valueRead, value);
          });
        });
      });

      test('add_null', () {
        Map value = {
          "dummy": 'test_value'
        };
        return objectStore.add(value).catchError((DatabaseError e) {
          // There must be an error!
          return e;
        }).then((e) {
          //expect(isTransactionReadOnlyError(e), isTrue);
          //devPrint(e);
          // IdbMemoryError(3): neither keyPath nor autoIncrement set and trying to add object without key
          expect(e is DatabaseError, isTrue);
        });
      });

      test('put_null', () {
        Map value = {
          "dummy": 'test_value'
        };
        return objectStore.put(value).catchError((DatabaseError e) {
          // There must be an error!
          return e;
        }).then((e) {
          //expect(isTransactionReadOnlyError(e), isTrue);
          //devPrint(e);
          expect(e is DatabaseError, isTrue);
        });
      });

      test('add_twice', () {
        Map value = {
          keyPath: 'test_value'
        };
        return objectStore.add(value).then((key) {
          expect(key, 'test_value');
          return objectStore.add(value).catchError((DatabaseError e) {
            // There must be an error!
            return e;
          }).then((e) {
            //expect(isTransactionReadOnlyError(e), isTrue);
            //devPrint(e);
            expect(e is DatabaseError, isTrue);

            // in native completed will never succeed so remove it
            transaction = null;
          });
        });
      });

      // put twice should be fine
      test('put_twice', () {
        Map value = {
          keyPath: 'test_value'
        };
        return objectStore.put(value).then((key) {
          expect(key, 'test_value');
          return objectStore.put(value).then((key) {
            // There must be only one item
            //return e;
            return objectStore.count().then((count) {
              expect(count, 1);
            });
          });
        });
      });

//      solo_test('simple add with keyPath and next', () {
//        Map value = {
//          'test': 'test_value',
//          keyPath: 123
//        };
//        return objectStore.add(value).then((key) {
//          expect(key, 123);
//          return objectStore.getObject(key).then((Map valueRead) {
//            expect(value, valueRead);
//          });
//        }).then((_) {
//          Map value = {
//            'test': 'test_value',
//          };
//          return objectStore.add(value).then((key) {
//            expect(key, 124);
//          });
//
//        });
//      });
//
//      test('put with keyPath', () {
//        Map value = {
//          'test': 'test_value',
//          keyPath: 123
//        };
//        return objectStore.put(value).then((key) {
//          expect(key, 123);
//          return objectStore.getObject(key).then((Map valueRead) {
//            expect(value, valueRead);
//          });
//        });
//      });
//
//      test('add key and keyPath', () {
//        Map value = {
//          'test': 'test_value',
//          keyPath: 123
//        };
//        return objectStore.add(value, 123).then((_) {
//          fail("should fail");
//        }, onError: (e) {
//
//        });
//      });
//
//      test('put key and keyPath', () {
//        Map value = {
//          'test': 'test_value',
//          keyPath: 123
//        };
//        return objectStore.put(value, 123).then((_) {
//          fail("should fail");
//        }, onError: (e) {
//          //print(e);
//        });
//      });
    });

    group('various', () {
      Database db;
      Transaction transaction;
      ObjectStore objectStore;
      setUp(() {
        return setUpSimpleStore(idbFactory).then((Database database) {
          db = database;
          transaction = db.transaction(STORE_NAME, IDB_MODE_READ_WRITE);
          objectStore = transaction.objectStore(STORE_NAME);
        });
      });

      tearDown(() {
        return transaction.completed.then((_) {
          db.close();
        });
      });

      test('delete', () {
        return objectStore.add("test").then((key) {
          return objectStore.delete(key).then((result) {
            expect(result, isNull);
          });
        });

      });
    });
  });
}
