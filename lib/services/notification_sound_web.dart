import 'dart:js_interop';

@JS('playNotificationSound')
external void _playNotificationSound(String sound);

void playNotificationSound([String sound = 'notification']) {
  _playNotificationSound(sound);
}
