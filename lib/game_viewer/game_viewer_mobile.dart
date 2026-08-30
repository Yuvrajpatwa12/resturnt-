import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'game_viewer.dart';

class MobileGameViewer extends GameViewer {
  const MobileGameViewer({super.key, required super.url, required super.title}) : super.internal();

  @override
  Widget build(BuildContext context) {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(url));
    return WebViewWidget(controller: controller);
  }
}

GameViewer getGameViewer({required String url, required String title}) => MobileGameViewer(url: url, title: title);
