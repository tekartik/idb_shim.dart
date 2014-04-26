part of idb_memory;

/**
 * Error thrown when a function is passed an unacceptable argument.
 */
class _MemoryError extends Error {
  final message;
  int errorCode;
  
  static final int DATABASE_UPGRADED_ERROR_CODE = 1;
  
  _MemoryError(this.errorCode, this.message);
  
  String toString() {
    String text = "IdbMemoryError";
    if (message != null) {
      text += ": $message";
    }
    return text;
  }
}
