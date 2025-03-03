// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:idb_shim/idb.dart';
import 'package:idb_shim/src/logger/logger_utils.dart';
import 'package:idb_shim/src/native_web/js_utils.dart';

import 'indexed_db_web.dart' as idb;

class CursorNative extends Cursor {
  final idb.IDBCursor _cursor;

  CursorNative(this._cursor);

  @override
  Object get key => _cursor.key!.dartifyValue();

  @override
  Object get primaryKey => _cursor.primaryKey!.dartifyValue();

  @override
  String get direction => _cursor.direction;

  @override
  void advance(int count) {
    _cursor.advance(count);
  }

  @override
  void next([Object? key]) {
    _cursor.continue_(key?.jsifyValue());
  }

  @override
  Future update(Object? value) {
    return _cursor.update(value?.jsifyValue()).future;
  }

  @override
  Future delete() {
    return _cursor.delete().future;
  }
}

// native idb cursor with value
class CursorWithValueNative extends CursorWithValue {
  final idb.IDBCursorWithValue _cwv;

  //  Object _value;
  //  Object _key;
  CursorWithValueNative(this._cwv);

  //    _value = _cwv.value;
  //    _key = _cwv.key;
  //  }
  @override
  Object get value => _cwv.value!.dartifyValue();

  @override
  Object get key => _cwv.key!.dartifyValue();

  @override
  Object get primaryKey => _cwv.primaryKey!.dartifyValue();

  @override
  String get direction => _cwv.direction;

  @override
  void advance(int count) {
    _cwv.advance(count);
  }

  @override
  void next([Object? key]) {
    if (key == null) {
      _cwv.continue_();
    } else {
      _cwv.continue_(key.jsifyKey());
    }
  }

  @override
  Future update(Object value) {
    return _cwv.update(value.jsifyValue()).future;
  }

  @override
  Future delete() {
    return _cwv.delete().future;
  }

  @override
  String toString() {
    return 'CursorWithValue(${logTruncateAny(primaryKey)}, ${logTruncateAny(key)}, ${logTruncateAny(value)}';
  }
}
