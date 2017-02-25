import 'package:idb_shim/idb_client.dart';
import 'idb_test_common.dart';
import 'package:stack_trace/stack_trace.dart';
// so that this can be run directly
main() {
  defineTests(idbMemoryContext);
}

void defineTests(TestContext ctx) {
  IdbFactory idbFactory = ctx.factory;

  Database db;
  Transaction transaction;
  ObjectStore objectStore;

  _createTransaction() {
    transaction = db.transaction(testStoreName, idbModeReadWrite);
    objectStore = transaction.objectStore(testStoreName);
  }

  // generic tearDown
  _tearDown() async {
    if (transaction != null) {
      await transaction.completed;
      transaction = null;
    }
    if (db != null) {
      db.close();
      db = null;
    }
  }

  _setUp() async {
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
          expect(Trace.format(st), contains(".createObjectStore"));
          //devPrint(e);
          //devPrint(Trace.format(st));
        }
      });
    });

    group('exception', () {
      tearDown(_tearDown);

      test('getObject_null', () async {
        await _setUp();
        _createTransaction();
        try {
          await objectStore.getObject(null);
        } catch (e, st) {
          //devPrint(e);
          //devPrint("got: ${Trace.format(st)}");
          //devPrint("full: ${st}");
          expect(Trace.format(st), contains(".getObject"));

          expect(e, isNotNull);
        }
      });
    });
  });
}
