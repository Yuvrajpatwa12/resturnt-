import 'package:flutter/material.dart';
import 'cart_manager.dart';
import 'game_viewer/game_viewer.dart';

class WebGamePage extends StatefulWidget {
  final String gameTitle;
  final String gameUrl;

  const WebGamePage({super.key, required this.gameTitle, required this.gameUrl});

  @override
  State<WebGamePage> createState() => _WebGamePageState();
}

class _WebGamePageState extends State<WebGamePage> {
  final Stopwatch _stopwatch = Stopwatch();

  @override
  void initState() {
    super.initState();
    _stopwatch.start();
  }

  @override
  void dispose() {
    _stopwatch.stop();
    ShopManager.instance.addGameTime(_stopwatch.elapsed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFF5C00),
        title: Text(widget.gameTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
      ),
      body: GameViewer(url: widget.gameUrl, title: widget.gameTitle),
    );
  }
}
