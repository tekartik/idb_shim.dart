library;

import 'package:idb_shim/idb.dart';

// native exception won't be of this type
// the text here has been copied to match the DomException message

/// Read only error.
class DatabaseReadOnlyError extends DatabaseError {
  /// Read only error.
  DatabaseReadOnlyError() : super(_errorMessage);
  static const _errorMessage = 'ReadOnlyError: The transaction is read-only.';
}

/// Store not found error.
class DatabaseStoreNotFoundError extends DatabaseError {
  /// Store not found error.
  DatabaseStoreNotFoundError([super.message = _errorMessage]);
  static const String _errorMessage =
      'NotFoundError: One of the specified object stores was not found.';

  /// Store not found message.
  static String storeMessage(Object storeOrStores) =>
      "NotFoundError: One of the specified object stores '$storeOrStores' was not found.";
}

/// Index not found.
class DatabaseIndexNotFoundError extends DatabaseError {
  /// Index not found.
  DatabaseIndexNotFoundError(String indexName) : super(indexMessage(indexName));

  /// Message helper.
  static String indexMessage(String indexName) =>
      "NotFoundError: The specified index '$indexName' was not found.";
}

/// Store not found.
class DatabaseTransactionStoreNotFoundError extends DatabaseError {
  /// Store not found.
  DatabaseTransactionStoreNotFoundError(String store)
    : super("NotFoundError: store '$store' not found in transaction.");
}

/// no key error.
class DatabaseNoKeyError extends DatabaseError {
  /// no key error.
  DatabaseNoKeyError() : super(_errorMessage);
  static const String _errorMessage =
      'DataError: The data provided does not meet requirements. No key or key range specified.';
}

/// invalid key error.
class DatabaseInvalidKeyError extends DatabaseError {
  /// invalid key error.
  DatabaseInvalidKeyError(Object? key)
    : super(
        "DataError: The data provided does not meet requirements. The parameter '$key' is not a valid key.",
      );
}
