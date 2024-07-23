// ignore_for_file: public_member_api_docs

import 'package:idb_shim/idb_client.dart';
import 'package:idb_shim/src/utils/unimplemented_stub.dart';

/// The native factory
IdbFactory get idbFactoryNative => idbUnimplementedStub('idbFactoryNative');

/// The web factory
IdbFactory get idbFactoryWeb => idbUnimplementedStub('idbFactoryWeb');

bool get idbFactoryNativeSupported =>
    idbUnimplementedStub('idbFactoryNativeSupported');

bool get idbFactoryWebSupported =>
    idbUnimplementedStub('idbFactoryWebSupported');

IdbFactory idbFactoryFromIndexedDB(dynamic nativeIdbFactory) =>
    idbUnimplementedStub('idbFactoryFromIndexedDB');
