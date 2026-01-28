import 'package:idb_shim/sdb.dart';

import '../idb_test_common.dart';

void main() {
  var store = SdbStoreRef<int, int>('test');
  var record = store.record(1);
  group('changes_listener', () {
    late SdbDatabase db;
    setUp(() async {
      db = await newSdbFactoryMemory().openDatabase(
        'test.db',
        version: 1,
        schema: SdbDatabaseSchema(stores: [store.schema(autoIncrement: true)]),
      );
    });
    tearDown(() async {
      await db.close();
    });

    test('simple add', () async {
      var list = <SdbRecordChange<Object, Object>>[];

      store.addOnChangesListener(db, (txn, addedList) {
        list.addAll(addedList);
      });

      await record.put(db, 2);
      expect(list.first.ref, record);
      expect(list.first.oldValue, null);
      expect(list.first.newValue, 2);
    });

    test('simple in transaction', () async {
      var list = <List<SdbRecordChange>>[];
      var beforeTransaction = true;
      var afterTransaction = false;
      var innerEnded = false;
      void onChanges(SdbTransaction txn, List<SdbRecordChange> changes) {
        expect(beforeTransaction, isFalse);
        expect(afterTransaction, isFalse);
        expect(innerEnded, isTrue);
        list.add(changes);
      }

      store.addOnChangesListener(db, onChanges);

      Future<T> runInTransaction<T>(
        FutureOr<T> Function(SdbTransaction transaction) action,
      ) async {
        beforeTransaction = true;
        afterTransaction = false;
        innerEnded = false;
        return await db
            .inStoreTransaction(store, SdbTransactionMode.readWrite, (
              txn,
            ) async {
              beforeTransaction = false;
              try {
                return await action(txn);
              } finally {
                innerEnded = true;
              }
            })
            .then((value) {
              afterTransaction = true;
              return value;
            });
      }

      await runInTransaction((txn) async {
        await record.put(txn, 100);
        await record.put(txn, 101);
        await record.delete(txn);
      });
      expect(list.length, 1);
      var changes = list[0];
      expect(changes.length, 3);
      expect(changes[0].isAdd, isTrue);
      expect(changes[1].isUpdate, isTrue);
      expect(changes[2].isDelete, isTrue);
    });

    test('add/update/delete', () async {
      var list = <SdbRecordChange>[];
      void onChanges(SdbTransaction txn, List<SdbRecordChange> changes) {
        list.addAll(changes);
      }

      store.addOnChangesListener(db, onChanges);

      await store.add(db, 1);
      expect(list.first.ref, record);
      expect(list.first.oldValue, null);
      expect(list.first.oldSnapshot, null);
      expect(list.first.newValue, 1);
      expect(list.first.newSnapshot!.value, 1);
      expect(list.first.isAdd, isTrue);
      expect(list.first.isDelete, isFalse);
      expect(list.first.isUpdate, isFalse);
      list.clear();
      await record.put(db, 2);
      expect(list.first.ref, record);
      expect(list.first.oldValue, 1);
      expect(list.first.oldSnapshot!.value, 1);
      expect(list.first.newValue, 2);
      expect(list.first.newSnapshot!.value, 2);
      expect(list.first.isAdd, isFalse);
      expect(list.first.isDelete, isFalse);
      expect(list.first.isUpdate, isTrue);
      list.clear();
      await record.delete(db);
      expect(list.first.ref, record);
      expect(list.first.oldValue, 2);
      expect(list.first.newValue, isNull);
      expect(list.first.isAdd, isFalse);
      expect(list.first.isDelete, isTrue);
      expect(list.first.isUpdate, isFalse);
    });
    test('add/remove listener/delete', () async {
      var list = <SdbRecordChange>[];
      void onChanges(SdbTransaction txn, List<SdbRecordChange> changes) {
        list.addAll(changes);
      }

      store.addOnChangesListener(db, onChanges);
      await record.put(db, 1);
      expect(list.length, 1);
      await record.put(db, 2);
      expect(list.length, 2);
      store.removeOnChangesListener(db, onChanges);
      await record.put(db, 3);
      expect(list.length, 2);
    });
    test('cascade', () async {
      var list = <SdbRecordChange>[];
      Future<void> onChanges(
        SdbTransaction txn,
        List<SdbRecordChange<int, int>> changes,
      ) async {
        for (var change in changes) {
          if (change.newValue! < 3) {
            // Update
            await change.ref.put(txn, change.newValue! + 1);
          }
        }
        list.addAll(changes);
      }

      store.addOnChangesListener(db, onChanges);
      await record.put(db, 1);
      expect(list.length, 3);
    });
    test('deleteAll', () async {
      var list = <SdbRecordChange>[];
      Future<void> onChanges(
        SdbTransaction txn,
        List<SdbRecordChange<int, int>> changes,
      ) async {
        list.addAll(changes);
      }

      store.addOnChangesListener(db, onChanges);
      await record.put(db, 1);
      expect(list.length, 1);
      await store.delete(db);
      expect(list.length, 2);
      await record.put(db, 1);
      expect(list.length, 3);
    });

    test('throw', () async {
      void onChanges(SdbTransaction txn, List<SdbRecordChange> changes) {
        throw StateError('no changes allowed');
      }

      store.addOnChangesListener(db, onChanges);
      try {
        await store.add(db, 2);
        fail('should fail');
      } on StateError catch (_) {
      } catch (e) {
        if (isDebug) {
          idbLog('throw during onChanges, unexpected $e');
        }
      }
      expect(await record.exists(db), isFalse);
    });
  });
}
