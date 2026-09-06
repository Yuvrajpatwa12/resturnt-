import 'dart:async';
import 'package:flutter/material.dart';
import 'cart_manager.dart';

class MusicPollWidget extends StatefulWidget {
  final Map<String, dynamic> pollData;
  const MusicPollWidget({super.key, required this.pollData});

  @override
  State<MusicPollWidget> createState() => _MusicPollWidgetState();
}

class _MusicPollWidgetState extends State<MusicPollWidget> {
  late Timer _timer;
  Duration _timeLeft = Duration.zero;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      final end = widget.pollData['endTime'] as DateTime;
      if (now.isAfter(end)) {
        timer.cancel();
        setState(() => _timeLeft = Duration.zero);
      } else {
        setState(() => _timeLeft = end.difference(now));
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final options = widget.pollData['options'] as List<dynamic>;
    final totalVotes = widget.pollData['totalVotes'] as int;
    final userVotedIndex = widget.pollData['userVotedIndex'] as int;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "LIVE COMMUNITY POLL",
                    style: TextStyle(
                      color: Color(0xFFFF5C00),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.pollData['title'],
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              _buildTimerDisplay(),
            ],
          ),
          const SizedBox(height: 24),
          ...List.generate(options.length, (index) {
            final option = options[index];
            final bool isVoted = userVotedIndex == index;
            final double percentage = totalVotes == 0 ? 0 : (option['votes'] / totalVotes);

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: GestureDetector(
                onTap: userVotedIndex == -1 ? () => ShopManager.instance.castPollVote(index) : null,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isVoted ? const Color(0xFFFF5C00).withValues(alpha: 0.03) : Colors.grey[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isVoted ? const Color(0xFFFF5C00).withValues(alpha: 0.3) : Colors.grey[200]!,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(option['image'], width: 32, height: 32, fit: BoxFit.cover),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                option['title'],
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontWeight: isVoted ? FontWeight.bold : FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            "${(percentage * 100).toStringAsFixed(0)}%",
                            style: TextStyle(
                              color: isVoted ? const Color(0xFFFF5C00) : Colors.grey[600],
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Stack(
                        children: [
                          Container(
                            height: 6,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 800),
                            curve: Curves.easeOutCubic,
                            height: 6,
                            width: (MediaQuery.of(context).size.width - 96) * percentage, // Account for padding
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFFAB40), Color(0xFFFF5C00)],
                              ),
                              borderRadius: BorderRadius.circular(3),
                              boxShadow: [
                                if (isVoted)
                                  BoxShadow(
                                    color: const Color(0xFFFF5C00).withValues(alpha: 0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  )
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          if (userVotedIndex != -1)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Center(
                child: Text(
                  "Thanks for voting! Waiting for others...",
                  style: TextStyle(color: Colors.grey, fontSize: 10, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimerDisplay() {
    final minutes = _timeLeft.inMinutes;
    final seconds = _timeLeft.inSeconds % 60;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFF5C00),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF5C00).withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            "${minutes.toString().padLeft(1, '0')}:${seconds.toString().padLeft(2, '0')}",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
