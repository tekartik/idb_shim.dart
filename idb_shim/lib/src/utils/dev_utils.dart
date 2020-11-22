/// Development helpers to generate warning in code
library idb_shim_dev_utils;

import 'package:meta/meta.dart';

void _devPrint(Object? object) {
  if (_devPrintEnabled) {
    print(object);
  }
}

bool _devPrintEnabled = true;

@deprecated
set devPrintEnabled(bool enabled) => _devPrintEnabled = enabled;

@deprecated
void devPrint(Object? object) {
  if (_devPrintEnabled) {
    print(object);
  }
}

/// Deprecated to prevent keeping the code used.
///
/// Can be use as a todo for weird code. int value = devWarning(myFunction());
/// The function is always called
@deprecated
T devWarning<T>(T value) => value;

void _devError([Object? msg]) {
  // one day remove the print however sometimes the error thrown is hidden
  try {
    throw UnsupportedError(msg?.toString() ?? 'devError');
  } catch (e, st) {
    if (_devPrintEnabled) {
      print('# ERROR $msg');
      print(st);
    }
    rethrow;
  }
}

@deprecated
void devError([String? msg]) => _devError(msg);

@visibleForTesting
void tekartikDevPrint(Object? object) => _devPrint(object);

@visibleForTesting
void tekartikDevError(Object? object) => _devError(object);

@visibleForTesting
set tekartikDevPrintEnabled(bool enabled) => _devPrintEnabled = enabled;
