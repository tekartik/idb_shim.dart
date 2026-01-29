import 'dart:async';

import 'package:idb_shim/sdb.dart';
import 'package:idb_shim/src/sdb/sdb_client_impl.dart';
import 'package:idb_shim/src/utils/async_utils.dart';

/// Transaction record change implementation
class SdbTransactionRecordChange<K extends SdbKey, V extends SdbValue>
    implements SdbRecordChange<K, V> {
  @override
  final SdbRecordSnapshot<K, V>? oldSnapshot;

  @override
  final SdbRecordSnapshot<K, V>? newSnapshot;

  /// Transaction record change implementation.
  SdbTransactionRecordChange(this.oldSnapshot, this.newSnapshot);

  @override
  SdbRecordChange<RK, RV> cast<RK extends SdbKey, RV extends SdbValue>() {
    if (this is SdbRecordChange<RK, RV>) {
      return this as SdbRecordChange<RK, RV>;
    } else {
      return SdbTransactionRecordChange(
        oldSnapshot?.cast<RK, RV>(),
        newSnapshot?.cast<RK, RV>(),
      );
    }
  }

  @override
  String toString() =>
      'RecordChange(${isAdd ? 'add' : (isDelete ? 'delete' : (isUpdate ? 'update' : ''))}: $oldSnapshot => $newSnapshot)';
}

/// Store change listener.
class _SdbStoreChangesListener<K extends SdbKey, V extends SdbValue> {
  /// The listener
  final SdbTransactionRecordChangeListener<K, V> onChangeListener;

  /// Extra store names to use in readWrite mode
  final List<String>? extraStoreNames;

  /// Store change listener.
  _SdbStoreChangesListener(
    this.onChangeListener, {
    required this.extraStoreNames,
  });

  /// Call on change
  FutureOr<void> onChange(
    SdbTransaction transaction,
    Iterable<SdbRecordChange> changes,
  ) {
    return onChangeListener(
      transaction,
      changes
          .map<SdbRecordChange<K, V>>((change) => change.cast<K, V>())
          .toList(),
    );
  }

  @override
  int get hashCode => onChangeListener.hashCode;

  @override
  bool operator ==(Object other) {
    return (other is _SdbStoreChangesListener) &&
        other.onChangeListener == onChangeListener;
  }
}

/// Mixin for store transaction changes.
mixin SdbStoreTransactionChangesMixin {
  final _txnOldSnapshot = <SdbRecordSnapshot?>[];
  final _txnNewSnapshot = <SdbRecordSnapshot?>[];

  /// Clear current transaction changes.
  void clearChanges() {
    _txnOldSnapshot.clear();
    _txnNewSnapshot.clear();
  }

  /// Add a change
  void add(
    SdbRecordSnapshot<SdbKey, SdbValue>? oldSnapshot,
    SdbRecordSnapshot<SdbKey, SdbValue>? newSnapshot,
  ) {
    _txnOldSnapshot.add(oldSnapshot);
    _txnNewSnapshot.add(newSnapshot);
  }

  /// Get the number of changes
  int get length => _txnNewSnapshot.length;

  /// Get all changes and clear its content
  Iterable<SdbRecordChange> getChanges() => List.generate(
    length,
    (index) => SdbTransactionRecordChange(
      _txnOldSnapshot[index],
      _txnNewSnapshot[index],
    ),
  );

  /// True if there is a pending change
  bool get hasChanges => _txnNewSnapshot.isNotEmpty;
}

// ignore: public_member_api_docs
class SdbStoreTransactionChanges with SdbStoreTransactionChangesMixin {
  // ignore: public_member_api_docs
  SdbStoreTransactionChanges();

  /// Get the record ref.
  SdbRecordRef getRecordRef(int index) =>
      (_txnNewSnapshot[index] ?? _txnOldSnapshot[index])!;
}

/// All transaction
class SdbDatabaseTransactionChanges {
  final _stores = <SdbStoreRef, SdbStoreTransactionChanges>{};

  /// Get store changes
  Iterable<MapEntry<SdbStoreRef, SdbStoreTransactionChanges>>
  get storeChanges => _stores.entries;

  /// Clear all changes
  void clearChanges() {
    _stores.clear();
  }

  // ignore: public_member_api_docs
  SdbDatabaseTransactionChanges();

  /// true if it has any changes
  bool get hasChanges => _stores.isNotEmpty;

  /// Add a given change
  void addChange(
    SdbRecordSnapshot? oldSnapshot,
    SdbRecordSnapshot? newSnapshot,
  ) {
    var store = oldSnapshot?.ref.store ?? newSnapshot?.ref.store;
    if (store == null) {
      return;
    }
    var storeChanges = _stores[store] ??= SdbStoreTransactionChanges();

    storeChanges.add(oldSnapshot, newSnapshot);
  }

  /// Get all store changes
  Iterable<(SdbStoreRef, SdbStoreTransactionChanges)> getAllStoreChanges() {
    return _stores.entries.map((e) => (e.key, e.value));
  }
}

/// Store changes listeners.
class SdbStoreChangesListeners {
  /// List of change listeners.
  final onChanges = <_SdbStoreChangesListener?>[];

  /// Extra store names to use in readWrite mode
  final List<String>? extraStoreNames;

  /// Store changes listeners.
  SdbStoreChangesListeners({this.extraStoreNames});
}

class _StoreTransactionChanges with SdbStoreTransactionChangesMixin {
  final SdbTransactionRecordChangeListener onChanges;
  final Set<String> excludedStoreNames;

  _StoreTransactionChanges({
    required this.onChanges,
    required this.excludedStoreNames,
  });
}

class _AllStoresChangesListeners {
  final _all = <SdbTransactionRecordChangeListener, _StoreTransactionChanges>{};

  void addChange(
    SdbRecordSnapshot? oldSnapshot,
    SdbRecordSnapshot? newSnapshot,
  ) {
    for (var listener in _all.values) {
      var storeName = oldSnapshot?.store.name ?? newSnapshot?.store.name;
      if (!listener.excludedStoreNames.contains(storeName)) {
        listener._txnOldSnapshot.add(oldSnapshot);
        listener._txnNewSnapshot.add(newSnapshot);
      }
    }
  }

  void addAllStoresChangesListener(
    SdbTransactionRecordChangeListener onChanges, {
    List<String>? excludedStoreNames,
  }) {
    _all[onChanges] = _StoreTransactionChanges(
      onChanges: onChanges,
      excludedStoreNames: excludedStoreNames?.toSet() ?? {},
    );
  }

  Iterable<_StoreTransactionChanges> get all => _all.values;
  _AllStoresChangesListeners();

  void removeListener(SdbTransactionRecordChangeListener onChanges) {
    _all.remove(onChanges);
  }

  bool hasStoreListener(String name) {
    for (var listener in _all.values) {
      if (!listener.excludedStoreNames.contains(name)) {
        return true;
      }
    }
    return false;
  }
}

/// Database listener.
class SdbDatabaseChangesListener {
  /// Get store changes listener
  SdbStoreChangesListeners? getStoreChangesListener(String store) {
    var storeChangesListeners = _stores[store];
    return storeChangesListeners;
  }

  final _stores = <String, SdbStoreChangesListeners>{};
  _AllStoresChangesListeners? _allStoresChangesListenersOrNull;
  _AllStoresChangesListeners get _allStoresChangesListeners =>
      _allStoresChangesListenersOrNull!;

  /// true if not empty.
  bool get isNotEmpty => !isEmpty;

  /// true if empty.
  bool get isEmpty =>
      _stores.isEmpty && _allStoresChangesListenersOrNull == null;

  /// Get all store changes listener
  Iterable<SdbStoreChangesListeners> get storeChangesListeners =>
      _stores.values;

  /// True if the store has a change listener (global, store or record)
  bool storeHasChangeListener(SdbStoreRef ref) => _hasStoreChangeListener(ref);

  /// true if it has a change listener for this store
  bool _hasStoreChangeListener(SdbStoreRef ref) =>
      isNotEmpty && _stores.containsKey(ref.name);

  /// Handle store changes
  FutureOr<void> handleStoreChanges(
    SdbTransaction txn,
    SdbStoreRef store,
    Iterable<SdbRecordChange> changes,
  ) {
    var listener = getStoreChangesListener(store.name);

    if (listener != null) {
      var steps = listener.onChanges.map((storeChangesListener) {
        return () {
          var result = storeChangesListener!.onChange(txn, changes);
          if (result is Future) {
            return result;
          }
        };
      }).toList();
      return runSequentially(steps);
    }
  }

  /// Add a global change listener
  void addGlobalChangesListener(
    SdbTransactionRecordChangeListener onChanges, {
    List<String>? excludedStoreNames,
  }) {
    _allStoresChangesListenersOrNull ??= _AllStoresChangesListeners();
    _allStoresChangesListeners.addAllStoresChangesListener(
      onChanges,
      excludedStoreNames: excludedStoreNames,
    );
  }

  /// Add a store change listener
  void removeGlobalChangesListener(
    SdbTransactionRecordChangeListener onChanges,
  ) {
    _allStoresChangesListenersOrNull?.removeListener(onChanges);
    if (_allStoresChangesListenersOrNull?.all.isEmpty ?? true) {
      _allStoresChangesListenersOrNull = null;
    }
  }

  /// Add a store change listener
  void addStoreChangesListener<K extends SdbKey, V extends SdbValue>(
    String store,
    SdbTransactionRecordChangeListener<K, V> onChanges, {
    required List<String>? extraStoreNames,
  }) {
    var storeChangesListeners = _stores[store];
    if (storeChangesListeners == null) {
      _stores[store] = storeChangesListeners = SdbStoreChangesListeners();
    }
    storeChangesListeners.onChanges.add(
      _SdbStoreChangesListener<K, V>(
        onChanges,
        extraStoreNames: extraStoreNames,
      ),
    );
  }

  /// Add a store change listener
  void removeStoreChangesListener<K extends SdbKey, V extends SdbValue>(
    SdbStoreRef<K, V> store,
    SdbTransactionRecordChangeListener<K, V> onChanges,
  ) {
    var storeChangesListeners = _stores[store.name];
    if (storeChangesListeners != null) {
      storeChangesListeners.onChanges.remove(
        _SdbStoreChangesListener<K, V>(onChanges, extraStoreNames: null),
      );
      if (storeChangesListeners.onChanges.isEmpty) {
        _stores.remove(store.name);
      }
    }
  }

  /// Clear all change listener
  void close() {
    _stores.clear();
  }

  /// true if it has any listener
  bool get hasListeners => _stores.isNotEmpty;

  /// Add a change in the transaction
  void addChange(
    SdbTransaction transaction,
    SdbRecordSnapshot<SdbKey, SdbValue>? oldSnapshot,
    SdbRecordSnapshot<SdbKey, SdbValue>? newSnapshot,
  ) {
    var store = oldSnapshot?.ref.store ?? newSnapshot?.ref.store;
    if (store == null) {
      return;
    }

    var listener = getStoreChangesListener(store.name);
    if (listener == null) {
      return;
    }

    var changes = transaction.txnImpl.changes;
    if (changes != null && (oldSnapshot != null || newSnapshot != null)) {
      changes.addChange(oldSnapshot, newSnapshot);
    }
  }

  /// Get extra store names for a store transaction
  List<String>? storeGetExtraStoreNames(String store) {
    var storeListeners = getStoreChangesListener(store);
    if (storeListeners != null) {
      var extraStoreNames = <String>{};
      for (var listener in storeListeners.onChanges) {
        if (listener != null && listener.extraStoreNames != null) {
          extraStoreNames.addAll(listener.extraStoreNames!);
        }
      }
      extraStoreNames.remove(store);
      if (extraStoreNames.isNotEmpty) {
        return extraStoreNames.toList();
      }
    }
    return null;
  }

  /// Stores extra store names for a store transaction
  List<String>? storesGetExtraStoreNames(List<String> stores) {
    if (!hasListeners) {
      return null;
    }
    var existing = stores.toSet();
    var allExtraStoreNames = <String>{};
    for (var store in stores) {
      var extraStoreNames = storeGetExtraStoreNames(store);
      if (extraStoreNames != null) {
        for (var name in extraStoreNames) {
          if (!existing.contains(name)) {
            allExtraStoreNames.add(name);
          }
        }
      }
    }

    return allExtraStoreNames.isEmpty ? null : allExtraStoreNames.toList();
  }
}
