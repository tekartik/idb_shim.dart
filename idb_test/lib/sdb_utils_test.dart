library;

import 'package:collection/collection.dart';
import 'package:idb_shim/sdb.dart';
import 'package:idb_shim/utils/sdb_import_export.dart';
//import 'package:idb_shim/utils/idb_utils.dart';
import 'package:idb_test/sdb_test.dart';
import 'package:path/path.dart';

import 'idb_test_common.dart';
//import 'idb_test_factory.dart';

void main() {
  idbSdbUtilsTests(idbMemoryContext);
}

var testStore = SdbStoreRef<int, SdbModel>(testStoreName);
var testIndex = testStore.index(testNameIndex);

var _testOneStoreKeyPathAutoSchema = SdbDatabaseSchema(
  stores: [
    testStore.schema(
      keyPath: SdbKeyPath.single(testNameField),
      autoIncrement: true,
    ),
  ],
);
var _openDatabaseOptions = SdbOpenDatabaseOptions(
  version: 1,
  schema: _testOneStoreKeyPathAutoSchema,
);
void idbSdbUtilsTests(TestContext ctx) {
  var factory = sdbFactoryFromIdb(ctx.factory);
  sdbUtilsTests(SdbTestContext(factory));
}

void sdbUtilsTests(SdbTestContext ctx) {
  final sdbFactory = ctx.factory;

  SdbDatabase? db;
  //Database dstDb;
  late String srcDbName;
  // ignore: unused_local_variable
  String? dstDbName;
  late String importedDbName;
  // prepare for test
  Future setupDeleteDb() async {
    srcDbName = 'sdb_utils_import_export.db';
    dstDbName = 'dst_$srcDbName';
    importedDbName = 'imported_$srcDbName';
    await sdbFactory.deleteDatabase(srcDbName);
  }

  void dbTearDown() {
    if (db != null) {
      db!.close();
      db = null;
    }
  }

  group('utils', () {
    Future dbCheckExportImportLines(
      SdbDatabase db,
      List expectedExportLines,
      Future Function(SdbDatabase db) check,
    ) async {
      // export
      final export = await sdbExportDatabaseLines(db);
      expect(export, expectedExportLines);

      // import
      var importedDb = await sdbImportDatabase(
        export,
        sdbFactory,
        importedDbName,
      );
      // The name might be relative...
      expect(importedDb.name.endsWith(importedDbName), isTrue);

      await check(importedDb);

      // re-export
      expect(await sdbExportDatabaseLines(importedDb), expectedExportLines);

      await importedDb.close();

      // re open
      importedDb = await sdbFactory.openDatabase(importedDbName);
      await check(importedDb);
      await importedDb.close();
    }

    Future checkAll(
      SdbDatabase db,
      List expectedExport,
      Future Function(SdbDatabase database) check,
    ) async {
      await check(db);
      await dbCheckExportImportLines(db, expectedExport, check);
    }

    group('schema', () {
      tearDown(dbTearDown);

      test('empty', () async {
        await setupDeleteDb();
        db = await sdbFactory.openDatabase(srcDbName);

        Future dbCheck(SdbDatabase db) async {
          expect(db.factory, sdbFactory);
          expect(db.storeNames.isEmpty, true);
          expect(basename(db.name).endsWith(basename(srcDbName)), isTrue);
          expect(db.version, 1);
        }

        await checkAll(db!, [
          {'sembast_export': 1, 'version': 1},
          {'store': '_main'},
          ['version', 1],
        ], dbCheck);
      });

      test('import version 2 and reopen', () async {
        await setupDeleteDb();
        db = await sdbFactory.openDatabase(
          srcDbName,
          options: SdbOpenDatabaseOptions(version: 2, onVersionChange: (_) {}),
        );
        expect(db!.version, 2);
        final export = await sdbExportDatabaseLines(db!);
        await db!.close();

        // import
        var importedDb = await sdbImportDatabase(
          export,
          sdbFactory,
          importedDbName,
        );
        expect(importedDb.version, 2);
        final newExport = await sdbExportDatabaseLines(importedDb);
        expect(newExport, export);
        await importedDb.close();

        db = await sdbFactory.openDatabase(importedDbName);
        expect(db!.version, 2);
      });

      test('empty sdb version 2', () async {
        await setupDeleteDb();
        db = await sdbFactory.openDatabase(
          srcDbName,
          options: SdbOpenDatabaseOptions(version: 2, onVersionChange: (_) {}),
        );

        Future dbCheck(SdbDatabase db) async {
          expect(db.factory, sdbFactory);
          expect(db.storeNames.isEmpty, true);
          expect(basename(db.name).endsWith(basename(srcDbName)), isTrue);
          expect(db.version, 2);
        }

        await checkAll(db!, [
          {'sembast_export': 1, 'version': 1},
          {'store': '_main'},
          ['version', 2],
        ], dbCheck);
      });

      test('one_store', () async {
        await setupDeleteDb();

        db = await sdbFactory.openDatabase(
          srcDbName,
          options: _openDatabaseOptions.copyWith(version: 2),
        );

        Future dbCheck(SdbDatabase db) async {
          expect(db.factory, sdbFactory);
          expect(db.storeNames, [testStoreName]);
          expect(basename(db.name).endsWith(basename(srcDbName)), isTrue);
          expect(db.version, 2);
          await db.inStoreTransaction(testStore, SdbTransactionMode.readOnly, (
            txn,
          ) async {
            var store = txn.store(testStore);
            expect(store.name, testStoreName);
            expect(store.keyPath?.keyPath, testNameField);
            store = txn.txnStore;
            expect(store.name, testStoreName);
            expect(store.keyPath?.keyPath, testNameField);

            expect(store.autoIncrement, isTrue);

            expect(store.indexNames, isEmpty);
          });
          await db.inStoreTransaction(testStore, SdbTransactionMode.readOnly, (
            txn,
          ) {
            final store = txn.store(testStore);
            expect(store.name, testStoreName);
            expect(store.keyPath?.keyPath, testNameField);

            expect(store.indexNames, isEmpty);
          });
        }

        final expectedExport = [
          {'sembast_export': 1, 'version': 1},
          {'store': '_main'},
          [
            'store_test_store',
            {'name': 'test_store', 'keyPath': 'name', 'autoIncrement': true},
          ],
          [
            'stores',
            ['test_store'],
          ],
          ['version', 2],
        ];

        await checkAll(db!, expectedExport, dbCheck);
      });

      test('one_record', () async {
        await setupDeleteDb();

        db = await sdbFactory.openDatabase(
          srcDbName,
          options: _openDatabaseOptions,
        );

        await testStore.add(db!, {'timestamp': SdbTimestamp(1, 0)});

        Future dbCheck(SdbDatabase db) async {
          expect(db.factory, sdbFactory);
          expect(db.storeNames, [testStoreName]);
          expect(basename(db.name).endsWith(basename(srcDbName)), isTrue);
          expect(db.version, 1);
          await db.inStoreTransaction(testStore, SdbTransactionMode.readOnly, (
            txn,
          ) async {
            var store = txn.store(testStore);
            expect(store.name, testStoreName);
            expect(store.keyPath?.keyPath, testNameField);
            store = txn.txnStore;
            expect(store.name, testStoreName);
            expect(store.keyPath?.keyPath, testNameField);

            expect(store.autoIncrement, isTrue);

            expect(store.indexNames, isEmpty);
          });
          await db.inStoreTransaction(testStore, SdbTransactionMode.readOnly, (
            txn,
          ) {
            final store = txn.store(testStore);
            expect(store.name, testStoreName);
            expect(store.keyPath?.keyPath, testNameField);

            expect(store.indexNames, isEmpty);
          });
        }

        final expectedExport = [
          {'sembast_export': 1, 'version': 1},
          {'store': '_main'},
          [
            'store_test_store',
            {'name': 'test_store', 'keyPath': 'name', 'autoIncrement': true},
          ],
          [
            'stores',
            ['test_store'],
          ],
          ['version', 1],
          {'store': 'test_store'},
          [
            1,
            {
              'timestamp': {
                '@': {'@Timestamp': '1970-01-01T00:00:01.000Z'},
              },
              'name': 1,
            },
          ],
        ];

        await checkAll(db!, expectedExport, dbCheck);
      });

      test('three_stores', () async {
        await setupDeleteDb();

        var testStore1 = SdbStoreRef<int, SdbModel>('store1');
        var testStore2 = SdbStoreRef<int, SdbModel>('store2');
        var testStore3 = SdbStoreRef<int, SdbModel>('store3');

        db = await sdbFactory.openDatabase(
          srcDbName,
          options: SdbOpenDatabaseOptions(
            version: 2,
            schema: SdbDatabaseSchema(
              stores: [
                testStore1.schema(),
                testStore2.schema(),
                testStore3.schema(),
              ],
            ),
          ),
        );

        Future dbCheck(SdbDatabase db) async {
          expect(db.factory, sdbFactory);
          expect(
            const UnorderedIterableEquality<String>().equals(db.storeNames, [
              'store1',
              'store2',
              'store3',
            ]),
            isTrue,
            reason: '${db.storeNames}',
          );
        }

        final expectedExport = [
          {'sembast_export': 1, 'version': 1},
          {'store': '_main'},
          [
            'store_store1',
            {'name': 'store1'},
          ],
          [
            'store_store2',
            {'name': 'store2'},
          ],
          [
            'store_store3',
            {'name': 'store3'},
          ],
          [
            'stores',
            ['store1', 'store2', 'store3'],
          ],
          ['version', 2],
        ];

        await checkAll(db!, expectedExport, dbCheck);
      });

      test('one_index', () async {
        await setupDeleteDb();

        db = await sdbFactory.openDatabase(
          srcDbName,
          options: _openDatabaseOptions.copyWith(
            schema: SdbDatabaseSchema(
              stores: [
                testStore.schema(
                  keyPath: SdbKeyPath.single(testNameField),
                  autoIncrement: true,
                  //  objectStore.createIndex(
                  //             testNameIndex,
                  //             testNameField,
                  //             unique: true,
                  //             multiEntry: true, // no here
                  //           );
                  indexes: [
                    testStore
                        .index(testNameIndex)
                        .schema(
                          keyPath: SdbKeyPath.single(testNameField),
                          unique: true,
                        ),
                  ],
                ),
              ],
            ),
            version: 3,
          ),
        );

        Future dbCheck(SdbDatabase db) async {
          expect(db.version, 3);
          await db.inStoreTransaction(testStore, SdbTransactionMode.readOnly, (
            txn,
          ) async {
            var store = txn.txnStore;
            expect(store.indexNames, [testNameIndex]);
            var index = store.index(testIndex);
            expect(index.name, testNameIndex);
            expect(index.keyPath.keyPath, testNameField);
            expect(index.unique, isTrue);
            expect(index.multiEntry, isFalse);
          });
        }

        final expectedExport = [
          {'sembast_export': 1, 'version': 1},
          {'store': '_main'},
          [
            'store_test_store',
            {
              'name': 'test_store',
              'keyPath': 'name',
              'autoIncrement': true,
              'indecies': [
                {'name': 'name_index', 'keyPath': 'name', 'unique': true},
              ],
            },
          ],
          [
            'stores',
            ['test_store'],
          ],
          ['version', 3],
        ];

        await checkAll(db!, expectedExport, dbCheck);
      });
    });
  });
}
