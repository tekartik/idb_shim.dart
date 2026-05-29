/// compat.
typedef NotificationRevision = JdbNotificationRevision;

/// The storage revision.
class JdbNotificationRevision {
  /// Revision for one storage
  JdbNotificationRevision(this.name, this.revision);

  /// Name of the database.
  final String name;

  /// Revision.
  final int revision;

  @override
  String toString() => '$name: $revision';
}

/// For storage notification debugging/logging.
const debugNotificationRevision = false; // devWarning(true); // false
