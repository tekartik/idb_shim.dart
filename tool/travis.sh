#!/bin/bash

# Fast fail the script on failures.
set -e

dartanalyzer --fatal-warnings \
  lib/idb.dart \
  lib/idb_browser.dart \
  lib/idb_client.dart \
  lib/idb_client_memory.dart \
  lib/idb_client_native.dart \
  lib/idb_client_sembast.dart \
  lib/idb_client_websql.dart \
  lib/idb_console.dart \
  lib/idb_io.dart \

pub run test -p vm
# pub run test -p content-shell -j 1
# pub run test -p firefox -j 1