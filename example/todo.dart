// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the COPYING file.

// This is a port of "A Simple ToDo List Using HTML5 IndexedDB" to Dart.
// See: http://www.html5rocks.com/en/tutorials/indexeddb/todo/

import 'dart:html';
import 'package:idb_shim/idb_browser.dart' as idb;
import 'package:idb_shim/idb.dart' as idb;
//import 'dart:indexed_db' as idb;
import 'dart:async';

//idb.IdbFactory idbFactory = window.indexedDB;
idb.IdbFactory idbFactory;

class TodoList {
  InputElement _input;
  Element _todoItems;

  TodoList() {
    _todoItems = querySelector('#todo-items');
    _input = querySelector('#todo') as InputElement;
    querySelector('input#submit').onClick.listen((e) => _onAddTodo());
  }

  static final String _todosDb = "com.tekartik.idb.todo";
  static final String _todosStore = "todos";

  idb.Database _db;
  int _version = 2;

  Future open() async {
    //return window.indexedDB.open(_TODOS_DB, version: _version,
    return idbFactory
        .open(_todosDb, version: _version, onUpgradeNeeded: _onUpgradeNeeded)
        .then(_onDbOpened)
        .catchError(_onError);
  }

  void _onError(e) {
    // Get the user's attention for the sake of this tutorial. (Of course we
    // would *never* use window.alert() in real life.)
    window.alert('Oh no! Something went wrong. See the console for details.');
    window.console.log('An error occurred: {$e}');
  }

  void _onDbOpened(idb.Database db) {
    _db = db;
    _getAllTodoItems();
  }

  void _onUpgradeNeeded(idb.VersionChangeEvent e) {
    idb.Database db = (e.target as idb.OpenDBRequest).result;
    if (!db.objectStoreNames.contains(_todosStore)) {
      db.createObjectStore(_todosStore, keyPath: 'timeStamp');
    }
  }

  void _onAddTodo() {
    var value = _input.value.trim();
    if (value.length > 0) {
      _addTodo(value);
    }
    _input.value = '';
  }

  Future _addTodo(String text) {
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
    _todoItems.nodes.clear();

    var trans = _db.transaction(_todosStore, 'readwrite');
    var store = trans.objectStore(_todosStore);

    // Get everything in the store.
    store.openCursor(autoAdvance: true).listen((cursor) {
      _renderTodo(cursor.value as Map);
    }, onError: _onError);
  }

  void _renderTodo(Map todoItem) {
    var textDisplay = Element.tag('span');
    textDisplay.text = todoItem['text'] as String;

    var deleteControl = Element.tag('a');
    deleteControl.text = '[Delete]';
    deleteControl.onClick
        .listen((e) => _deleteTodo(todoItem['timeStamp'] as String));

    var item = Element.tag('li');
    item.nodes.add(textDisplay);
    item.nodes.add(deleteControl);
    _todoItems.nodes.add(item);
  }
}

///
/// Typically the argument is window.location.search
///
Map<String, String> getArguments(String search) {
  Map<String, String> params = Map();
  if (search != null) {
    int questionMarkIndex = search.indexOf('?');
    if (questionMarkIndex != -1) {
      search = search.substring(questionMarkIndex + 1);
    }
    search.split("&").forEach((e) {
      if (e.contains("=")) {
        List<String> split = e.split("=");
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

Future main() async {
  var urlArgs = getArguments(window.location.search);
  String idbFactoryName = urlArgs['idb_factory'];
  // init factory from url
  idbFactory = idb.getIdbFactory(idbFactoryName);
  if (idbFactory == null) {
    window.alert(
        "No idbFactory of type '$idbFactoryName' supported on this browser");
  } else {
    querySelector("#idb span").innerHtml = "Using '${idbFactory.name}'";
    await TodoList().open();
  }
}