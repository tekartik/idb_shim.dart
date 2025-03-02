// ignore_for_file: avoid_print

import 'package:idb_shim/idb_io.dart';
import 'package:idb_shim/sdb.dart';

void main() async {
  final idbFactory = sdbFactoryFromIdb(
    getIdbFactoryPersistent('.local/tmp/out'),
  );

  var store = SdbStoreRef<int, SdbModel>('store');
  // open the database
  final db = await idbFactory.openDatabase(
    'my_records.db',
    version: 1,
    onVersionChange: (SdbVersionChangeEvent event) {
      final db = event.db;
      // create the store
      db.createStore(store, autoIncrement: true);
    },
  );
  // Add some data
  var key = await store.add(db, {'some': 'data'});
  final value = await store.record(key).get(db);

  print(value);
  await db.close();
}
