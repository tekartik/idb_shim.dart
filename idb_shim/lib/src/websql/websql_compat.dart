import 'package:idb_shim/idb_client.dart';
import 'package:idb_shim/src/common/common_factory.dart';

@deprecated
IdbFactory? get idbFactoryWebSql {
  if (IdbWebSqlFactory.supported) {
    return IdbWebSqlFactory();
  } else {
    return null;
  }
}

@deprecated
IdbFactory? get idbWebSqlFactory => idbFactoryWebSql;

@deprecated
class IdbWebSqlFactory extends IdbFactoryBase {
  @override
  bool get persistent => false;

  static IdbWebSqlFactory? _instance;

  IdbWebSqlFactory._();

  @override
  String get name => idbFactoryNameWebSql;

  factory IdbWebSqlFactory() {
    _instance ??= IdbWebSqlFactory._();

    return _instance!;
  }

  @override
  Future<Database> open(String dbName,
      {int? version,
      OnUpgradeNeededFunction? onUpgradeNeeded,
      OnBlockedFunction? onBlocked}) async {
    throw 'WebSQL no longer supported';
  }

  @override
  Future<IdbFactory> deleteDatabase(String dbName,
      {OnBlockedFunction? onBlocked}) async {
    throw 'WebSQL no longer supported';
  }

  @override
  bool get supportsDatabaseNames {
    return false;
  }

  @override
  Future<List<String>> getDatabaseNames() {
    throw 'WebSQL no longer supported';
  }

  /// Check if WebSQL is supported on this platform
  static bool get supported {
    return false;
  }

  @override
  bool get supportsDoubleKey => false;
}
