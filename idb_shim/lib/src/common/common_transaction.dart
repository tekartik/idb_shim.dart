// ignore_for_file: public_member_api_docs

import 'package:idb_shim/idb.dart';

abstract class IdbTransactionBase
    with IdbTransactionMixin
    implements Transaction {

  IdbTransactionBase(this.database);
  @override
  Database database;
}

/// Commmon implementation.
mixin IdbTransactionMixin implements Transaction {
  @override
  void abort() {
    // To implement for each factory
    // throw DatabaseError('Aborted');
  }
}
