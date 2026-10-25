import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<void> registerPushServiceWorker() async {
  await web.window.navigator.serviceWorker
      .register('firebase-messaging-sw.js'.toJS)
      .toDart;
}
