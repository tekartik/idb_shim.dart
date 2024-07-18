// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:idb_shim/idb_client.dart';
import 'package:idb_shim/src/common/common_factory.dart';
import 'package:idb_shim/src/logger/logger_database.dart';
import 'package:idb_shim/src/logger/logger_transaction.dart';

enum IdbFactoryLoggerType {
  all,
}

/// Logger wrapper
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

class _VersionChangeEventLogger implements VersionChangeEvent {
  final IdbFactoryLogger factory;
  final int id;
  @override
  late final DatabaseLogger database =
      DatabaseLogger(factory: factory, idbDatabase: delegate.database, id: id);

  @override
  late final TransactionLogger transaction =
      TransactionLogger(database, delegate.transaction);

  final VersionChangeEvent delegate;

  _VersionChangeEventLogger(this.factory, this.delegate, this.id);

  @override
  int get newVersion => delegate.newVersion;

  @override
  int get oldVersion => delegate.oldVersion;

  @override
  Object get target => delegate.target;

  @override
  Object get currentTarget => delegate.currentTarget;
}

/// Wrapper for window.indexedDB and worker self.indexedDB
class IdbFactoryWrapperImpl extends IdbFactoryBase implements IdbFactoryLogger {
  final IdbFactory nativeFactory;
  static int _id = 0;

  @override
  void log(String message, {int? id}) {
    if (_incrementAndShouldLog) {
      // ignore: avoid_print
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
    FutureOr<void> onUpgradeNeededLogger(VersionChangeEvent event) {
      log('onUpgradeNeeded $event', id: id);
      return onUpgradeNeeded!(_VersionChangeEventLogger(this, event, id));
    }

    try {
      var db = await nativeFactory.open(dbName,
          version: version,
          onUpgradeNeeded:
              onUpgradeNeeded != null ? onUpgradeNeededLogger : null,
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

  @override
  String toString() => 'Logger($factory)';
}

/// Debug extension for Logger.
extension IdbFactoryLoggerDebugExt on IdbFactory {
  /// Quick logger wrapper, useful in unit test.
  ///
  /// idbFactory = idbFactory.debugQuickLoggerWrapper()
  ///
  /// [maxLogCount] default to 100
  @Deprecated('Debug/dev mode')
  IdbFactory debugWrapInLogger(
      {IdbFactoryLoggerType type = IdbFactoryLoggerType.all,
      int? maxLogCount}) {
    IdbFactoryLogger.debugMaxLogCount = maxLogCount ?? 100;
    var factory = getIdbFactoryLogger(this, type: type);
    return factory;
  }
}
