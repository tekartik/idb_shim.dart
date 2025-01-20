# Usage in flutter

While idb_shim over sembast is a solution on Flutter, The recommend implementation is [idb_sqflite](https://pub.dev/packages/idb_sqflite) 
based on sqflite for mobile (iOS, MacOS and Android) or desktop and dart VM using [sqflite_ffi_common](https://pub.dev/packages/sqflite_common_ffi).

Choosing an implementation is mainly finding the best `IdbFactory` for the platform.

Here is a basic example to target both web and mobile

In `pubspec.yaml`:
```yaml
dependencies:
  idb_shim: any
  idb_sqflite: any
```

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:idb_sqflite/idb_sqflite.dart';

late IdbFactory idbFactory;

/// Initialization example for flutter
///
/// It uses indexed_db on the web and sqflite on other platforms
void initIdbFactory() {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    idbFactory = idbFactoryWeb;
  } else {
    idbFactory = idbFactorySqflite;
  }
}
```