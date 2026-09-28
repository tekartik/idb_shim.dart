# sdb_version_change_exp

Several apps (frames or tabs of one origin) opening the same SDB database at
different versions: what `closeOnVersionChange`, `onVersionChangeRequest` and
`onBlocked` of `SdbOpenDatabaseOptions` do.

`index.html` runs the app twice, in two iframes (A and B); `app.html?app=C`
opens it in a tab. Each app has buttons to open the database at version 1, 2
or 3, add a record, close it and delete it, and a "Close on version change"
option read when opening.

- Open version 1 in A, then version 2 in B: A gets the version change
  request, closes itself (`closeOnVersionChange`) and B opens at once.
- Untick the option in A, open version 2 there (the same version, nothing
  happens), then version 3 in B: B is blocked (`onBlocked`, a banner) until
  Close is pressed in A, then its open completes on its own.
- Delete the database in one app: the other closes too (a request with no
  new version). Also the way to start over from version 1: a version lower
  than the database's cannot be opened (`VersionError`).

Two more options, read when opening too: "On version change" (log only,
alert, or reload the page, the reloaded page notes why) and "When blocked"
(the banner, or an alert). Both alert and reload are deferred to after the
callback: the database closes itself when the callback returns, and an alert
inside it would keep the other app waiting while it shows.

Run it:

```sh
dart run tool/build_and_serve_web.dart
```

then open http://localhost:8080.
