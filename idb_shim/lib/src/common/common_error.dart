// Not exported
// ignore_for_file: public_member_api_docs

import 'package:idb_shim/idb_client.dart';

class DatabaseNoKeyExpectedError extends DatabaseError {
  DatabaseNoKeyExpectedError()
    : super(
        'DataError: The object store uses in-line keys and the key parameter was provided.',
      );
}

class DatabaseMissingInlineKeyError extends DatabaseError {
  DatabaseMissingInlineKeyError()
    : super(
        'DataError: The object store uses in-line keys and its value was not found.',
      );
}

class DatabaseMissingKeyError extends DatabaseError {
  DatabaseMissingKeyError()
    : super(
        'DataError: neither keyPath nor autoIncrement set and trying to add object without key.',
      );
}
