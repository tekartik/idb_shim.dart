library idb_shim.src.utils.browser_utils;

//
// Dart vs Javascript detection
//
bool get _isDartVm => !_isJavascriptVm;
bool get _isJavascriptVm => identical(1.0, 1);

bool __isDartVm;
bool get isDartVm {
  if (__isDartVm == null) {
    __isDartVm = _isDartVm;
  }
  return __isDartVm;
}
