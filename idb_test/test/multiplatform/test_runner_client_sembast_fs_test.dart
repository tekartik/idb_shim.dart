library idb_shim.test_runner_client_sembast_fs_test;

import 'dart:convert';

import 'package:idb_shim/idb_client.dart';
import 'package:idb_shim/src/sembast/sembast_database.dart' as idb_sdb;
import 'package:idb_test/idb_test_common.dart';
import 'package:idb_test/test_runner.dart' as test_runner;
import 'package:sembast/sembast.dart' as sdb;
import 'package:sembast/sembast_memory.dart' as sdb;
import 'package:sembast/src/file_system.dart';
import 'package:sembast/src/sembast_fs.dart' as sdb;

void main() {
  group('memory_fs', () {
    defineTests(idbMemoryFsContext);
  });
}

void defineTests(SembastFsTestContext ctx) {
  final idbFactory = ctx.idbFactorySembast;

  group('simple', () {
    test('open', () async {
      var db = await idbFactory.open('test');
      db.close();
    });
  });

  // common tests
  test_runner.defineAllTests(ctx);

  dbGroup(ctx, 'format', () {
    final tmpSdbFactory = sdb.databaseFactoryMemoryFs as sdb.DatabaseFactoryFs;

    Database? db;
    late sdb.Database memSdb;

    // generic tearDown
    Future dbTearDown() async {
      if (db != null) {
        db!.close();
        db = null;
      }
    }

    Future<List<Map?>> getFileContent(File file) async {
      final content = <Map?>[];
      await utf8.decoder
          .bind(file.openRead())
          .transform(const LineSplitter())
          .listen((String line) {
        content.add(json.decode(line) as Map?);
      }).asFuture<void>();
      return content;
    }

    Future<List<Map?>> getStorageContent() async {
      var content = await getFileContent(
          ctx.sdbFactory.fs.file(idbFactory.getDbPath(dbTestName)));
      // devPrint(content);
      return content;
    }

    Future<List<Map?>> getSdbStorageContext() async {
      return getFileContent(tmpSdbFactory.fs.file(memSdb.path));
    }

    Future<sdb.Database> openTmpDatabase([int version = 1]) async {
      final sdbName = '${dbTestName}_mem';
      final db = await tmpSdbFactory.openDatabase(sdbName,
          version: version, mode: sdb.DatabaseMode.empty);
      return db;
    }

    Future checkExport() async {
      expect(await getStorageContent(), await getSdbStorageContext());
    }

    var store = sdb.StoreRef<String, Object>.main();
    tearDown(dbTearDown);
    dbTest('empty', () async {
      db = await idbFactory.open(dbTestName);
      memSdb = await openTmpDatabase(1);
      await store.record('version').put(memSdb, 1);
      db!.close();
      await memSdb.close();
      // Make sure the db is flushed
      await (db as idb_sdb.DatabaseSembast).db!.close();
    });

    dbTest('one_store', () async {
      late IdbObjectStoreMeta storeMeta;

      void onUpgradeNeeded(VersionChangeEvent e) {
        final db = e.database;
        final store = db.createObjectStore(testStoreName,
            keyPath: testNameField, autoIncrement: true);
        storeMeta = IdbObjectStoreMeta.fromObjectStore(store);
      }

      db = await idbFactory.open(dbTestName,
          version: 2, onUpgradeNeeded: onUpgradeNeeded);

      memSdb = await openTmpDatabase(1);
      await store.record('version').put(memSdb, 2);
      await store.record('stores').put(memSdb, [storeMeta.name]);
      await store
          .record('store_${storeMeta.name}')
          .put(memSdb, storeMeta.toMap());
      db!.close();
      await memSdb.close();
      // Make sure the db is flushed
      await (db as idb_sdb.DatabaseSembast).db!.close();
      await checkExport();
    });

    dbTest('one_index', () async {
      late IdbObjectStoreMeta storeMeta;

      void onUpgradeNeeded(VersionChangeEvent e) {
        final db = e.database;
        final store = db.createObjectStore(testStoreName, autoIncrement: true);
        storeMeta = IdbObjectStoreMeta.fromObjectStore(store);
        final index = store.createIndex(testNameIndex, testNameField,
            unique: true, multiEntry: true);
        final indexMeta = IdbIndexMeta.fromIndex(index);
        storeMeta.putIndex(indexMeta);
      }

      db = await idbFactory.open(dbTestName,
          version: 3, onUpgradeNeeded: onUpgradeNeeded);

      memSdb = await openTmpDatabase(1);
      await store.record('version').put(memSdb, 3);
      await store.record('stores').put(memSdb, [storeMeta.name]);
      await store
          .record('store_${storeMeta.name}')
          .put(memSdb, storeMeta.toMap());
      db!.close();
      await memSdb.close();
      // Make sure the db is flushed
      await (db as idb_sdb.DatabaseSembast).db!.close();
      await checkExport();
    });

    dbTest('dummy_file', () async {
      var dbName = dbTestName;
      var file = ctx.sdbFactory.fs.file(idbFactory.getDbPath(dbTestName));
      await file.create(recursive: true);
      var sink = file.openWrite(mode: FileMode.write);
      sink.writeln('test');
      await sink.close();

      db = await idbFactory.open(dbName);
      db!.close();
    });
  });
}
