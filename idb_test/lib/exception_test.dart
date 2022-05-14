import 'package:idb_shim/idb_client.dart';

import 'idb_test_common.dart';

// so that this can be run directly
void main() {
  defineTests(idbMemoryContext);
}

void defineTests(TestContext ctx) {
  final idbFactory = ctx.factory;

  Database? db;
  Transaction? transaction;

  // generic tearDown
  Future dbTearDown() async {
    if (transaction != null) {
      await transaction!.completed;
      transaction = null;
    }
    if (db != null) {
      db!.close();
      db = null;
    }
  }

  group('exception', () {
    // Make testDbName less bad
    final testDbName = ctx.dbName;

    group('error', () {
      setUp(() async {
        await idbFactory!.deleteDatabase(testDbName);
      });

      tearDown(dbTearDown);

      test('create object store not in initialize', () async {
        try {
          await idbFactory!.open(testDbName).then((Database database) {
            try {
              database.createObjectStore(testStoreName, autoIncrement: true);
            } catch (_) {
              //devPrint(e);
              //devPrint(e.runtimeType);
              //devPrint(Trace.format(st));
              database.close();
              rethrow;
            }
            fail('should fail');
          });
        } catch (e, st) {
          expect(isTestFailure(e), isFalse);
          if (!ctx.isIdbEdge) {
            // Trace.format crashing on 2.5.0-dev.2.0
            // devPrint('st: ${Trace.format(st)}');
            expect(st.toString(), contains('createObjectStore'));
          } else {
            print('edge error: $e');
          }
          //devPrint(e);
          //devPrint(Trace.format(st));
        }
      });
    });
  });
}
