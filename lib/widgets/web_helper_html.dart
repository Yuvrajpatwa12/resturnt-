import 'package:web/web.dart' as web;

bool isIosBrowser() {
  try {
    final ua = web.window.navigator.userAgent.toLowerCase();
    return ua.contains('iphone') || ua.contains('ipad') || ua.contains('ipod');
  } catch (e) {
    return false;
  }
}

bool isPwaStandalone() {
  try {
    final nav = web.window.navigator;
    // Check iOS standalone property or display-mode: standalone
    final standalone = (nav as dynamic).standalone == true;
    final matchMedia = web.window.matchMedia('(display-mode: standalone)').matches;
    return standalone || matchMedia;
  } catch (e) {
    return false;
  }
}
