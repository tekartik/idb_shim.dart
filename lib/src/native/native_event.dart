part of idb_shim_native;

class _NativeEvent extends Event {
  html.Event _htmlEvent;
  _NativeEvent(this._htmlEvent);

  @override
  String toString() {
    return _htmlEvent.toString();
  }
}
