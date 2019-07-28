library idb_shim;

import 'dart:async';

import 'package:idb_shim/src/common/common_factory.dart';

export 'src/client/client.dart';
export 'src/client/error.dart';

const String idbModeReadWrite = "readwrite";
const String idbModeReadOnly = "readonly";

const String idbDirectionNext = "next";
const String idbDirectionPrev = "prev";

// shim using native indexeddb implementation
const idbFactoryNameNative = "native";
@deprecated
const idbFactoryNative = idbFactoryNameNative;
// shim using Sembast implementation
const idbFactoryNameSembastIo = "sembast_io";
// shim using Sembast io implementation
const idbFactoryNameIo = "io";
// shim using Sembast memory implementation
const idbFactoryNameSembastMemory = "sembast_memory";
// shim using Sembast Memory implementation
const idbFactoryNameMemory = "memory";
// pseudo - best persistent shim (indexeddb or if not available websql)
const idbFactoryNamePersistent = "persistent";
// pseudo - best browser shim (persistent of it not available memory)
const idbFactoryNameBrowser = "browser";
// shim using WebSql implementation
@deprecated
const idbFactoryWebSql = "websql";
// ignore: deprecated_member_use_from_same_package
const idbFactoryNameWebSql = idbFactoryWebSql;
@deprecated
const idbFactorySembastIo = idbFactoryNameSembastIo;
@deprecated
const idbFactoryIo = idbFactoryNameIo;
@deprecated
const idbFactorySembastMemory = idbFactoryNameSembastMemory;
@deprecated
const idbFactoryMemory = idbFactoryNameMemory;
@deprecated
const idbFactoryPersistent = idbFactoryNamePersistent;
@deprecated
const idbFactoryBrowser = idbFactoryNameBrowser;

///
/// represents a cursor for traversing or iterating over multiple records in a
/// database.
///
/// The cursor has a source that indicates which index or object store it is
/// iterating over. It has a position within the range, and moves in a direction
/// that is increasing or decreasing in the order of record keys. The cursor
/// enables an application to asynchronously process all the records in the
/// cursor's range.
///
/// You can have an unlimited number of cursors at the same time. You always get
/// the same IDBCursor object representing a given cursor. Operations are
/// performed on the underlying index or object store.
///
abstract class Cursor {
  ///
  /// returns the key for the record at the cursor's position. If the cursor is
  /// outside its range, this is set to undefined. The cursor's key can be
  /// any data type
  ///
  /// idb_shim: specific - key must be num or String
  ///
  Object get key;

  ///
  /// returns the cursor's current effective key. If the cursor is currently
  /// being iterated or has iterated outside its range, this is set to undefined.
  /// The cursor's primary key can be any data type.
  ///
  /// idb_shim: specific - key must be num or String
  ///
  Object get primaryKey;

  ///
  /// returns the direction of traversal of the cursor (set using
  /// [ObjectStore.openCursor] for example).
  ///
  /// idb_shim: next, prev supported only (not nextunique, prevunique)
  ///
  String get direction;

  ///
  /// sets the number times a cursor should move its position forward.
  ///
  void advance(int count);

  ///
  /// advances the cursor to the next position along its direction, to the item
  /// whose key matches the optional key parameter. If no key is specified,
  /// the cursor advances to the immediate next position, based on the its
  /// direction.
  ///
  void next();

  ///
  /// updates the value at the current position of the cursor in the object
  /// store. If the cursor points to a record that has just been deleted,
  /// a new record is created.
  ///
  Future update(value);

  ///
  /// deletes the record at the cursor's position, without changing the cursor's
  /// position. Once the record is deleted, the cursor's value is set to null.
  ///
  Future delete();
}

///
/// represents a cursor for traversing or iterating over multiple records in a
/// database. It is the same as the [Cursor], except that it includes the value
/// property.
///
/// The cursor has a source that indicates which index or object store it is
/// iterating over. It has a position within the range, and moves in a direction
/// that is increasing or decreasing in the order of record keys. The cursor
/// enables an application to asynchronously process all the records in the
/// cursor's range.
///
/// You can have an unlimited number of cursors at the same time. You always get
/// the same CursorWithValue object representing a given cursor. Operations are
/// performed on the underlying index or object store.
///
abstract class CursorWithValue extends Cursor {
  Object get value;
}

///
/// static, asynchronous transaction on a database using event handler
/// attributes. All reading and writing of data is done within transactions. You
/// actually use [Database] to start transactions and [Transaction] to set the
/// mode of the transaction (e.g. is it readonly or readwrite), and access an
/// [ObjectStore] to make a request. You can also use it to abort transactions.
///
abstract class Transaction {
  ///
  /// returns the database connection with which this transaction is associated.
  ///
  Database get database;

  ///
  /// returns an object store that has already been added to the scope of this
  /// transaction.
  ///
  /// Every call to this method on the same transaction object, with the same
  /// name, returns the same IDBObjectStore instance. If this method is called
  /// on a different transaction object, a different [ObjectStore] instance
  /// is returned.
  ///
  ObjectStore objectStore(String name);

  ///
  /// complete when the transaction is done
  ///
  Future<Database> get completed;
}

///
/// represents an object store in a database. Records within an object store are
/// sorted according to their keys. This sorting enables fast insertion,
/// look-up, and ordered retrieval.
///
abstract class ObjectStore {
  ///
  /// Destroys the index with the specified name in the connected database, used
  /// during a version upgrade.
  ///
  /// Note that this method must be called only from a VersionChange transaction
  /// mode callback. Note that this method synchronously modifies the
  /// [ObjectStore.indexNames] property.
  ///
  void deleteIndex(String name);

  ///
  /// Creates and returns a new Index object in the connected database.
  ///
  /// Note that this method must be called only from a VersionChange transaction
  /// mode callback.
  ///
  Index createIndex(String name, keyPath, {bool unique, bool multiEntry});

  ///
  /// Creates a structured clone of the value, and stores the cloned value in
  /// the object store. This is for adding new records to an object store.
  ///
  /// Returns the key of the inserted object
  /// The add method is an insert only method. If a record already exists in the
  /// object store with the key parameter as its key, then an error
  /// ConstrainError event is fired on the returned request object.
  /// For updating existing records, you should use the [ObjectStore.put]
  /// method instead.
  ///
  ///
  Future add(dynamic value, [dynamic key]);

  ///
  /// creates a structured clone of the value and stores the cloned value in the
  /// object store. This is for adding new records, or updating existing records
  /// in an object store when the transaction's mode is readwrite.
  ///
  /// If the record is successfully stored, then a success event is fired on the
  /// returned request object with the result set to the key for the stored
  /// record, and the transaction set to the transaction in which this object
  /// store is opened.
  ///
  /// The put method is an update or insert method. See the [ObjectStore.add]
  /// method for an insert only method.
  ///
  Future put(dynamic value, [dynamic key]);

  ///
  /// returns the object selected by the specified key. This is for
  /// retrieving specific records from an object store.
  ///
  /// If a value is successfully found, then a structured clone of it is created
  /// and set as the result of the request object.
  ///
  Future getObject(dynamic key);

  ///
  /// deletes the current object store. This is for deleting individual records
  /// out of an object store.
  ///
  Future delete(dynamic key);

  ///
  /// clears this object store in a separate thread.
  /// This is for deleting all the current data out of an object store.
  ///
  /// Clearing an object store consists of removing all records from the object
  /// store and removing all records in indexes that reference the object store.
  ///
  Future clear();

  ///
  /// opens a named index in the current object store, after which it can be
  /// used to, for example, return a series of records sorted by that index
  /// using a cursor.
  ///
  Index index(String name);

  ///
  /// Used for iterating through an object store with a cursor.
  ///
  Stream<CursorWithValue> openCursor(
      {key, KeyRange range, String direction, bool autoAdvance});

  ///
  /// Used for iterating through an object store with a key cursor.
  ///
  Stream<Cursor> openKeyCursor(
      {key, KeyRange range, String direction, bool autoAdvance});

  ///
  /// returns the total number of records that match the provided key or
  /// IDBKeyRange. If no arguments are provided, it returns the total number of
  /// records in the store.
  ///
  Future<int> count([dynamic keyOrRange]);

  ///
  /// Returns the key path of this object store.
  ///
  /// If this property is null, the application must provide a key for each
  /// modification operation.
  ///
  dynamic get keyPath;

  ///
  /// returns the value of the auto increment flag for this object store.
  ///
  bool get autoIncrement;

  ///
  /// The name of this object store.
  ///
  String get name;

  ///
  /// returns a list of the names of indexes on objects in this object store.
  ///
  List<String> get indexNames;

  @override
  String toString() => "$name (key $keyPath auto $autoIncrement)";
}

///
/// provides a connection to a database; you can use an [Database] object to
/// open a transaction on your database then create, manipulate, and delete
/// objects (data) in that database. The interface provides the only way to get
/// and manage versions of the database.
///
abstract class Database {
  /// ctor
  Database(this._factory);

  ///
  ///  creates and returns a new object store or index.
  ///
  /// The method takes the name of the store as well as a parameter object that
  /// lets you define important optional properties. You can use the property to
  /// uniquely identify individual objects in the store. As the property is an
  /// identifier, it should be unique to every object, and every object should
  /// have that property.
  ///
  /// This method can be called only within a versionchange transaction.
  ///
  ObjectStore createObjectStore(String name,
      {String keyPath, bool autoIncrement});

  ///
  /// returns a transaction object (Transaction) containing the
  /// [Transaction.objectStore] method, which you can use to access your object
  /// store.
  ///
  /// [mode] can be readonly (idbModeReadOnly), the default or readwrite (idbModeReadWrite)
  ///
  Transaction transaction(storeNameOrStoreNames, String mode);

  ///
  /// helper for transaction on list of object stores
  ///
  Transaction transactionList(List<String> storeNames, String mode);

  ///
  /// list of the names of the object stores currently in the connected database
  ///
  Iterable<String> get objectStoreNames;

  ///
  /// destroys the object store with the given name in the connected database,
  /// along with any indexes that reference it.
  ///
  /// As with createObjectStore, this method can be called only within a
  /// versionchange transaction.
  ///
  /// raise exception if not found
  ///
  void deleteObjectStore(String name);

  ///
  /// returns immediately and closes the connection in a separate thread.
  ///
  /// The connection is not actually closed until all transactions created using
  /// this connection are complete. No new transactions can be created for this
  /// connection once this method is called. Methods that create transactions
  /// throw an exception if a closing operation is pending.
  ///
  void close();

  ///
  /// A 64-bit integer that contains the version of the connected database.
  ///
  /// When a database is first created, this attribute is null.
  ///
  int get version;

  ///
  /// listen for onVersionChange event
  ///
  ///  best behavior would be to simply close the database and eventually
  ///  reload the page assuming the same page is updating the database
  ///  in a new version
  ///
  Stream<VersionChangeEvent> get onVersionChange;

  ///
  ///  name of the connected database.
  ///
  String get name;

  ///
  /// factory for this type of database
  ///
  IdbFactory get factory => _factory;
  final IdbFactory _factory;
}

///
/// provides asynchronous access to an index in a database. An index is a kind
/// of object store for looking up records in another object store, called the
/// referenced object store. You use this interface to retrieve data.
///
/// You can retrieve records in an object store through the primary key or by
/// using an index. An index lets you look up records in an object store using
/// properties of the values in the object stores records other than the primary
/// key
///
/// The index is a persistent key-value storage where the value part of its
/// records is the key part of a record in the referenced object store. The
/// records in an index are automatically populated whenever records in
/// the referenced object store are inserted, updated, or deleted. Each record
/// in an index can point to only one record in its referenced object store,
/// but several indexes can reference the same object store. When the object
/// store changes, all indexes that refers to the object store are automatically
/// updated.
///
abstract class Index {
  ///
  /// returns the number of records within a key range.
  ///
  Future<int> count([keyOrRange]);

  ///
  /// finds either the value in the referenced object store that corresponds to
  /// the given key or the first corresponding value, if key is set to
  /// a [KeyRange]
  ///
  Future get(dynamic key);

  ///
  /// finds either the given key or the primary key, if key is set to a
  /// [KeyRange].
  ///
  /// this returns the primary key of the record the key is associated with, not
  /// the whole record as [Index.get] does.
  ///
  Future getKey(dynamic key);

  Stream<CursorWithValue> openCursor(
      {key, KeyRange range, String direction, bool autoAdvance});

  Stream<Cursor> openKeyCursor(
      {key, KeyRange range, String direction, bool autoAdvance});

  ///
  /// returns the key path of the current index. If null, this index is not
  /// auto-populated.
  ///
  dynamic get keyPath;

  ///
  /// states whether the index allows duplicate keys or not.
  ///
  /// This is decided when the index is created, using the
  /// [ObjectStore.createIndex] method. This method takes an optional
  /// parameter, unique, which if set to true means that the index will
  /// not be able to accept duplicate entries.
  ///
  bool get unique;

  ///
  /// returns a boolean value that affects how the index behaves when the result
  /// of evaluating the index's key path yields an array.
  ///
  /// This is decided when the index is created, using the
  /// [ObjectStore.createIndex] method. This method takes an optional parameter,
  /// multientry, which is set to true/false.
  ///
  bool get multiEntry;

  ///
  /// returns the name of the current index.
  ///
  String get name;

  @override
  String toString() {
    return 'name:$name keyPath:$keyPath unique:$unique multiEntry:$multiEntry';
  }
}

///
/// provides access to results of asynchronous requests to databases and
/// database objects using event handler attributes. Each reading and writing
/// operation on a database is done using a request.
///
abstract class Request {
  Database result;
  Transaction transaction;

  Request(this.result, this.transaction);
}

///
/// provides access to the results of requests to open or delete databases
///
class OpenDBRequest extends Request {
  OpenDBRequest(Database database, Transaction transaction)
      : super(database, transaction);
}

///
/// indicates that the version of the database has changed, as the result
/// of an onupgradeneeded event handler function.
///
abstract class VersionChangeEvent {
  /// returns the old version number of the database.
  int get oldVersion;

  /// returns the new version number of the database.
  int get newVersion;

  /// the current transaction
  Transaction get transaction;

  // event target
  Object get target;

  Object get currentTarget;

  ///
  /// idb_shim specific
  /// added for convenience
  ///
  Database get database;
}

///
/// Event abstraction for onBlockedFunction
///
abstract class Event {}

typedef OnUpgradeNeededFunction = void Function(VersionChangeEvent event);

typedef OnBlockedFunction = void Function(Event event);

///
/// represents a continuous interval over some data type that is used for keys.
///
/// Records can be retrieved from [ObjectStore] and [Index] objects using keys
/// or a range of keys. You can limit the range using lower and upper bounds.
/// For example, you can iterate over all values of a key in the value range A–Z.
///
/// A key range can be a single value or a range with upper and lower bounds or
/// endpoints. If the key range has both upper and lower bounds, then it is
/// bounded; if it has no bounds, it is unbounded. A bounded key range can
/// either be open (the endpoints are excluded) or closed (the endpoints are
/// included)
///
class KeyRange {
  KeyRange();

  KeyRange.only(/*Key*/ value) : this.bound(value, value);

  KeyRange.lowerBound(this._lowerBound, [bool open = false]) {
    _lowerBoundOpen = open ?? false;
  }

  KeyRange.upperBound(this._upperBound, [bool open = false]) {
    _upperBoundOpen = open ?? false;
  }

  KeyRange.bound(this._lowerBound, this._upperBound,
      [bool lowerOpen = false, bool upperOpen = false]) {
    _lowerBoundOpen = lowerOpen ?? false;
    _upperBoundOpen = upperOpen ?? false;
  }

  dynamic _lowerBound;
  bool _lowerBoundOpen = true;
  dynamic _upperBound;
  bool _upperBoundOpen = true;

  Object get lower => _lowerBound;

  bool get lowerOpen => _lowerBoundOpen;

  Object get upper => _upperBound;

  bool get upperOpen => _upperBoundOpen;

  num _compareValue(value1, value2) {
    if (value1 is num) {
      return value1 - (value2 as num);
    } else if (value1 is String) {
      return value1.compareTo(value2 as String);
    } else if (value1 is List) {
      List list = value1;
      for (int i = 0; i < list.length; i++) {
        var diff = _compareValue(list[i], (value2 as List)[i]);
        if (diff != 0) {
          return diff;
        }
      }
      return 0;
    } else {
      throw UnsupportedError(
          "key '$value1' of type ${value1.runtimeType} not supported");
    }
  }

  ///
  /// Added method for memory implementation
  ///
  bool _checkLowerBound(key) {
    if (_lowerBound != null) {
      bool exclude = _lowerBoundOpen != null && _lowerBoundOpen;
      num cmp = _compareValue(key, _lowerBound);
      if (cmp == 0 && exclude) {
        return false;
      } else {
        return cmp >= 0;
      }
    }
    return true;
  }

  bool _checkUpperBound(key) {
    if (_upperBound != null) {
      bool exclude = _upperBoundOpen != null && _upperBoundOpen;
      num cmp = _compareValue(key, _upperBound);
      if (cmp == 0 && exclude) {
        return false;
      } else {
        return cmp <= 0;
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
    StringBuffer sb = StringBuffer('kr');
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

///
/// Out factory for opening a database instead of using window.indexedDB
///
abstract class IdbFactory {
  ///
  /// requests opening a connection to a database.
  ///
  /// performs he open operation asynchronously. If the operation is successful,
  /// it returns a new [Database] object for the connection.
  ///
  /// If an error occurs while the database connection is being opened,
  /// then an error event is fired on the request object returned from this
  /// method.
  ///
  /// May trigger upgradeneeded, blocked or versionchange events.
  ///
  Future<Database> open(String dbName,
      {int version,
      OnUpgradeNeededFunction onUpgradeNeeded,
      OnBlockedFunction onBlocked});

  ///
  /// compares two values as keys to determine equality and ordering for
  /// IndexedDB operations, such as storing and iterating.
  ///
  int cmp(Object first, Object second);

  ///
  /// performs the deletion operation asynchronously.
  ///
  ///  Will trigger an upgradedneeded event and, if any other tabs have open
  ///  connections to the database, a blocked event.
  ///
  Future<IdbFactory> deleteDatabase(String name, {OnBlockedFunction onBlocked});

  ///
  /// if getDatabaseNames can be called
  ///
  bool get supportsDatabaseNames;

  ///
  /// list of databases
  ///
  Future<List<String>> getDatabaseNames();

  /// Changed to true when a factory is created
  static bool get supported => IdbFactoryBase.supported;

  ///
  /// idb_shim specific
  ///
  String get name;

  /// whether the changes are persistent (i.e. not in memory)
  bool get persistent;
}

///
/// Generic database error
///
class DatabaseError extends Error {
  String get message => _message;
  String _message;

  StackTrace _stackTrace;

  @override
  StackTrace get stackTrace => _stackTrace ?? super.stackTrace;

  set stackTrace(StackTrace stackTrace) {
    _stackTrace = stackTrace;
  }

  DatabaseError(this._message);

  @override
  String toString() => message;
}

///
/// Generic database exception
///
class DatabaseException implements Exception {
  String get message => _message;
  String _message;

  DatabaseException(this._message);

  @override
  String toString() {
    if (message == null) return "DatabaseException";
    return "DatabaseException: $message";
  }
}
