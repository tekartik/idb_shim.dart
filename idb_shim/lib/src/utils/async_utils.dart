import 'dart:async';

FutureOr<(T1, T2)> _run2StepsSequentially<T1, T2>(
  FutureOr<T1> Function() step1,
  FutureOr<T2> Function() step2,
) {
  var result1 = step1();

  FutureOr<(T1, T2)> handleStep2(T1 value1) {
    (T1, T2) withStep2Value(T2 value2) {
      return (value1, value2);
    }

    var rawResult2 = step2();
    if (rawResult2 is Future) {
      var future2 = rawResult2 as Future;
      return future2.then((rawValue2) {
        var value2 = rawValue2 as T2;
        return withStep2Value(value2);
      });
    } else {
      return withStep2Value(rawResult2);
    }
  }

  if (result1 is Future) {
    var future1 = result1 as Future;
    return future1.then((rawValue1) {
      var value1 = rawValue1 as T1;
      return handleStep2(value1);
    });
  } else {
    var value1 = result1;
    return handleStep2(value1);
  }
}

/// Run a list of steps sequentially.
FutureOr<List<T>> _run1StepSequentially<T>(FutureOr<T> Function() step) {
  var result = step();
  if (result is Future) {
    var future = result as Future;
    return future.then((rawValue) {
      var value = rawValue as T;
      return <T>[value];
    });
  } else {
    var value = result;
    return <T>[value];
  }
}

/// Run a list of steps sequentially.
FutureOr<List<T>> runSequentially<T>(Iterable<FutureOr<T> Function()> steps) {
  var first = steps.firstOrNull;
  if (first == null) {
    return <T>[];
  }

  var nextSteps = steps.skip(1);
  if (nextSteps.isEmpty) {
    return _run1StepSequentially(first);
  }
  var result = _run2StepsSequentially(first, () => runSequentially(nextSteps));
  if (result is Future) {
    var future = result as Future;
    return future.then((rawValue) {
      var value = rawValue as (T, List<T>);
      return <T>[value.$1, ...value.$2];
    });
  } else {
    var value = result;
    return <T>[value.$1, ...value.$2];
  }
}
