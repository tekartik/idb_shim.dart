///
/// Generic database exception.
///
class DatabaseException implements Exception {
  /// Create a database exception with a message.
  DatabaseException(this._message);

  /// Error message.
  String get message => _message;
  final String _message;

  @override
  String toString() {
    return 'DatabaseException: $message';
  }
}
