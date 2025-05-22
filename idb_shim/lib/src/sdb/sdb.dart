import 'package:idb_shim/idb_io.dart' as idb;

import 'sdb_factory.dart';
import 'sdb_factory_impl.dart';

export 'sdb_boundary.dart'
    show SdbBoundaries, SdbBoundary, SdbLowerBoundary, SdbUpperBoundary;
export 'sdb_database.dart' show SdbDatabase, SdbDatabaseExtension;
export 'sdb_factory.dart' show SdbFactory, SdbFactoryExtension;
export 'sdb_filter.dart'
    show SdbFilter, SdbFilterRecordSnapshot, SdbFilterRecordSnapshotExt;
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
        SdbOpenStoreRefExtension;
export 'sdb_record.dart' show SdbRecordRef, SdbRecordRefExtension;
export 'sdb_record_snapshot.dart'
    show
        SdbRecordSnapshot,
        SdbRecordSnapshotListExt,
        SdbRecordKey,
        SdbRecordKeyListExt;
export 'sdb_store.dart' show SdbStoreRef, SdbStoreRefExtension;
export 'sdb_transaction.dart' show SdbTransaction, SdbTransactionMode;
export 'sdb_transaction.dart' show SdbTransaction;
export 'sdb_transaction_store.dart'
    show
        SdbTransactionStoreRef,
        SdbTransactionStoreRefExtension,
        SdbSingleStoreTransaction,
        SdbSingleStoreTransactionExtension,
        SdbMultiStoreTransaction,
        SdbMultiStoreTransactionExtension;
export 'sdb_types.dart' show SdbModel, SdbKey, SdbValue;
export 'sdb_version.dart'
    show SdbOnVersionChangeCallback, SdbVersionChangeEvent;

/// Factory from idb factory.
SdbFactory sdbFactoryFromIdb(idb.IdbFactory idbFactory) {
  return SdbFactoryImpl(idbFactory);
}

/// Memory factory.
final SdbFactory sdbFactoryMemory = sdbFactoryFromIdb(idb.idbFactoryMemory);

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
