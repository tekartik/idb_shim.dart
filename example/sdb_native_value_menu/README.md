# sdb_native_value_menu

Browser objects stored as is in an sdb database (`sdbFactoryWeb`) by wrapping
them in an `SdbNativeValue`, alone or inside a model:

- a `Blob` and a `File`,
- a non extractable `CryptoKey` (AES-GCM) with a text encrypted with it, that
  can still be decrypted after a reload,
- `FileSystemFileHandle` and `FileSystemDirectoryHandle` objects of the OPFS
  (every browser) or picked by the user (Chromium-only pickers),
- a model mixing plain values, an `SdbTimestamp` and native values.

`read all` reads them back, also after a reload. Picked handles lose their
permission after a reload in Chromium: `query permission of the handles`
shows `prompt`, `request read permission of the handles` asks again (a user
gesture is needed). Firefox and Safari have no permission API (OPFS handles
only, always accessible). The memory factory (`newSdbFactoryMemory()`)
rejects native values.

Run it:

```sh
dart run tool/build_and_serve_web.dart
```

then open http://localhost:8080.
