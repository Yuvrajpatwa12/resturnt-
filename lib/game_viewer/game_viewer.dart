import 'package:flutter/material.dart';
import 'game_viewer_stub.dart'
    if (dart.library.io) 'game_viewer_mobile.dart'
    if (dart.library.html) 'game_viewer_web.dart';

abstract class GameViewer extends StatelessWidget {
  final String url;
  final String title;
  const GameViewer.internal({super.key, required this.url, required this.title});

  factory GameViewer({required String url, required String title}) => getGameViewer(url: url, title: title);
}
