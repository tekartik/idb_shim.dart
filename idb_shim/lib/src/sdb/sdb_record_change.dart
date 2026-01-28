import 'dart:async';

import 'package:idb_shim/sdb.dart';

/// Record change info streamed during `StoreRef.onChange`.
///
/// Handle both add, update and delete
abstract class SdbRecordChange<K extends SdbKey, V extends SdbValue> {
  /// The previous record snapshot, null for record added.
  SdbRecordSnapshot<K, V>? get oldSnapshot;

  /// The new record value, null for record removed
  SdbRecordSnapshot<K, V>? get newSnapshot;

  /// Cast if needed
  SdbRecordChange<RK, RV> cast<RK extends SdbKey, RV extends SdbValue>();
}

/// Record change listener, from a single store.
typedef SdbTransactionRecordChangeListener<
  K extends SdbKey,
  V extends SdbValue
> =
    FutureOr<void> Function(
      SdbTransaction transaction,
      List<SdbRecordChange<K, V>> changes,
    );

/// Record change helper.
extension SdbRecordChangeExtension<K extends SdbKey, V extends SdbValue>
    on SdbRecordChange<K, V> {
  /// The previous record value, null for record added.
  V? get oldValue => oldSnapshot?.value;

  /// The new record value, null for record removed
  V? get newValue => newSnapshot?.value;

  /// True if the record was added.
  bool get isAdd => oldValue == null;

  /// true if the record was deleted.
  bool get isDelete => newValue == null;

  /// True if the record was updated.
  bool get isUpdate => !isAdd && !isDelete;

  /// The record ref (new or old one for delete)
  SdbRecordRef<K, V> get ref => snapshot.ref;

  /// The record snapshot (new or old one for delete)
  SdbRecordSnapshot<K, V> get snapshot => newSnapshot ?? oldSnapshot!;
}
