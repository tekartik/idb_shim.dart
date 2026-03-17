import 'dart:typed_data';

import 'package:idb_shim/sdb.dart';
import 'package:idb_test/sdb_test.dart';

import 'idb_test_common.dart';

void main() {
  idbSdbTypeTest(idbMemoryContext);
}

var typeModelStore = SdbStoreRef<int, SdbModel>('model');
var typeModelIndex = typeModelStore.index('type');
var typeModelStoreSchema = typeModelStore.schema(
  autoIncrement: true,
  indexes: [typeModelIndex.schema(keyPath: 'type')],
);

var anyTypeStore = SdbStoreRef<String, Object>('type');
var anyTypeStoreSchema = anyTypeStore.schema();

void idbSdbTypeTest(TestContext ctx) {
  var factory = sdbFactoryFromIdb(ctx.factory);
  sdbTypeTest(SdbTestContext(factory));
}

/// Simple SDB test
void sdbTypeTest(SdbTestContext ctx) {
  var factory = ctx.factory;
  late SdbDatabase db;
  group('type', () {
    var dbName = 'type_test.db';
    Future<void> open() async {
      db = await factory.openDatabase(
        dbName,
        options: SdbOpenDatabaseOptions(
          version: 1,
          schema: SdbDatabaseSchema(
            stores: [typeModelStoreSchema, anyTypeStoreSchema],
          ),
        ),
      );
    }

    setUpAll(() async {
      await factory.deleteDatabase(dbName);
      await open();
    });
    tearDownAll(() async {
      await db.close();
    });

    Future<void> reopen() async {
      await db.close();
      await open();
    }

    Future<void> testType<T extends Object>(String key, T value) async {
      // Simple store
      var ref = anyTypeStore.record(key);
      await ref.put(db, value);
      var readValue = await ref.getValue(db);
      expect(readValue, value);
      expect(readValue, isA<T>());

      // Model
      var modelKey = await typeModelStore.add(db, {
        'value': value,
        'type': key,
      });
      var modelRef = typeModelStore.record(modelKey);
      readValue = (await modelRef.getValue(db))!['value'];
      expect(readValue, value);
      expect(readValue, isA<T>());

      await reopen();

      // Simple store
      readValue = await ref.getValue(db);
      expect(readValue, value);
      expect(readValue, isA<T>());
      readValue = (await anyTypeStore.findRecord(
        db,
        options: SdbFindOptions(boundaries: SdbBoundaries.key(key)),
      ))!.value;
      expect(readValue, value);
      // Weird...skip for uint8List for now
      expect(
        readValue,
        isA<T>(),
        reason:
            'findRecords should return the correct type $T instead of ${readValue.runtimeType}',
      );

      // Model
      readValue = (await modelRef.getValue(db))!['value'];
      expect(readValue, value);
      expect(readValue, isA<T>());
      readValue = (await typeModelStore.findRecord(
        db,
        options: SdbFindOptions(boundaries: SdbBoundaries.key(modelKey)),
      ))!.value['value'];
      expect(readValue, value);
      expect(
        readValue,
        isA<T>(),
        reason:
            'findRecords should return the correct type $T instead of ${readValue.runtimeType}',
      );
      // Using index
      readValue = (await typeModelIndex.record(key).getValue(db))!['value'];
      expect(readValue, value);
      expect(readValue, isA<T>());
      readValue = (await typeModelIndex.findRecord(
        db,
        options: SdbFindOptions(boundaries: SdbBoundaries.key(key)),
      ))!.value['value'];
      expect(readValue, value);
      expect(readValue, isA<T>());
    }

    test('int', () async {
      await testType('int', 1);
    });
    test('string', () async {
      await testType('string', 'test');
    });
    test('bool', () async {
      await testType('bool', 'true');
    });
    test('double', () async {
      await testType('double', 1.5);
    });
    test('map', () async {
      await testType<Map<String, Object?>>('map', {'test': 1, 'other': true});
    });
    test('list', () async {
      await testType<List<Object?>>('list', ['test', 1, 'other', true]);
    });
    test('uint8list', () async {
      await testType('uint8list', Uint8List.fromList([1, 2, 3]));
    });
    test('datetime', () async {
      await testType('datetime', DateTime.timestamp());
    });
    test('timestamp', () async {
      await testType('timestamp', SdbTimestamp.now());
    });
    test('blob', () async {
      await testType('blob', SdbBlob.fromList([1, 2, 3]));
    });
  });
}
