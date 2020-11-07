import 'package:idb_shim/idb.dart';

abstract class IdbTransactionBase
    with IdbTransactionMixin
    implements Transaction {
  @override
  Database database;

  IdbTransactionBase(this.database);
}

/// Commmon implementation.
mixin IdbTransactionMixin implements Transaction {
  @override
  void abort() {
    // To implement for each factory
    // throw DatabaseError('Aborted');
  }
}
