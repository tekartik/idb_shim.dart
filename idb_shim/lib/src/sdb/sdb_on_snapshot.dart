import 'dart:async';

import 'package:idb_shim/sdb.dart';
import 'package:idb_shim/src/sdb/sdb_database_impl.dart';

/// Snapshots extension on store.
extension SdbStoreRefExtensionOnSnapshots<K extends SdbKey, V extends SdbValue>
    on SdbStoreRef<K, V> {
  /// Reads the data and set a listener to redo the query on changes,
  /// including changes made in other browser tabs.
  Stream<List<SdbRecordSnapshot<K, V>>> onSnapshots(
    SdbDatabase db, {
    SdbFindOptions<K>? options,
  }) {
    // ignore: close_sinks
    late StreamController<List<SdbRecordSnapshot<K, V>>> controller;
    StreamSubscription<List<String>>? externalSub;
    void addSnapshots() {
      findRecords(db, options: options).then((snapshots) {
        if (!controller.isClosed) {
          controller.add(snapshots);
        }
      });
    }

    FutureOr<void> onChange(
      SdbTransaction transaction,
      List<SdbRecordChange<K, V>> changes,
    ) {
      addSnapshots();
    }

    controller = StreamController<List<SdbRecordSnapshot<K, V>>>(
      onListen: () {
        addSnapshots();
        addOnChangesListener(db, onChange);
        externalSub = db.impl.externalStoreChanges
            .where((storeNames) => storeNames.contains(name))
            .listen((_) => addSnapshots());
        controller.onCancel = () {
          externalSub?.cancel();
          externalSub = null;
          removeOnChangesListener(db, onChange);
        };
      },
    );
    return controller.stream;
  }
}

/// Snapshots extension on index.
extension SdbIndexRefExtensionOnSnapshots<
  K extends SdbKey,
  V extends SdbValue,
  IK extends SdbIndexKey
>
    on SdbIndexRef<K, V, IK> {
  /// Reads the data and set a listener to redo the query on changes,
  /// including changes made in other browser tabs.
  Stream<List<SdbIndexRecordSnapshot<K, V, IK>>> onSnapshots(
    SdbDatabase db, {
    SdbFindOptions<IK>? options,
  }) {
    // ignore: close_sinks
    late StreamController<List<SdbIndexRecordSnapshot<K, V, IK>>> controller;
    StreamSubscription<List<String>>? externalSub;
    void addSnapshots() {
      findRecords(db, options: options).then((snapshots) {
        if (!controller.isClosed) {
          controller.add(snapshots);
        }
      });
    }

    FutureOr<void> onChange(
      SdbTransaction transaction,
      List<SdbRecordChange<K, V>> changes,
    ) {
      addSnapshots();
    }

    controller = StreamController<List<SdbIndexRecordSnapshot<K, V, IK>>>(
      onListen: () {
        addSnapshots();
        store.addOnChangesListener(db, onChange);
        externalSub = db.impl.externalStoreChanges
            .where((storeNames) => storeNames.contains(store.name))
            .listen((_) => addSnapshots());
        controller.onCancel = () {
          externalSub?.cancel();
          externalSub = null;
          store.removeOnChangesListener(db, onChange);
        };
      },
    );
    return controller.stream;
  }
}

/// Snapshot extension on record.
extension SdbRecordRefExtensionOnSnapshot<K extends SdbKey, V extends SdbValue>
    on SdbRecordRef<K, V> {
  /// Reads the data and set a listener to redo the query on changes,
  /// including changes made in other browser tabs.
  Stream<SdbRecordSnapshot<K, V>?> onSnapshot(SdbDatabase db) {
    // ignore: close_sinks
    late StreamController<SdbRecordSnapshot<K, V>?> controller;
    StreamSubscription<List<String>>? externalSub;
    void addSnapshot() {
      get(db).then((snapshot) {
        if (!controller.isClosed) {
          controller.add(snapshot);
        }
      });
    }

    FutureOr<void> onChange(
      SdbTransaction transaction,
      List<SdbRecordChange<K, V>> changes,
    ) {
      for (var change in changes) {
        if (change.ref.key == key) {
          addSnapshot();
        }
      }
    }

    controller = StreamController<SdbRecordSnapshot<K, V>?>(
      onListen: () {
        addSnapshot();
        store.addOnChangesListener(db, onChange);
        // Cross-tab: re-fetch the record when any change in this store arrives
        // from another tab. We cannot filter by key at this level.
        externalSub = db.impl.externalStoreChanges
            .where((storeNames) => storeNames.contains(store.name))
            .listen((_) => addSnapshot());
        controller.onCancel = () {
          externalSub?.cancel();
          externalSub = null;
          store.removeOnChangesListener(db, onChange);
        };
      },
    );
    return controller.stream;
  }
}

/// Snapshot extension on index record.
extension SdbIndexRecordRefExtensionOnSnapshot<
  K extends SdbKey,
  V extends SdbValue,
  IK extends SdbIndexKey
>
    on SdbIndexRecordRef<K, V, IK> {
  /// Reads the data and set a listener to redo the query on changes,
  /// including changes made in other browser tabs.
  Stream<SdbIndexRecordSnapshot<K, V, IK>?> onSnapshot(SdbDatabase db) {
    // ignore: close_sinks
    late StreamController<SdbIndexRecordSnapshot<K, V, IK>?> controller;
    StreamSubscription<List<String>>? externalSub;
    void addSnapshot() {
      get(db).then((snapshot) {
        if (!controller.isClosed) {
          controller.add(snapshot);
        }
      });
    }

    FutureOr<void> onChange(
      SdbTransaction transaction,
      List<SdbRecordChange<K, V>> changes,
    ) {
      addSnapshot();
    }

    controller = StreamController<SdbIndexRecordSnapshot<K, V, IK>?>(
      onListen: () {
        addSnapshot();
        index.store.addOnChangesListener(db, onChange);
        externalSub = db.impl.externalStoreChanges
            .where((storeNames) => storeNames.contains(index.store.name))
            .listen((_) => addSnapshot());
        controller.onCancel = () {
          externalSub?.cancel();
          externalSub = null;
          index.store.removeOnChangesListener(db, onChange);
        };
      },
    );
    return controller.stream;
  }

  /// Reads the data and set a listener to redo the query on changes,
  /// including changes made in other browser tabs.
  Stream<List<SdbIndexRecordSnapshot<K, V, IK>>> onSnapshots(
    SdbDatabase db, {
    SdbFindOptions<IK>? options,
  }) {
    // ignore: close_sinks
    late StreamController<List<SdbIndexRecordSnapshot<K, V, IK>>> controller;
    StreamSubscription<List<String>>? externalSub;
    void addSnapshots() {
      findRecords(db, options: options).then((snapshots) {
        if (!controller.isClosed) {
          controller.add(snapshots);
        }
      });
    }

    FutureOr<void> onChange(
      SdbTransaction transaction,
      List<SdbRecordChange<K, V>> changes,
    ) {
      addSnapshots();
    }

    controller = StreamController<List<SdbIndexRecordSnapshot<K, V, IK>>>(
      onListen: () {
        addSnapshots();
        store.addOnChangesListener(db, onChange);
        externalSub = db.impl.externalStoreChanges
            .where((storeNames) => storeNames.contains(store.name))
            .listen((_) => addSnapshots());
        controller.onCancel = () {
          externalSub?.cancel();
          externalSub = null;
          store.removeOnChangesListener(db, onChange);
        };
      },
    );
    return controller.stream;
  }
}
