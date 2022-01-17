// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:idb_shim/idb_client.dart';
import 'package:idb_shim/src/common/common_factory.dart';
import 'package:idb_shim/src/logger/logger_database.dart';

enum IdbFactoryLoggerType {
  all,
}

abstract class IdbFactoryLogger extends IdbFactory {
  /// Allow setting a max number of logs
  static int? debugMaxLogCount;

  IdbFactory get factory;

  IdbFactoryLoggerType? type;

  void log(String message, {int? id});
  void err(String message, {int? id});
}

/// Get or create new logger
IdbFactoryLogger getIdbFactoryLogger(IdbFactory factory,
    {IdbFactoryLoggerType type = IdbFactoryLoggerType.all}) {
  if (factory is IdbFactoryWrapperImpl) {
    factory.type = type;
    return factory;
  }
  return IdbFactoryWrapperImpl(factory);
}

int _logCount = 0;
bool get _incrementAndShouldLog {
  ++_logCount;
  if (IdbFactoryLogger.debugMaxLogCount != null) {
    return _logCount <= IdbFactoryLogger.debugMaxLogCount!;
  }
  return false;
}

/// Wrapper for window.indexedDB and worker self.indexedDB
class IdbFactoryWrapperImpl extends IdbFactoryBase implements IdbFactoryLogger {
  final IdbFactory nativeFactory;
  static int _id = 0;

  @override
  void log(String message, {int? id}) {
    if (_incrementAndShouldLog) {
      print('[idb${id != null ? '-$id' : ''}]: $message');
    }
  }

  @override
  void err(String message, {int? id}) {
    if (_incrementAndShouldLog) {
      log('!!! $message', id: id);
    }
  }

  @override
  bool get persistent => true;

  IdbFactoryWrapperImpl(this.nativeFactory) {
    assert(nativeFactory is! IdbFactoryWrapperImpl);
  }

  @override
  String get name => idbFactoryNameNative;

  @override
  Future<Database> open(String dbName,
      {int? version,
      OnUpgradeNeededFunction? onUpgradeNeeded,
      OnBlockedFunction? onBlocked}) async {
    var id = ++_id;
    log('opening $dbName${version != null ? ', version: $version' : ''}',
        id: id);
    try {
      var db = await nativeFactory.open(dbName,
          version: version,
          onUpgradeNeeded: onUpgradeNeeded,
          onBlocked: onBlocked);
      log('opened $dbName');
      return DatabaseLogger(factory: this, idbDatabase: db, id: id);
    } catch (e) {
      err('open $dbName failed $e');
      rethrow;
    }
  }

  @override
  Future<IdbFactory> deleteDatabase(String dbName,
      {OnBlockedFunction? onBlocked}) async {
    log('deleting $dbName');
    try {
      var result =
          await nativeFactory.deleteDatabase(dbName, onBlocked: onBlocked);
      log('deleted $dbName');
      return result;
    } catch (e) {
      log('delete $dbName failed $e');
      rethrow;
    }
  }

  @override
  bool get supportsDatabaseNames {
    // ignore: deprecated_member_use_from_same_package
    return nativeFactory.supportsDatabaseNames;
  }

  @override
  // ignore: deprecated_member_use_from_same_package
  Future<List<String>> getDatabaseNames() => nativeFactory.getDatabaseNames();

  @override
  int cmp(Object first, Object second) => nativeFactory.cmp(first, second);

  @override
  bool get supportsDoubleKey =>
      (nativeFactory as IdbFactoryBase).supportsDoubleKey;

  @override
  IdbFactoryLoggerType? type;

  @override
  IdbFactory get factory => nativeFactory;
}
