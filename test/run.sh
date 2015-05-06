#/bin/sh

_DIR=$(dirname $BASH_SOURCE)

#dart ${_DIR}/test_runner_all_io_test.dart
pub run test -j 1 -r expanded
