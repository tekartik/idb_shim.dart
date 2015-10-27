library idb_shim.test_runner_client_sembast_fs_test;

import 'test_runner.dart' as test_runner;
import 'idb_test_common.dart';
import 'package:idb_shim/idb_client.dart';
import 'package:idb_shim/idb_client_sembast.dart';
import 'package:sembast/src/file_system.dart';
import 'package:sembast/src/sembast_fs.dart' as sdb;
import 'package:sembast/sembast_memory.dart' as sdb;
import 'package:sembast/sembast_io.dart' as sdb;
import 'package:sembast/sembast.dart' as sdb;
import 'dart:convert';

void main() {
  group('memory_fs', () {
    defineTests(idbMemoryFsContext);
  });
}

defineTests(SembastFsTestContext ctx) {
  IdbSembastFactory idbFactory = ctx.factory;

  // common tests
  test_runner.defineTests(ctx);

  dbGroup(ctx, 'format', () {
    // to compare
    //sdb.FsDatabaseFactory tmpSdbFactory = sdb.ioDatabaseFactory; //memoryFsDatabaseFactory;
    sdb.FsDatabaseFactory tmpSdbFactory = sdb.memoryFsDatabaseFactory;

    Database db;
    sdb.Database memSdb;

    // generic tearDown
    _tearDown() async {
      if (db != null) {
        db.close();
        db = null;
      }
    }

    Future<List<Map>> getFileContent(File file) async {
      List<Map> content = [];
      await file
          .openRead()
          .transform(const Utf8Decoder())
          .transform(const LineSplitter())
          .listen((String line) {
        content.add(JSON.decode(line));
      }).asFuture();
      return content;
    }

    Future<List<Map>> getStorageContent() async {
      return getFileContent(
          ctx.sdbFactory.fs.newFile(idbFactory.getDbPath(dbTestName)));
    }

    Future<List<Map>> getSdbStorageContext() async {
      return getFileContent(tmpSdbFactory.fs.newFile(memSdb.path));
    }

    Future<sdb.Database> openTmpDatabase([int version = 1]) async {
      String sdbName = "${dbTestName}_mem";
      sdb.Database db = await tmpSdbFactory.openDatabase(sdbName,
          version: version, mode: sdb.DatabaseMode.EMPTY);
      return db;
    }

    _checkExport() async {
      expect(await getStorageContent(), await getSdbStorageContext());
    }

    tearDown(_tearDown);
    dbTest('empty', () async {
      db = await idbFactory.open(dbTestName);
      memSdb = await openTmpDatabase(1);
      await memSdb.put(1, "version");
      await _checkExport();
    });

    dbTest('one_store', () async {
      IdbObjectStoreMeta storeMeta;

      void _initializeDatabase(VersionChangeEvent e) {
        Database db = e.database;
        ObjectStore store = db.createObjectStore(testStoreName,
            keyPath: testNameField, autoIncrement: true);
        storeMeta = new IdbObjectStoreMeta.fromObjectStore(store);
      }
      db = await idbFactory.open(dbTestName,
          version: 2, onUpgradeNeeded: _initializeDatabase);

      memSdb = await openTmpDatabase(1);
      await memSdb.put(2, "version");
      await memSdb.put([storeMeta.name], "stores");
      await memSdb.put(storeMeta.toMap(), "store_${storeMeta.name}");
      await _checkExport();
    });

    dbTest('one_index', () async {
      IdbObjectStoreMeta storeMeta;

      void _initializeDatabase(VersionChangeEvent e) {
        Database db = e.database;
        ObjectStore store =
            db.createObjectStore(testStoreName, autoIncrement: true);
        storeMeta = new IdbObjectStoreMeta.fromObjectStore(store);
        Index index = store.createIndex(testNameIndex, testNameField,
            unique: true, multiEntry: true);
        IdbIndexMeta indexMeta = new IdbIndexMeta.fromIndex(index);
        storeMeta.putIndex(indexMeta);
      }
      db = await idbFactory.open(dbTestName,
          version: 3, onUpgradeNeeded: _initializeDatabase);

      memSdb = await openTmpDatabase(1);
      await memSdb.put(3, "version");
      await memSdb.put([storeMeta.name], "stores");
      await memSdb.put(storeMeta.toMap(), "store_${storeMeta.name}");
      await _checkExport();
    });
  });
}
