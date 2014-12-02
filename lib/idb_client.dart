library idb_shim_client;

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

  /**
   * The keyPath property of the IDBObjectStore interface returns the
   * key path of this object store.
   * If this property is null, the application must provide a key for each modification operation.
   */
  dynamic get keyPath;

  /**
   * The autoIncrement property of the IDBObjectStore interface returns the 
   * value of the auto increment flag for this object store.
   */
  bool get autoIncrement;

  /**
   * The name property of the IDBObjectStore interface returns the name of this object store.
   */
  String get name;

  /**
   * The indexNames property of the IDBObjectStore interface returns a 
   * list of the names of indexes on objects in this object store.
   */
  List<String> get indexNames;

  @override
  String toString() => "${name} (key ${keyPath} auto ${autoIncrement})";
}

abstract class Database {
  Database(this._factory);
  ObjectStore createObjectStore(String name, {String keyPath, bool autoIncrement});
  Transaction transaction(storeName_OR_storeNames, String mode);
  Transaction transactionList(List<String> storeNames, String mode);
  
  /**
   * list of the names of the object stores currently in the connected database
   */
  Iterable<String> get objectStoreNames;
  
  /**
   * destroys the object store with the given name in the connected database, 
   * along with any indexes that reference it.
   * 
   * As with createObjectStore, this method can be called only within a versionchange
   * transaction.
   * 
   * raise exception if not found
   */
  void deleteObjectStore(String name);

  /**
   * returns immediately and closes the connection in a separate thread.
   * The connection is not actually closed until all transactions created using this
   * connection are complete. No new transactions can be created for this connection
   * once this method is called. Methods that create transactions throw an exception 
   * if a closing operation is pending.
   */
  void close();

  /**
   * A 64-bit integer that contains the version of the connected database. 
   * When a database is first created, this attribute is an empty string.
   */
  int get version;

  /**
   * listen for onVersionChange event
   * best behavior would be to simply close the database and eventually
   * reload the page assuming the same page is updating the database
   * in a new version
   */
  Stream<VersionChangeEvent> get onVersionChange;

  /**
   * The IDBDatabase interface of the IndexedDB API provides a connection to a database; 
   * you can use an IDBDatabase object to open a transaction on your database then create, 
   * manipulate, and delete objects (data) in that database. The interface provides 
   * the only way to get and manage versions of the database.
   */
  String get name;

  /**
   * factory for this type of database
   */
  IdbFactory get factory => _factory;
  final IdbFactory _factory;
}


abstract class Index {
  Future<int> count([key_OR_range]);
  Future get(dynamic key);
  
  /**
   * The getKey() method of the IDBIndex interface returns an IDBRequest object, 
   * and, in a separate thread, finds either the given key or the primary key,
   * if key is set to an IDBKeyRange.
   * If a key is successfully found it is set as the result of the request object: 
   * this returns the primary key of the record the key is associated with, not 
   * the whole record as IDBIndex.get does.
   */
  Future getKey(dynamic key);
  Stream<CursorWithValue> openCursor({key, KeyRange range, String direction, bool autoAdvance});
  Stream<Cursor> openKeyCursor({key, KeyRange range, String direction, bool autoAdvance});

  /**
   * The keyPath property of the IDBIndex interface returns the key path of the
   * current index. If null, this index is not auto-populated.
   */
  dynamic get keyPath;

  /**
   * The unique property returns a boolean that states whether the index 
   * allows duplicate keys or not.
   * This is decided when the index is created, using the 
   * IDBObjectStore.createIndex method. This method takes an optional 
   * parameter, unique, which if set to true means that the index will 
   * not be able to accept duplicate entries.
   */
  bool get unique;

  /**
   * The multiEntry property of the IDBIndex interface returns a boolean 
   * value that affects how the index behaves when the result of evaluating 
   * the index's key path yields an array.
   * 
   * This is decided when the index is created, using the
   * IDBObjectStore.createIndex method. This method takes an optional
   * parameter, multientry, which is set to true/false.
   */
  bool get multiEntry;

  /**
   * The name property of the IDBIndex interface returns the name of 
   * the current index.
   */
  String get name;
  
  @override
  String toString() {
    return 'name:${name} keyPath:${keyPath} unique:${unique} multiEntry:${multiEntry}';
  }
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
  bool get persistent;
}
