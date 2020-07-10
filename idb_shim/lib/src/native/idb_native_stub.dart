import 'package:idb_shim/idb_client.dart';
import 'package:idb_shim/src/utils/unimplemented_stub.dart';

export 'package:idb_shim/src/native/native_compat.dart';

/// The native factory
IdbFactory get idbFactoryNative => idbUnimplementedStub('idbFactoryNative');
