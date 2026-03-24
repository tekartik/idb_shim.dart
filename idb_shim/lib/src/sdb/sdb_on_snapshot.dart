import 'dart:async';

import 'package:idb_shim/sdb.dart';

/// Snapshots extension on store.
extension SdbStoreRefExtensionOnSnapshots<K extends SdbKey, V extends SdbValue>
    on SdbStoreRef<K, V> {
  /// Reads the data and set a listener to redo the query on changes.
  /// It only tracks changes in the current isolate/tab.
  Stream<List<SdbRecordSnapshot<K, V>>> onSnapshots(
    SdbDatabase db, {
    SdbFindOptions<K>? options,
  }) {
    late StreamController<List<SdbRecordSnapshot<K, V>>> controller;
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
        controller.onCancel = () {
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
  /// Reads the data and set a listener to redo the query on changes.
  /// It only tracks changes in the current isolate/tab.
  Stream<List<SdbIndexRecordSnapshot<K, V, IK>>> onSnapshots(
    SdbDatabase db, {
    SdbFindOptions<IK>? options,
  }) {
    late StreamController<List<SdbIndexRecordSnapshot<K, V, IK>>> controller;
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
        controller.onCancel = () {
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
  /// Reads the data and set a listener to redo the query on changes.
  /// It only tracks changes in the current isolate/tab.
  Stream<SdbRecordSnapshot<K, V>?> onSnapshot(SdbDatabase db) {
    late StreamController<SdbRecordSnapshot<K, V>?> controller;
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
        controller.onCancel = () {
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
  /// Reads the data and set a listener to redo the query on changes.
  /// It only tracks changes in the current isolate/tab.
  Stream<SdbIndexRecordSnapshot<K, V, IK>?> onSnapshot(SdbDatabase db) {
    late StreamController<SdbIndexRecordSnapshot<K, V, IK>?> controller;
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
        controller.onCancel = () {
          index.store.removeOnChangesListener(db, onChange);
        };
      },
    );
    return controller.stream;
  }

  /// Reads the data and set a listener to redo the query on changes.
  /// It only tracks changes in the current isolate/tab.
  Stream<List<SdbIndexRecordSnapshot<K, V, IK>>> onSnapshots(
    SdbDatabase db, {
    SdbFindOptions<IK>? options,
  }) {
    late StreamController<List<SdbIndexRecordSnapshot<K, V, IK>>> controller;
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
        controller.onCancel = () {
          store.removeOnChangesListener(db, onChange);
        };
      },
    );
    return controller.stream;
  }
}
