import 'package:flutter/material.dart';

class VoiceOrderPage extends StatefulWidget {
  const VoiceOrderPage({super.key});

  @override
  State<VoiceOrderPage> createState() => _VoiceOrderPageState();
}

class _VoiceOrderPageState extends State<VoiceOrderPage> {
  bool isListening = true;
  String transcript = "I'd like to order a Smokehouse Bri...";
  
  final List<String> suggestions = [
    "Add Curly Fries",
    "Extra Cheese",
    "Make it a Combo",
    "Check Order Status",
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFF5C00), Color(0xFFFF8C00), Colors.black],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // --- Header ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Text(
                      "CHIYABREAK VOICE AI",
                      style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 2),
                    ),
                    IconButton(
                      icon: const Icon(Icons.help_outline, color: Colors.white70),
                      onPressed: () {},
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 2),

              // --- Main UI ---
              const Text(
                "How can I help you?",
                style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5),
              ),
              const SizedBox(height: 12),
              
              // Transcript Box
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                height: 60,
                alignment: Alignment.center,
                child: Text(
                  isListening ? "\"$transcript\"" : "Tap the mic to start",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 18,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),

              const Spacer(),

              // --- Reacting Waveform ---
              if (isListening)
                SizedBox(
                  height: 100,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(20, (index) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 4,
                        height: (index % 5 + 1) * 15.0 * (isListening ? 1.5 : 0.5),
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    }),
                  ),
                ),
              
              const SizedBox(height: 40),

              // --- Glowing Mic Animation ---
              GestureDetector(
                onTap: () => setState(() => isListening = !isListening),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (isListening) _buildPulse(160, 0.1),
                    if (isListening) _buildPulse(130, 0.2),
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.3),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.mic,
                        size: 45,
                        color: isListening ? const Color(0xFFFF5C00) : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                isListening ? "Listening..." : "Tap to Speak",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),

              const Spacer(flex: 2),

              // --- Suggestion Chips ---
              Padding(
                padding: const EdgeInsets.only(bottom: 30),
                child: Column(
                  children: [
                    const Text(
                      "TRY SAYING:",
                      style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                    ),
                    const SizedBox(height: 16),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: suggestions.map((s) => _buildSuggestionChip(s)).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPulse(double size, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(opacity),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildSuggestionChip(String text) {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
