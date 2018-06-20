library idb_shim.utils_test;

import 'package:idb_shim/idb_client.dart';
import 'package:idb_shim/utils/idb_utils.dart';
import 'package:idb_shim/utils/idb_import_export.dart';
import 'idb_test_common.dart';
import 'package:path/path.dart';
//import 'idb_test_factory.dart';

main() {
  defineTests(idbMemoryContext);
}

void defineTests(TestContext ctx) {
  IdbFactory idbFactory = ctx.factory;

  Database db;
  //Database dstDb;
  String _srcDbName;
  String _dstDbName;
  String _importedDbName;
  // prepare for test
  Future _setupDeleteDb() async {
    _srcDbName = ctx.dbName;
    _dstDbName = "dst_${_srcDbName}";
    _importedDbName = "imported_${_srcDbName}";
    await idbFactory.deleteDatabase(_srcDbName);
  }

  _tearDown() {
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
    _checkExportImport(
        Database db, Map expectedExport, Future check(Database)) async {
      // export
      Map export = await sdbExportDatabase(db);
      expect(export, expectedExport);

      // import
      Database importedDb =
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

      _checkCopySchema(Database db, Future check(Database)) async {
        Database dstDb = await copySchema(db, idbFactory, _dstDbName);
        expect(dstDb.name, _dstDbName);
        await check(dstDb);
        dstDb.close();
      }

      _checkAll(Database db, Map expectedExport, Future check(Database database)) async {
        await check(db);
        await _checkCopySchema(db, check);
        await _checkExportImport(db, expectedExport, check);
      }

      test('empty', () async {
        await _setupDeleteDb();
        db = await idbFactory.open(_srcDbName);

        _check(Database db) async {
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
          Database db = e.database;
          //ObjectStore objectStore =
          db.createObjectStore(testStoreName,
              keyPath: testNameField, autoIncrement: true);
        }

        db = await idbFactory.open(_srcDbName,
            version: 2, onUpgradeNeeded: _initializeDatabase);

        _check(Database db) async {
          expect(db.factory, idbFactory);
          expect(db.objectStoreNames, [testStoreName]);
          expect(basename(db.name).endsWith(basename(_srcDbName)), isTrue);
          expect(db.version, 2);
          Transaction txn = db.transaction(testStoreName, idbModeReadOnly);
          ObjectStore store = txn.objectStore(testStoreName);
          expect(store.name, testStoreName);
          expect(store.keyPath, testNameField);

          // autoIncrement not supported on ie
          if (!ctx.isIdbIe) {
            expect(store.autoIncrement, isTrue);
          }
          expect(store.indexNames, []);
          await txn.completed;
        }

        Map expectedExport = {
          'sembast_export': 1,
          'version': 1,
          'stores': [
            {
              'name': '_main',
              'keys': ['version', 'stores', 'store_test_store'],
              'values': [
                2,
                ['test_store'],
                {'name': 'test_store', 'keyPath': 'name', 'autoIncrement': true}
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
          Database db = e.database;
          ObjectStore objectStore =
              db.createObjectStore(testStoreName, autoIncrement: true);
          objectStore.createIndex(testNameIndex, testNameField,
              unique: true, multiEntry: true);
        }

        db = await idbFactory.open(_srcDbName,
            version: 3, onUpgradeNeeded: _initializeDatabase);

        _check(Database db) async {
          expect(db.version, 3);
          Transaction txn = db.transaction(testStoreName, idbModeReadOnly);
          ObjectStore store = txn.objectStore(testStoreName);
          expect(store.indexNames, [testNameIndex]);
          Index index = store.index(testNameIndex);
          expect(index.name, testNameIndex);
          expect(index.keyPath, testNameField);
          expect(index.unique, isTrue);

          // multiEntry not supported on ie
          if (!ctx.isIdbIe) {
            expect(index.multiEntry, isTrue);
          }
          await txn.completed;
        }

        Map expectedExport = {
          'sembast_export': 1,
          'version': 1,
          'stores': [
            {
              'name': '_main',
              'keys': ['version', 'stores', 'store_test_store'],
              'values': [
                3,
                ['test_store'],
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
                }
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

      _checkCopyStore(
          Database srcDatabase,
          String srcStoreName,
          Database dstDatabase,
          String dstStoreName,
          check(Database database, String name)) async {
        await check(srcDatabase, srcStoreName);
        await copyStore(srcDatabase, srcStoreName, dstDatabase, dstStoreName);
        await check(dstDatabase, dstStoreName);
      }

      test('empty', () async {
        await _setupDeleteDb();

        void _initializeDatabase(VersionChangeEvent e) {
          Database db = e.database;
          //ObjectStore objectStore =
          db.createObjectStore(testStoreName);
          db.createObjectStore(testStoreName2);
        }

        db = await idbFactory.open(_srcDbName,
            version: 1, onUpgradeNeeded: _initializeDatabase);

        _check(Database db, String storeName) async {
          Transaction txn = db.transaction(storeName, idbModeReadOnly);
          ObjectStore store = txn.objectStore(storeName);

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
          Database db = e.database;
          //ObjectStore objectStore =
          db.createObjectStore(testStoreName);
          db.createObjectStore(testStoreName2);
        }

        db = await idbFactory.open(_srcDbName,
            version: 1, onUpgradeNeeded: _initializeDatabase);

        // put one in src and one in dst that should get deleted
        Transaction txn =
            db.transaction([testStoreName, testStoreName2], idbModeReadWrite);
        ObjectStore store = txn.objectStore(testStoreName);
        await (store.put("value1", "key1"));
        ObjectStore store2 = txn.objectStore(testStoreName2);
        await (store2.put("value2", "key2"));
        await txn.completed;

        _check(Database db, String storeName) async {
          Transaction txn = db.transaction(storeName, idbModeReadOnly);
          store = txn.objectStore(storeName);
          expect(await store.getObject("key1"), "value1");
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

      _checkCopyDatabase(Database db, Future check(Database database)) async {
        Database dstDb = await copyDatabase(db, idbFactory, _dstDbName);
        expect(dstDb.name, _dstDbName);
        await check(dstDb);
        dstDb.close();
      }

      _checkAll(Database db, Map expectedExport, Future check(Database database)) async {
        await check(db);
        await _checkCopyDatabase(db, check);
        await _checkExportImport(db, expectedExport, check);
      }

      test('empty', () async {
        await _setupDeleteDb();
        db = await idbFactory.open(_srcDbName);

        _check(Database db) async {
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
          Database db = e.database;
          //ObjectStore objectStore =
          db.createObjectStore(testStoreName);
          db.createObjectStore(testStoreName2);
        }

        db = await idbFactory.open(_srcDbName,
            version: 1, onUpgradeNeeded: _initializeDatabase);

        // put one in src and one in dst that should get deleted
        Transaction txn = db.transaction(testStoreName, idbModeReadWrite);
        ObjectStore store = txn.objectStore(testStoreName);
        await (store.put("value1", "key1"));
        await (store.put("value2", "key2"));
        await txn.completed;

        //dstDb = await copyDatabase(db, idbFactory, _dstDbName);

        _check(Database db) async {
          Transaction txn =
              db.transaction([testStoreName, testStoreName2], idbModeReadOnly);
          store = txn.objectStore(testStoreName);
          expect(await store.getObject("key1"), "value1");
          expect(await store.getObject("key2"), "value2");

          if (!ctx.isIdbIe) {
            expect(await store.count(), 2);
          }
          ObjectStore store2 = txn.objectStore(testStoreName2);

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
                    'version',
                    'stores',
                    'store_test_store',
                    'store_test_store_2'
                  ],
                  'values': [
                    1,
                    ['test_store', 'test_store_2'],
                    {'name': 'test_store'},
                    {'name': 'test_store_2'}
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
