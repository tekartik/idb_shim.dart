import 'dart:async';
import 'dart:js_interop';

import 'package:idb_shim/sdb.dart';
import 'package:sdb_web_worker_exp/shared.dart';
import 'package:sdb_web_worker_exp/ui.dart';
import 'package:web/web.dart' as web;

Future<void> main() async {
  initUi();
}

var sharedWorkerUri = Uri.parse('sw.dart.js');
late web.Worker worker;
var _workerReady = () async {
  worker = web.Worker(sharedWorkerUri.toString().toJS);
}();

/// Send a command to the worker and await its response.
Future<Object?> sendRawMessage(Object message) {
  var completer = Completer<Object?>();
  var messageChannel = web.MessageChannel();
  final zone = Zone.current;
  messageChannel.port1.onmessage = (web.MessageEvent event) {
    zone.run(() {
      completer.complete(event.data.dartify());
    });
  }.toJS;
  worker.postMessage(message.jsify(), _portAsOption(messageChannel.port2));
  return completer.future;
}

JSObject _portAsOption(web.MessagePort port) => [port].toJS;

Future<int?> getTestValue() async {
  var response =
      await sendRawMessage([
            commandVarGet,
            {'key': storeKey},
          ])
          as Map;
  return (response['result'] as Map)['value'] as int?;
}

Future<void> setTestValue(int? value) async {
  await sendRawMessage([
    commandVarSet,
    {'key': storeKey, 'value': value},
  ]);
}

Future<void> incrementVarInWorker() async {
  await _workerReady;
  write('worker ready');
  var value = await getTestValue();
  write('var before $value');
  value = (value ?? 0) + 1;
  await setTestValue(value);
  value = await getTestValue();
  write('var after $value');
}

var _dbFuture = sdbFactoryWeb.openDatabase(
  databasePath,
  options: SdbOpenDatabaseOptions(
    version: 1,
    schema: SdbDatabaseSchema(stores: [store.schema()]),
  ),
);

Future<void> incrementVarInMain() async {
  var db = await _dbFuture;
  var value = await db.getTestValue();
  write('var before $value');
  value = (value ?? 0) + 1;
  await db.setTestValue(value);
  value = await db.getTestValue();
  write('var after $value');
}

final _mainTrackSubscriptions = <String, StreamSubscription>{};
final _workerTrackChannels = <String, web.MessageChannel>{};

Future<void> startTrackingMain(String key) async {
  var db = await _dbFuture;
  await _mainTrackSubscriptions[key]?.cancel();
  _mainTrackSubscriptions[key] = db.trackValue(key).listen((snapshot) {
    write('main track: ${snapshot?.value}');
  });
}

Future<void> stopTrackingMain(String key) async {
  await _mainTrackSubscriptions[key]?.cancel();
  _mainTrackSubscriptions.remove(key);
}

Future<void> startTrackingWorker(String key) async {
  var channel = web.MessageChannel();
  final zone = Zone.current;
  channel.port1.onmessage = (web.MessageEvent event) {
    zone.run(() {
      var data = event.data.dartify();
      if (data is Map) {
        write('worker track: ${data["value"]}');
      }
    });
  }.toJS;
  _workerTrackChannels[key] = channel;
  worker.postMessage(
    [
      commandTrackStart,
      {'key': key},
    ].jsify(),
    _portAsOption(channel.port2),
  );
}

Future<void> stopTrackingWorker(String key) async {
  if (_workerTrackChannels.containsKey(key)) {
    var messageChannel = web.MessageChannel();
    worker.postMessage(
      [
        commandTrackStop,
        {'key': key},
      ].jsify(),
      _portAsOption(messageChannel.port2),
    );
    _workerTrackChannels.remove(key);
  }
}

void initUi() {
  addButton('increment var in worker', () async {
    await incrementVarInWorker();
  });
  addButton('increment var in main', () async {
    await incrementVarInMain();
  });
  addButton('clear var in main', () async {
    var db = await _dbFuture;
    await db.setTestValue(null);
    var value = await db.getTestValue();
    write('var after $value');
  });
  addButton('track worker', () async {
    await startTrackingWorker(storeKey);
  });
  addButton('stop tracking worker', () async {
    await stopTrackingWorker(storeKey);
  });
  addButton('track main', () async {
    await startTrackingMain(storeKey);
  });
  addButton('stop tracking main', () async {
    await stopTrackingMain(storeKey);
  });
}
