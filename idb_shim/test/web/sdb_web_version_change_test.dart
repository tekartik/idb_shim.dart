@TestOn('browser')
library;

import 'dart:async';

import 'package:idb_shim/idb_client_native.dart';
import 'package:idb_shim/idb_sdb.dart';
import 'package:test/test.dart';

final _store = SdbStoreRef<int, SdbModel>('test');
SdbDatabaseSchema get _schema =>
    SdbDatabaseSchema(stores: [_store.schema(autoIncrement: true)]);
const _dbName = 'sdb_web_version_change_test.db';

void main() {
  group('sdb_web_version_change', () {
    var factory = sdbFactoryWeb;
    var requests = <SdbVersionChangeRequestEvent>[];
    var blocked = <SdbBlockedEvent>[];

    Future<SdbDatabase> open(int version, {bool? closeOnVersionChange}) =>
        factory.openDatabase(
          _dbName,
          options: SdbOpenDatabaseOptions(
            version: version,
            schema: _schema,
            closeOnVersionChange: closeOnVersionChange,
            onVersionChangeRequest: requests.add,
            onBlocked: blocked.add,
          ),
        );

    setUp(() async {
      requests.clear();
      blocked.clear();
      await factory.deleteDatabase(_dbName);
    });

    test('closes on version change, the other open is not blocked', () async {
      var db1 = await open(1);
      await _store.add(db1, {'test': 1});

      var db2 = await open(2);
      expect(db2.version, 2);
      expect(db1.isClosed, isTrue);
      expect(requests, hasLength(1));
      var request = requests.first;
      expect(request.db, db1);
      expect(request.oldVersion, 1);
      expect(request.newVersion, 2);
      expect(blocked, isEmpty);

      // The data is there, the closed connection is unusable.
      expect(await _store.count(db2), 1);
      await expectLater(_store.count(db1), throwsA(anything));
      await db2.close();
    });

    test('blocked until the other connection closes', () async {
      var db1 = await open(1, closeOnVersionChange: false);

      var blockedCompleter = Completer<SdbBlockedEvent>();
      var openFuture = factory.openDatabase(
        _dbName,
        options: SdbOpenDatabaseOptions(
          version: 2,
          schema: _schema,
          onBlocked: blockedCompleter.complete,
        ),
      );
      var blockedEvent = await blockedCompleter.future;
      expect(blockedEvent.name, _dbName);
      expect(blockedEvent.version, 2);
      // The request was made, the database did not close.
      expect(requests, hasLength(1));
      expect(requests.first.newVersion, 2);
      expect(db1.isClosed, isFalse);
      var done = false;
      unawaited(openFuture.then((_) => done = true));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(done, isFalse);

      // Closing the old connection lets the open complete.
      await db1.close();
      var db2 = await openFuture;
      expect(done, isTrue);
      expect(db2.version, 2);
      await db2.close();
    });

    test('closes on delete', () async {
      var db1 = await open(1);
      await factory.deleteDatabase(_dbName);
      expect(db1.isClosed, isTrue);
      expect(requests, hasLength(1));
      expect(requests.first.oldVersion, 1);
      expect(requests.first.newVersion, isNull);
    });

    test('raw version change event', () async {
      // The raw idb stream tells a delete apart too.
      var db1 = await open(1, closeOnVersionChange: false);
      var events = <int?>[];
      db1.rawIdb.onVersionChange.listen((event) {
        events.add(event.newVersionOrNull);
        db1.rawIdb.close();
      });
      await factory.deleteDatabase(_dbName);
      expect(events, [null]);
      expect(requests.single.newVersion, isNull);
    });
  }, skip: !idbFactoryNativeSupported);
}
