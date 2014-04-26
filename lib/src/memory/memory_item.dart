part of idb_memory;

/**
 * A memory item is composed of a map and a primary key
 */
class _MemoryItem {

  _MemoryItem(this._key, var value, this._keyPath) {
    // We encode the value mainly to test encoding here...
    this._encodedValue = encodeValue(value);
  }
  String _keyPath;
  var _encodedValue;
  var _key;

  /**
   * Safe way to get the value from an item
   */
  static dynamic safeValue(_MemoryItem item) {
    if (item == null) {
      return null;
    }
    return item.value;
  }
  
  @override
  String toString() {
    return '[$_key] $_encodedValue';
  }

  // Value set when reading it, won't change
  dynamic _value;
  dynamic get value {
    if (_value == null) {
      _value = decodeValue(_encodedValue);
      if (_keyPath != null) {
        _value[_keyPath] = key;
      }
    }
    return _value;
  }
  
  dynamic get key => _key;

  /**
   * Get either the primary key or the value for the key path
   */
  dynamic operator [](String keyPath) {
    if (keyPath == null) {
      return _key;
    }
    return value[keyPath];
  }
}
