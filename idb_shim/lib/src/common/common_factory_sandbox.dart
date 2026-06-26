import 'package:idb_shim/idb.dart';
import 'package:idb_shim/src/common/common_factory.dart';
import 'package:path/path.dart' as p;

/// Idb factory sandbox extension.
extension IdbFactorySandboxExtension on IdbFactory {
  /// Factory sandboxing.
  ///
  /// Every database opened or deleted through the returned factory is
  /// located below [path] in the original factory.
  ///
  /// If the factory is already a sandbox, the tree is sanitized (i.e. never 2
  /// levels of sandboxing).
  ///
  /// Works with any [IdbFactory] implementation (native, io, memory).
  IdbFactory sandbox({required String path}) {
    var self = this;
    if (self is _IdbFactorySandbox) {
      return _IdbFactorySandbox(
        delegate: self.delegate,
        rootPath: self.delegatePath(path),
      );
    }
    return _IdbFactorySandbox(delegate: this, rootPath: path);
  }

  /// full path of a database path
  String fullPath(String path) {
    if (this is _IdbFactorySandbox) {
      return (this as _IdbFactorySandbox).delegatePath(path);
    }
    return path;
  }
}

class _IdbFactorySandbox extends IdbFactoryBase {
  _IdbFactorySandbox({required this.delegate, required String rootPath})
    : rootPath = p.normalize(rootPath);

  /// The wrapped factory.
  final IdbFactory delegate;

  /// The root path of the sandbox in the delegate factory.
  final String rootPath;

  /// Converts a name/path in the sandboxed factory to a name/path in the
  /// delegate factory. Throws an [ArgumentError] if the path escapes the
  /// sandbox.
  String delegatePath(String path) {
    var relativePath = p.isAbsolute(path)
        ? p.relative(path, from: p.rootPrefix(path))
        : path;
    var fullPath = p.normalize(p.join(rootPath, relativePath));
    if (!p.isWithin(rootPath, fullPath)) {
      throw ArgumentError.value(
        path,
        'path',
        'Path is outside of the sandbox root $rootPath',
      );
    }
    return fullPath;
  }

  @override
  Future<Database> open(
    String dbName, {
    int? version,
    OnUpgradeNeededFunction? onUpgradeNeeded,
    OnBlockedFunction? onBlocked,
  }) => delegate.open(
    delegatePath(dbName),
    version: version,
    onUpgradeNeeded: onUpgradeNeeded,
    onBlocked: onBlocked,
  );

  @override
  Future<IdbFactory> deleteDatabase(
    String name, {
    OnBlockedFunction? onBlocked,
  }) async {
    await delegate.deleteDatabase(delegatePath(name), onBlocked: onBlocked);
    return this;
  }

  @override
  int cmp(Object first, Object second) => delegate.cmp(first, second);

  @override
  bool get supportsDatabaseNames {
    // ignore: deprecated_member_use_from_same_package
    return delegate.supportsDatabaseNames;
  }

  @override
  Future<List<String>> getDatabaseNames() async {
    // ignore: deprecated_member_use_from_same_package
    var names = await delegate.getDatabaseNames();
    return names
        .where((name) => p.isWithin(rootPath, name))
        .map((name) => p.relative(name, from: rootPath))
        .toList();
  }

  @override
  bool get persistent => delegate.persistent;

  @override
  bool get supportsDoubleKey {
    var delegate = this.delegate;
    return delegate is IdbFactoryBase && delegate.supportsDoubleKey;
  }

  @override
  String get name => 'sandbox(${delegate.name}, $rootPath)';

  @override
  String toString() => name;
}
