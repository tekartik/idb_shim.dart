// set to true to debug transaction life cycle
// ignore_for_file: public_member_api_docs

import 'package:idb_shim/idb.dart';
import 'package:idb_shim/src/common/common_exception.dart';
import 'package:idb_shim/src/common/common_meta.dart';
import 'package:idb_shim/src/common/common_transaction.dart';
import 'package:idb_shim/src/sembast/sembast_database.dart';
import 'package:idb_shim/src/sembast/sembast_object_store.dart';
import 'package:idb_shim/src/utils/core_imports.dart';
import 'package:sembast/sembast.dart' as sdb;

bool _debugTransaction = false; // devWarning(true); // false;

// _lazyMode is what indexeddb on chrome supports
// supporting wait between calls
// default is false to matche ie/safari strict behavior
bool _transactionLazyMode = false;

typedef Action = FutureOr Function();

// Failing
bool newTransaction = false;

Future<void> _delayedInit() async {
  await Future<void>.delayed(Duration.zero);
}

/// Transaction wrapper around a sembast transaction.
class TransactionSembast extends IdbTransactionBase
    with TransactionWithMetaMixin {
  @override
  DatabaseSembast get database => super.database as DatabaseSembast;

  /// Sembast database.
  sdb.Database get sdbDatabase => database.db!;

  /// Sembast transaction.
  sdb.Transaction? sdbTransaction;

  static int _debugAllIds = 0;
  int? _debugId;

  int _index = 0;
  bool _inactive = false;

  var _aborted = false;
  Exception? _endException;
  // In case of an error it must be cancelled

  // The outer result
  final _completedCompleter = Completer<Database>.sync();

  @Deprecated('Use only in one place')
  void _complete() {
    if (!_completedCompleter.isCompleted) {
      if (_aborted) {
        _completeError(newAbortException());
      } else {
        _completedCompleter.complete(database);
      }
    }
  }

  @Deprecated('Use only in one place')
  void _completeError(Object e, [StackTrace? st]) {
    if (!_completedCompleter.isCompleted) {
      _completedCompleter.completeError(e, st);
    }
  }

  Future _execute(int i) {
    if (_debugTransaction) {
      print('exec $i');
    }
    final completer = _completers[i];
    final action = _actions[i] as Action;

    // Time very important here
    if (newTransaction) {
      // Not working
      return () async {
        try {
          dynamic result = action();
          if (result is Future) {
            result = await result;
          }
          if (_debugTransaction) {
            print('done $i');
          }
          completer.complete(result);
        } catch (e, st) {
          if (_debugTransaction) {
            print('err $i $e');
          }
          completer.completeError(e, st);
        }
      }();
    } else {
      // Yes!
      return Future.sync(action).then((result) {
        if (_debugTransaction) {
          print('done $i');
        }
        completer.complete(result);
      }).catchError((Object e, StackTrace st) {
        //devPrint(' err $i');
        if (_debugTransaction) {
          print('err $i $e');
        }
        completer.completeError(e, st);
      });
    }
  }

  Future _next() {
    if (_aborted) {
      if (_debugTransaction) {
        print('throwing abort exception');
      }
      throw newAbortException('Transaction aborted');
    }
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

      Future checkNextAction() {
        //return new Future<void>.value().then((_) {
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
        return Future.delayed(const Duration(), checkNextAction);
      } else {
        //return new Future.sync(new Duration(), _checkNextAction);
        return checkNextAction();
      }
    }
  }

  // Lazy execution of the first action
  Future? _lazyExecution;

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

      Future sdbAction() {
        //assert(sdbDatabase.transaction == null);

        // No return value here
        return sdbDatabase.transaction((txn) async {
          // assign right away as this is tested
          sdbTransaction = txn;
          // Do we care about the type here?
          var result = await _next();

          // If aborted throw an error exception so that saves are
          // cancelled
          if (_endException != null) {
            throw _endException!;
          }

          return result;
        }).whenComplete(() {
          if (!_transactionCompleter.isCompleted) {
            _transactionCompleter.complete();
          }
          if (_debugTransaction) {
            print('txn end of sembast transaction');
          }
        }).catchError((Object e) {
          if (!_transactionCompleter.isCompleted) {
            _transactionCompleter.completeError(e);
          }
        });
      }
      //lazyExecution = new Future.sync(() {
      // don't return the result here

      if (_transactionLazyMode) {
        // old lazy mode
        _lazyExecution = Future.microtask(sdbAction);
      } else {
        _lazyExecution = Future.sync(sdbAction);
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
  final _transactionCompleter = Completer<void>();
  final _completers = <Completer>[];
  final _actions = <Function>[];
  final _futures = <Future>[];

  @override
  final IdbTransactionMeta? meta;

  ///
  /// Constructor.
  TransactionSembast(DatabaseSembast super.database, this.meta) {
    if (_debugTransaction) {
      _debugId = ++_debugAllIds;
    }

    // Trigger a timer to close the transaction if nothing happens
    if (!_transactionLazyMode) {
      // in 1.12, calling completed matched ie behavior
      // simply call completed
      // completed;

      _delayedInit().then((_) async {
        if (_debugTransaction) {
          print('Delayed init triggered');
        }
        // Lazy trigger completed.
        try {
          await _completed;
        } catch (e) {
          if (_debugTransaction) {
            print(
                'Handle TransactionSembast constructor async completed error $e');
          }
        }
        if (_debugTransaction) {
          print('completed aborted: $_aborted');
        }
        _inactive = true;

        // Try a simple await to postpone the completed
        await Future<void>.value();
        // The only place to call it
        // ignore: deprecated_member_use_from_same_package
        _complete();
      });
    }
  }

  Future<void> get _completed async {
    try {
      if (_lazyExecution == null) {
        if (_debugTransaction) {
          print('no lazy executor $_debugId...');
        }
        _inactive = true;
      } else {
        if (_debugTransaction) {
          print('lazy executor created $_debugId...');
        }

        // Old and new code

        /*
      // Timing is super important here

      return _lazyExecution.then((_) {
        return _transactionCompleter.future.then((_) {
          return Future.wait(_futures).then((_) {
            return database;
          }).catchError((e, st) {
            // catch any errors
            // this is needed so that completed always complete
            // without error
            devPrint('_execute error $e');
          });
        });
      });
      */

        // Tricky part experimented on 2020-11-01 with success
        // with a sync completer
        await _lazyExecution!.then((_) async {
          try {
            await Future.wait(
                <Future>[_transactionCompleter.future, ..._futures]);
          } catch (e) {
            if (_debugTransaction) {
              print('Handling transaction error $e');
            }
            _endException = DatabaseException(e.toString());
          }
        });
      }
    } catch (e) {
      if (_debugTransaction) {
        print('Catch _completed exception $e');
      }
      rethrow;
    }
  }

  @override
  Future<Database> get completed async {
    /*
    if (_debugTransaction) {
      print('completed $_debugId...');
    }
    Future<Database> _completed() => this._completed.whenComplete(() {
          if (_debugTransaction) {
            print(
                'completed ${_completedCompleter.isCompleted}, aborted: $_aborted');
          }
          _inactive = true;
        });
    if (_isCompletedOrAborted) {
      _complete();
      return _completedCompleter.future;
    }
    // postpone to next 2 cycles to allow enqueing
    // actions after completed has been called
    //if (_transactionLazyMode) {
    await Future<void>.value();
    await _completed();

     */
    // postpone to next cycle to allow enqueing
    await Future<void>.value();
    try {
      await _completed;
    } catch (_) {}
    return _completedCompleter.future;
  }

//    sdbTransaction == null ? new Future.value(database) : sdbTransaction.completed.then((_) {
//    // delay the completed event
//
//  });

  @override
  ObjectStore objectStore(String name) {
    meta!.checkObjectStore(name);
    return ObjectStoreSembast(this, database.meta.getObjectStore(name));
  }

  @override
  void abort() {
    if (_debugTransaction) {
      print('abort');
    }
    _aborted = true;
    _endException = newAbortException();
  }

//  @override
//  String toString() {
//    return
//  }
}
