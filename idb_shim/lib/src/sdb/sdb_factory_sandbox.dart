import 'package:idb_shim/idb_sdb.dart';
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
///
/// A database opened through a sandbox has the name opened in the sandbox
/// and the sandbox as factory.
abstract class SdbFactorySandbox implements SdbFactory {
  /// Converts a name/path in the sandboxed factory to a name/path in the
  /// delegate factory. Throws an [ArgumentError] if the path escapes the
  /// sandbox.
  String delegatePath(String path);
}

/// Private helpers
extension SdbFactorySandboxPrvExtension on SdbFactory {}

/// An sdb factory on the idb sandbox of the idb factory of [delegate]: the
/// idb sandbox maps the names (and gives the name opened in the sandbox to
/// the databases).
class _SdbFactorySandbox extends SdbFactoryIdb implements SdbFactorySandbox {
  _SdbFactorySandbox({required this.delegate, required String rootPath})
    : rootPath = delegate.pathContext.normalize(rootPath),
      super(delegate.idbFactory.sandbox(path: rootPath));

  /// The wrapped factory.
  final SdbFactoryIdb delegate;

  /// The root path of the sandbox in the delegate factory.
  final String rootPath;

  IdbFactorySandbox get _idbFactorySandbox => idbFactory as IdbFactorySandbox;

  /// Converts a name/path in the sandboxed factory to a name/path in the
  /// delegate factory. Throws an [ArgumentError] if the path escapes the
  /// sandbox.
  @override
  String delegatePath(String path) => _idbFactorySandbox.delegatePath(path);

  @override
  String get name => 'sandbox(${delegate.name}, $rootPath)';

  @override
  String toString() => name;
}
