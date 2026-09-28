import 'package:web/web.dart' as web;

/// Show a message to the user (`window.alert`, blocking until dismissed).
void sdbWebAlert(String message) {
  web.window.alert(message);
}

/// Reload the page.
void sdbWebReload() {
  web.window.location.reload();
}
