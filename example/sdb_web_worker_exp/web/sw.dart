// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:js_interop';

import 'package:idb_shim/sdb.dart';
import 'package:sdb_web_worker_exp/shared.dart';
import 'package:web/web.dart' as web;

final scope = (globalContext as web.DedicatedWorkerGlobalScope);

var _database = sdbFactoryWebWorker.openDatabase(
  databasePath,
  options: SdbOpenDatabaseOptions(
    version: 1,
    schema: SdbDatabaseSchema(stores: [store.schema()]),
  ),
);

final _workerTrackSubscriptions = <String, StreamSubscription>{};

Future<void> _handleMessageEvent(web.Event event) async {
  var messageEvent = event as web.MessageEvent;
  var rawData = messageEvent.data.dartify();
  print('sw rawData $rawData');
  try {
    var port = messageEvent.ports.toDart.first;

    if (rawData is List) {
      var command = rawData[0];

      if (command == commandVarSet) {
        var data = rawData[1] as Map;
        var key = data['key'] as String;
        var value = data['value'] as int?;
        var db = await _database;
        await db.setValue(key, value);
        port.postMessage(null);
      } else if (command == commandVarGet) {
        var data = rawData[1] as Map;
        var key = data['key'] as String;
        var db = await _database;
        var value = await db.getValue(key);
        port.postMessage(
          {
            'result': {'key': key, 'value': value},
          }.jsify(),
        );
      } else if (command == commandTrackStart) {
        var data = rawData[1] as Map;
        var key = data['key'] as String;
        var db = await _database;
        await _workerTrackSubscriptions[key]?.cancel();
        _workerTrackSubscriptions[key] = db.trackValue(key).listen((snapshot) {
          port.postMessage({'key': key, 'value': snapshot?.value}.jsify());
        });
      } else if (command == commandTrackStop) {
        var data = rawData[1] as Map;
        var key = data['key'] as String;
        await _workerTrackSubscriptions[key]?.cancel();
        _workerTrackSubscriptions.remove(key);
        port.postMessage(null);
      } else {
        print('$command unknown');
        port.postMessage(null);
      }
    } else {
      print('rawData $rawData unknown');
      port.postMessage(null);
    }
  } catch (e) {
    print('error $e');
  }
}

void main(List<String> args) {
  var zone = Zone.current;
  print('Web worker started');
  try {
    scope.onmessage = (web.MessageEvent event) {
      zone.run(() {
        _handleMessageEvent(event);
      });
    }.toJS;
  } catch (e) {
    print('onmessage error $e');
  }
}
