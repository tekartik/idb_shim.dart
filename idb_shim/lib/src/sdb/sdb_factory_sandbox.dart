import 'package:idb_shim/idb_sdb.dart';

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
  SdbFactory sandbox({required String path}) =>
      sdbFactoryFromIdb(idbFactory.sandbox(path: path));
}
