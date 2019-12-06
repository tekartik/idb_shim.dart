// set to true to debug transaction life cycle
import 'package:idb_shim/idb.dart';
import 'package:idb_shim/src/common/common_meta.dart';
import 'package:idb_shim/src/common/common_transaction.dart';
import 'package:idb_shim/src/sembast/sembast_database.dart';
import 'package:idb_shim/src/sembast/sembast_object_store.dart';
import 'package:idb_shim/src/utils/core_imports.dart';
import 'package:sembast/sembast.dart' as sdb;

bool _debugTransaction = false;

// _lazyMode is what indexeddb on chrome supports
// supporting wait between calls
// default is false to matche ie/safari strict behavior
bool _transactionLazyMode = false;

typedef Action = FutureOr Function();

/// Transaction wrapper around a sembast transaction.
class TransactionSembast extends IdbTransactionBase
    with TransactionWithMetaMixin {
  @override
  DatabaseSembast get database => super.database as DatabaseSembast;

  /// Sembast database.
  sdb.Database get sdbDatabase => database.db;

  /// Sembast transaction.
  sdb.Transaction sdbTransaction;

  static int _debugAllIds = 0;
  int _debugId;

  int _index = 0;
  bool _inactive = false;

  Future _execute(int i) {
    if (_debugTransaction) {
      print('exec $i');
    }
    final completer = _completers[i];
    final action = _actions[i] as Action;
    return Future.sync(action).then((result) {
      if (_debugTransaction) {
        print('done $i');
      }
      completer.complete(result);
    }).catchError((e, st) {
      //devPrint(' err $i');
      if (_debugTransaction) {
        print('err $i');
      }
      completer.completeError(e, st as StackTrace);
    });
  }

  Future _next() {
    //print('_next? ${index}/${actions.length}');
    if (_index < _actions.length) {
      // Always try more
      return _execute(_index++).then((_) {
        return _next();
      });
    } else {
      // Safari/IE crashs it a call is made
      // after an async cycle
      if (_debugTransaction) {
        print('transaction done?');
      }

      // check next cycle too
      // Make sure we run after all task and micro task
      // this allows having multiple await between calls
      // however any delayed action will be out of the transaction
      // This fixes sample get/await/get

      Future _checkNextAction() {
        //return new Future.value().then((_) {
        if (_index < _actions.length) {
          return _next();
        }
        if (_debugTransaction) {
          print('transaction done');
        }
        _inactive = true;
        return Future.value(null);
      }

      if (_transactionLazyMode) {
        return Future.delayed(const Duration(), _checkNextAction);
      } else {
        //return new Future.sync(new Duration(), _checkNextAction);
        return _checkNextAction();
      }
    }
  }

  // Lazy execution of the first action
  Future _lazyExecution;

  ///
  /// Create or execute the transaction.
  ///
  /// leaving a time to breath
  /// Since it must run everything in a single call, let all the actions
  /// in the first callback enqueue before running
  ///
  Future<T> execute<T>(FutureOr<T> Function() action) {
    final actionFuture = _enqueue(action);
    _futures.add(actionFuture);

    if (_lazyExecution == null) {
      // Short lifecycle experiment

      //lazyExecution = new Future.delayed(new Duration(), () {

      Future _sdbAction() {
        //assert(sdbDatabase.transaction == null);

        // No return value here
        return sdbDatabase.transaction((txn) {
          // assign right away as this is tested
          sdbTransaction = txn;
          return _next();
        }).whenComplete(() {
          _transactionCompleter.complete();
        }).catchError((e) {
          _transactionCompleter.completeError(e);
        });
      }
      //lazyExecution = new Future.sync(() {
      // don't return the result here

      if (_transactionLazyMode) {
        // old lazy mode
        _lazyExecution = Future.microtask(_sdbAction);
      } else {
        _lazyExecution = Future.sync(_sdbAction);
      }

      //return lazyExecution;
    }

    return actionFuture;
  }

  Future<T> _enqueue<T>(FutureOr<T> Function() action) {
    if (_debugTransaction) {
      print('enqueing');
    }
    if (_inactive) {
      return Future.error(DatabaseError('TransactionInactiveError'));
    }
// not lazy
    var completer = Completer<T>.sync();
    _completers.add(completer);
    _actions.add(action);
    //devPrint('push ${actions.length}');
    //_next();
    return completer.future.then((result) {
      // re-push termination check
      //print(result);
      return result;
    });
  }

  //sdb.Transaction sdbTransaction;
  final _transactionCompleter = Completer();
  final _completers = <Completer>[];
  final _actions = <Function>[];
  final _futures = <Future>[];

  @override
  final IdbTransactionMeta meta;

  TransactionSembast(DatabaseSembast database, this.meta) : super(database) {
    if (_debugTransaction) {
      _debugId = ++_debugAllIds;
    }

    // Trigger a timer to close the transaction if nothing happens
    if (!_transactionLazyMode) {
      // in 1.12, calling completed matched ie behavior
      // simply call completed
      // completed;

      Future.delayed(const Duration(), () {
        completed;
      });
    }
  }

  Future<Database> get _completed {
    if (_lazyExecution == null) {
      if (_debugTransaction) {
        print('no lazy executor $_debugId...');
      }
      _inactive = true;
      return Future.value(database);
    } else {
      if (_debugTransaction) {
        print('lazy executor created $_debugId...');
      }
    }
    return _lazyExecution.then((_) {
      return _transactionCompleter.future.then((_) {
        return Future.wait(_futures).then((_) {
          return database;
        }).catchError((e, st) {
          // catch any errors
          // this is needed so that completed always complete
          // without error
        });
      });
    });
  }

  @override
  Future<Database> get completed {
    if (_debugTransaction) {
      print('completed $_debugId...');
    }
    Future<Database> _completed() => this._completed.then((Database db) {
          if (_debugTransaction) {
            print('completed');
          }
          _inactive = true;
          return db;
        });

    // postpone to next 2 cycles to allow enqueing
    // actions after completed has been called
    //if (_transactionLazyMode) {
    return Future.value().then((_) => _completed());
  }

//    sdbTransaction == null ? new Future.value(database) : sdbTransaction.completed.then((_) {
//    // delay the completed event
//
//  });

  @override
  ObjectStore objectStore(String name) {
    meta.checkObjectStore(name);
    return ObjectStoreSembast(this, database.meta.getObjectStore(name));
  }

//  @override
//  String toString() {
//    return
//  }
}
