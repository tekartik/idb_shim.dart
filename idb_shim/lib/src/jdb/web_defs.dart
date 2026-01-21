/// compat.
typedef NotificationRevision = JdbNotificationRevision;

/// The storage revision.
class JdbNotificationRevision {
  /// Name of the database.
  final String name;

  /// Revision.
  final int revision;

  /// Revision for one storage
  JdbNotificationRevision(this.name, this.revision);

  @override
  String toString() => '$name: $revision';
}

/// For storage notification debugging/logging.
final debugNotificationRevision = false; // devWarning(true); // false
