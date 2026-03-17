library;

import 'dart:typed_data';

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

    void dbCreateTransaction() {
      transaction = db!.transaction(testStoreName, idbModeReadWrite);
      objectStore = transaction!.objectStore(testStoreName);
    }

    // new
    late String dbName;
    // prepare for test
    Future setupDeleteDb() async {
      dbName = ctx.dbName;
      await idbFactory.deleteDatabase(dbName);
    }

    // generic tearDown
    Future dbTearDown() async {
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
        await setupDeleteDb();

        void onUpgradeNeeded(VersionChangeEvent e) {
          final db = e.database;
          db.createObjectStore(testStoreName, autoIncrement: true);
        }

        db = await idbFactory.open(
          dbName,
          version: 1,
          onUpgradeNeeded: onUpgradeNeeded,
        );
      });

      tearDown(dbTearDown);

      Future testReadValue(int key, Object value) async {
        var read = await objectStore.getObject(key);
        expect(read, value);
        // Read using cursor
        var completer = Completer<Object>.sync();
        objectStore.openCursor(key: key).listen((cvw) {
          completer.complete(cvw.value);
        });
        expect(await completer.future, value);
      }

      Future testUpdateValue(int key, Object value) async {
        var completer = Completer<void>.sync();
        objectStore.openCursor(key: key).listen((cvw) {
          // Update with the same value
          cvw.update(value);
          // devPrint('update: $value ${value.runtimeType}');
          completer.complete();
        });
        await completer.future;
      }

      Future<void> testValue<V extends Object>(V value) async {
        dbCreateTransaction();
        // Write
        var key = await objectStore.add(value) as int;
        // Read
        await testReadValue(key, value);
        // Update
        await testUpdateValue(key, value);
        // Read
        await testReadValue(key, value);

        await transaction!.completed;

        // Re-open!
        db!.close();
        db = await idbFactory.open(dbName);

        dbCreateTransaction();
        await testReadValue(key, value);
      }

      test('values', () async {
        var allValues = [
          // null,
          true,
          1,
          1.2,
          'text',
          DateTime.fromMillisecondsSinceEpoch(1, isUtc: true),
          Uint8List.fromList([1, 2, 3]),
          {
            'test': [
              [1, null],
              {
                'sub': [
                  [
                    [1],
                    [2, 1],
                  ],
                  [null],
                  'text',
                ],
                'null_sub': null,
              },
            ],
          },
        ];
        for (var value in allValues) {
          await testValue(value);
        }
        await testValue([
          null,
          {'test': null},
          ...allValues,
        ]);
      });
      test('all_types', () async {
        // int
        await testValue(1);
        // string
        await testValue('test');
        // bool
        await testValue(true);
        // double
        await testValue(1.5);
        // map
        await testValue<Map<String, Object?>>({'test': 1, 'other': true});
        // list
        await testValue<List<Object?>>(['test', 1, 'other', true]);
        // uint8list
        await testValue(Uint8List.fromList([1, 2, 3]));
        // datetime
        await testValue(DateTime.timestamp());
      });

      test('dateTime', () async {
        dbCreateTransaction();
        // date time is read as utc
        var key = await objectStore.add(DateTime.fromMillisecondsSinceEpoch(1));
        var read = await objectStore.getObject(key);
        expect(read, isA<DateTime>());
        expect(read, DateTime.fromMillisecondsSinceEpoch(1, isUtc: true));
      });

      test('Uint8List', () async {
        dbCreateTransaction();
        // date time is read as utc
        var key = await objectStore.add(Uint8List.fromList([1, 2, 3]));
        var read = await objectStore.getObject(key);
        expect(read, const TypeMatcher<Uint8List>());
        expect(read, [1, 2, 3]);
      });

      test('list with null', () async {
        dbCreateTransaction();
        // date time is read as utc
        var key = await objectStore.add([1, null, 2]);
        var read = await objectStore.getObject(key);
        expect(read, isNot(isA<Uint8List>()));
        expect(read, [1, null, 2]);
      });
    });
  });
}
