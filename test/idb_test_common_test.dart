library idb_test_utils;

import 'idb_test_common.dart';
import 'package:idb_shim/idb_client.dart';

void main() {
  group('idb_test_common', () {
    test('transaction_readonly_error', () {
      expect(isTransactionReadOnlyError(null), isFalse);
      expect(isTransactionReadOnlyError(new DatabaseStoreNotFoundError()),
          isFalse);

      expect(isTransactionReadOnlyError(new DatabaseReadOnlyError()), isTrue);
      // Firefox
      expect(
          isTransactionReadOnlyError(new DatabaseError(
              "A mutation operation was attempted in a READ_ONLY transaction.")),
          isTrue);
    });

    test('store_notfound_error', () {
      expect(isNotFoundError(null), isFalse);
      expect(isNotFoundError(new DatabaseReadOnlyError()), isFalse);

      expect(isNotFoundError(new DatabaseStoreNotFoundError()), isTrue);
      // Firefox
      expect(
          isNotFoundError(new DatabaseError(
              'The operation failed because the requested database object could not be found. For example, an object store did not exist but was being opened."  code: "8" nsresult: "0x80660003 (NotFoundError)"  location: "<unknown>"')),
          isTrue);
    });

    test('isTestFailure', () {
      try {
        fail("failure");
      } catch (e) {
        expect(isTestFailure(e), isTrue);
      }
      try {
        throw 'some string';
      } catch (e) {
        expect(isTestFailure(e), isFalse);
      }
    });
  });
}
