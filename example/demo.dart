import 'package:idb_shim/idb_io.dart';
import 'package:idb_shim/idb_client.dart';

main() async {
  IdbFactory idbFactory = getIdbPersistentFactory('test/tmp/out');

  // define the store name
  const String storeName = "records";

  // open the database
  Database db = await idbFactory.open("my_records.db", version: 1,
      onUpgradeNeeded: (VersionChangeEvent event) {
    Database db = event.database;
    // create the store
    db.createObjectStore(storeName, autoIncrement: true);
  });

  // put some data
  var txn = db.transaction(storeName, "readwrite");
  var store = txn.objectStore(storeName);
  var key = await store.put({"some": "data"});
  await txn.completed;

  // read some data
  txn = db.transaction(storeName, "readonly");
  store = txn.objectStore(storeName);
  Map value = await store.getObject(key);
  await txn.completed;

  print(value);
}
