import 'package:flutter/material.dart';
import 'dart:math';

class GamePage extends StatefulWidget {
  final bool isTeamMode;
  const GamePage({super.key, this.isTeamMode = false});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  int score = 0;
  int teamScore = 154; // Simulated team score
  double burgerTop = 150;
  double burgerLeft = 100;
  final Random random = Random();

  void moveBurger() {
    setState(() {
      score++;
      if (widget.isTeamMode) teamScore++;
      burgerTop = random.nextDouble() * 400 + 100;
      burgerLeft = random.nextDouble() * 250 + 20;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFF5C00),
        elevation: 0,
        title: Text(widget.isTeamMode ? "Team: Burger Catcher" : "Burger Catcher", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          Positioned(
            top: 20,
            left: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Your Score: $score",
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFFF5C00)),
                ),
                if (widget.isTeamMode)
                  Text(
                    "Team Total: $teamScore",
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                  ),
              ],
            ),
          ),
          Positioned(
            top: burgerTop,
            left: burgerLeft,
            child: GestureDetector(
              onTap: moveBurger,
              child: TweenAnimationBuilder(
                duration: const Duration(milliseconds: 200),
                tween: Tween<double>(begin: 1.0, end: 1.2),
                key: ValueKey(score),
                builder: (context, double scale, child) {
                  return Transform.scale(
                    scale: scale == 1.2 ? 1.0 : scale, // Simple pulse effect
                    child: const Icon(
                      Icons.lunch_dining,
                      size: 100,
                      color: Colors.orange,
                    ),
                  );
                },
              ),
            ),
          ),
          const Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.all(40.0),
              child: Text(
                "Tap the burger as fast as you can!",
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
