library idb_shim.quick_standalone;

import 'package:idb_shim/idb_client.dart';
import 'idb_test_common.dart';

const STORE_NAME = "quick_store";
const DB_NAME = "quick_db";
const NAME_INDEX = "quick_index";
const NAME_FIELD = "quick_field";

// so that this can be run directly
void main() => defineTests(idbTestMemoryFactory);

void defineTests(IdbFactory idbFactory) {
  group('quick_standalone', () {
    Database db;
    Transaction transaction;
    ObjectStore objectStore;

    _createTransaction() {
      transaction = db.transaction(STORE_NAME, idbModeReadWrite);
      objectStore = transaction.objectStore(STORE_NAME);
    }

    setUp(() {
      return idbFactory.deleteDatabase(DB_NAME).then((_) {
        void _initializeDatabase(VersionChangeEvent e) {
          Database db = e.database;
          ObjectStore objectStore =
              db.createObjectStore(STORE_NAME, autoIncrement: true);
          objectStore.createIndex(NAME_INDEX, NAME_FIELD, unique: true);
        }
        return idbFactory
            .open(DB_NAME, version: 1, onUpgradeNeeded: _initializeDatabase)
            .then((Database database) {
          db = database;
          _createTransaction();
        });
      });
    });

    tearDown(() {
      if (transaction != null) {
        return transaction.completed.then((_) {
          db.close();
        });
      } else {
        db.close();
      }
    });

    test('add/get map', () {
      Map value = {NAME_FIELD: "test1"};
      Index index = objectStore.index(NAME_INDEX);
      return objectStore.add(value).then((key) {
        return index.get("test1").then((Map readValue) {
          expect(readValue, value);
        });
      });
    });
  });
}
