part of idb_shim_client;

// added definition
class DatabaseError extends Error {
  String get message => _message;
  String _message;
  DatabaseError(this._message);

  String toString() => message;
}

// native exception won't be of this type
// the text here has been copied to match the DomException message
class DatabaseReadOnlyError extends DatabaseError {
  static String _MESSAGE = "ReadOnlyError: The transaction is read-only.";
  DatabaseReadOnlyError() : super(_MESSAGE);
}

class DatabaseStoreNotFoundError extends DatabaseError {
  static const String _MESSAGE =
      "NotFoundError: One of the specified object stores was not found.";
  static String storeMessage(var store_OR_stores) =>
  "NotFoundError: One of the specified object stores '${store_OR_stores}' was not found.";
  DatabaseStoreNotFoundError([String message = _MESSAGE]) : super(message);
}

class DatabaseTransactionStoreNotFoundError extends DatabaseError {
  DatabaseTransactionStoreNotFoundError(String store)
      : super("NotFoundError: store '${store}' not found in transaction.");
}

class DatabaseNoKeyError extends DatabaseError {
  static String _MESSAGE =
      "DataError: The data provided does not meet requirements. No key or key range specified.";
  DatabaseNoKeyError() : super(_MESSAGE);
}

class DatabaseInvalidKeyError extends DatabaseError {
  DatabaseInvalidKeyError(key)
      : super(
            "DataError: The data provided does not meet requirements. The parameter '${key}' is not a valid key.");
}
