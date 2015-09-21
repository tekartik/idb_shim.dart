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
  static String _MESSAGE =
      "NotFoundError: One of the specified object stores was not found.";
  DatabaseStoreNotFoundError() : super(_MESSAGE);
}
