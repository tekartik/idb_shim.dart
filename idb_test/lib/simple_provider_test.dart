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
  final idbFactory = ctx.factory;
  group('simple provider', () {
    group('with data', () {
      late SimpleProvider provider;

      setUp(() {
        provider = SimpleProvider(idbFactory);
        return provider.openWith3SampleRows();
      });

      tearDown(() {
        provider.close();
      });

      test('simple cursor auto advance', () {
        // Check ordered by id
        final store = provider.db!
            .transaction(testStoreName, idbModeReadOnly)
            .objectStore(testStoreName);
        final stream = store.openCursor(autoAdvance: true);
        return provider.cursorToList(stream).then((List<SimpleRow> list) {
          expect(list[0].name, equals('test2'));
          expect(list[0].id, equals(1));
          expect(list[1].name, equals('test1'));
          expect(list[2].name, equals('test3'));
          expect(list[2].id, equals(3));
        }).then((_) {
          // Check ordered by name
          final store = provider.db!
              .transaction(testStoreName, idbModeReadOnly)
              .objectStore(testStoreName);
          final index = store.index(nameIndex);
          final stream = index.openCursor(autoAdvance: true);
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
        final store = provider.db!
            .transaction(testStoreName, idbModeReadOnly)
            .objectStore(testStoreName);
        final stream = store.openCursor();
        final completer = Completer();
        final list = <SimpleRow>[];
        stream.listen((CursorWithValue cwv) {
          expect(cwv.direction, 'next');
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
        final store = provider.db!
            .transaction(testStoreName, idbModeReadOnly)
            .objectStore(testStoreName);
        final index = store.index(nameIndex);
        final stream =
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
      final provider = SimpleProvider(idbFactory);
      return provider.openEmpty().then((_) {
        final transaction =
            provider.db!.transaction(testStoreName, idbModeReadWrite);
        final objectStore = transaction.objectStore(testStoreName);
        final object = {nameField: 'test'};
        objectStore.add(object).then((r) {
          final key = r as int?;
          expect(key, equals(1));
          //print('added $r');
          objectStore.getObject(r).then((newObject) {
            //print(newObject);
            expect((newObject as Map).length, equals(1));
            expect(newObject[nameField], equals('test'));

            objectStore.put(newObject, r).then((newR) {
              final key = newR as int?;
              expect(key, equals(1));
              //print(newObject);
              expect(newObject.length, equals(1));
              expect(newObject[nameField], equals('test'));

              return objectStore.delete(r);
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
