import 'package:idb_shim/idb_client.dart';

import '../idb_test_common.dart';

// so that this can be run directly
void main() {
  defineTests(idbMemoryContext);
}

void defineTests(TestContext ctx) {
  IdbFactory idbFactory = ctx.factory;

  Database db;
  Transaction transaction;
  ObjectStore objectStore;

  void _createTransaction() {
    transaction = db.transaction(testStoreName, idbModeReadWrite);
    objectStore = transaction.objectStore(testStoreName);
  }

  // generic tearDown
  Future _tearDown() async {
    if (transaction != null) {
      await transaction.completed;
      transaction = null;
    }
    if (db != null) {
      db.close();
      db = null;
    }
  }

  Future _setUp() async {
    return setUpSimpleStore(idbFactory, dbName: ctx.dbName)
        .then((Database database) {
      db = database;
    });
  }

  group('exception', () {
    // Make testDbName less bad
    String testDbName = ctx.dbName;

    group('error', () {
      setUp(() async {
        await idbFactory.deleteDatabase(testDbName);
      });

      tearDown(_tearDown);

      test('create object store not in initialize', () async {
        try {
          await idbFactory.open(testDbName).then((Database database) {
            try {
              database.createObjectStore(testStoreName, autoIncrement: true);
            } catch (_) {
              //devPrint(e);
              //devPrint(e.runtimeType);
              //devPrint(Trace.format(st));
              database.close();
              rethrow;
            }
            fail("should fail");
          });
          fail("should fail");
        } catch (e, st) {
          expect(isTestFailure(e), isFalse);
          if (!ctx.isIdbEdge) {
            // Trace.format crashing on 2.5.0-dev.2.0
            // devPrint("st: ${Trace.format(st)}");
            expect(st?.toString(), contains("createObjectStore"));
          } else {
            print("edge error: $e");
          }
          //devPrint(e);
          //devPrint(Trace.format(st));
        }
      });

      test('getObject_null', () async {
        await _setUp();
        _createTransaction();
        try {
          await objectStore.getObject(null);
        } catch (e, st) {
          //devPrint(e);
          // Trace.format crashing on 2.5.0-dev.2.0
          // devPrint("st: ${Trace.format(st)}");
          // devPrint("full: ${st}");
          expect(st?.toString(), contains("getObject"));
          expect(e, isNotNull);
        }
      });
    });
  });
}
