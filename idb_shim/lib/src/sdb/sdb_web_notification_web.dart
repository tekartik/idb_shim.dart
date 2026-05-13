import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

const _channelName = 'sdb_store_changes';

final _broadcastChannel = web.BroadcastChannel(_channelName);

/// Broadcast store changes to other tabs via BroadcastChannel.
/// Message format: [dbName, [storeName1, storeName2, ...]]
void sdbBroadcastStoreChanges(String dbName, List<String> storeNames) {
  final storeNamesArr = JSArray.withLength(storeNames.length);
  for (var i = 0; i < storeNames.length; i++) {
    storeNamesArr[i] = storeNames[i].toJS;
  }
  final message = JSArray.withLength(2);
  message[0] = dbName.toJS;
  message[1] = storeNamesArr;
  _broadcastChannel.postMessage(message);
}

StreamController<(String, List<String>)>? _controller;

/// Stream of (dbName, storeNames) notifications from other tabs.
Stream<(String, List<String>)> get sdbExternalStoreChangesStream {
  _controller ??= StreamController<(String, List<String>)>.broadcast(
    onListen: () {
      _broadcastChannel.onmessage = (web.MessageEvent event) {
        final data = event.data;
        if (!data.isA<JSArray>()) return;
        final arr = data as JSArray;
        if (arr.length != 2) return;
        final jsName = arr[0];
        final jsStores = arr[1];
        if (!jsName.isA<JSString>() || !jsStores.isA<JSArray>()) return;
        final dbName = (jsName as JSString).toDart;
        final storesArr = jsStores as JSArray;
        final storeNames = <String>[];
        for (var i = 0; i < storesArr.length; i++) {
          final s = storesArr[i];
          if (s.isA<JSString>()) {
            storeNames.add((s as JSString).toDart);
          }
        }
        if (storeNames.isNotEmpty) {
          _controller?.add((dbName, storeNames));
        }
      }.toJS;
    },
    onCancel: () {
      _broadcastChannel.onmessage = null;
    },
  );
  return _controller!.stream;
}
