library store_test_common;

import 'dart:async';

import 'package:idb_shim/idb_client.dart';

import 'idb_test_common.dart' hide testNameIndex, testNameField;
import 'simple_provider.dart';

// so that this can be run directly
void main() {
  defineTests(idbMemoryContext);
}

void defineTests(TestContext ctx) {
  IdbFactory idbFactory = ctx.factory;
  group('simple provider', () {
    group('with data', () {
      SimpleProvider provider;

      setUp(() {
        provider = SimpleProvider(idbFactory);
        return provider.openWith3SampleRows();
      });

      tearDown(() {
        provider.close();
      });

      test('simple cursor auto advance', () {
        // Check ordered by id
        ObjectStore store = provider.db
            .transaction(testStoreName, idbModeReadOnly)
            .objectStore(testStoreName);
        Stream<CursorWithValue> stream = store.openCursor(autoAdvance: true);
        return provider.cursorToList(stream).then((List<SimpleRow> list) {
          expect(list[0].name, equals('test2'));
          expect(list[0].id, equals(1));
          expect(list[1].name, equals('test1'));
          expect(list[2].name, equals('test3'));
          expect(list[2].id, equals(3));
        }).then((_) {
          // Check ordered by name
          ObjectStore store = provider.db
              .transaction(testStoreName, idbModeReadOnly)
              .objectStore(testStoreName);
          Index index = store.index(nameIndex);
          Stream<CursorWithValue> stream = index.openCursor(autoAdvance: true);
          return provider.cursorToList(stream).then((List<SimpleRow> list) {
            expect(list[0].name, equals('test1'));
            expect(list[0].id, equals(2));
            expect(list[1].name, equals('test2'));
            expect(list[2].name, equals('test3'));
            expect(list[2].id, equals(3));
          });
        });
      });

      test('simple cursor no auto advance', () {
        // Check ordered by id
        ObjectStore store = provider.db
            .transaction(testStoreName, idbModeReadOnly)
            .objectStore(testStoreName);
        Stream<CursorWithValue> stream = store.openCursor();
        Completer completer = Completer();
        List<SimpleRow> list = [];
        stream.listen((CursorWithValue cwv) {
          expect(cwv.direction, "next");
          list.add(SimpleRow(cwv));
          cwv.next();
        }).onDone(() {
          expect(list.length, equals(3));
          expect(list[0].name, equals('test2'));
          expect(list[0].id, equals(1));
          expect(list[1].name, equals('test1'));
          expect(list[2].name, equals('test3'));
          expect(list[2].id, equals(3));
          completer.complete();
        });
        return completer.future;
      });

      test('simple cursor reverse', () {
        // Check ordered by name reverse
        ObjectStore store = provider.db
            .transaction(testStoreName, idbModeReadOnly)
            .objectStore(testStoreName);
        Index index = store.index(nameIndex);
        Stream<CursorWithValue> stream =
            index.openCursor(direction: idbDirectionPrev, autoAdvance: true);
        return provider.cursorToList(stream).then((List<SimpleRow> list) {
          expect(list[0].name, equals('test3'));
          expect(list[1].name, equals('test2'));
          expect(list[2].name, equals('test1'));
        });
      });
    });

    setUp(() {});

    test('add/get/put/delete', () {
      //Function done = expectDone();
      SimpleProvider provider = SimpleProvider(idbFactory);
      return provider.openEmpty().then((_) {
        Transaction transaction =
            provider.db.transaction(testStoreName, idbModeReadWrite);
        ObjectStore objectStore = transaction.objectStore(testStoreName);
        Map object = {nameField: "test"};
        objectStore.add(object).then((r) {
          int key = r as int;
          expect(key, equals(1));
          //print('added $r');
          objectStore.getObject(r).then((newObject) {
            //print(newObject);
            expect(newObject.length, equals(1));
            expect(newObject[nameField], equals('test'));

            objectStore.put(newObject, r).then((newR) {
              int key = newR as int;
              expect(key, equals(1));
              //print(newObject);
              expect(newObject.length, equals(1));
              expect(newObject[nameField], equals('test'));

              objectStore.delete(r).then((nullValue) {
                expect(nullValue, isNull);
              });
            });
          });
        });
        return transaction.completed.then((_) {
          provider.close();
          // done();
        });
      });
    });
  });
}
