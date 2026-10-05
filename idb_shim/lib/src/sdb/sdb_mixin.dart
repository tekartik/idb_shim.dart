/// Internal interfaces and helpers for the implementers of sdb (idb based or
/// not), not part of the public API.
library;

export 'package:idb_shim/sdb.dart';
export 'package:idb_shim/src/common/common_value.dart'
    show compareKeys, IdbValueMapExt;
export 'package:idb_shim/src/sdb/sdb_types.dart' show SdbKey, SdbValue;
export 'package:idb_shim/src/sembast/sembast_value.dart'
    show toSembastValue, fromSembastValue;
export 'package:idb_shim/src/utils/env_utils.dart' show isDebug;

export 'sdb_changes_listener.dart'
    show
        SdbTransactionChangesDefaultMixin,
        SdbDatabaseChangesListener,
        SdbDatabaseTransactionChanges;
export 'sdb_client.dart'
    show
        SdbClientInterface,
        SdbClientInterfaceDefaultMixin,
        SdbClientExtensionPrv;
export 'sdb_codec.dart' show SdbCodecPrvExt;
export 'sdb_cursor.dart' show SdbCursorRowImpl;
export 'sdb_database.dart'
    show SdbDatabaseDefaultMixin, SdbDatabaseInterface, SdbDatabaseExtensionPrv;
export 'sdb_filter_impl.dart' show sdbRecordMatchesFilter;
export 'sdb_index_cursor.dart' show SdbIndexCursorRowImpl;
export 'sdb_index_impl.dart' show SdbIndexRefImpl, SdbIndexRefInternalExtension;
export 'sdb_index_record_snapshot_impl.dart'
    show SdbIndexRecordSnapshotImpl, SdbIndexRecordKeyImpl;
export 'sdb_key_path_utils.dart'
    show sdbKeyPathToIdbKeyPath, sdbKeyPathFromAny, idbKeyPathFromAny;
export 'sdb_key_utils.dart' show sdbIndexKeyToIdbKey;
export 'sdb_open.dart'
    show
        SdbOpenDatabaseDefaultMixin,
        SdbOpenStoreRefDefaultMixin,
        SdbOpenStoreRefInterface;
export 'sdb_record_snapshot_impl.dart'
    show SdbRecordSnapshotImpl, SdbRecordKeyImpl;
export 'sdb_schema.dart' show SchemaSdbDatabasePrvExtension;
export 'sdb_transaction.dart'
    show SdbTransactionInterface, SdbTransactionExtensionPrv;
export 'sdb_transaction_index.dart' show SdbTransactionIndexRefInterface;
export 'sdb_transaction_store.dart' show SdbTransactionStoreRefInterface;
