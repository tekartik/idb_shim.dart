import 'dart:html' as html;

import 'package:idb_shim/idb.dart';

class EventNative extends Event {
  html.Event _htmlEvent;

  EventNative(this._htmlEvent);

  @override
  String toString() {
    return _htmlEvent.toString();
  }
}
