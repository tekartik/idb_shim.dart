library;

import 'package:idb_shim/sdb.dart';
import 'package:idb_shim/utils/sdb_import_export.dart';

import 'idb_test_common.dart';
import 'sdb_test.dart';
import 'src/test_native_object.dart';

void main() {
  sdbNativeValueTests(sdbMemoryContext);
}

final _store = SdbStoreRef<String, SdbValue>('native_value');

SdbNativeValue _nativeValue() => SdbNativeValue(newTestNativeObject());

/// Native values, stored or rejected depending on the factory.
void sdbNativeValueTests(SdbTestContext ctx) {
  var factory = ctx.factory;

  group('sdb_native_value', () {
    var dbName = 'sdb_native_value.db';
    late SdbDatabase db;
    setUp(() async {
      await factory.deleteDatabase(dbName);
      db = await factory.openDatabase(
        dbName,
        options: SdbOpenDatabaseOptions(
          version: 1,
          schema: SdbDatabaseSchema(stores: [_store.schema()]),
        ),
      );
    });
    tearDown(() async {
      await db.close();
    });

    if (ctx.supportsNativeValue) {
      test('put get', () async {
        await _store.record('root').put(db, _nativeValue());
        await _store.record('nested').put(db, {
          'value': 1,
          'native': _nativeValue(),
        });
        expect(await _store.record('root').getValue(db), isA<SdbNativeValue>());
        var nested = (await _store.record('nested').getValue(db))! as Map;
        expect(nested['value'], 1);
        expect(nested['native'], isA<SdbNativeValue>());
      });
      test('export', () async {
        await _store.record('plain').put(db, {'value': 1});
        await _store.record('root').put(db, _nativeValue());
        await _store.record('nested').put(db, {
          'value': 2,
          'native': _nativeValue(),
        });
        await expectLater(
          () => sdbExportDatabaseLines(db),
          throwsA(isA<ArgumentError>()),
        );
        var lines = await sdbExportDatabaseLines(
          db,
          nativeValueEncoder: (context) async {
            await Future<void>.delayed(Duration.zero);
            return context.path.isEmpty
                ? SdbExportNativeValue.dropRecord
                : 'native ${context.key}';
          },
        );
        var importedDb = await sdbImportDatabase(
          lines,
          factory,
          'sdb_native_value_imported.db',
        );
        try {
          expect(await _store.record('plain').getValue(importedDb), {
            'value': 1,
          });
          expect(await _store.record('root').getValue(importedDb), isNull);
          expect(await _store.record('nested').getValue(importedDb), {
            'value': 2,
            'native': 'native nested',
          });
        } finally {
          await importedDb.close();
        }
      });
    } else {
      test('put rejected', () async {
        await expectLater(
          () => _store.record('key').put(db, _nativeValue()),
          // The transaction abort error can hide the ArgumentError.
          throwsA(anything),
        );
        expect(await _store.count(db), 0);
      });
      test('export encoder not called', () async {
        await _store.record('plain').put(db, {'value': 1});
        expect(
          await sdbExportDatabaseLines(
            db,
            nativeValueEncoder: (_) => fail('no native value'),
          ),
          await sdbExportDatabaseLines(db),
        );
      });
    }
  });
}
