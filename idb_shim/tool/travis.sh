#!/bin/bash

# Fast fail the script on failures.
set -xe

# dartanalyzer --fatal-warnings .
dartanalyzer .

pub run test -p vm -j 1
# pub run test -p chrome -j 1 test/test_runner_compat_browser_test_.dart

# Temp commenting: failing on 2.3.1.-dev.0.0
# Maybe build_runner with vm_compiler should not be used along with web_compiler
# pub run build_runner test -- -p vm -j 1 test/multiplatform

pub run build_runner test -- -p chrome -j 1 test/test_runner_client_native_test.dart
pub run build_runner test -- -p chrome -j 1 test/multiplatform
pub run build_runner test -- -p chrome -j 1 test/test_runner_compat_browser_test.dart test/multiplatform
pub run test -p chrome -j 1 test/test_runner_compat_browser_test.dart
# pub run build_runner test -r -- -p chrome -j 1 test/test_runner_compat_browser_test.dart
# failing on 2.0.0-dev.66
# pub run test -p chrome test/test_runner_bug_test.dart
# pub run build_runner test -r -- -p chrome test/test_runner_bug_test.dart


# run in release (dart2js)
# pub run build_runner test -r -- -p chrome -j 1 test/test_runner_compat_browser_test.dart
# pub run test -p content-shell -j 1
# pub run test -p firefox -j 1

# test dartdevc support
pub run build_runner build example -o example:build/example_debug
pub run build_runner build -r example -o example:build/example_release