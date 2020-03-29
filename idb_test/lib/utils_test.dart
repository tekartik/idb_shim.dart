library idb_shim.utils_test;

import 'package:collection/collection.dart';
import 'package:idb_shim/idb_client.dart';
import 'package:idb_shim/utils/idb_import_export.dart';
import 'package:idb_shim/utils/idb_utils.dart';
import 'package:path/path.dart';

import 'idb_test_common.dart';
//import 'idb_test_factory.dart';

void main() {
  defineTests(idbMemoryContext);
}

void defineTests(TestContext ctx) {
  final idbFactory = ctx.factory;

  Database db;
  //Database dstDb;
  String _srcDbName;
  String _dstDbName;
  String _importedDbName;
  // prepare for test
  Future _setupDeleteDb() async {
    _srcDbName = ctx.dbName;
    _dstDbName = 'dst_$_srcDbName';
    _importedDbName = 'imported_$_srcDbName';
    await idbFactory.deleteDatabase(_srcDbName);
  }

  void _tearDown() {
    if (db != null) {
      db.close();
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
    Future _checkExportImport(Database db, Map expectedExport,
        Future Function(Database db) check) async {
      // export
      final export = await sdbExportDatabase(db);
      expect(export, expectedExport);

      // import
      final importedDb =
          await sdbImportDatabase(export, idbFactory, _importedDbName);
      // The name might be relative...
      expect(importedDb.name.endsWith(_importedDbName), isTrue);

      await check(importedDb);

      // re-export
      expect(await sdbExportDatabase(importedDb), expectedExport);

      importedDb.close();
    }

    group('copySchema', () {
      tearDown(_tearDown);

      Future _checkCopySchema(
          Database db, Future Function(Database db) check) async {
        final dstDb = await copySchema(db, idbFactory, _dstDbName);
        expect(dstDb.name, _dstDbName);
        await check(dstDb);
        dstDb.close();
      }

      Future _checkAll(Database db, Map expectedExport,
          Future Function(Database database) check) async {
        await check(db);
        await _checkCopySchema(db, check);
        await _checkExportImport(db, expectedExport, check);
      }

      test('empty', () async {
        await _setupDeleteDb();
        db = await idbFactory.open(_srcDbName);

        Future _check(Database db) async {
          expect(db.factory, idbFactory);
          expect(db.objectStoreNames.isEmpty, true);
          expect(basename(db.name).endsWith(basename(_srcDbName)), isTrue);
          expect(db.version, 1);
        }

        await _checkAll(
            db,
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
            _check);
      });

      test('one_store', () async {
        await _setupDeleteDb();

        void _initializeDatabase(VersionChangeEvent e) {
          final db = e.database;
          //ObjectStore objectStore =
          db.createObjectStore(testStoreName,
              keyPath: testNameField, autoIncrement: true);
        }

        db = await idbFactory.open(_srcDbName,
            version: 2, onUpgradeNeeded: _initializeDatabase);

        Future _check(Database db) async {
          expect(db.factory, idbFactory);
          expect(db.objectStoreNames, [testStoreName]);
          expect(basename(db.name).endsWith(basename(_srcDbName)), isTrue);
          expect(db.version, 2);
          final txn = db.transaction(testStoreName, idbModeReadOnly);
          final store = txn.objectStore(testStoreName);
          expect(store.name, testStoreName);
          expect(store.keyPath, testNameField);

          // autoIncrement not supported on ie
          if (!ctx.isIdbIe) {
            expect(store.autoIncrement, isTrue);
          }
          expect(store.indexNames, []);
          await txn.completed;
        }

        final expectedExport = <String, dynamic>{
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
          expectedExport['stores'][0]['values'][2].remove('autoIncrement');
        }
        await _checkAll(db, expectedExport, _check);
      });
      test('three_stores', () async {
        await _setupDeleteDb();

        void _initializeDatabase(VersionChangeEvent e) {
          final db = e.database;
          //ObjectStore objectStore =
          db.createObjectStore('store3');
          db.createObjectStore('store1');
          db.createObjectStore('store2');
        }

        db = await idbFactory.open(_srcDbName,
            version: 2, onUpgradeNeeded: _initializeDatabase);

        Future _check(Database db) async {
          expect(db.factory, idbFactory);
          expect(
              const UnorderedIterableEquality()
                  .equals(db.objectStoreNames, ['store1', 'store2', 'store3']),
              isTrue,
              reason: '${db.objectStoreNames}');
        }

        final expectedExport = <String, dynamic>{
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
          expectedExport['stores'][0]['values'][2].remove('autoIncrement');
        }
        await _checkAll(db, expectedExport, _check);
      });

      test('one_index', () async {
        await _setupDeleteDb();

        void _initializeDatabase(VersionChangeEvent e) {
          final db = e.database;
          final objectStore =
              db.createObjectStore(testStoreName, autoIncrement: true);
          objectStore.createIndex(testNameIndex, testNameField,
              unique: true, multiEntry: true);
        }

        db = await idbFactory.open(_srcDbName,
            version: 3, onUpgradeNeeded: _initializeDatabase);

        Future _check(Database db) async {
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

        final expectedExport = <String, dynamic>{
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
          expectedExport['stores'][0]['values'][2].remove('autoIncrement');
          expectedExport['stores'][0]['values'][2]['indecies'][0]
              .remove('multiEntry');
        }
        await _checkAll(db, expectedExport, _check);
      });

      test('two_indecies', () async {
        await _setupDeleteDb();

        void _initializeDatabase(VersionChangeEvent e) {
          final db = e.database;
          final objectStore =
              db.createObjectStore(testStoreName, autoIncrement: true);
          objectStore.createIndex(testNameIndex2, testNameField2,
              unique: false, multiEntry: true);
          objectStore.createIndex(testNameIndex, testNameField,
              unique: true, multiEntry: true);
        }

        db = await idbFactory.open(_srcDbName,
            version: 4, onUpgradeNeeded: _initializeDatabase);

        Future _check(Database db) async {
          expect(db.version, 4);
          final txn = db.transaction(testStoreName, idbModeReadOnly);
          final store = txn.objectStore(testStoreName);
          expect(
              const UnorderedIterableEquality()
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

        final expectedExport = <String, dynamic>{
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
          expectedExport['stores'][0]['values'][2].remove('autoIncrement');
          expectedExport['stores'][0]['values'][2]['indecies'][0]
              .remove('multiEntry');
        }
        await _checkAll(db, expectedExport, _check);
      });
    });

    group('copyStore', () {
      tearDown(_tearDown);

      Future _checkCopyStore(
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
        await _setupDeleteDb();

        void _initializeDatabase(VersionChangeEvent e) {
          final db = e.database;
          //ObjectStore objectStore =
          db.createObjectStore(testStoreName);
          db.createObjectStore(testStoreName2);
        }

        db = await idbFactory.open(_srcDbName,
            version: 1, onUpgradeNeeded: _initializeDatabase);

        Future _check(Database db, String storeName) async {
          final txn = db.transaction(storeName, idbModeReadOnly);
          final store = txn.objectStore(storeName);

          // count() not supported on ie
          if (!ctx.isIdbIe) {
            expect(await store.count(), 0);
          }
          await txn.completed;
        }

        await _checkCopyStore(db, testStoreName, db, testStoreName2, _check);
      });

      test('two_stores_one_record_each', () async {
        // fake multi store transaction on safari ctx.isIdbSafari;
        await _setupDeleteDb();

        void _initializeDatabase(VersionChangeEvent e) {
          final db = e.database;
          //ObjectStore objectStore =
          db.createObjectStore(testStoreName);
          db.createObjectStore(testStoreName2);
        }

        db = await idbFactory.open(_srcDbName,
            version: 1, onUpgradeNeeded: _initializeDatabase);

        // put one in src and one in dst that should get deleted
        final txn =
            db.transaction([testStoreName, testStoreName2], idbModeReadWrite);
        var store = txn.objectStore(testStoreName);
        await (store.put('value1', 'key1'));
        final store2 = txn.objectStore(testStoreName2);
        await (store2.put('value2', 'key2'));
        await txn.completed;

        Future _check(Database db, String storeName) async {
          final txn = db.transaction(storeName, idbModeReadOnly);
          store = txn.objectStore(storeName);
          expect(await store.getObject('key1'), 'value1');
          if (!ctx.isIdbIe) {
            expect(await store.count(), 1);
          }

          await txn.completed;
        }

        await _checkCopyStore(db, testStoreName, db, testStoreName2, _check);
      });
    });

    group('copyDatabase', () {
      tearDown(_tearDown);

      Future _checkCopyDatabase(
          Database db, Future Function(Database database) check) async {
        final dstDb = await copyDatabase(db, idbFactory, _dstDbName);
        expect(dstDb.name, _dstDbName);
        await check(dstDb);
        dstDb.close();
      }

      Future _checkAll(Database db, Map expectedExport,
          Future Function(Database database) check) async {
        await check(db);
        await _checkCopyDatabase(db, check);
        await _checkExportImport(db, expectedExport, check);
      }

      test('empty', () async {
        await _setupDeleteDb();
        db = await idbFactory.open(_srcDbName);

        Future _check(Database db) async {
          expect(db.factory, idbFactory);
          expect(db.objectStoreNames.isEmpty, true);
          expect(basename(db.name).endsWith(basename(_srcDbName)), isTrue);
          expect(db.version, 1);
        }

        await _checkAll(
            db,
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
            _check);
      });

      // safari does not support multiple stores - fakes
      test('two_store_two_records', () async {
        await _setupDeleteDb();

        void _initializeDatabase(VersionChangeEvent e) {
          final db = e.database;
          //ObjectStore objectStore =
          db.createObjectStore(testStoreName);
          db.createObjectStore(testStoreName2);
        }

        db = await idbFactory.open(_srcDbName,
            version: 1, onUpgradeNeeded: _initializeDatabase);

        // put one in src and one in dst that should get deleted
        final txn = db.transaction(testStoreName, idbModeReadWrite);
        var store = txn.objectStore(testStoreName);
        // Put 2 before to check the order
        await (store.put('value2', 'key2'));
        await (store.put('value1', 'key1'));

        await txn.completed;

        //dstDb = await copyDatabase(db, idbFactory, _dstDbName);

        Future _check(Database db) async {
          final txn =
              db.transaction([testStoreName, testStoreName2], idbModeReadOnly);
          store = txn.objectStore(testStoreName);
          expect(await store.getObject('key1'), 'value1');
          expect(await store.getObject('key2'), 'value2');

          if (!ctx.isIdbIe) {
            expect(await store.count(), 2);
          }
          var store2 = txn.objectStore(testStoreName2);

          if (!ctx.isIdbIe) {
            expect(await store2.count(), 0);
          }
          await txn.completed;
        }

        await _checkAll(
            db,
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
                }
              ]
            },
            _check);
      });
    });
  });
}
