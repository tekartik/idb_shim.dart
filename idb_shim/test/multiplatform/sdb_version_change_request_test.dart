import 'package:idb_shim/sdb.dart';
import 'package:test/test.dart';

final _store = SdbStoreRef<int, SdbModel>('test');
SdbDatabaseSchema get _schema =>
    SdbDatabaseSchema(stores: [_store.schema(autoIncrement: true)]);
const _dbName = 'sdb_version_change_request_test.db';

void main() {
  group('version_change_request', () {
    test('options', () {
      var options = SdbOpenDatabaseOptions(version: 1);
      // Null: close, and alert, at open time.
      expect(options.versionChangeAction, isNull);
      expect(options.onVersionChangeRequest, isNull);
      expect(options.blockedAction, isNull);
      expect(options.onBlocked, isNull);
      void onRequest(SdbVersionChangeRequestEvent event) {}
      void onBlocked(SdbBlockedEvent event) {}
      var copy = options.copyWith(
        versionChangeAction: SdbVersionChangeAction.none,
        onVersionChangeRequest: onRequest,
        blockedAction: SdbBlockedAction.none,
        onBlocked: onBlocked,
      );
      expect(copy.version, 1);
      expect(copy.versionChangeAction, SdbVersionChangeAction.none);
      expect(copy.onVersionChangeRequest, onRequest);
      expect(copy.blockedAction, SdbBlockedAction.none);
      expect(copy.onBlocked, onBlocked);
      var copy2 = copy.copyWith(
        version: 2,
        versionChangeAction: SdbVersionChangeAction.closeAndReload,
      );
      expect(copy2.version, 2);
      expect(copy2.versionChangeAction, SdbVersionChangeAction.closeAndReload);
      expect(copy2.onVersionChangeRequest, onRequest);
      expect(copy2.blockedAction, SdbBlockedAction.none);
      expect(copy2.onBlocked, onBlocked);
    });

    test('isClosed', () async {
      var factory = newSdbFactoryMemory();
      var db = await factory.openDatabase(
        _dbName,
        options: SdbOpenDatabaseOptions(version: 1, schema: _schema),
      );
      expect(db.isClosed, isFalse);
      await db.close();
      expect(db.isClosed, isTrue);
      // Closing twice is fine.
      await db.close();
      expect(db.isClosed, isTrue);
    });

    test('no version change request in memory', () async {
      // A memory (sembast) database has no other connection: a second open at
      // a higher version upgrades it while the first one stays open, nothing
      // is requested nor blocked.
      var factory = newSdbFactoryMemory();
      var requests = <SdbVersionChangeRequestEvent>[];
      var db1 = await factory.openDatabase(
        _dbName,
        options: SdbOpenDatabaseOptions(
          version: 1,
          schema: _schema,
          onVersionChangeRequest: requests.add,
        ),
      );
      var db2 = await factory.openDatabase(
        _dbName,
        options: SdbOpenDatabaseOptions(
          version: 2,
          schema: _schema,
          onBlocked: (_) => fail('never blocked in memory'),
        ),
      );
      expect(db2.version, 2);
      expect(requests, isEmpty);
      expect(db1.isClosed, isFalse);
      await db1.close();
      await db2.close();
    });
  });
}
