import 'package:idb_shim/idb_io.dart' as idb;

import 'sdb_factory.dart';
import 'sdb_factory_impl.dart';

export 'sdb_boundary.dart'
    show SdbBoundaries, SdbBoundary, SdbLowerBoundary, SdbUpperBoundary;
export 'sdb_client.dart' show SdbClient;
export 'sdb_client_impl.dart' show SdbClientExtension;
export 'sdb_database.dart' show SdbDatabase, SdbDatabaseExtension;
export 'sdb_database_impl.dart' show SdbDatabaseIdbExt;
export 'sdb_factory.dart' show SdbFactory, SdbFactoryExtension;
export 'sdb_filter.dart'
    show SdbFilter, SdbFilterRecordSnapshot, SdbFilterRecordSnapshotExt;
export 'sdb_find_options.dart' show SdbFindOptions, sdbFindOptionsMerge;
export 'sdb_index.dart'
    show
        SdbIndexRef,
        SdbIndex1Ref,
        SdbIndex2Ref,
        SdbIndex3Ref,
        SdbIndex4Ref,
        SdbIndexRefExtension,
        SdbIndex1RefExtension,
        SdbIndex2RefExtension,
        SdbIndex3RefExtension,
        SdbIndex4RefExtension;
export 'sdb_index_record.dart'
    show SdbIndexRecordRef, SdbIndexRecordRefExtension;
export 'sdb_index_record_snapshot.dart'
    show
        SdbIndexRecordSnapshot,
        SdbIndexRecordSnapshotListExt,
        SdbIndexRecordKey,
        SdbIndexRecordKeyListExt;
export 'sdb_open.dart'
    show
        SdbOpenDatabase,
        SdbOpenDatabaseExtension,
        SdbOpenStoreRef,
        SdbOpenStoreRefExtension,
        SdbOpenIndexRef;
export 'sdb_record.dart' show SdbRecordRef, SdbRecordRefExtension;
export 'sdb_record_snapshot.dart'
    show
        SdbRecordSnapshot,
        SdbRecordSnapshotListExt,
        SdbRecordKey,
        SdbRecordKeyListExt;
export 'sdb_schema.dart'
    show
        SdbDatabaseSchema,
        SdbDatabaseSchemaExtension,
        SdbStoreSchema,
        SdbStoreSchemaExtension,
        SdbIndexSchema,
        SdbFactorySchemaExtension,
        SdbStoreRefSchemaExtension,
        SchemaSdbDatabaseExtension,
        SdbDatabaseSchemaDef,
        SdbIndexSchemaDef,
        SdbKeyPath,
        SdbStoreSchemaDef,
        SdbIndexSchemaExtension,
        SdbKeyPathExtension,
        SdbIndexRefSchemaExtension;
export 'sdb_store.dart' show SdbStoreRef, SdbStoreRefExtension;
export 'sdb_store_impl.dart' show SdbStoreRefDbExtension;
export 'sdb_transaction.dart'
    show SdbTransaction, SdbTransactionMode, SdbTransactionExtension;
export 'sdb_transaction.dart' show SdbTransaction;
export 'sdb_transaction_index.dart' show SdbTransactionIndexRef;
export 'sdb_transaction_store.dart'
    show
        SdbTransactionStoreRef,
        SdbTransactionStoreRefExtension,
        SdbSingleStoreTransaction,
        SdbSingleStoreTransactionExtension,
        SdbMultiStoreTransaction,
        SdbMultiStoreTransactionExtension;
export 'sdb_types.dart' show SdbModel, SdbKey, SdbValue, SdbIndexKey;
export 'sdb_version.dart'
    show SdbOnVersionChangeCallback, SdbVersionChangeEvent;

/// Factory from idb factory.
SdbFactory sdbFactoryFromIdb(idb.IdbFactory idbFactory) {
  return SdbFactoryImpl(idbFactory);
}

/// Memory factory.
final SdbFactory sdbFactoryMemory = sdbFactoryFromIdb(idb.idbFactoryMemory);

/// New memory factory.
SdbFactory newSdbFactoryMemory() =>
    sdbFactoryFromIdb(idb.newIdbFactoryMemory());

/// Native (browser) factory.
final SdbFactory sdbFactoryWeb = sdbFactoryFromIdb(idb.idbFactoryWeb);

/// Native (web worker) factory.
final SdbFactory sdbFactoryWebWorker = sdbFactoryFromIdb(
  idb.idbFactoryWebWorker,
);

/// Sembast io factory.
final SdbFactory sdbFactoryIo = sdbFactoryFromIdb(idb.idbFactorySembastIo);

/// Web constant helper (needed for non-flutter app)
const kSdbDartIsWeb = idb.kIdbDartIsWeb;
