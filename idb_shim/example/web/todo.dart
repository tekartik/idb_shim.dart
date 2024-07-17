// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the COPYING file.

// This is a port of 'A Simple ToDo List Using HTML5 IndexedDB' to Dart.
// See: http://www.html5rocks.com/en/tutorials/indexeddb/todo/

import 'dart:async';

import 'package:idb_shim/idb.dart' as idb;
import 'package:idb_shim/idb_browser.dart' as idb;
import 'package:web/web.dart';

idb.IdbFactory? idbFactory;

class TodoList {
  late HTMLInputElement _input;
  late Element _todoItems;

  TodoList() {
    _todoItems = document.querySelector('#todo-items')!;
    _input = document.querySelector('#todo') as HTMLInputElement;
    document.querySelector('input#submit')!.onClick.listen((e) => _onAddTodo());
  }

  static final String _todosDb = 'com.tekartik.idb.todo';
  static final String _todosStore = 'todos';

  late idb.Database _db;
  final _version = 2;

  Future<void> open() async {
    //return window.indexedDB.open(_TODOS_DB, version: _version,
    return idbFactory!
        .open(_todosDb, version: _version, onUpgradeNeeded: _onUpgradeNeeded)
        .then(_onDbOpened)
        .catchError(_onError);
  }

  void _onError(Object e) {
    // Get the user's attention for the sake of this tutorial. (Of course we
    // would *never* use window.alert() in real life.)
    window.alert('Oh no! Something went wrong. See the console for details.');
    // ignore: avoid_print
    print('An error occurred: {$e}');
  }

  void _onDbOpened(idb.Database db) {
    _db = db;
    _getAllTodoItems();
  }

  void _onUpgradeNeeded(idb.VersionChangeEvent e) {
    final db = (e.target as idb.OpenDBRequest).result;
    if (!db.objectStoreNames.contains(_todosStore)) {
      db.createObjectStore(_todosStore, keyPath: 'timeStamp');
    }
  }

  void _onAddTodo() {
    var value = _input.value.trim();
    if (value.isNotEmpty) {
      _addTodo(value);
    }
    _input.value = '';
  }

  Future<void> _addTodo(String text) {
    var trans = _db.transaction(_todosStore, 'readwrite');
    var store = trans.objectStore(_todosStore);
    return store
        .put({
          'text': text,
          'timeStamp': DateTime.now().millisecondsSinceEpoch.toString()
        })
        .then((_) => _getAllTodoItems())
        .catchError((e) => _onError);
  }

  void _deleteTodo(String id) {
    var trans = _db.transaction(_todosStore, 'readwrite');
    var store = trans.objectStore(_todosStore);
    var request = store.delete(id);
    request.then((e) => _getAllTodoItems(), onError: _onError);
  }

  void _getAllTodoItems() {
    for (var i = 0; i < _todoItems.children.length; i++) {
      _todoItems.children.item(i)?.remove();
    }

    var trans = _db.transaction(_todosStore, 'readwrite');
    var store = trans.objectStore(_todosStore);

    // Get everything in the store.
    store.openCursor(autoAdvance: true).listen((cursor) {
      _renderTodo(cursor.value as Map);
    }, onError: _onError);
  }

  void _renderTodo(Map todoItem) {
    var textDisplay = HTMLSpanElement();
    textDisplay.text = todoItem['text']?.toString() ?? '<no data>';

    var deleteControl = HTMLAnchorElement();
    deleteControl.text = '[Delete]';
    deleteControl.onClick
        .listen((e) => _deleteTodo(todoItem['timeStamp'] as String));

    var item = HTMLLIElement();
    item.appendChild(textDisplay);
    item.appendChild(deleteControl);
    _todoItems.appendChild(item);
  }
}

///
/// Typically the argument is window.location.search
///
Map<String, String> getArguments(String? search) {
  final params = <String, String>{};
  if (search != null) {
    final questionMarkIndex = search.indexOf('?');
    if (questionMarkIndex != -1) {
      search = search.substring(questionMarkIndex + 1);
    }
    search.split('&').forEach((e) {
      if (e.contains('=')) {
        final split = e.split('=');
        params[split[0]] = split[1];
      } else {
        if (e.isNotEmpty) {
          params[e] = '';
        }
      }
    });
  }
  return params;
}

Future<void> main() async {
  var urlArgs = getArguments(window.location.search);
  final idbFactoryName = urlArgs['idb_factory'];
  // init factory from url
  idbFactory = idb.getIdbFactory(idbFactoryName);
  if (idbFactory == null) {
    window.alert(
        "No idbFactory of type '$idbFactoryName' supported on this browser");
  } else {
    document.querySelector('#idb span')!.textContent =
        "Using '${idbFactory!.name}'";
    await TodoList().open();
  }
}
