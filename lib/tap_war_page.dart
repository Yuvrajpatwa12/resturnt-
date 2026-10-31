import 'package:flutter/material.dart';
import 'dart:async';
import 'cart_manager.dart';
import 'services/tenant_service.dart';
import 'services/api_service.dart';

class TapWarPage extends StatefulWidget {
  const TapWarPage({super.key});

  @override
  State<TapWarPage> createState() => _TapWarPageState();
}

class _TapWarPageState extends State<TapWarPage> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  final TextEditingController _nameController = TextEditingController();
  bool _dialogShown = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      lowerBound: 0.95,
      upperBound: 1.05,
    );

    // Listen to timer to show winner dialog
    ShopManager.instance.tapWarTimer.addListener(_onTimerChange);
  }

  void _onTimerChange() {
    if (ShopManager.instance.tapWarTimer.value == 0 && !_dialogShown) {
      final leaderboard = ShopManager.instance.tapLeaderboard.value;
      if (leaderboard.isNotEmpty && leaderboard.first['isUser'] == true) {
        _dialogShown = true;
        _showWinnerNameDialog();
      }
    }
  }

  @override
  void dispose() {
    ShopManager.instance.tapWarTimer.removeListener(_onTimerChange);
    _pulseController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _handleTap() {
    ShopManager.instance.recordTap();
    _pulseController.forward().then((_) => _pulseController.reverse());
    // Add haptic feedback simulation here if needed
  }

  void _showWinnerNameDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text("🏆 YOU WON!", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Enter your name to be featured on the Hall of Fame!", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: "Your Name",
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (_nameController.text.isNotEmpty) {
                  ShopManager.instance.updateTableName("Table 12", _nameController.text);
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5C00),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              child: const Text("SAVE MY VICTORY", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: () {
            ShopManager.instance.endTapWar();
            Navigator.pop(context);
          },
        ),
        title: const Text("Hall Battle: Tap War", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // --- 1. TIMER & STATUS ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              color: Colors.white,
              child: Column(
                children: [
                  ValueListenableBuilder<int>(
                    valueListenable: ShopManager.instance.tapWarTimer,
                    builder: (context, timeLeft, child) {
                      final isLowTime = timeLeft <= 5;
                      return Column(
                        children: [
                          Text(
                            "00:${timeLeft.toString().padLeft(2, '0')}",
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.w900,
                              color: isLowTime ? Colors.red : const Color(0xFFFF5C00),
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                          Text(
                            isLowTime ? "FINISH FAST!" : "KEEP TAPPING!",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              color: isLowTime ? Colors.red : Colors.grey,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(30.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // --- 2. MASSIVE TAP BUTTON ---
                  ValueListenableBuilder<int>(
                    valueListenable: ShopManager.instance.tapWarTimer,
                    builder: (context, timeLeft, child) {
                      final bool isGameOver = timeLeft <= 0;
                      return GestureDetector(
                        onTap: isGameOver ? null : _handleTap,
                        child: ScaleTransition(
                          scale: _pulseController,
                          child: Container(
                            width: 220,
                            height: 220,
                            decoration: BoxDecoration(
                              color: isGameOver ? Colors.grey[300] : const Color(0xFFFF5C00),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: (isGameOver ? Colors.grey : const Color(0xFFFF5C00)).withValues(alpha: 0.4),
                                  blurRadius: 30,
                                  spreadRadius: 10,
                                ),
                                if (!isGameOver)
                                  const BoxShadow(
                                    color: Colors.white,
                                    blurRadius: 2,
                                    spreadRadius: -10,
                                    offset: Offset(0, -5),
                                  ),
                              ],
                              border: Border.all(color: Colors.white, width: 8),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isGameOver ? Icons.timer_off : Icons.touch_app,
                                    size: 60,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    isGameOver ? "TIME UP!" : "TAP!",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // --- 3. LIVE LEADERBOARD ---
            Container(
              padding: const EdgeInsets.fromLTRB(24, 30, 24, 40),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "HALL LEADERBOARD",
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  ValueListenableBuilder<List<Map<String, dynamic>>>(
                    valueListenable: ShopManager.instance.tapLeaderboard,
                    builder: (context, leaderboard, child) {
                      final bool isGameOver = ShopManager.instance.tapWarTimer.value <= 0;
                      final winner = leaderboard.isNotEmpty ? leaderboard.first : null;

                      return Column(
                        children: [
                          if (isGameOver && winner != null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 24),
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFFD700), Color(0xFFFFA000)], // Gold Gradient
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.amber.withValues(alpha: 0.3),
                                    blurRadius: 15,
                                    offset: const Offset(0, 8),
                                  )
                                ],
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 40),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          "HALL CHAMPION! 🏆",
                                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1),
                                        ),
                                        Text(
                                          "${winner['table']} wins with ${winner['score']} taps!",
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ...leaderboard.asMap().entries.map((entry) {
                            final index = entry.key;
                            final item = entry.value;
                            final bool isUser = item['isUser'];
                            final bool isWinner = index == 0 && isGameOver;
                            final double scoreWidthFactor = (item['score'] / 300).clamp(0.05, 1.0);

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 80,
                                    child: Row(
                                      children: [
                                        if (isWinner) 
                                          const Icon(Icons.stars, color: Colors.amber, size: 14),
                                        if (isWinner) const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            item['table'],
                                            style: TextStyle(
                                              fontWeight: isUser || isWinner ? FontWeight.w900 : FontWeight.bold,
                                              fontSize: 13,
                                              color: isWinner ? Colors.amber[900] : (isUser ? const Color(0xFFFF5C00) : Colors.black87),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Stack(
                                      children: [
                                        Container(
                                          height: 12,
                                          decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(6)),
                                        ),
                                        AnimatedContainer(
                                          duration: const Duration(milliseconds: 300),
                                          height: 12,
                                          width: (MediaQuery.of(context).size.width - 210) * scoreWidthFactor,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: isWinner 
                                                ? [const Color(0xFFFFD700), const Color(0xFFFFA000)]
                                                : (isUser 
                                                    ? [const Color(0xFFFF8C00), const Color(0xFFFF5C00)]
                                                    : [Colors.grey[400]!, Colors.grey[300]!]),
                                            ),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 15),
                                  Text(
                                    item['score'].toString(),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                      color: isWinner ? Colors.amber[900] : (isUser ? const Color(0xFFFF5C00) : Colors.black54),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TapWarMultiplayerPage extends StatefulWidget {
  final int squadId;
  final String? startAt;

  const TapWarMultiplayerPage({
    super.key,
    required this.squadId,
    this.startAt,
  });

  @override
  State<TapWarMultiplayerPage> createState() => _TapWarMultiplayerPageState();
}

class _TapWarMultiplayerPageState extends State<TapWarMultiplayerPage> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  int _localTaps = 0;
  int _localTapDelta = 0;
  List<Map<String, dynamic>> _scores = [];
  Timer? _tickTimer;
  int _timeLeft = 30; // 30 seconds match duration
  bool _isStarted = false;
  bool _isGameOver = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      lowerBound: 0.95,
      upperBound: 1.05,
    );

    if (widget.startAt != null) {
      try {
        final startTime = DateTime.parse(widget.startAt!);
        final diff = startTime.difference(DateTime.now()).inSeconds;
        if (diff > 0) {
          _timeLeft = diff + 30;
        }
      } catch (_) {}
    }

    _tickTimer = Timer.periodic(const Duration(seconds: 1), _onTick);
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _onTick(Timer timer) async {
    if (_isGameOver) return;

    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return;
    final myId = ShopManager.instance.currentUserId;

    if (_localTapDelta > 0) {
      final deltaToSend = _localTapDelta;
      _localTapDelta = 0;
      final success = await ApiService.submitTapBatch(
        tenantId: tenant.id,
        userId: myId,
        squadId: widget.squadId,
        tapCountIncrement: deltaToSend,
      );
      if (!success) {
        _localTapDelta += deltaToSend;
      }
    }

    final gameState = await ApiService.getGameState(
      tenantId: tenant.id,
      squadId: widget.squadId,
    );

    if (gameState != null && gameState['status'] == 'success' && mounted) {
      setState(() {
        _scores = List<Map<String, dynamic>>.from(gameState['scores'] ?? []);
        final status = gameState['squad_status']?.toString().toLowerCase();
        if (status == 'completed' || _timeLeft <= 0) {
          _isGameOver = true;
        }
      });
    }

    setState(() {
      if (_timeLeft > 0) {
        _timeLeft--;
        if (_timeLeft <= 30) {
          _isStarted = true;
        }
      } else {
        _isGameOver = true;
        _tickTimer?.cancel();
      }
    });
  }

  void _handleTap() {
    if (!_isStarted || _isGameOver) return;
    setState(() {
      _localTaps++;
      _localTapDelta++;
    });
    _pulseController.forward().then((_) => _pulseController.reverse());
  }

  @override
  Widget build(BuildContext context) {
    final myId = ShopManager.instance.currentUserId;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Multiplayer Tap War 🔥", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              color: Colors.white,
              child: Column(
                children: [
                  Text(
                    !_isStarted ? "GET READY..." : "00:${(_timeLeft > 30 ? 30 : _timeLeft).toString().padLeft(2, '0')}",
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: !_isStarted ? Colors.orange : ((_timeLeft <= 5) ? Colors.red : const Color(0xFFFF5C00)),
                    ),
                  ),
                  Text(
                    !_isStarted ? "BATTLE STARTING SOON" : "TAP AS FAST AS YOU CAN!",
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(30.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _handleTap,
                    child: ScaleTransition(
                      scale: _pulseController,
                      child: Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          color: (!_isStarted || _isGameOver) ? Colors.grey[300] : const Color(0xFFFF5C00),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: ((!_isStarted || _isGameOver) ? Colors.grey : const Color(0xFFFF5C00)).withValues(alpha: 0.4),
                              blurRadius: 30,
                              spreadRadius: 10,
                            ),
                          ],
                          border: Border.all(color: Colors.white, width: 8),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                (!_isStarted || _isGameOver) ? Icons.timer_outlined : Icons.touch_app,
                                size: 60,
                                color: Colors.white,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                !_isStarted ? "WAIT" : (_isGameOver ? "TIME UP!" : "TAP!"),
                                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "My Taps: $_localTaps",
                                style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(24, 30, 24, 40),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("LIVE SQUAD LEADERBOARD", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.grey)),
                  const SizedBox(height: 20),
                  if (_scores.isEmpty)
                    const Center(child: Text("Waiting for player scores...", style: TextStyle(color: Colors.grey)))
                  else
                    ..._scores.asMap().entries.map((entry) {
                      final index = entry.key;
                      final s = entry.value;
                      final bool isMe = s['user_id'] == myId;
                      final int score = int.tryParse(s['tap_count']?.toString() ?? '0') ?? 0;
                      final double factor = (score / 300).clamp(0.05, 1.0);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 100,
                              child: Text(
                                s['user_name'] ?? 'Diner',
                                style: TextStyle(fontWeight: isMe ? FontWeight.w900 : FontWeight.bold, fontSize: 13, color: isMe ? const Color(0xFFFF5C00) : Colors.black87),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Expanded(
                              child: Stack(
                                children: [
                                  Container(height: 12, decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(6))),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    height: 12,
                                    width: (MediaQuery.of(context).size.width - 230) * factor,
                                    decoration: BoxDecoration(
                                      color: isMe ? const Color(0xFFFF5C00) : Colors.grey[400],
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 15),
                            Text(score.toString(), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: isMe ? const Color(0xFFFF5C00) : Colors.black54)),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

