import 'package:idb_shim/idb.dart';

/// New abort exception to avoid creating them everywhere
DatabaseException newAbortException([String message = 'Aborted']) =>
    DatabaseException(message);

/// New abort exception to avoid creating them everywhere
DatabaseException wrapException(Exception e, [String? message]) =>
    DatabaseException(
      '${e.runtimeType}: $e${message != null ? ' ($message)' : ''}',
    );
