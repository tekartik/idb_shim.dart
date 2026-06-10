import 'package:idb_shim/sdb.dart';
// ignore: implementation_imports
import 'package:idb_shim/src/sdb/sdb_database_impl.dart'
    show SdbDatabaseInternalExtension;

import 'idb_test_common.dart';
import 'sdb_test.dart';

void main() {
  defineSdbOnSnapshotTests(sdbMemoryContext);
}

void defineIdbSdbOnSnapshotTests(TestContext ctx) {
  var factory = sdbFactoryFromIdb(ctx.factory);
  defineSdbOnSnapshotTests(SdbTestContext(factory));
}

final _testStore = SdbStoreRef<int, String>('test');
final _testModelStore = SdbStoreRef<int, SdbModel>('test_model');
final _testIndex = _testModelStore.index<String>('test_index');

void defineSdbOnSnapshotTests(SdbTestContext ctx) {
  var factory = ctx.factory;

  group('on_snapshot', () {
    late SdbDatabase db;

    setUp(() async {
      var dbName = 'sdb_on_snapshot_test.db';
      await factory.deleteDatabase(dbName);
      db = await factory.openDatabase(
        dbName,
        options: SdbOpenDatabaseOptions(
          version: 1,
          schema: SdbDatabaseSchema(
            stores: [
              _testStore.schema(),
              _testModelStore.schema(
                indexes: [_testIndex.schema(keyPath: 'test_index')],
              ),
            ],
          ),
        ),
      );
    });

    tearDown(() async {
      await db.close();
    });

    late Completer completer;
    void newCompleter() {
      completer = Completer();
    }

    void complete() {
      if (!completer.isCompleted) {
        completer.complete();
      }
    }

    Future<void> completed() => completer.future;

    test('onSnapshot', () async {
      var record = _testStore.record(1);

      var snapshots = <SdbRecordSnapshot<int, String>?>[];
      var subscription = record.onSnapshot(db).listen((snapshot) {
        snapshots.add(snapshot);
        complete();
      });

      // Initial null
      newCompleter();
      await completed();
      expect(snapshots, [null]);

      // Put 1
      newCompleter();
      await record.put(db, 'text1');
      await completed();
      expect(snapshots.last!.value, 'text1');

      // Put 2
      newCompleter();
      await record.put(db, 'text2');
      await completed();
      expect(snapshots.last!.value, 'text2');

      // Delete
      newCompleter();
      await record.delete(db);
      await completed();
      expect(snapshots.last, null);

      expect(db.impl.changesListener.isEmpty, isFalse);
      await subscription.cancel();
      expect(db.impl.changesListener.isEmpty, isTrue);
    });

    test('onSnapshots', () async {
      var snapshotsList = <List<SdbRecordSnapshot<int, String>>>[];
      var subscription = _testStore.onSnapshots(db).listen((snapshots) {
        snapshotsList.add(snapshots);
        complete();
      });

      // Initial empty
      newCompleter();
      await completed();
      expect(snapshotsList.last, isEmpty);

      // Add 1
      newCompleter();
      await _testStore.record(1).put(db, 'text1');
      await completed();
      expect(snapshotsList.last, hasLength(1));
      expect(snapshotsList.last.first.value, 'text1');

      // Add 2
      newCompleter();
      await _testStore.record(2).put(db, 'text2');
      await completed();
      expect(snapshotsList.last, hasLength(2));
      expect(snapshotsList.last[1].value, 'text2');

      // Update 1
      newCompleter();
      await _testStore.record(1).put(db, 'text1_updated');
      await completed();
      expect(snapshotsList.last.first.value, 'text1_updated');

      // Delete 2
      newCompleter();
      await _testStore.record(2).delete(db);
      await completed();
      expect(snapshotsList.last, hasLength(1));

      expect(db.impl.changesListener.isEmpty, isFalse);
      await subscription.cancel();
      expect(db.impl.changesListener.isEmpty, isTrue);
    });

    test('onIndexSnapshots', () async {
      var snapshotsList =
          <List<SdbIndexRecordSnapshot<int, SdbModel, String>>>[];
      var subscription = _testIndex.onSnapshots(db).listen((snapshots) {
        snapshotsList.add(snapshots);
        complete();
      });

      // Initial empty
      newCompleter();
      await completed();
      expect(snapshotsList.last, isEmpty);

      // Add 1 matching index
      newCompleter();
      await _testModelStore.record(1).put(db, {'test_index': 'text1'});
      await completed();
      expect(snapshotsList.last, hasLength(1));
      expect(snapshotsList.last.first.value['test_index'], 'text1');

      // Add 2 matching index
      newCompleter();
      await _testModelStore.record(2).put(db, {'test_index': 'text2'});
      await completed();
      expect(snapshotsList.last, hasLength(2));

      // Delete 2
      newCompleter();
      await _testModelStore.record(2).delete(db);
      await completed();
      expect(snapshotsList.last, hasLength(1));

      expect(db.impl.changesListener.isEmpty, isFalse);
      await subscription.cancel();
      expect(db.impl.changesListener.isEmpty, isTrue);
    });

    test('onCount (store)', () async {
      var counts = <int>[];
      var subscription = _testStore.onCount(db).listen((count) {
        counts.add(count);
        complete();
      });

      // Initial 0
      newCompleter();
      await completed();
      expect(counts.last, 0);

      // Add 1
      newCompleter();
      await _testStore.record(1).put(db, 'text1');
      await completed();
      expect(counts.last, 1);

      // Add 2
      newCompleter();
      await _testStore.record(2).put(db, 'text2');
      await completed();
      expect(counts.last, 2);

      // Delete 1
      newCompleter();
      await _testStore.record(1).delete(db);
      await completed();
      expect(counts.last, 1);

      expect(db.impl.changesListener.isEmpty, isFalse);
      await subscription.cancel();
      expect(db.impl.changesListener.isEmpty, isTrue);
    });

    test('onCount (index)', () async {
      var counts = <int>[];
      var subscription = _testIndex.onCount(db).listen((count) {
        counts.add(count);
        complete();
      });

      // Initial 0
      newCompleter();
      await completed();
      expect(counts.last, 0);

      // Add 1 matching index
      newCompleter();
      await _testModelStore.record(1).put(db, {'test_index': 'text1'});
      await completed();
      expect(counts.last, 1);

      // Add 2 matching index
      newCompleter();
      await _testModelStore.record(2).put(db, {'test_index': 'text2'});
      await completed();
      expect(counts.last, 2);

      // Delete 1
      newCompleter();
      await _testModelStore.record(1).delete(db);
      await completed();
      expect(counts.last, 1);

      expect(db.impl.changesListener.isEmpty, isFalse);
      await subscription.cancel();
      expect(db.impl.changesListener.isEmpty, isTrue);
    });
  });
}
