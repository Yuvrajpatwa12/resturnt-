import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'cart_manager.dart';
import 'services/tenant_service.dart';
import 'services/api_service.dart';

class VoiceOrderPage extends StatefulWidget {
  const VoiceOrderPage({super.key});

  @override
  State<VoiceOrderPage> createState() => _VoiceOrderPageState();
}

class _VoiceOrderPageState extends State<VoiceOrderPage> with TickerProviderStateMixin {
  late AnimationController _orbAnimationController;
  late AnimationController _rippleAnimationController;
  late stt.SpeechToText _speech;

  bool _isSpeechAvailable = false;
  bool _isListening = false;
  bool _isSending = false;
  bool _isSent = false;
  String _transcript = "";

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initSpeech();

    _orbAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    _rippleAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
  }

  void _initSpeech() async {
    try {
      _isSpeechAvailable = await _speech.initialize(
        onStatus: (status) {
          if ((status == 'done' || status == 'notListening') && _isListening) {
            _stopListeningAndSend();
          }
        },
        onError: (error) {
          debugPrint("Speech Error: $error");
        },
      );
    } catch (e) {
      debugPrint("Speech init exception: $e");
    }
  }

  @override
  void dispose() {
    _orbAnimationController.dispose();
    _rippleAnimationController.dispose();
    _speech.stop();
    super.dispose();
  }

  void _toggleListening() {
    if (_isSending) return;
    if (_isListening) {
      _stopListeningAndSend();
    } else {
      _startListening();
    }
  }

  void _startListening() async {
    setState(() {
      _isListening = true;
      _transcript = "";
      _isSent = false;
    });

    _orbAnimationController.repeat(reverse: true);
    _rippleAnimationController.repeat();

    if (!_isSpeechAvailable) {
      try {
        _isSpeechAvailable = await _speech.initialize(
          onStatus: (status) {
            if ((status == 'done' || status == 'notListening') && _isListening) {
              _stopListeningAndSend();
            }
          },
          onError: (error) {
            debugPrint("Speech Error: $error");
          },
        );
      } catch (e) {
        debugPrint("Speech init error: $e");
      }
    }

    if (_isSpeechAvailable) {
      await _speech.listen(
        onResult: (result) {
          if (mounted) {
            setState(() {
              _transcript = result.recognizedWords;
            });
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 5),
        partialResults: true,
      );
    }
  }

  void _stopListeningAndSend() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
    setState(() {
      _isListening = false;
    });

    _orbAnimationController.stop();
    _rippleAnimationController.stop();

    if (_transcript.trim().isNotEmpty) {
      _sendVoiceOrderToWaiter();
    }
  }

  Future<void> _sendVoiceOrderToWaiter() async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null || _transcript.trim().isEmpty) return;

    setState(() => _isSending = true);

    final int tableNum = ShopManager.instance.selectedTableId.value ?? 1;
    final String name = ShopManager.instance.customerName.value.isNotEmpty
        ? ShopManager.instance.customerName.value
        : "Guest Diner";

    final res = await ApiService.uploadVoiceOrder(
      tenantId: tenant.id,
      tableNumber: tableNum,
      customerName: name,
      transcript: _transcript,
    );

    setState(() {
      _isSending = false;
      _isSent = true;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 12),
              Text("Voice Order sent to Waiter Pro!"),
            ],
          ),
          backgroundColor: const Color(0xFF4C6FFF),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEDF2FD),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF7FAFF),
              Color(0xFFE8EFFD),
              Color(0xFFDDE6F9),
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        // --- 1. TOP HEADER ---
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                icon: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.arrow_back, color: Color(0xFF2C3E50), size: 20),
                                ),
                                onPressed: () => Navigator.pop(context),
                              ),
                              const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "Chat with ",
                                    style: TextStyle(
                                      color: Color(0xFF2E3A59),
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    "Eato",
                                    style: TextStyle(
                                      color: Color(0xFF4C70FF),
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 48), // Spacer for symmetry
                            ],
                          ),
                        ),

                        const Spacer(),

                        // --- 2. CENTER 3D IRIDESCENT ORB ---
                        AnimatedBuilder(
                          animation: _orbAnimationController,
                          builder: (context, child) {
                            final double floatOffset = _isListening
                                ? math.sin(_orbAnimationController.value * math.pi * 2) * 8.0
                                : 0.0;
                            return Transform.translate(
                              offset: Offset(0, floatOffset),
                              child: Container(
                                width: 180,
                                height: 180,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF6B8AFF).withValues(alpha: _isListening ? 0.4 : 0.15),
                                      blurRadius: _isListening ? 40 : 20,
                                      spreadRadius: _isListening ? 10 : 2,
                                    ),
                                    BoxShadow(
                                      color: const Color(0xFFB0C6FF).withValues(alpha: _isListening ? 0.5 : 0.2),
                                      blurRadius: _isListening ? 60 : 30,
                                      spreadRadius: _isListening ? 15 : 5,
                                    ),
                                  ],
                                ),
                                child: CustomPaint(
                                  painter: IridescentOrbPainter(
                                    progress: _isListening ? _orbAnimationController.value : 0.0,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                        const Spacer(),

                        // --- 3. SPEECH TRANSCRIPTION DISPLAY ---
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28.0),
                          child: _transcript.isNotEmpty
                              ? Text(
                                  _transcript,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFF2D3748),
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    height: 1.3,
                                  ),
                                )
                              : Text(
                                  _isListening
                                      ? "Listening... Speak your order now"
                                      : "Tap the microphone below to start speaking...",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _isListening ? const Color(0xFF4C70FF) : Colors.grey[500],
                                    fontSize: 18,
                                    fontWeight: _isListening ? FontWeight.bold : FontWeight.w500,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                        ),

                        const SizedBox(height: 16),

                        // --- 4. STATUS SUBTITLE ---
                        Text(
                          _isSending
                              ? "Sending voice order to Waiter Pro..."
                              : (_isSent
                                  ? "Order sent! Tap mic to record another."
                                  : (_isListening ? "Go ahead, I'm listening..." : "Mic is Off")),
                          style: TextStyle(
                            color: _isListening ? const Color(0xFF4C70FF) : const Color(0xFF718096),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),

                        const Spacer(flex: 2),

                        // --- 5. BOTTOM CONTROLS BAR ---
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Chat/Keyboard Icon
                              IconButton(
                                icon: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF718096), size: 24),
                                onPressed: () {
                                  _showTextPromptDialog(context);
                                },
                              ),

                              // Central Microphone Button (Tap to Start/Stop)
                              GestureDetector(
                                onTap: _toggleListening,
                                child: AnimatedBuilder(
                                  animation: _rippleAnimationController,
                                  builder: (context, child) {
                                    return Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        // Pulsing concentric ripple rings (Active when listening)
                                        if (_isListening) ...[
                                          _buildRippleRing(90, 0.15),
                                          _buildRippleRing(74, 0.25),
                                          _buildRippleRing(60, 0.35),
                                        ],
                                        // Center Mic Circle
                                        Container(
                                          width: 62,
                                          height: 62,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: _isListening
                                                  ? [const Color(0xFF6B8CFF), const Color(0xFF4C6FFF)]
                                                  : [const Color(0xFFA0AEC0), const Color(0xFF718096)],
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: (_isListening ? const Color(0xFF4C6FFF) : Colors.grey)
                                                    .withValues(alpha: 0.4),
                                                blurRadius: 14,
                                                offset: const Offset(0, 5),
                                              ),
                                            ],
                                          ),
                                          child: Icon(
                                            _isSending
                                                ? Icons.hourglass_top_rounded
                                                : (_isListening ? Icons.mic_rounded : Icons.mic_none_rounded),
                                            color: Colors.white,
                                            size: 28,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),

                              // Close Button
                              IconButton(
                                icon: const Icon(Icons.close_rounded, color: Color(0xFF718096), size: 24),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildRippleRing(double baseSize, double maxAlpha) {
    final double anim = _rippleAnimationController.value;
    final double size = baseSize + (anim * 25);
    final double alpha = maxAlpha * (1.0 - anim);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFF5E7DFF).withValues(alpha: alpha),
          width: 1.5,
        ),
      ),
    );
  }

  void _showTextPromptDialog(BuildContext context) {
    final controller = TextEditingController(text: _transcript);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Type your order query"),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: "e.g. I want 1 Smokehouse Brisket burger and a tea...",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _transcript = controller.text;
              });
              Navigator.pop(context);
              if (_transcript.trim().isNotEmpty) {
                _sendVoiceOrderToWaiter();
              }
            },
            child: const Text("Send Voice Order"),
          ),
        ],
      ),
    );
  }
}

// Custom Painter for 3D Holographic Iridescent Orb
class IridescentOrbPainter extends CustomPainter {
  final double progress;

  IridescentOrbPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Outer Glow / Atmosphere
    final outerGlowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF88A9FF).withValues(alpha: 0.6),
          const Color(0xFFC4D5FF).withValues(alpha: 0.2),
          Colors.transparent,
        ],
        stops: const [0.6, 0.85, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, outerGlowPaint);

    // Main Spherical Body Gradient
    final double rotAngle = progress * math.pi * 2;
    final Offset lightSource = Offset(
      center.dx + math.cos(rotAngle) * (radius * 0.3),
      center.dy + math.sin(rotAngle) * (radius * 0.3) - (radius * 0.2),
    );

    final mainSpherePaint = Paint()
      ..shader = RadialGradient(
        center: Alignment(
          (lightSource.dx - center.dx) / radius,
          (lightSource.dy - center.dy) / radius,
        ),
        radius: 0.9,
        colors: const [
          Color(0xFFE8F1FF), // Soft highlight
          Color(0xFF91B4FF), // Iridescent lavender
          Color(0xFF537FFF), // Vivid cobalt blue
          Color(0xFF3852C7), // Deep royal blue
        ],
        stops: const [0.0, 0.35, 0.75, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.85));

    canvas.drawCircle(center, radius * 0.85, mainSpherePaint);

    // Holographic Specular Reflection / Pearl Crescent Highlight
    final Offset highlightCenter = Offset(center.dx - radius * 0.22, center.dy - radius * 0.25);
    final highlightPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.85),
          Colors.white.withValues(alpha: 0.3),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: highlightCenter, radius: radius * 0.4));

    canvas.drawCircle(highlightCenter, radius * 0.35, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant IridescentOrbPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
