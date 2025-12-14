import 'package:idb_shim/sdb.dart';
import 'package:test/test.dart';

//import '../idb_test_common.dart';

void main() {
  group('schema_ref', () {
    test('keyPath', () async {
      expect(SdbKeyPath.single('key'), SdbKeyPath.single('key'));
      expect(SdbKeyPath.single('key'), isNot(SdbKeyPath.single('key1')));
      expect(
        SdbKeyPath.multi(['key1', 'key2']),
        SdbKeyPath.multi(['key1', 'key2']),
      );
      expect(
        SdbKeyPath.multi(['key1', 'key2']),
        isNot(SdbKeyPath.single('key1')),
      );
      expect(
        SdbKeyPath.multi(['key1', 'key2']),
        isNot(SdbKeyPath.multi(['key2', 'key1'])),
      );
    });
    test('index', () async {
      expect(
        SdbIndexSchemaDef(name: 'test', keyPath: 'key', unique: true),
        SdbIndexSchemaDef(name: 'test', keyPath: 'key', unique: true),
      );
      expect(
        SdbIndexSchemaDef(name: 'test', keyPath: 'key', unique: true),
        isNot(SdbIndexSchemaDef(name: 'test', keyPath: 'key', unique: false)),
      );
      expect(
        SdbIndexSchemaDef(name: 'test', keyPath: 'key', unique: true),
        isNot(SdbIndexSchemaDef(name: 'test', keyPath: 'key1', unique: true)),
      );
      expect(
        SdbIndexSchemaDef(name: 'test', keyPath: 'key', unique: true),
        isNot(SdbIndexSchemaDef(name: 'test1', keyPath: 'key', unique: true)),
      );
    });
    test('store', () async {
      expect(
        SdbStoreSchemaDef(name: 'store1'),
        SdbStoreSchemaDef(name: 'store1'),
      );
      expect(
        SdbStoreSchemaDef(name: 'store1'),
        isNot(SdbStoreSchemaDef(name: 'store2')),
      );
      expect(
        SdbStoreSchemaDef(
          name: 'store1',
          indexes: [
            SdbIndexSchemaDef(name: 'index1', keyPath: 'key', unique: true),
          ],
        ),
        SdbStoreSchemaDef(
          name: 'store1',
          indexes: [
            SdbIndexSchemaDef(name: 'index1', keyPath: 'key', unique: true),
          ],
        ),
      );
      expect(
        SdbStoreSchemaDef(
          name: 'store1',
          indexes: [
            SdbIndexSchemaDef(name: 'index1', keyPath: 'key', unique: true),
          ],
        ),
        isNot(
          SdbStoreSchemaDef(
            name: 'store1',
            indexes: [
              SdbIndexSchemaDef(name: 'index1', keyPath: 'key', unique: false),
            ],
          ),
        ),
      );
    });
    test('database', () async {
      expect(
        SdbDatabaseSchemaDef(stores: [SdbStoreSchemaDef(name: 'store1')]),
        SdbDatabaseSchemaDef(stores: [SdbStoreSchemaDef(name: 'store1')]),
      );
      expect(
        SdbDatabaseSchemaDef(stores: [SdbStoreSchemaDef(name: 'store1')]),
        isNot(
          SdbDatabaseSchemaDef(stores: [SdbStoreSchemaDef(name: 'store2')]),
        ),
      );
    });
  });
}
