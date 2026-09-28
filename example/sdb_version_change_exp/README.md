# sdb_version_change_exp

Several apps (frames or tabs of one origin) opening the same SDB database at
different versions: what `closeOnVersionChange`, `onVersionChangeRequest` and
`onBlocked` of `SdbOpenDatabaseOptions` do.

`index.html` runs the app twice, in two iframes (A and B); `app.html?app=C`
opens it in a tab. Each app has buttons to open the database at version 1, 2
or 3, add a record, close it and delete it, and two options read when
opening: what to do on a version change (`SdbVersionChangeAction`: close,
none, close and reload, close, alert and reload) and when blocked
(`SdbBlockedAction`: alert, none with a banner from the callback).

- Open version 1 in A, then version 2 in B: A gets the version change
  request, closes itself (`close`) and B opens at once.
- Set A to `none`, open version 2 there (the same version, nothing happens),
  then version 3 in B: B is blocked, the default alert says to close the
  other tab, until Close is pressed in A, then its open completes on its own.
- Set A to `closeAndReload` and open version 3 in B: A reloads and notes why.
- Delete the database in one app: the other closes too (a request with no
  new version). Also the way to start over from version 1: a version lower
  than the database's cannot be opened (`VersionError`).

Run it:

```sh
dart run tool/build_and_serve_web.dart
```

then open http://localhost:8080.
