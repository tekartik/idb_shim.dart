// ignore_for_file: public_member_api_docs

import 'package:idb_shim/idb.dart';

import 'indexed_db_web.dart' as idb;

class EventNative extends Event {
  final idb.Event _idbEvent;

  EventNative(this._idbEvent);

  @override
  String toString() {
    return _idbEvent.toString();
  }
}
