library idb_shim.quick_standalone;

import 'package:idb_shim/idb_client.dart';

import 'idb_test_common.dart';

const _storeName = 'quick_store';
const _dbName = 'quick_db';
const _nameIndex = 'quick_index';
const _nameField = 'quick_field';

// so that this can be run directly
void main() {
  defineTests(idbMemoryContext);
}

void defineTests(TestContext ctx) {
  final idbFactory = ctx.factory;
  group('quick_standalone', () {
    late Database db;
    Transaction? transaction;
    late ObjectStore objectStore;

    void dbCreateTransaction() {
      transaction = db.transaction(_storeName, idbModeReadWrite);
      objectStore = transaction!.objectStore(_storeName);
    }

    setUp(() {
      return idbFactory!.deleteDatabase(_dbName).then((_) {
        void onUpgradeNeeded(VersionChangeEvent e) {
          final db = e.database;
          final objectStore =
              db.createObjectStore(_storeName, autoIncrement: true);
          objectStore.createIndex(_nameIndex, _nameField, unique: true);
        }

        return idbFactory
            .open(_dbName, version: 1, onUpgradeNeeded: onUpgradeNeeded)
            .then((Database database) {
          db = database;
        });
      });
    });

    tearDown(() {
      if (transaction != null) {
        return transaction!.completed.then((_) {
          db.close();
        });
      } else {
        db.close();
      }
      return null;
    });

    test('add/get map', () {
      dbCreateTransaction();
      final value = {_nameField: 'test1'};
      final index = objectStore.index(_nameIndex);
      return objectStore.add(value).then((key) {
        return index.get('test1').then((readValue) {
          expect(readValue, value);
        });
      });
    });
  });
}
