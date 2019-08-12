import 'package:idb_shim/idb.dart';

abstract class IdbTransactionBase implements Transaction {
  @override
  Database database;

  IdbTransactionBase(this.database);
}
