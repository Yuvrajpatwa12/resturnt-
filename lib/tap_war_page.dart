import 'package:flutter/material.dart';
import 'dart:async';
import 'cart_manager.dart';
import 'services/tenant_service.dart';
import 'services/api_service.dart';

class TapWarMultiplayerPage extends StatefulWidget {
  final int squadId;
  final String? startAt;
  final bool isBattleground;
  final int durationSeconds;

  const TapWarMultiplayerPage({
    super.key,
    required this.squadId,
    this.startAt,
    this.isBattleground = false,
    this.durationSeconds = 30,
  });

  @override
  State<TapWarMultiplayerPage> createState() => _TapWarMultiplayerPageState();
}

class _TapWarMultiplayerPageState extends State<TapWarMultiplayerPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  int _localTaps = 0;
  int _localTapDelta = 0;
  List<Map<String, dynamic>> _scores = [];
  Timer? _tickTimer;
  Timer? _endTimer;
  int _timeLeft = 30; // 30 seconds match duration
  bool _isStarted = false;
  bool _isGameOver = false;
  DateTime? _scheduledStartAt;
  DateTime? _scheduledEndAt;
  DateTime? _highestCountReachedAt;
  Map<String, dynamic>? _result;
  bool _isCalculatingResults = false;
  bool _finalSubmissionSent = false;
  bool _scoreSubmitFailed = false;

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
        _scheduledStartAt = startTime;
        _scheduledEndAt = startTime.add(
          Duration(seconds: widget.durationSeconds),
        );
        _timeLeft = _scheduledEndAt!.difference(DateTime.now()).inSeconds;
      } catch (_) {}
    }
    if (widget.isBattleground && _scheduledEndAt == null) {
      _scheduledStartAt = DateTime.now();
      _scheduledEndAt = _scheduledStartAt!.add(
        Duration(seconds: widget.durationSeconds),
      );
      _timeLeft = widget.durationSeconds;
    }
    if (widget.isBattleground) {
      final endDelay = _scheduledEndAt!.difference(DateTime.now());
      _endTimer = Timer(
        endDelay.isNegative ? Duration.zero : endDelay,
        _finishBattleground,
      );
    }

    _tickTimer = Timer.periodic(const Duration(seconds: 1), _onTick);
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _endTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _onTick(Timer timer) async {
    if (widget.isBattleground) {
      _tickBattleground();
      return;
    }
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

  void _tickBattleground() {
    if (_isGameOver || _scheduledStartAt == null || _scheduledEndAt == null) {
      return;
    }
    final now = DateTime.now();
    if (!now.isBefore(_scheduledEndAt!)) {
      _finishBattleground();
      return;
    }
    setState(() {
      _isStarted = !now.isBefore(_scheduledStartAt!);
      _timeLeft = _isStarted
          ? _scheduledEndAt!.difference(now).inSeconds
          : _scheduledStartAt!.difference(now).inSeconds +
                widget.durationSeconds;
    });
  }

  void _finishBattleground() {
    if (_isGameOver || !mounted) return;
    _tickTimer?.cancel();
    setState(() {
      _isStarted = true;
      _isGameOver = true;
      _timeLeft = 0;
      _isCalculatingResults = true;
    });
    _submitBattlegroundScore();
  }

  Future<void> _submitBattlegroundScore() async {
    if (_finalSubmissionSent) return;
    _finalSubmissionSent = true;
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) {
      if (mounted) {
        setState(() {
          _scoreSubmitFailed = true;
          _isCalculatingResults = false;
        });
      }
      return;
    }
    final submission = await ApiService.submitFinalScore(
      tenantId: tenant.id,
      squadId: widget.squadId,
      tapCount: _localTaps,
      reachedAtTimestamp: _highestCountReachedAt?.toIso8601String(),
    );
    if (submission == null || submission['status'] != 'success') {
      if (mounted) setState(() => _scoreSubmitFailed = true);
    }
    await _fetchBattlegroundResult();
  }

  Future<void> _fetchBattlegroundResult() async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return;
    for (var attempt = 0; attempt < 2; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(const Duration(seconds: 11));
      }
      if (!mounted) return;
      final state = await ApiService.getGameState(
        tenantId: tenant.id,
        squadId: widget.squadId,
      );
      if (state != null && state['status'] == 'success' && mounted) {
        final result = state['result'];
        setState(() {
          _scores = List<Map<String, dynamic>>.from(state['scores'] ?? []);
          if (result is Map) _result = Map<String, dynamic>.from(result);
          _isCalculatingResults = _result == null;
        });
        if (_result != null) return;
      }
    }
    if (mounted && _result == null) {
      setState(() {
        _isCalculatingResults = false;
        _scoreSubmitFailed = true;
      });
    }
  }

  void _handleTap() {
    final now = DateTime.now();
    if (widget.isBattleground) {
      if (_scheduledStartAt == null ||
          _scheduledEndAt == null ||
          now.isBefore(_scheduledStartAt!) ||
          !now.isBefore(_scheduledEndAt!)) {
        return;
      }
    } else if (!_isStarted || _isGameOver) {
      return;
    }
    setState(() {
      if (widget.isBattleground) _isStarted = true;
      _localTaps++;
      if (widget.isBattleground) {
        _highestCountReachedAt = now;
      } else {
        _localTapDelta++;
      }
    });
    _pulseController.forward().then((_) => _pulseController.reverse());
  }

  Widget _buildBattlegroundResult(String myId) {
    final resultType = _result?['result_type']?.toString();
    final winnerId = _result?['winner_user_id']?.toString();
    final drawIds = List<String>.from(
      (_result?['draw_user_ids'] as List? ?? []).map((id) => id.toString()),
    );
    Map<String, dynamic>? winner;
    Map<String, dynamic>? myScore;
    for (final score in _scores) {
      if (score['user_id']?.toString() == winnerId) winner = score;
      if (score['user_id']?.toString() == myId) myScore = score;
    }
    final isDisqualified =
        int.tryParse(myScore?['disqualified']?.toString() ?? '0') == 1;

    String title;
    if (isDisqualified) {
      title = 'Invalid score detected — disqualified from this match';
    } else if (resultType == 'winner') {
      title = winner == null
          ? 'Winner: ${winnerId ?? 'Unknown'}'
          : '${winner['user_name']} wins with ${winner['tap_count']} taps!';
    } else if (resultType == 'draw') {
      title = drawIds.contains(myId)
          ? 'It’s a draw!'
          : 'The match ended in a draw.';
    } else {
      title = 'No valid scores were submitted.';
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDisqualified ? Colors.red.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: isDisqualified ? Colors.red.shade800 : Colors.deepOrange,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          if (drawIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Draw: ${_scores.where((score) => drawIds.contains(score['user_id']?.toString())).map((score) => score['user_name']).join(', ')}',
                style: const TextStyle(color: Colors.black54),
              ),
            ),
        ],
      ),
    );
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
        title: Text(
          widget.isBattleground ? "Battleground 🔥" : "Multiplayer Tap War 🔥",
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
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
                    _isGameOver &&
                            widget.isBattleground &&
                            _isCalculatingResults
                        ? "CALCULATING RESULTS..."
                        : !_isStarted
                        ? "GET READY..."
                        : widget.isBattleground
                        ? "${(_timeLeft ~/ 60).toString().padLeft(2, '0')}:${(_timeLeft % 60).toString().padLeft(2, '0')}"
                        : "00:${(_timeLeft > 30 ? 30 : _timeLeft).toString().padLeft(2, '0')}",
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: !_isStarted
                          ? Colors.orange
                          : ((_timeLeft <= 5)
                                ? Colors.red
                                : const Color(0xFFFF5C00)),
                    ),
                  ),
                  Text(
                    _isGameOver &&
                            widget.isBattleground &&
                            _isCalculatingResults
                        ? "WAITING FOR THE SERVER"
                        : !_isStarted
                        ? "BATTLE STARTING SOON"
                        : _isGameOver
                        ? "MATCH FINISHED"
                        : "TAP AS FAST AS YOU CAN!",
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      color: Colors.grey,
                    ),
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
                          color: (!_isStarted || _isGameOver)
                              ? Colors.grey[300]
                              : const Color(0xFFFF5C00),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color:
                                  ((!_isStarted || _isGameOver)
                                          ? Colors.grey
                                          : const Color(0xFFFF5C00))
                                      .withValues(alpha: 0.4),
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
                                (!_isStarted || _isGameOver)
                                    ? Icons.timer_outlined
                                    : Icons.touch_app,
                                size: 60,
                                color: Colors.white,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                !_isStarted
                                    ? "WAIT"
                                    : (_isGameOver ? "TIME UP!" : "TAP!"),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "My Taps: $_localTaps",
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
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
                  Text(
                    widget.isBattleground
                        ? "FINAL BATTLEGROUND SCORES"
                        : "LIVE SQUAD LEADERBOARD",
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (widget.isBattleground &&
                      _isGameOver &&
                      _isCalculatingResults)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          "Calculating results...",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else if (widget.isBattleground && !_isGameOver)
                    const Center(
                      child: Text(
                        "Final scores appear when the match ends.",
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  else if (_scores.isEmpty)
                    Center(
                      child: Text(
                        _scoreSubmitFailed
                            ? "Could not submit or retrieve your final score."
                            : "Waiting for player scores...",
                        style: const TextStyle(color: Colors.grey),
                      ),
                    )
                  else
                    ..._scores.map((s) {
                      final bool isMe = s['user_id'] == myId;
                      final int score =
                          int.tryParse(s['tap_count']?.toString() ?? '0') ?? 0;
                      final double factor = (score / 300).clamp(0.05, 1.0);
                      final bool disqualified =
                          int.tryParse(s['disqualified']?.toString() ?? '0') ==
                          1;
                      final bool isDnf =
                          int.tryParse(s['is_dnf']?.toString() ?? '0') == 1;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 100,
                              child: Text(
                                '${s['user_name'] ?? 'Diner'}${disqualified
                                    ? ' · DISQUALIFIED'
                                    : isDnf
                                    ? ' · DNF'
                                    : ''}',
                                style: TextStyle(
                                  fontWeight: isMe
                                      ? FontWeight.w900
                                      : FontWeight.bold,
                                  fontSize: 13,
                                  color: disqualified
                                      ? Colors.red
                                      : isMe
                                      ? const Color(0xFFFF5C00)
                                      : Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Expanded(
                              child: Stack(
                                children: [
                                  Container(
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    height: 12,
                                    width:
                                        (MediaQuery.of(context).size.width -
                                            230) *
                                        factor,
                                    decoration: BoxDecoration(
                                      color: disqualified
                                          ? Colors.red
                                          : isMe
                                          ? const Color(0xFFFF5C00)
                                          : Colors.grey[400],
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 15),
                            Text(
                              isDnf ? 'DNF' : score.toString(),
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                color: disqualified
                                    ? Colors.red
                                    : isMe
                                    ? const Color(0xFFFF5C00)
                                    : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  if (widget.isBattleground && _result != null)
                    _buildBattlegroundResult(myId),
                  if (widget.isBattleground &&
                      _scoreSubmitFailed &&
                      _result == null)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Text(
                        "Your score could not be submitted. You may be marked DNF.",
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
