import 'dart:async';
import 'dart:indexed_db' as idb;

import 'package:idb_shim/idb.dart';

class _NativeCursor extends Cursor {
  final idb.Cursor _cursor;

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

// native idb cursor with value
class _NativeCursorWithValue extends CursorWithValue {
  final idb.CursorWithValue _cwv;

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

class CursorWithValueControllerNative {
  StreamController<CursorWithValue> _ctlr;

  CursorWithValueControllerNative(Stream<idb.CursorWithValue> stream) {
    StreamSubscription streamSubscription;
    _ctlr = StreamController<CursorWithValue>(
        // Sync must be true
        sync: true,
        onListen: () {
          streamSubscription = stream.listen((idb.CursorWithValue cwv) {
            // idbDevPrint("adding ${cwv.key} ${cwv.value} ${cwv.primaryKey}");
            _ctlr.add(_NativeCursorWithValue(cwv));
          }, onDone: () {
            _ctlr.close();
          }, onError: (error) {
            _ctlr.addError(error);
          });
        },
        onCancel: () {
          streamSubscription?.cancel();
        });
  }

  Stream<CursorWithValue> get stream => _ctlr.stream;
}

class CursorControllerNative {
  // Sync must be true
  StreamController<Cursor> _ctlr;

  CursorControllerNative(Stream<idb.Cursor> stream) {
    StreamSubscription streamSubscription;
    _ctlr = StreamController<Cursor>(
        // Sync must be true
        sync: true,
        onListen: () {
          streamSubscription = stream.listen((idb.Cursor cursor) {
            _ctlr.add(_NativeCursor(cursor));
          }, onDone: () {
            _ctlr.close();
          }, onError: (error) {
            _ctlr.addError(error);
          });
        },
        onCancel: () {
          streamSubscription?.cancel();
        });
  }

  Stream<Cursor> get stream => _ctlr.stream;
}
