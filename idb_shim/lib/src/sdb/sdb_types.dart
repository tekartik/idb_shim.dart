/// Internal model types for Simple DB.
library;

import 'package:idb_shim/src/native_value.dart';
import 'package:sembast/blob.dart';
export 'sdb_timestamp.dart';

//typedef V = Map<String, Object?>;
//typedef K = int;

/// Value type.

/// Index type.
typedef SdbIndexKey = Object;

/// Model class.
typedef SdbModel = Map<String, Object?>;

/// Key type
typedef SdbKey = Object;

/// Value type
typedef SdbValue = Object;

/// Blob
typedef SdbBlob = Blob;

/// Browser object stored as is (`FileSystemHandle`, JS `Blob`...), only
/// supported by the native (browser) and memory factories, see
/// [IdbNativeValue].
typedef SdbNativeValue = IdbNativeValue;
