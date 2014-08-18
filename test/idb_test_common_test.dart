library idb_test_utils;

import 'package:unittest/unittest.dart';
import 'idb_test_common.dart';
import 'package:idb_shim/idb_client.dart';

void main() {

  group('idb_test_common', () {

    test('transaction_readonly_error', () {
      expect(isTransactionReadOnlyError(null), isFalse);
      expect(isTransactionReadOnlyError(new DatabaseStoreNotFoundError()), isFalse);

      expect(isTransactionReadOnlyError(new DatabaseReadOnlyError()), isTrue);
      // Firefox
      expect(isTransactionReadOnlyError(new DatabaseError("A mutation operation was attempted in a READ_ONLY transaction.")), isTrue);
    });

    test('store_notfound_error', () {
      expect(isStoreNotFoundError(null), isFalse);
      expect(isStoreNotFoundError(new DatabaseReadOnlyError()), isFalse);

      expect(isStoreNotFoundError(new DatabaseStoreNotFoundError()), isTrue);
      // Firefox
      expect(isStoreNotFoundError(new DatabaseError('The operation failed because the requested database object could not be found. For example, an object store did not exist but was being opened."  code: "8" nsresult: "0x80660003 (NotFoundError)"  location: "<unknown>"')), isTrue);
    });
  });
}
