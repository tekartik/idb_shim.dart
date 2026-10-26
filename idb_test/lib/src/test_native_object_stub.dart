/// An object to wrap in an `IdbNativeValue` in tests: a Dart object here
/// (only the memory factories store it).
Object newTestNativeObject() => _TestNativeObject();

class _TestNativeObject {
  @override
  String toString() => 'TestNativeObject';
}
