library idb_shim.quick_standalone;

import 'package:idb_shim/idb_client.dart';
import 'idb_test_common.dart';

const STORE_NAME = "quick_store";
const DB_NAME = "quick_db";
const NAME_INDEX = "quick_index";
const NAME_FIELD = "quick_field";

// so that this can be run directly
main() {
  defineTests(idbMemoryContext);
}

void defineTests(TestContext ctx) {
  IdbFactory idbFactory = ctx.factory;
  group('quick_standalone', () {
    Database db;
    Transaction transaction;
    ObjectStore objectStore;

    void _createTransaction() {
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
      _createTransaction();
      Map value = {NAME_FIELD: "test1"};
      Index index = objectStore.index(NAME_INDEX);
      return objectStore.add(value).then((key) {
        return index.get("test1").then((readValue) {
          expect(readValue, value);
        });
      });
    });
  });
}
