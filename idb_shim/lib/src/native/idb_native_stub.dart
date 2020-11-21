import 'package:idb_shim/idb_client.dart';
import 'package:idb_shim/src/utils/unimplemented_stub.dart';

/// The native factory
IdbFactory get idbFactoryNative => idbUnimplementedStub('idbFactoryNative');
bool get idbFactoryNativeSupported =>
    idbUnimplementedStub('idbFactoryNativeSupported');

IdbFactory idbFactoryFromIndexedDB(dynamic nativeIdbFactory) =>
    idbUnimplementedStub('idbFactoryFromIndexedDB');
