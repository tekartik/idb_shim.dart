library idb_client;

import 'dart:async';

part 'src/client/client.dart';
part 'src/client/error.dart';

const String IDB_MODE_READ_WRITE = "readwrite";
const String IDB_MODE_READ_ONLY = "readonly";

const String IDB_DIRECTION_NEXT = "next";
const String IDB_DIRECTION_PREV = "prev";

// shim using native indexeddb implementation
const IDB_FACTORY_NATIVE = "native";
// shim using WebSql implementation
const IDB_FACTORY_WEBSQL = "websql";
// shim using Memory implementation
const IDB_FACTORY_MEMORY = "memory";
// pseudo - best persistent shim (indexeddb or if not available websql)
const IDB_FACTORY_PERSISTENT = "persistent";
// pseudo - best browser shim (persistent of it not available memory)
const IDB_FACTORY_BROWSER = "browser";

abstract class Cursor {
  Object get key;
  Object get primaryKey;
  String get direction;
  void advance(int count);
  void next();
  Future update(value);
  Future delete();
}

abstract class CursorWithValue extends Cursor {
  Object get value;
}

abstract class Transaction {
  Database database;

  ObjectStore objectStore(String name);
  Transaction(this.database);

  Future<Database> get completed;
}

abstract class ObjectStore {

  Index createIndex(String name, keyPath, {bool unique, bool multiEntry});

  /**
   * Typically value is a Map and the future contains the key
   */
  Future add(dynamic value, [dynamic key]);
  Future put(dynamic value, [dynamic key]);
  Future getObject(dynamic key);
  Future delete(dynamic key);
  Future clear();
  Index index(String name);

  Stream<CursorWithValue> openCursor({key, KeyRange range, String direction, bool autoAdvance});

  Future<int> count([dynamic key_OR_range]);
  
  dynamic get keyPath;
  bool get autoIncrement;
}

abstract class Database {
  ObjectStore createObjectStore(String name, {String keyPath, bool autoIncrement});
  Transaction transaction(storeName_OR_storeNames, String mode);
  Transaction transactionList(List<String> storeNames, String mode);
  Iterable<String> get objectStoreNames;
  void deleteObjectStore(String name);
  void close();
  int get version;
  
  /**
   * listen for onVersionChange event
   * best behavior would be to simply close the database and eventually
   * reload the page assuming the same page is updating the database
   * in a new version
   */
  Stream<VersionChangeEvent> get onVersionChange;
}

abstract class Index {
  Future<int> count([key_OR_range]);
  Future get(dynamic key);
  Future getKey(dynamic key);
  Stream<CursorWithValue> openCursor({key, KeyRange range, String direction, bool autoAdvance});
  Stream<Cursor> openKeyCursor({key, KeyRange range, String direction, bool autoAdvance});
}

abstract class Request {
  Database result;
  Transaction transaction;
  Request(this.result, this.transaction);
}

class OpenDBRequest extends Request {
  OpenDBRequest(Database database, Transaction transaction) : super(database, transaction);
}

abstract class VersionChangeEvent {
  int get oldVersion;
  int get newVersion;
  Transaction get transaction;
  Object get target;
  Object get currentTarget => target;
  
  /**
   * added for convenience
   */
  Database get database;
}

abstract class Event {
}

typedef void OnUpgradeNeededFunction(VersionChangeEvent event);
typedef void OnBlockedFunction(Event event);

/**
 * Key Range 
 */
class KeyRange {

  KeyRange();
  KeyRange.only(/*Key*/ value) : this.bound(value, value);
  KeyRange.lowerBound(this._lowerBound, [bool open = false]) {
    _lowerBoundOpen = open;
  }
  KeyRange.upperBound(this._upperBound, [bool open = false]) {
    _upperBoundOpen = open;
  }
  KeyRange.bound(this._lowerBound, this._upperBound, [bool lowerOpen = false, bool upperOpen = false]) {
    _lowerBoundOpen = lowerOpen;
    _upperBoundOpen = upperOpen;
  }
  
  var _lowerBound;
  bool _lowerBoundOpen = true;
  var _upperBound;
  bool _upperBoundOpen = true;

  Object get lower => _lowerBound;
  bool get lowerOpen => _lowerBoundOpen;
  Object get upper => _upperBound;
  bool get upperOpen => _upperBoundOpen;

  /**
   * Added method for memory implementation
   */
  bool _checkLowerBound(key) {
    if (_lowerBound != null) {
      if (_lowerBoundOpen != null && _lowerBoundOpen) {
        if (key is num) {
          return (key > _lowerBound);
        } else if (key is String) {
          return key.compareTo(_lowerBound) > 0;
        } else {
          throw new UnsupportedError("key '$key' of type ${key.runtimeType} not supported");
        }
      } else {
        if (key is num) {
          return (key >= _lowerBound);
        } else if (key is String) {
          return key.compareTo(_lowerBound) >= 0;
        } else {
          throw new UnsupportedError("key '$key' of type ${key.runtimeType} not supported");
        }
      }
    }
    return true;
  }

  bool _checkUpperBound(key) {
    if (_upperBound != null) {
      if (_upperBoundOpen != null && _upperBoundOpen) {
        if (key is num) {
          return (key < _upperBound);
        } else if (key is String) {
          return key.compareTo(_upperBound) < 0;
        } else {
          throw new UnsupportedError("key '$key' of type ${key.runtimeType} not supported");
        }
      } else {
        if (key is num) {
          return (key <= _upperBound);
        } else if (key is String) {
          return key.compareTo(_upperBound) <= 0;
        } else {
          throw new UnsupportedError("key '$key' of type ${key.runtimeType} not supported");
        }
      }
    }
    return true;
  }

  bool contains(key) {
    if (!_checkLowerBound(key)) {
      return false;
    } else {
      return _checkUpperBound(key);
    }
  }
  
  @override
  String toString() {
    StringBuffer sb = new StringBuffer('kr');
    if (lower == null) {
      sb.write('...');
    } else {
      if (lowerOpen) {
        sb.write(']');
      } else {
        sb.write('[');
      }
      sb.write(lower);
    }
    sb.write('-');
    if (upper == null) {
      sb.write('...');
    } else {
      sb.write(upper);
      if (upperOpen) {
        sb.write('[');
      } else {
        sb.write(']');
      }
    }
    return sb.toString();
  }
}

abstract class IdbFactory {
  /**
   * When a factory is created, mark it as supported
   */
  IdbFactory() {
    IdbFactory.supported = true;
  }
  Future<Database> open(String dbName, {int version, OnUpgradeNeededFunction onUpgradeNeeded, OnBlockedFunction onBlocked});
  Future<IdbFactory> deleteDatabase(String name, {void onBlocked(Event)});
  bool get supportsDatabaseNames;
  Future<List<String>> getDatabaseNames();
  static bool supported = false; // Changed to true when a factory is created
  
  /**
   * idb_shim specific
   */
  String get name;
}

