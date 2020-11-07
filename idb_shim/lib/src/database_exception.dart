///
/// Generic database exception.
///
class DatabaseException implements Exception {
  /// Error message.
  String get message => _message;
  final String _message;

  /// Create a database exception with a message.
  DatabaseException(this._message);

  @override
  String toString() {
    if (message == null) {
      return 'DatabaseException';
    }
    return 'DatabaseException: $message';
  }
}
