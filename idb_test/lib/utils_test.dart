library idb_shim.utils_test;

import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:idb_shim/idb_client.dart';
import 'package:idb_shim/utils/idb_import_export.dart';
import 'package:idb_shim/utils/idb_utils.dart';
import 'package:path/path.dart';

import 'database_test.dart';
import 'idb_test_common.dart';
//import 'idb_test_factory.dart';

void main() {
  defineTests(idbMemoryContext);
}

void defineTests(TestContext ctx) {
  final idbFactory = ctx.factory;

  Database? db;
  //Database dstDb;
  late String srcDbName;
  String? dstDbName;
  late String importedDbName;
  // prepare for test
  Future setupDeleteDb() async {
    srcDbName = ctx.dbName;
    dstDbName = 'dst_$srcDbName';
    importedDbName = 'imported_$srcDbName';
    await idbFactory.deleteDatabase(srcDbName);
  }

  void dbTearDown() {
    if (db != null) {
      db!.close();
      db = null;
    }
    /*
    if (dstDb != null) {
      dstDb.close();
      dstDb = null;
    }
    */
  }

  group('utils', () {
    Future dbCheckExportImport(Database db, Map expectedExport,
        Future Function(Database db) check) async {
      // export
      final export = await sdbExportDatabase(db);
      expect(export, expectedExport);

      // import
      var importedDb =
          await sdbImportDatabase(export, idbFactory, importedDbName);
      // The name might be relative...
      expect(importedDb.name.endsWith(importedDbName), isTrue);

      await check(importedDb);

      // re-export
      expect(await sdbExportDatabase(importedDb), expectedExport);

      importedDb.close();

      // re open
      importedDb = await idbFactory.open(importedDbName);
      await check(importedDb);
      importedDb.close();
    }

    group('copySchema', () {
      tearDown(dbTearDown);

      Future checkCopySchema(
          Database db, Future Function(Database db) check) async {
        final dstDb = await copySchema(db, idbFactory, dstDbName!);
        expect(dstDb.name, dstDbName);
        await check(dstDb);
        dstDb.close();
      }

      Future checkAll(Database db, Map expectedExport,
          Future Function(Database database) check) async {
        await check(db);
        await checkCopySchema(db, check);
        await dbCheckExportImport(db, expectedExport, check);
      }

      test('empty', () async {
        await setupDeleteDb();
        db = await idbFactory.open(srcDbName);

        Future dbCheck(Database db) async {
          expect(db.factory, idbFactory);
          expect(db.objectStoreNames.isEmpty, true);
          expect(basename(db.name).endsWith(basename(srcDbName)), isTrue);
          expect(db.version, 1);
        }

        await checkAll(
            db!,
            {
              'sembast_export': 1,
              'version': 1,
              'stores': [
                {
                  'name': '_main',
                  'keys': ['version'],
                  'values': [1]
                }
              ]
            },
            dbCheck);
      });

      test('import version 2 and reopen', () async {
        await setupDeleteDb();
        db = await idbFactory.open(srcDbName,
            version: 2, onUpgradeNeeded: (_) {});
        expect(db!.version, 2);
        final export = await sdbExportDatabase(db!);
        db!.close();

        // import
        var importedDb =
            await sdbImportDatabase(export, idbFactory, importedDbName);
        expect(importedDb.version, 2);
        //devPrint()
        final newExport = await sdbExportDatabase(db!);
        expect(newExport, export);
        importedDb.close();

        db = await idbFactory.open(importedDbName);
        expect(db!.version, 2);
      });

      test('empty idbVersion 2', () async {
        await setupDeleteDb();
        db = await idbFactory.open(srcDbName,
            version: 2, onUpgradeNeeded: (_) {});

        Future dbCheck(Database db) async {
          expect(db.factory, idbFactory);
          expect(db.objectStoreNames.isEmpty, true);
          expect(basename(db.name).endsWith(basename(srcDbName)), isTrue);
          expect(db.version, 2);
        }

        await checkAll(
            db!,
            {
              'sembast_export': 1,
              'version': 1,
              'stores': [
                {
                  'name': '_main',
                  'keys': ['version'],
                  'values': [2]
                }
              ]
            },
            dbCheck);
      });

      test('one_store', () async {
        await setupDeleteDb();

        void onUpgradeNeeded(VersionChangeEvent e) {
          final db = e.database;
          //ObjectStore objectStore =
          db.createObjectStore(testStoreName,
              keyPath: testNameField, autoIncrement: true);
        }

        db = await idbFactory.open(srcDbName,
            version: 2, onUpgradeNeeded: onUpgradeNeeded);

        Future dbCheck(Database db) async {
          expect(db.factory, idbFactory);
          expect(db.objectStoreNames, [testStoreName]);
          expect(basename(db.name).endsWith(basename(srcDbName)), isTrue);
          expect(db.version, 2);
          final txn = db.transaction(testStoreName, idbModeReadOnly);
          final store = txn.objectStore(testStoreName);
          expect(store.name, testStoreName);
          expect(store.keyPath, testNameField);

          // autoIncrement not supported on ie
          if (!ctx.isIdbIe) {
            expect(store.autoIncrement, isTrue);
          }
          expect(store.indexNames, isEmpty);
          await txn.completed;
        }

        final expectedExport = <String, Object?>{
          'sembast_export': 1,
          'version': 1,
          'stores': [
            {
              'name': '_main',
              'keys': ['store_test_store', 'stores', 'version'],
              'values': [
                {
                  'name': 'test_store',
                  'keyPath': 'name',
                  'autoIncrement': true
                },
                ['test_store'],
                2
              ]
            }
          ]
        };
        if (ctx.isIdbIe) {
          ((((expectedExport['stores'] as List)[0] as Map)['values'] as List)[2]
                  as Map)
              .remove('autoIncrement');
        }
        await checkAll(db!, expectedExport, dbCheck);
      });

      test('three_stores', () async {
        await setupDeleteDb();

        void onUpgradeNeeded(VersionChangeEvent e) {
          final db = e.database;
          //ObjectStore objectStore =
          db.createObjectStore('store3');
          db.createObjectStore('store1');
          db.createObjectStore('store2');
        }

        db = await idbFactory.open(srcDbName,
            version: 2, onUpgradeNeeded: onUpgradeNeeded);

        Future dbCheck(Database db) async {
          expect(db.factory, idbFactory);
          expect(
              const UnorderedIterableEquality<String>()
                  .equals(db.objectStoreNames, ['store1', 'store2', 'store3']),
              isTrue,
              reason: '${db.objectStoreNames}');
        }

        final expectedExport = <String, Object?>{
          'sembast_export': 1,
          'version': 1,
          'stores': [
            {
              'name': '_main',
              'keys': [
                'store_store1',
                'store_store2',
                'store_store3',
                'stores',
                'version'
              ],
              'values': [
                {'name': 'store1'},
                {'name': 'store2'},
                {'name': 'store3'},
                ['store1', 'store2', 'store3'],
                2
              ]
            }
          ]
        };
        if (ctx.isIdbIe) {
          ((((expectedExport['stores'] as List)[0] as Map)['values'] as List)[2]
                  as Map)
              .remove('autoIncrement');
        }
        await checkAll(db!, expectedExport, dbCheck);
      });

      test('one_index', () async {
        await setupDeleteDb();

        void onUpgradeNeeded(VersionChangeEvent e) {
          final db = e.database;
          final objectStore =
              db.createObjectStore(testStoreName, autoIncrement: true);
          objectStore.createIndex(testNameIndex, testNameField,
              unique: true, multiEntry: true);
        }

        db = await idbFactory.open(srcDbName,
            version: 3, onUpgradeNeeded: onUpgradeNeeded);

        Future dbCheck(Database db) async {
          expect(db.version, 3);
          final txn = db.transaction(testStoreName, idbModeReadOnly);
          final store = txn.objectStore(testStoreName);
          expect(store.indexNames, [testNameIndex]);
          final index = store.index(testNameIndex);
          expect(index.name, testNameIndex);
          expect(index.keyPath, testNameField);
          expect(index.unique, isTrue);

          // multiEntry not supported on ie
          if (!ctx.isIdbIe) {
            expect(index.multiEntry, isTrue);
          }
          await txn.completed;
        }

        final expectedExport = <String, Object?>{
          'sembast_export': 1,
          'version': 1,
          'stores': [
            {
              'name': '_main',
              'keys': ['store_test_store', 'stores', 'version'],
              'values': [
                {
                  'name': 'test_store',
                  'autoIncrement': true,
                  'indecies': [
                    {
                      'name': 'name_index',
                      'keyPath': 'name',
                      'unique': true,
                      'multiEntry': true
                    }
                  ]
                },
                ['test_store'],
                3
              ]
            }
          ]
        };
        if (ctx.isIdbIe) {
          ((((expectedExport['stores'] as List)[0] as Map)['values'] as List)[2]
                  as Map)
              .remove('autoIncrement');
          ((((((expectedExport['stores'] as List)[0] as Map)['values']
                  as List)[2] as Map)['indecies'] as List)[0] as Map)
              .remove('multiEntry');
        }
        await checkAll(db!, expectedExport, dbCheck);
      });

      test('one_index_key_path_2_columns', () async {
        await setupDeleteDb();

        void onUpgradeNeeded(VersionChangeEvent e) {
          final db = e.database;
          final objectStore =
              db.createObjectStore(testStoreName, autoIncrement: true);
          objectStore.createIndex(
              testNameIndex, [testNameField, testNameField2],
              unique: true);
        }

        db = await idbFactory.open(srcDbName,
            version: 1, onUpgradeNeeded: onUpgradeNeeded);

        Future dbCheck(Database db) async {
          expect(db.version, 1);
          final txn = db.transaction(testStoreName, idbModeReadOnly);
          final store = txn.objectStore(testStoreName);
          expect(store.indexNames, [testNameIndex]);
          final index = store.index(testNameIndex);
          expect(index.name, testNameIndex);
          expect(index.keyPath, [testNameField, testNameField2]);
          expect(index.unique, isTrue);

          // multiEntry not supported on ie
          if (!ctx.isIdbIe) {
            expect(index.multiEntry, isFalse);
          }
          await txn.completed;
        }

        final expectedExport = <String, Object?>{
          'sembast_export': 1,
          'version': 1,
          'stores': [
            {
              'name': '_main',
              'keys': ['store_test_store', 'stores', 'version'],
              'values': [
                {
                  'name': 'test_store',
                  'autoIncrement': true,
                  'indecies': [
                    {
                      'name': 'name_index',
                      'keyPath': ['name', 'name_2'],
                      'unique': true,
                    }
                  ]
                },
                ['test_store'],
                1
              ]
            }
          ]
        };
        if (ctx.isIdbIe) {
          ((((expectedExport['stores'] as List)[0] as Map)['values'] as List)[2]
                  as Map)
              .remove('autoIncrement');
          ((((((expectedExport['stores'] as List)[0] as Map)['values']
                  as List)[2] as Map)['indecies'] as List)[0] as Map)
              .remove('multiEntry');
        }
        await checkAll(db!, expectedExport, dbCheck);
      });

      test('two_indecies', () async {
        await setupDeleteDb();

        void onUpgradeNeeded(VersionChangeEvent e) {
          final db = e.database;
          final objectStore =
              db.createObjectStore(testStoreName, autoIncrement: true);
          objectStore.createIndex(testNameIndex2, testNameField2,
              unique: false, multiEntry: true);
          objectStore.createIndex(testNameIndex, testNameField,
              unique: true, multiEntry: true);
        }

        db = await idbFactory.open(srcDbName,
            version: 4, onUpgradeNeeded: onUpgradeNeeded);

        Future dbCheck(Database db) async {
          expect(db.version, 4);
          final txn = db.transaction(testStoreName, idbModeReadOnly);
          final store = txn.objectStore(testStoreName);
          expect(
              const UnorderedIterableEquality<String>()
                  .equals(store.indexNames, [testNameIndex2, testNameIndex]),
              isTrue,
              reason:
                  '${store.indexNames} vs ${[testNameIndex2, testNameIndex]}');
          final index = store.index(testNameIndex);
          expect(index.name, testNameIndex);
          expect(index.keyPath, testNameField);
          expect(index.unique, isTrue);

          // multiEntry not supported on ie
          if (!ctx.isIdbIe) {
            expect(index.multiEntry, isTrue);
          }
          await txn.completed;
        }

        final expectedExport = <String, Object?>{
          'sembast_export': 1,
          'version': 1,
          'stores': [
            {
              'name': '_main',
              'keys': ['store_test_store', 'stores', 'version'],
              'values': [
                {
                  'name': 'test_store',
                  'autoIncrement': true,
                  'indecies': [
                    {
                      'name': 'name_index',
                      'keyPath': 'name',
                      'unique': true,
                      'multiEntry': true
                    },
                    {
                      'name': 'name_index_2',
                      'keyPath': 'name_2',
                      'multiEntry': true
                    }
                  ]
                },
                ['test_store'],
                4
              ]
            }
          ]
        };
        if (ctx.isIdbIe) {
          ((((expectedExport['stores'] as List)[0] as Map)['values'] as List)[2]
                  as Map)
              .remove('autoIncrement');
          ((((((expectedExport['stores'] as List)[0] as Map)['values']
                  as List)[2] as Map)['indecies'] as List)[0] as Map)
              .remove('multiEntry');
        }
        await checkAll(db!, expectedExport, dbCheck);
      });
    });

    group('copyStore', () {
      tearDown(dbTearDown);

      Future dbCheckCopyStore(
          Database srcDatabase,
          String srcStoreName,
          Database dstDatabase,
          String dstStoreName,
          Future Function(Database database, String name) check) async {
        await check(srcDatabase, srcStoreName);
        await copyStore(srcDatabase, srcStoreName, dstDatabase, dstStoreName);
        await check(dstDatabase, dstStoreName);
      }

      test('empty', () async {
        await setupDeleteDb();

        void onUpgradeNeeded(VersionChangeEvent e) {
          final db = e.database;
          //ObjectStore objectStore =
          db.createObjectStore(testStoreName);
          db.createObjectStore(testStoreName2);
        }

        db = await idbFactory.open(srcDbName,
            version: 1, onUpgradeNeeded: onUpgradeNeeded);

        Future dbCheck(Database db, String storeName) async {
          final txn = db.transaction(storeName, idbModeReadOnly);
          final store = txn.objectStore(storeName);

          // count() not supported on ie
          if (!ctx.isIdbIe) {
            expect(await store.count(), 0);
          }
          await txn.completed;
        }

        await dbCheckCopyStore(
            db!, testStoreName, db!, testStoreName2, dbCheck);
      });

      test('two_stores_one_record_each', () async {
        // fake multi store transaction on safari ctx.isIdbSafari;
        await setupDeleteDb();

        void onUpgradeNeeded(VersionChangeEvent e) {
          final db = e.database;
          //ObjectStore objectStore =
          db.createObjectStore(testStoreName);
          db.createObjectStore(testStoreName2);
        }

        db = await idbFactory.open(srcDbName,
            version: 1, onUpgradeNeeded: onUpgradeNeeded);

        // put one in src and one in dst that should get deleted
        final txn =
            db!.transaction([testStoreName, testStoreName2], idbModeReadWrite);
        var store = txn.objectStore(testStoreName);
        await (store.put('value1', 'key1'));
        final store2 = txn.objectStore(testStoreName2);
        await (store2.put('value2', 'key2'));
        await txn.completed;

        Future dbCheck(Database db, String storeName) async {
          final txn = db.transaction(storeName, idbModeReadOnly);
          store = txn.objectStore(storeName);
          expect(await store.getObject('key1'), 'value1');
          if (!ctx.isIdbIe) {
            expect(await store.count(), 1);
          }

          await txn.completed;
        }

        await dbCheckCopyStore(
            db!, testStoreName, db!, testStoreName2, dbCheck);
      });
    });

    group('copyDatabase', () {
      tearDown(dbTearDown);

      Future checkCopyDatabase(
          Database db, Future Function(Database database) check) async {
        final dstDb = await copyDatabase(db, idbFactory, dstDbName!);
        expect(dstDb.name, dstDbName);
        await check(dstDb);
        dstDb.close();
      }

      Future checkAll(Database db, Map expectedExport,
          Future Function(Database database) check) async {
        await check(db);
        await checkCopyDatabase(db, check);
        await dbCheckExportImport(db, expectedExport, check);
      }

      test('empty', () async {
        await setupDeleteDb();
        db = await idbFactory.open(srcDbName);

        Future dbCheck(Database db) async {
          expect(db.factory, idbFactory);
          expect(db.objectStoreNames.isEmpty, true);
          expect(basename(db.name).endsWith(basename(srcDbName)), isTrue);
          expect(db.version, 1);
        }

        await checkAll(
            db!,
            {
              'sembast_export': 1,
              'version': 1,
              'stores': [
                {
                  'name': '_main',
                  'keys': ['version'],
                  'values': [1]
                }
              ]
            },
            dbCheck);
      });

      test('all_types', () async {
        await setupDeleteDb();

        void onUpgradeNeeded(VersionChangeEvent e) {
          final db = e.database;
          db.createObjectStore(testStoreName);
        }

        db = await idbFactory.open(srcDbName,
            version: 1, onUpgradeNeeded: onUpgradeNeeded);
        final txn = db!.transaction(testStoreName, idbModeReadWrite);
        final store = txn.objectStore(testStoreName);
        var map = {
          'my_bool': true,
          'my_date': DateTime.utc(2020, DateTime.october, 27, 13, 14, 15, 999),
          'my_int': 1,
          'my_double': 1.5,
          'my_blob': Uint8List.fromList([1, 2, 3]),
          'my_string': 'some text',
          'my_list': [4, 5, 6],
          'my_map': {'sub': 73},
          'my_complex': [
            {
              'sub': [
                {
                  'inner': [7, 8, 9]
                }
              ]
            }
          ],
        };
        await store.put(map, 'my_key');
        await txn.completed;
        Future dbCheck(Database db) async {
          expect(db.factory, idbFactory);
          expect(db.objectStoreNames, [testStoreName]);
          expect(basename(db.name).endsWith(basename(srcDbName)), isTrue);
          expect(db.version, 1);
          final txn = db.transaction(testStoreName, idbModeReadOnly);
          final store = txn.objectStore(testStoreName);
          expect(store.name, testStoreName);
          expect(store.keyPath, isNull);

          expect(store.indexNames, isEmpty);
          expect(await store.getObject('my_key'), map);
          await txn.completed;
        }

        final expectedExport = <String, Object?>{
          'sembast_export': 1,
          'version': 1,
          'stores': [
            {
              'name': '_main',
              'keys': ['store_test_store', 'stores', 'version'],
              'values': [
                {'name': 'test_store'},
                ['test_store'],
                1
              ]
            },
            {
              'name': 'test_store',
              'keys': ['my_key'],
              'values': [
                {
                  'my_bool': true,
                  'my_date': {'@Timestamp': '2020-10-27T13:14:15.999Z'},
                  'my_int': 1,
                  'my_double': 1.5,
                  'my_blob': {'@Blob': 'AQID'},
                  'my_string': 'some text',
                  'my_list': [4, 5, 6],
                  'my_map': {'sub': 73},
                  'my_complex': [
                    {
                      'sub': [
                        {
                          'inner': [7, 8, 9]
                        }
                      ]
                    }
                  ]
                }
              ]
            }
          ]
        };
        await dbCheckExportImport(db!, expectedExport, dbCheck);
      }, skip: tmpSkipForNativeWeb);

      // safari does not support multiple stores - fakes
      test('two_store_two_and_one_records', () async {
        await setupDeleteDb();

        void onUpgradeNeeded(VersionChangeEvent e) {
          final db = e.database;
          //ObjectStore objectStore =
          db.createObjectStore(testStoreName);
          db.createObjectStore(testStoreName2);
        }

        db = await idbFactory.open(srcDbName,
            version: 1, onUpgradeNeeded: onUpgradeNeeded);

        // put one in src and one in dst that should get deleted
        final txn =
            db!.transaction([testStoreName, testStoreName2], idbModeReadWrite);
        var store = txn.objectStore(testStoreName);
        // Put 2 before to check the order
        await (store.put('value2', 'key2'));
        await (store.put('value1', 'key1'));
        store = txn.objectStore(testStoreName2);
        // Put 2 before to check the order
        await (store.put('value3', 'key3'));

        await txn.completed;

        //dstDb = await copyDatabase(db, idbFactory, _dstDbName);

        Future dbCheck(Database db) async {
          final txn =
              db.transaction([testStoreName, testStoreName2], idbModeReadOnly);
          store = txn.objectStore(testStoreName);
          expect(await store.getObject('key1'), 'value1');
          expect(await store.getObject('key2'), 'value2');

          if (!ctx.isIdbIe) {
            expect(await store.count(), 2);
          }
          var store2 = txn.objectStore(testStoreName2);
          expect(await store2.getObject('key3'), 'value3');
          if (!ctx.isIdbIe) {
            expect(await store2.count(), 1);
          }
          await txn.completed;
        }

        await checkAll(
            db!,
            {
              'sembast_export': 1,
              'version': 1,
              'stores': [
                {
                  'name': '_main',
                  'keys': [
                    'store_test_store',
                    'store_test_store_2',
                    'stores',
                    'version'
                  ],
                  'values': [
                    {'name': 'test_store'},
                    {'name': 'test_store_2'},
                    ['test_store', 'test_store_2'],
                    1
                  ]
                },
                {
                  'name': 'test_store',
                  'keys': ['key1', 'key2'],
                  'values': ['value1', 'value2']
                },
                {
                  'name': 'test_store_2',
                  'keys': ['key3'],
                  'values': ['value3']
                }
              ]
            },
            dbCheck);
      });

      // safari does not support multiple stores - fakes
      test('one composite record', () async {
        await setupDeleteDb();

        void onUpgradeNeeded(VersionChangeEvent e) {
          final db = e.database;
          db.createObjectStore(testStoreName, keyPath: ['my', 'key']);
        }

        db = await idbFactory.open(srcDbName,
            version: 1, onUpgradeNeeded: onUpgradeNeeded);

        // put one in src and one in dst that should get deleted
        final txn = db!.transaction(testStoreName, idbModeReadWrite);
        var store = txn.objectStore(testStoreName);
        // Put 2 before to check the order
        var map = {'my': 1, 'key': 1};
        var key = await store.put(map);
        expect(key, [1, 1]);
        expect(await store.getObject([1, 1]), map);

        await txn.completed;

        //dstDb = await copyDatabase(db, idbFactory, _dstDbName);

        //expect(await sdbExportDatabase(db!), {});
        Future dbCheck(Database db) async {
          final txn = db.transaction(testStoreName, idbModeReadOnly);
          store = txn.objectStore(testStoreName);
          expect(await store.getObject([1, 1]), map);
          await txn.completed;
        }

        await checkAll(
            db!,
            {
              'sembast_export': 1,
              'version': 1,
              'stores': [
                {
                  'name': '_main',
                  'keys': ['store_test_store', 'stores', 'version'],
                  'values': [
                    {
                      'name': 'test_store',
                      'keyPath': ['my', 'key']
                    },
                    ['test_store'],
                    1
                  ]
                },
                {
                  'name': 'test_store',
                  'keys': [1],
                  'values': [
                    {'my': 1, 'key': 1}
                  ]
                }
              ]
            },
            dbCheck);
      });
    });
  });
}
