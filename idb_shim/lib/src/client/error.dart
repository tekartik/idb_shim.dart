library idb_shim.error;

import 'package:idb_shim/idb.dart';

// native exception won't be of this type
// the text here has been copied to match the DomException message

/// Read only error.
class DatabaseReadOnlyError extends DatabaseError {
  static final _errorMessage = 'ReadOnlyError: The transaction is read-only.';

  /// Read only error.
  DatabaseReadOnlyError() : super(_errorMessage);
}

/// Store not found error.
class DatabaseStoreNotFoundError extends DatabaseError {
  static const String _errorMessage =
      'NotFoundError: One of the specified object stores was not found.';

  /// Store not found message.
  static String storeMessage(Object storeOrStores) =>
      "NotFoundError: One of the specified object stores '$storeOrStores' was not found.";

  /// Store not found error.
  DatabaseStoreNotFoundError([super.message = _errorMessage]);
}

/// Index not found.
class DatabaseIndexNotFoundError extends DatabaseError {
  /// Message helper.
  static String indexMessage(String indexName) =>
      "NotFoundError: The specified index '$indexName' was not found.";

  /// Index not found.
  DatabaseIndexNotFoundError(String indexName) : super(indexMessage(indexName));
}

/// Store not found.
class DatabaseTransactionStoreNotFoundError extends DatabaseError {
  /// Store not found.
  DatabaseTransactionStoreNotFoundError(String store)
      : super("NotFoundError: store '$store' not found in transaction.");
}

/// no key error.
class DatabaseNoKeyError extends DatabaseError {
  static final String _errorMessage =
      'DataError: The data provided does not meet requirements. No key or key range specified.';

  /// no key error.
  DatabaseNoKeyError() : super(_errorMessage);
}

/// invalid key error.
class DatabaseInvalidKeyError extends DatabaseError {
  /// invalid key error.
  DatabaseInvalidKeyError(Object? key)
      : super(
            "DataError: The data provided does not meet requirements. The parameter '$key' is not a valid key.");
}
