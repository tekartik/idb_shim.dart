import 'dart:async';

import 'package:idb_shim/idb_sdb.dart';

/// Event passed to [SdbOnVersionChangeCallback].
abstract class SdbVersionChangeEvent {
  /// The old version, 0 if new
  int get oldVersion;

  /// The new version.
  int get newVersion;

  /// The opened database.
  SdbOpenDatabase get db;

  /// The opened transaction
  SdbOpenTransaction get transaction;

  /// Event passed to [SdbOnVersionChangeCallback].
  factory SdbVersionChangeEvent({
    required SdbOpenDatabase db,
    required SdbOpenTransaction transaction,
    required int oldVersion,
    required int newVersion,
  }) => SdbVersionChangeEventImpl(db, transaction, oldVersion, newVersion);
}

/// Callback for [SdbFactory.openDatabase].
typedef SdbOnVersionChangeCallback =
    FutureOr<void> Function(SdbVersionChangeEvent event);

/// Version change implementation.
class SdbVersionChangeEventImpl implements SdbVersionChangeEvent {
  @override
  final SdbOpenDatabase db;
  @override
  final SdbOpenTransaction transaction;
  @override
  final int oldVersion;
  @override
  final int newVersion;

  /// Version change implementation.
  SdbVersionChangeEventImpl(
    this.db,
    this.transaction,
    this.oldVersion,
    this.newVersion,
  );
}
