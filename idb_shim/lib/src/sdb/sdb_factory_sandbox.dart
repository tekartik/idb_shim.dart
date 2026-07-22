import 'package:idb_shim/idb_sdb.dart';
import 'package:idb_shim/src/sdb/sdb_factory.dart';
import 'package:path/path.dart' as p;

import 'sdb_factory_impl.dart';

/// Sdb Factory sandbox extension.
extension SdbFactorySandboxExtension on SdbFactory {
  /// Factory sandboxing.
  ///
  /// Every database opened or deleted through the returned factory is
  /// located below [path] in the original factory.
  ///
  /// If the factory is already a sandbox, the tree is sanitized (i.e. never 2
  /// levels of sandboxing).
  ///
  /// Works with any [SdbFactory] implementation (io, memory, web).
  SdbFactory sandbox({required String path}) {
    var self = this;
    if (self is _SdbFactorySandbox) {
      return _SdbFactorySandbox(
        delegate: self.delegate,
        rootPath: self.delegatePath(path),
      );
    }
    return _SdbFactorySandbox(
      delegate: (this as SdbFactoryIdb),
      rootPath: path,
    );
  }

  @Deprecated('Use getDatabaseFullPath() instead')
  /// full path of a database path
  String fullPath(String path) => idbFactory.fullPath(path);

  /// Path context
  p.Context get pathContext => idbFactory.pathContext;
}

/// Sandboxed
abstract class SdbFactorySandbox implements SdbFactory {}

/// Private helpers
extension SdbFactorySandboxPrvExtension on SdbFactory {}

class _SdbFactorySandbox
    with SdbFactoryDefaultMixin
    implements SdbFactorySandbox, SdbFactoryIdb {
  _SdbFactorySandbox({required this.delegate, required String rootPath})
    : rootPath = delegate.pathContext.normalize(rootPath);

  /// The wrapped factory.
  final SdbFactoryIdb delegate;

  /// The root path of the sandbox in the delegate factory.
  final String rootPath;

  /// Converts a name/path in the sandboxed factory to a name/path in the
  /// delegate factory. Throws an [ArgumentError] if the path escapes the
  /// sandbox.
  String delegatePath(String path) {
    var relativePath = pathContext.isAbsolute(path)
        ? pathContext.relative(path, from: pathContext.rootPrefix(path))
        : path;
    var fullPath = pathContext.normalize(
      pathContext.join(rootPath, relativePath),
    );
    if (!pathContext.isWithin(rootPath, fullPath)) {
      throw ArgumentError.value(
        path,
        'path',
        'Path is outside of the sandbox root $rootPath',
      );
    }
    return fullPath;
  }

  /// For debugging purpose
  @override
  Future<String> getDatabaseFullPath(String name) async {
    return idbFactory.getDatabaseFullPath(delegatePath(name));
  }

  @override
  String get name => 'sandbox(${delegate.name}, $rootPath)';

  @override
  String toString() => name;

  @override
  IdbFactory get idbFactory => delegate.factoryIdb.idbFactory;

  @override
  Future<SdbDatabase> openDatabaseImpl(
    String name,
    SdbOpenDatabaseOptions options,
  ) {
    return delegate.openDatabaseImpl(delegatePath(name), options);
  }

  @override
  Future<SdbDatabase> openDatabase(
    String name, {
    SdbOpenDatabaseOptions? options,
    int? version,
    SdbOnVersionChangeCallback? onVersionChange,
    SdbDatabaseSchema? schema,
  }) {
    return delegate.openDatabase(
      delegatePath(name),
      options: options,
      // deprecated
      // version: version,
      // onVersionChange: onVersionChange,
      // schema: schema,
    );
  }

  @override
  Future<void> deleteDatabase(String name) {
    return delegate.deleteDatabase(delegatePath(name));
  }
}
