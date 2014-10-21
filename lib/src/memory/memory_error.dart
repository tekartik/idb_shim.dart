part of idb_shim_memory;

/**
 * Error thrown when a function is passed an unacceptable argument.
 */
class _MemoryError extends DatabaseError {
  int errorCode;
  
  static final int DATABASE_UPGRADED_ERROR_CODE = 1;
  static final int KEY_ALREADY_EXISTS = 2;
  static final int MISSING_KEY = 3;
  
  _MemoryError(this.errorCode, String message) : super(message);
  
  String toString() {
    String text = "IdbMemoryError(${errorCode})";
    if (message != null) {
      text += ": $message";
    }
    return text;
  }
}
