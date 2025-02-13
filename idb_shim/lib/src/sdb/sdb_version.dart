import 'dart:async';

import 'sdb_open.dart';

/// Event passed to [SdbOnVersionChangeCallback].
abstract class SdbVersionChangeEvent {
  /// The old version, 0 if new
  int get oldVersion;

  /// The new version.
  int get newVersion;

  /// The opened database.
  SdbOpenDatabase get db;
}

/// Callback for [SdbOpenDatabase.onVersionChange].
typedef SdbOnVersionChangeCallback =
    FutureOr<void> Function(SdbVersionChangeEvent event);

/// Version change implementation.
class SdbVersionChangeEventImpl implements SdbVersionChangeEvent {
  @override
  final SdbOpenDatabase db;
  @override
  final int oldVersion;
  @override
  final int newVersion;

  /// Version change implementation.
  SdbVersionChangeEventImpl(this.db, this.oldVersion, this.newVersion);
}
