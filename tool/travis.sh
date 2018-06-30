#!/bin/bash

# Fast fail the script on failures.
set -xe

dartanalyzer --fatal-warnings .

pub run test -p vm -j 1
# pub run test -p chrome -j 1 test/test_runner_compat_browser_test_.dart
pub run build_runner test -- -p vm -j 1
pub run build_runner test -- -p chrome -j 1 test/test_runner_compat_browser_test.dart

# run in release (dart2js)
# pub run build_runner test -r -- -p chrome -j 1 test/test_runner_compat_browser_test.dart
# pub run test -p content-shell -j 1
# pub run test -p firefox -j 1

# test dartdevc support
pub run build_runner build example -o example:build/example_debug
pub run build_runner build -r example -o example:build/example_release