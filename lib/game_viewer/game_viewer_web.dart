import 'package:flutter/material.dart';
import 'dart:ui_web' as ui_web;
import 'package:web/web.dart' as web;
import 'game_viewer.dart';

class WebGameViewer extends GameViewer {
  const WebGameViewer({super.key, required super.url, required super.title}) : super.internal();

  @override
  Widget build(BuildContext context) {
    // Generate a unique ID for this specific URL/Game
    final String viewId = 'game-view-${title.hashCode}';
    
    _registerFactory(viewId, url);

    return Stack(
      children: [
        const Center(
          child: CircularProgressIndicator(color: Color(0xFFFF5C00)),
        ),
        HtmlElementView(
          key: ValueKey(viewId),
          viewType: viewId,
        ),
      ],
    );
  }

  static final Set<String> _registeredIds = {};

  void _registerFactory(String viewId, String gameUrl) {
    if (!_registeredIds.contains(viewId)) {
      ui_web.platformViewRegistry.registerViewFactory(viewId, (int viewId) {
        final web.HTMLIFrameElement iframe = web.HTMLIFrameElement()
          ..src = gameUrl
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          ..allow = 'autoplay; fullscreen'
          // Standard attributes to help with embedding
          ..setAttribute('allowfullscreen', 'true')
          ..setAttribute('scrolling', 'no');
        return iframe;
      });
      _registeredIds.add(viewId);
    }
  }
}

GameViewer getGameViewer({required String url, required String title}) => WebGameViewer(url: url, title: title);
