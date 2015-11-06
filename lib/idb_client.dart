library idb_shim.idb_client;

// Will be deprecated someday...
import 'idb.dart';
export 'idb.dart';

// Pre 1.0 definition - for Compatibility
@deprecated
const String IDB_MODE_READ_WRITE = idbModeReadWrite;
@deprecated
const String IDB_MODE_READ_ONLY = idbModeReadOnly;
@deprecated
const String IDB_DIRECTION_NEXT = idbDirectionNext;
@deprecated
const String IDB_DIRECTION_PREV = idbDirectionPrev;
@deprecated
const IDB_FACTORY_NATIVE = idbFactoryNative;
@deprecated
const IDB_FACTORY_WEBSQL = idbFactoryWebSql;
@deprecated
const IDB_FACTORY_SEMBAST_IO = idbFactorySembastIo;
@deprecated
const IDB_FACTORY_SEMBAST_MEMORY = idbFactorySembastMemory;
@deprecated
const IDB_FACTORY_MEMORY = idbFactoryMemory;
@deprecated
const IDB_FACTORY_PERSISTENT = idbFactoryPersistent;
@deprecated
const IDB_FACTORY_BROWSER = idbFactoryBrowser;
