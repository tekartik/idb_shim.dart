import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// An object to wrap in an `IdbNativeValue` in tests: an empty JS `Blob`
/// (stored by the native and the memory factories).
Object newTestNativeObject() => globalContext
    .getProperty<JSFunction>('Blob'.toJS)
    .callAsConstructor<JSObject>(<JSAny>[].toJS);
