// set to true to debug transaction life cycle
// ignore_for_file: public_member_api_docs

import 'package:idb_shim/idb.dart';
import 'package:idb_shim/src/common/common_exception.dart';
import 'package:idb_shim/src/common/common_meta.dart';
import 'package:idb_shim/src/common/common_transaction.dart';
import 'package:idb_shim/src/sembast/sembast_database.dart';
import 'package:idb_shim/src/sembast/sembast_object_store.dart';
import 'package:idb_shim/src/utils/core_imports.dart';
import 'package:sembast/sembast.dart' as sembast;

// bool _debugTransaction = devWarning(true);
bool _debugTransaction = false;

typedef Action<T> = FutureOr<T> Function();

class _TransactionAction<T> {
  final Action<T> action;
  final completer = Completer<T>();
  final bool doNotAbortOnError;

  _TransactionAction(this.action, {required this.doNotAbortOnError});
}

Future<void> _delayedInit() async {
  await Future<void>.delayed(Duration.zero);
}

/// Lazey completer only created when needed (when completed is called)
class _LazyCompleter<T> {
  var _completed = false;
  Object? _completedError;
  T? _completedValue;
  Completer<T>? _completer;

  Future<T> get future {
    if (_completed) {
      if (_completedError != null) {
        return Future<T>.error(_completedError!);
      } else {
        return Future<T>.value(_completedValue);
      }
    }
    _completer ??= Completer<T>();
    return _completer!.future;
  }

  void complete([T? value]) {
    if (!_completed) {
      _completed = true;
      _completedValue = value;
      var completer = _completer;
      if (completer != null && !completer.isCompleted) {
        completer.complete(value);
      }
    }
  }

  void completeError(Object error, [StackTrace? stackTrace]) {
    if (!_completed) {
      _completed = true;
      _completedError = error;
      var completer = _completer;
      if (completer != null && !completer.isCompleted) {
        _completer!.completeError(error, stackTrace);
      }
    }
  }

  bool get isCompleted => _completer?.isCompleted ?? false;
}

/// Transaction wrapper around a sembast transaction.
class TransactionSembast extends IdbTransactionBase
    with TransactionWithMetaMixin {
  @override
  DatabaseSembast get database => super.database as DatabaseSembast;

  /// Sembast database.
  sembast.Database get sembastDatabase => database.db!;

  /// Sembast transaction.
  sembast.Transaction? sembastTransaction;

  static int _debugAllIds = 0;
  int? _debugId;

  var _aborted = false;

  final _completerCompleter = _LazyCompleter<Database>();

  void _complete() {
    _completerCompleter.complete(database);
    return;
  }

  void _completeError(Object e, [StackTrace? st]) {
    _completerCompleter.completeError(e, st);
  }

  void _log(String message) {
    idbLog('txn $_debugId: $message');
  }

  final _txnActions = <_TransactionAction>[];

  /// Only create when action is added
  Future? _sembastTransaction;

  /// Transaction is active until the sembast transaction is running
  var _inactive = false;

  Object _newAbortException() => newAbortException();
  Object _newDatabaseInactiveError() =>
      DatabaseError('DatabaseInactiveError: transaction database closed');

  ///
  /// Create or execute the transaction.
  ///
  /// leaving a time to breath
  /// Since it must run everything in a single call, let all the actions
  /// in the first callback enqueue before running
  ///
  Future<T> execute<T>(
    FutureOr<T> Function() action, {
    bool? doNotAbordOnError,
  }) {
    try {
      if (_aborted) {
        throw _newAbortException();
      }
      if (_inactive) {
        throw _newDatabaseInactiveError();
      }
      var txnAction = _TransactionAction(
        action,
        doNotAbortOnError: doNotAbordOnError ?? false,
      );

      _txnActions.add(txnAction);
      return txnAction.completer.future;
    } finally {
      _sembastTransaction ??= () async {
        try {
          await sembastDatabase.transaction((txn) async {
            try {
              // assign right away as this is tested
              sembastTransaction = txn;
              while (true) {
                var actions = List.of(_txnActions);
                _txnActions.clear();
                for (var txnAction in actions) {
                  if (_aborted) {
                    if (_debugTransaction) {
                      _log('aborting action exception');
                    }

                    txnAction.completer.completeError(_newAbortException());
                  }
                  try {
                    dynamic result = txnAction.action();
                    if (result is Future) {
                      result = await result;
                    }
                    if (_debugTransaction) {
                      _log('done new action');
                    }
                    txnAction.completer.complete(result);
                  } catch (e, st) {
                    if (_debugTransaction) {
                      _log(
                        'err new action $e ${txnAction.doNotAbortOnError ? 'no abort' : 'abort'}',
                      );
                    }
                    txnAction.completer.completeError(e, st);

                    /// Abort on first error
                    if (!txnAction.doNotAbortOnError) {
                      abort();
                    }
                  }
                }

                if (_txnActions.isEmpty) {
                  if (_debugTransaction) {
                    _log('no action 1 left');
                  }

                  await _delayedInit();
                  if (_txnActions.isEmpty) {
                    if (_debugTransaction) {
                      _log('no action 2 left, exiting');
                    }
                    break;
                  }
                }
              }

              /// Clear remainging actions
              if (_aborted) {
                if (_debugTransaction) {
                  _log('throwing abort exception at end');
                }
                throw _newAbortException();
              }
            } catch (e) {
              // Errors are handled per action
              if (_debugTransaction) {
                _log('inner transaction error $e');
              }
              rethrow;
            } finally {
              /// Marked as inactive, no more action accepted
              _inactive = true;

              /// Complete remaining actions with abort error
              var actions = List.of(_txnActions);
              _txnActions.clear();
              for (var txnAction in actions) {
                txnAction.completer.completeError(_newAbortException());
              }
            }
          });
          _complete();
        } catch (e) {
          /// Important to catch outer transaction errors so that the future
          /// does not complete with an error
          /// print('outer transaction error $e');
          _completeError(e);
        }
      }();
    }
  }

  @override
  final IdbTransactionMeta? meta;

  ///
  /// Constructor.
  TransactionSembast(DatabaseSembast super.database, this.meta) {
    if (_debugTransaction) {
      _debugId = ++_debugAllIds;
    }
    () async {
      if (_debugTransaction) {
        _log('sembast new transaction constructor');
      }
      if (_completerCompleter.isCompleted) {
        return;
      }
      await _delayedInit();
      if (_completerCompleter.isCompleted) {
        return;
      }
      if (_sembastTransaction == null) {
        if (_debugTransaction) {
          _log('still no action?');
        }
        await _delayedInit();
        if (_completerCompleter.isCompleted) {
          return;
        }
        if (_debugTransaction) {
          _log('Not started, exiting');
        }
        _inactive = true;
        _complete();
      }
    }();
  }

  @override
  Future<Database> get completed async {
    if (_aborted) {
      throw _newAbortException();
    }
    return _completerCompleter.future;
  }

  @override
  ObjectStore objectStore(String name) {
    meta!.checkObjectStore(name);
    return ObjectStoreSembast(this, database.meta.getObjectStore(name));
  }

  @override
  void abort() {
    if (_debugTransaction) {
      _log('abort');
    }
    if (!_inactive) {
      _aborted = true;
    }
  }
}
