import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'web_helper_stub.dart' if (dart.library.html) 'web_helper_html.dart';

class IosPwaPrompt extends StatefulWidget {
  const IosPwaPrompt({super.key});

  @override
  State<IosPwaPrompt> createState() => _IosPwaPromptState();
}

class _IosPwaPromptState extends State<IosPwaPrompt> {
  bool _showPrompt = false;

  @override
  void initState() {
    super.initState();
    _checkIosPwa();
  }

  Future<void> _checkIosPwa() async {
    if (!kIsWeb) return;

    // Check if running on iOS browser and not already in standalone/PWA mode
    final isIos = isIosBrowser();
    final isStandalone = isPwaStandalone();

    if (isIos && !isStandalone) {
      final prefs = await SharedPreferences.getInstance();
      final dismissed = prefs.getBool('ios_pwa_prompt_dismissed') ?? false;
      if (!dismissed && mounted) {
        setState(() => _showPrompt = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_showPrompt) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () {}, // Prevent dismissal on background tap
      child: Container(
        color: Colors.black.withValues(alpha: 0.5),
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 450),
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 20,
                  offset: Offset(0, 10),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5C00).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.phone_iphone_rounded,
                    size: 32,
                    color: Color(0xFFFF5C00),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Install App on iPhone",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "To receive instant push notifications for Waves & Orders on your iPhone, add this app to your Home Screen:",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 20),
                
                // Step 1
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.ios_share_rounded, color: Color(0xFFFF5C00), size: 22),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "1. Tap the Share button at the bottom of Safari/Chrome",
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                
                // Step 2
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.add_box_outlined, color: Color(0xFFFF5C00), size: 22),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "2. Scroll down & select 'Add to Home Screen'",
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      setState(() => _showPrompt = false);
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('ios_pwa_prompt_dismissed', true);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5C00),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      "Got It!",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
