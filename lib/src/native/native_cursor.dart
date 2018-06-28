part of idb_shim_native;

class _NativeCursor extends Cursor {
  idb.Cursor _cursor;
  _NativeCursor(this._cursor);

  @override
  Object get key => _cursor.key;

  @override
  Object get primaryKey => _cursor.primaryKey;

  @override
  String get direction => _cursor.direction;

  @override
  void advance(int count) {
    _cursor.advance(count);
  }

  @override
  void next([Object key]) {
    _cursor.next(key);
  }

  @override
  Future update(value) {
    return _cursor.update(value);
  }

  @override
  Future delete() {
    return _cursor.delete();
  }
}

/**
 * 
 */
class _NativeCursorWithValue extends CursorWithValue {
  idb.CursorWithValue _cwv;
  //  Object _value;
  //  Object _key;
  _NativeCursorWithValue(this._cwv);
  //    _value = _cwv.value;
  //    _key = _cwv.key;
  //  }
  @override
  Object get value => _cwv.value;

  @override
  Object get key => _cwv.key;

  @override
  Object get primaryKey => _cwv.primaryKey;

  @override
  String get direction => _cwv.direction;

  @override
  void advance(int count) {
    _cwv.advance(count);
  }

  @override
  void next([Object key]) {
    _cwv.next(key);
  }

  @override
  Future update(value) {
    return _cwv.update(value);
  }

  @override
  Future delete() {
    return _cwv.delete();
  }
}

class _NativeCursorWithValueController {
  // Sync must be true
  StreamController<CursorWithValue> _ctlr = new StreamController(sync: true);
  _NativeCursorWithValueController(Stream<idb.CursorWithValue> stream) {
    stream.listen((idb.CursorWithValue cwv) {
      _ctlr.add(new _NativeCursorWithValue(cwv));
    }, onDone: () {
      _ctlr.close();
    }, onError: (error) {
      _ctlr.addError(error);
    });
  }

  Stream<CursorWithValue> get stream => _ctlr.stream;
}

class _NativeCursorController {
  // Sync must be true
  StreamController<Cursor> _ctlr = new StreamController(sync: true);
  _NativeCursorController(Stream<idb.Cursor> stream) {
    stream.listen((idb.Cursor cursor) {
      _ctlr.add(new _NativeCursor(cursor));
    }, onDone: () {
      _ctlr.close();
    }, onError: (error) {
      _ctlr.addError(error);
    });
  }

  Stream<Cursor> get stream => _ctlr.stream;
}
