part of idb_shim_sembast;

// set to true to debug transaction life cycle
bool _debugTransaction = false;

// _lazyMode is what indexeddb on chrome supports
// supporting wait between calls
// default is false to matche ie/safari strict behavior
bool _transactionLazyMode = false;

class _SdbTransaction extends Transaction with TransactionWithMetaMixin {
  _SdbDatabase get database => super.database as _SdbDatabase;
  sdb.Database get sdbDatabase => database.db;

  static int debugAllIds = 0;
  int _debugId;

  int index = 0;
  bool _inactive = false;

  _execute(i) {
    if (_debugTransaction) {
      print("exec $i");
    }
    Completer completer = completers[i];
    Function action = actions[i];
    return new Future.sync(action).then((result) {
      if (_debugTransaction) {
        print("done $i");
      }
      completer.complete(result);
    }).catchError((e) {
      //devPrint(" err $i");
      if (_debugTransaction) {
        print("err $i");
      }
      completer.completeError(e);
    });
  }

  _next() {
    //print('_next? ${index}/${actions.length}');
    if (index < actions.length) {
      // Always try more
      return _execute(index++).then((_) {
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

      _checkNextAction() {
        //return new Future.value().then((_) {
        if (index < actions.length) {
          return _next();
        }
        if (_debugTransaction) {
          print('transaction done');
        }
        _inactive = true;
      }

      if (_transactionLazyMode) {
        return new Future.delayed(new Duration(), _checkNextAction);
      } else {
        //return new Future.sync(new Duration(), _checkNextAction);
        return _checkNextAction();
      }
    }
  }

  // Lazy execution of the first action
  Future lazyExecution;

  //
  // Create or execute the transaction
  // leaving a time to breath
  // Since it must run everything in a single call, let all the actions
  // in the first callback enqueue before running
  //
  Future execute(action()) {
    Future actionFuture = _enqueue(action);
    futures.add(actionFuture);

    if (lazyExecution == null) {
      // Short lifecycle experiment

      //lazyExecution = new Future.delayed(new Duration(), () {

      _sdbAction() {
        //assert(sdbDatabase.transaction == null);

        // No return value here
        return sdbDatabase.inTransaction(() {
          // assign right away as this is tested
          // sdbTransaction = sdbDatabase.currentTransaction;

          return _next();

//
//          _checkNext() {
//            _next();
//            if (index < actions.length) {
//              return new Future.sync(_next());
//            }
//
//                return finalResult;
//
//              }();
//                    }
//
//          return _checkNext();
        }).whenComplete(() {
          transactionCompleter.complete();
        }).catchError((e) {
          transactionCompleter.completeError(e);
        });
      }
      //lazyExecution = new Future.sync(() {
      // don't return the result here

      if (_transactionLazyMode) {
        // old lazy mode
        lazyExecution = new Future.microtask(_sdbAction);
      } else {
        lazyExecution = new Future.sync(_sdbAction);
      }

      //return lazyExecution;
    }

    return actionFuture;
  }

  _enqueue(action()) {
    if (_debugTransaction) {
      print('enqueing');
    }
    if (_inactive) {
      return new Future.error(new DatabaseError("TransactionInactiveError"));
    }
// not lazy
    Completer completer = new Completer.sync();
    completers.add(completer);
    actions.add(action);
    //devPrint("push ${actions.length}");
    //_next();
    return completer.future.then((result) {
      // re-push termination check
      //print(result);
      return result;
    });
  }

  //sdb.Transaction sdbTransaction;
  var transactionCompleter = new Completer();
  List<Completer> completers = [];
  List<Function> actions = [];
  List<Future> futures = [];

  final IdbTransactionMeta meta;
  _SdbTransaction(_SdbDatabase database, this.meta) : super(database) {
    if (_debugTransaction) {
      _debugId = ++debugAllIds;
    }

    // Trigger a timer to close the transaction if nothing happens
    if (!_transactionLazyMode) {
      // in 1.12, calling completed matched ie behavior
      // simply call completed
      // completed;

      new Future.delayed(new Duration(), () {
        completed;
      });
    }
  }

  Future<Database> get _completed {
    if (lazyExecution == null) {
      if (_debugTransaction) {
        print('no lazy executor $_debugId...');
      }
      _inactive = true;
      return new Future.value(database);
    } else {
      if (_debugTransaction) {
        print('lazy executor created $_debugId...');
      }
    }
    return lazyExecution.then((_) {
      return transactionCompleter.future.then((_) {
        return Future.wait(futures).then((_) {
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
    return new Future.value().then((_) => _completed());
  }

//    sdbTransaction == null ? new Future.value(database) : sdbTransaction.completed.then((_) {
//    // delay the completed event
//
//  });

  @override
  ObjectStore objectStore(String name) {
    meta.checkObjectStore(name);
    return new _SdbObjectStore(this, database.meta.getObjectStore(name));
  }

//  @override
//  String toString() {
//    return
//  }
}
