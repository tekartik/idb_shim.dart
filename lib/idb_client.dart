library idb_client;

import 'src/common/common_key_range.dart';
import 'dart:async';

const String MODE_READ_WRITE = "readwrite";
const String MODE_READ_ONLY = "readonly";

const String DIRECTION_NEXT = "next";
const String DIRECTION_PREV = "prev";

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
  Stream<CursorWithValue> openCursor({key, KeyRange range, String direction, bool autoAdvance});
  Stream<Cursor> openKeyCursor({key, KeyRange range, String direction, bool autoAdvance});
}

class Request {
  Database result;
  Transaction transaction;
  Request(this.result, this.transaction);
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

class Event {
}

typedef void OnUpgradeNeededFunction(VersionChangeEvent event);
typedef void OnBlockedFunction(Event event);

/**
 * Global KeyRange factory 
 */
KeyRangeFactory __keyRangeFactory;
KeyRangeFactory get _keyRangeFactory {
  if (__keyRangeFactory == null) {
    __keyRangeFactory = new CommonKeyRangeFactory();
  }
  return __keyRangeFactory;
}

abstract class KeyRange {

  KeyRange();
  factory KeyRange.only(/*Key*/ value) {
    return _keyRangeFactory.createOnly(value);
  }
  factory KeyRange.lowerBound(/*Key*/ bound, [bool open = false]) {
    return _keyRangeFactory.createLowerBound(bound, open);
  }
  factory KeyRange.upperBound(/*Key*/ bound, [bool open = false]) {
    return _keyRangeFactory.createUpperBound(bound, open);
  }
  factory KeyRange.bound(/*Key*/ lower,  /*Key*/ upper, [bool lowerOpen = false, bool upperOpen = false]) => _keyRangeFactory.createBound(lower, upper, lowerOpen, upperOpen);
  Object get lower;
  bool get lowerOpen;
  Object get upper;
  bool get upperOpen;
}

abstract class KeyRangeFactory {
  KeyRange createOnly(/*Key*/ value);
  KeyRange createLowerBound(/*Key*/ bound, [bool open = false]);
  KeyRange createUpperBound(/*Key*/ bound, [bool open = false]);
  KeyRange createBound(/*Key*/ lower,  /*Key*/ upper, [bool lowerOpen = false, bool upperOpen = false]);
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
}
