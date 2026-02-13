// ignore_for_file: avoid_print
library;

import 'package:idb_shim/sdb.dart';
import 'package:path/path.dart';

void main() async {
  print('Stored in .local/tmp/out/my_records.db');
  final sdbFactory = sdbFactoryIo;
  var dbPath = join('.local', 'tmp', 'out', 'my_records.db');

  // Testing only, remove any existing database
  await sdbFactory.deleteDatabase(dbPath);
  var store = SdbStoreRef<int, SdbModel>('store');
  // open the database
  final db = await sdbFactory.openDatabase(
    dbPath,
    options: SdbOpenDatabaseOptions(
      version: 1,
      schema: SdbDatabaseSchema(stores: [store.schema(autoIncrement: true)]),
    ),
  );
  // Add some data
  var key = await store.add(db, {'some': 'data'});
  await store.add(db, {'some': 'other data'});
  final value = await store.record(key).get(db);
  print('Read one record: $value');

  // Read all records
  var allRecords = await store.findRecords(db);
  print('All records:');
  for (var record in allRecords) {
    print(record);
  }
  var foundRecords = await db.inStoreTransaction(
    store,
    SdbTransactionMode.readOnly,
    (txn) {
      return store.findRecords(txn, filter: SdbFilter.equals('some', 'data'));
    },
  );
  print('Filtered records:');
  for (var record in foundRecords) {
    print(record);
  }
  foundRecords = await db.inStoreTransaction(
    store,
    SdbTransactionMode.readOnly,
    (txn) {
      return txn.txnStore.findRecords(filter: SdbFilter.equals('some', 'data'));
    },
  );
  print('Filtered records in transaction:');
  for (var record in foundRecords) {
    print(record);
  }

  await db.close();
}
