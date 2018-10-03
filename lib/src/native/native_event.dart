import 'package:idb_shim/idb.dart';
import 'dart:html' as html;

class EventNative extends Event {
  html.Event _htmlEvent;
  EventNative(this._htmlEvent);

  @override
  String toString() {
    return _htmlEvent.toString();
  }
}
