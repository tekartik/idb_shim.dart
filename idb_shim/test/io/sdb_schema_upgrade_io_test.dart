@TestOn('vm')
library;

import 'package:idb_shim/sdb/sdb.dart';
import 'package:path/path.dart';
import 'package:sembast/sembast.dart' show disableSembastCooperator;
import 'package:sembast/sembast.dart';
import 'package:test/test.dart';

import 'sdb_schema_upgrade_validator.dart';

final _store1 = SdbStoreRef<int, SdbModel>('store1');
final _store2 = SdbStoreRef<int, SdbModel>('store2');
final _store3 = SdbStoreRef<int, SdbModel>('store3');
final _index2 = _store2.index<int>('index2');

void main() {
  disableSembastCooperator();
  var dbPath = join(
    '.dart_tool',
    'tekartik',
    'idb_shim_sdb_schema_upgrade_io_test',
  );
  // var schemaVersion = (1, SdbDatabaseSchema(stores: []));
  var options1 = SdbOpenDatabaseOptions(
    version: 1,
    schema: SdbDatabaseSchema(stores: [_store1.schema()]),
  );
  var options2 = SdbOpenDatabaseOptions(
    version: 2,
    schema: SdbDatabaseSchema(
      stores: [
        _store1.schema(),
        _store2.schema(
          autoIncrement: true,
          keyPath: SdbKeyPath.single('id'),
          indexes: [_index2.schema(keyPath: 'my_field')],
        ),
      ],
    ),
  );
  var options3 = SdbOpenDatabaseOptions(
    version: 3,
    schema: SdbDatabaseSchema(
      stores: [
        _store1.schema(),
        _store2.schema(
          autoIncrement: true,
          keyPath: SdbKeyPath.single('id'),
          indexes: [_index2.schema(keyPath: 'my_field')],
        ),
        _store3.schema(),
      ],
    ),
  );

  var allOptions = [options1, options2, options3];
  var optionsLatest = options3;
  test('schema open upgrade', () async {
    var dbName = join(dbPath, 'schema_upgrade.db');
    var factory = sdbFactoryIo;
    await factory.deleteDatabase(dbName);
    for (var options in allOptions) {
      var db = await factory.openDatabase(dbName, options: options);
      await db.close();
    }
  });
  test('schema open create', () async {
    var dbName = join(dbPath, 'schema_create.db');
    var factory = sdbFactoryIo;

    for (var options in allOptions) {
      await factory.deleteDatabase(dbName);
      var db = await factory.openDatabase(dbName, options: options);
      await db.close();
    }
  });

  test('schema upgrade latest', () async {
    await SdbSchemaUpgradeValidator(
      name: 'schema_upgrade_test',
    ).run(options: optionsLatest);
  });
}
