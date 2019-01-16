/// Development helpers to generate warning in code
library idb_shim_dev_utils;

void _devPrint(Object object) {
  if (_devPrintEnabled) {
    print(object);
  }
}

bool _devPrintEnabled = true;

@deprecated
set devPrintEnabled(bool enabled) => _devPrintEnabled = enabled;

@deprecated
void devPrint(Object object) {
  if (_devPrintEnabled) {
    print(object);
  }
}

@deprecated
int devWarning;

void _devError([Object msg]) {
  // one day remove the print however sometimes the error thrown is hidden
  try {
    throw UnsupportedError(msg?.toString());
  } catch (e, st) {
    if (_devPrintEnabled) {
      print("# ERROR $msg");
      print(st);
    }
    rethrow;
  }
}

@deprecated
void devError([String msg]) => _devError(msg);

// exported for testing
void tekartikDevPrint(Object object) => _devPrint(object);

void tekartikDevError(Object object) => _devError(object);

set tekartikDevPrintEnabled(bool enabled) => _devPrintEnabled = enabled;
