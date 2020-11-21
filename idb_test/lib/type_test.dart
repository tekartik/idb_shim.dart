library idb_test.type_test;

import 'dart:typed_data';

import 'package:idb_shim/idb_client.dart';

import 'idb_test_common.dart';

// so that this can be run directly
void main() {
  defineTests(idbMemoryContext);
}

void defineTests(TestContext ctx) {
  final idbFactory = ctx.factory;
  group('type', () {
    Database? db;
    Transaction? transaction;
    late ObjectStore objectStore;

    void _createTransaction() {
      transaction = db!.transaction(testStoreName, idbModeReadWrite);
      objectStore = transaction!.objectStore(testStoreName);
    }

    // new
    late String _dbName;
    // prepare for test
    Future _setupDeleteDb() async {
      _dbName = ctx.dbName;
      await idbFactory!.deleteDatabase(_dbName);
    }

    // generic tearDown
    Future _tearDown() async {
      if (transaction != null) {
        await transaction!.completed;
        transaction = null;
      }
      if (db != null) {
        db!.close();
        db = null;
      }
    }

    group('simple', () {
      setUp(() async {
        await _setupDeleteDb();

        void _initializeDatabase(VersionChangeEvent e) {
          final db = e.database;
          db.createObjectStore(testStoreName, autoIncrement: true);
        }

        db = await idbFactory!
            .open(_dbName, version: 1, onUpgradeNeeded: _initializeDatabase);
      });

      tearDown(_tearDown);

      Future _testReadValue(int key, Object value) async {
        var read = await objectStore.getObject(key);
        expect(read, value);
        // Read using cursor
        var completer = Completer.sync();
        objectStore.openCursor(key: key).listen((cvw) {
          completer.complete(cvw.value);
        });
        expect(await completer.future, value);
      }

      Future _testUpdateValue(int key, Object value) async {
        var completer = Completer.sync();
        objectStore.openCursor(key: key).listen((cvw) {
          // Update with the same value
          cvw.update(value);
          // devPrint('update: $value ${value.runtimeType}');
          completer.complete();
        });
        await completer.future;
      }

      Future _testValue(Object value) async {
        _createTransaction();
        // Write
        var key = await objectStore.add(value) as int;
        // Read
        await _testReadValue(key, value);
        // Update
        await _testUpdateValue(key, value);
        // Read
        await _testReadValue(key, value);

        await transaction!.completed;

        // Re-open!
        db!.close();
        db = await idbFactory!.open(_dbName);

        _createTransaction();
        await _testReadValue(key, value);
      }

      test('values', () async {
        for (var value in [
          // null, disabled for nnbd
          true,
          1,
          1.2,
          'text',
          DateTime.fromMillisecondsSinceEpoch(1, isUtc: true),
          Uint8List.fromList([1, 2, 3]),
        ]) {
          await _testValue(value);
        }
      });

      test('dateTime', () async {
        _createTransaction();
        // date time is read as utc
        var key = await objectStore.add(DateTime.fromMillisecondsSinceEpoch(1));
        var read = await objectStore.getObject(key);
        expect(read, DateTime.fromMillisecondsSinceEpoch(1, isUtc: true));
      });

      test('Uint8List', () async {
        _createTransaction();
        // date time is read as utc
        var key = await objectStore.add(Uint8List.fromList([1, 2, 3]));
        var read = await objectStore.getObject(key);
        expect(read, const TypeMatcher<Uint8List>());
        expect(read, [1, 2, 3]);
      });
    });
  });
}
