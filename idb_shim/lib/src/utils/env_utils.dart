/// Special runtime trick to known whether we are in the javascript world
const idbIsRunningAsJavascript = identical(0, 0.0);

/// Borrowed from flutter (isRunningAsJavascript is false in wasm)
const bool kIdbDartIsWeb = bool.fromEnvironment('dart.library.js_interop');

bool? _isRelease;

/// Check whether in release mode
bool? get isRelease {
  if (_isRelease == null) {
    _isRelease = true;
    assert(() {
      _isRelease = false;
      return true;
    }());
  }
  return _isRelease;
}

/// Check whether running in debug mode
bool get isDebug => !isRelease!;
