library common_key_range;

import 'package:idb_shim/idb_client.dart';

/**
 * Common for Memory and WebSql implementation
 */
class CommonKeyRange extends KeyRange {
  //var _onlyValue;
  var _lowerBound;
  bool _lowerBoundOpen = true;
  var _upperBound;
  bool _upperBoundOpen = true;

  Object get lower => _lowerBound;
  bool get lowerOpen => _lowerBoundOpen;
  Object get upper => _upperBound;
  bool get upperOpen => _upperBoundOpen;

  //  MemoryKeyRange._createOnly(this._onlyValue) : _lowerBoundOpen = false, _upperBoundOpen = false {
  //    _lowerBound = _onlyValue;
  //    _upperBound = _onlyValue;
  //  }

  CommonKeyRange._createLowerBound(this._lowerBound, this._lowerBoundOpen);
  CommonKeyRange._createUpperBound(this._upperBound, this._upperBoundOpen);
  CommonKeyRange._createBound(this._lowerBound, this._upperBound, this._lowerBoundOpen, this._upperBoundOpen);

  bool _checkLowerBound(key) {
    if (_lowerBound != null) {
      if (_lowerBoundOpen != null && _lowerBoundOpen) {
        if (key is num) {
          return (key > _lowerBound);
        } else if (key is String) {
          return key.compareTo(_lowerBound) > 0;
        } else {
          throw new UnsupportedError("key '$key' of type ${key.runtimeType} not supported");
        }
      } else {
        if (key is num) {
          return (key >= _lowerBound);
        } else if (key is String) {
          return key.compareTo(_lowerBound) >= 0;
        } else {
          throw new UnsupportedError("key '$key' of type ${key.runtimeType} not supported");
        }
      }
    }
    return true;
  }

  bool _checkUpperBound(key) {
    if (_upperBound != null) {
      if (_upperBoundOpen != null && _upperBoundOpen) {
        if (key is num) {
          return (key < _upperBound);
        } else if (key is String) {
          return key.compareTo(_upperBound) < 0;
        } else {
          throw new UnsupportedError("key '$key' of type ${key.runtimeType} not supported");
        }
      } else {
        if (key is num) {
          return (key <= _upperBound);
        } else if (key is String) {
          return key.compareTo(_upperBound) <= 0;
        } else {
          throw new UnsupportedError("key '$key' of type ${key.runtimeType} not supported");
        }
      }
    }
    return true;
  }

  bool contains(key) {
    if (!_checkLowerBound(key)) {
      return false;
    } else {
      return _checkUpperBound(key);
    }
  }
}

class CommonKeyRangeFactory extends KeyRangeFactory {
  KeyRange createOnly(/*Key*/ value) => createBound(value, value);
  KeyRange createLowerBound(/*Key*/ bound, [bool open = false]) => new CommonKeyRange._createLowerBound(bound, open);
  KeyRange createUpperBound(/*Key*/ bound, [bool open = false]) => new CommonKeyRange._createUpperBound(bound, open);
  KeyRange createBound(/*Key*/ lower,  /*Key*/ upper, [bool lowerOpen = false, bool upperOpen = false]) => new CommonKeyRange._createBound(lower, upper, lowerOpen, upperOpen);
}
