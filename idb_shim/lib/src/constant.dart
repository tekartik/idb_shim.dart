/// Read-write mode for transaction.
const String idbModeReadWrite = 'readwrite';

/// Read-only mode for transaction.
const String idbModeReadOnly = 'readonly';

/// Default forward mode for cursor.
const String idbDirectionNext = 'next';

/// Backward mode for cursor.
const String idbDirectionPrev = 'prev';

/// Factory name using native indexeddb implementation.
const idbFactoryNameNative = 'native';

/// Factory name logger (wrapping another factory).
const idbFactoryNameLogger = 'logger';

/// Factory name using Sembast implementation
const idbFactoryNameSembastIo = 'sembast_io';

/// Factory name using Sembast io implementation.
@Deprecated('Use idbFactoryNameSembastIo instead')
const idbFactoryNameIo = 'io';

/// Factory name using Sembast memory implementation
const idbFactoryNameSembastMemory = 'sembast_memory';

/// Factory name that could be used to use Sembast Memory implementation.
const idbFactoryNameMemory = 'memory';

/// Pseudo - best persistent shim (indexeddb).
const idbFactoryNamePersistent = 'persistent';

/// Pseudo - best browser shim (persistent of it not available memory).
const idbFactoryNameBrowser = 'browser';

/// Shim using WebSql implementation - no longer supported.
const idbFactoryNameWebSql = 'websql';
