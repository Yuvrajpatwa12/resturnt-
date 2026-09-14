import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'models.dart';

class ProductVoiceAssistantPage extends StatefulWidget {
  final Product product;

  const ProductVoiceAssistantPage({super.key, required this.product});

  @override
  State<ProductVoiceAssistantPage> createState() => _ProductVoiceAssistantPageState();
}

class _ProductVoiceAssistantPageState extends State<ProductVoiceAssistantPage> {
  final FlutterTts flutterTts = FlutterTts();
  final List<Map<String, String>> _messages = [];
  bool _isTtsReady = false;
  bool _isSpeaking = false;
  bool _isNepaliSupported = true; // Assume true initially

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  void _initTts() async {
    try {
      // On Web, voices load asynchronously. Wait a moment for them to register.
      if (kIsWeb) {
        await Future.delayed(const Duration(milliseconds: 500));
        debugPrint("TTS Web: Checking for available voices...");
        List<dynamic> languages = await flutterTts.getLanguages;
        debugPrint("TTS Web: Available Languages: $languages");
      }

      // Try setting Nepali
      bool isNepaliAvailable = false;
      try {
        isNepaliAvailable = await flutterTts.isLanguageAvailable("ne-NP");
      } catch (e) {
        debugPrint("TTS: Error checking Nepali availability: $e");
      }

      if (isNepaliAvailable) {
        debugPrint("TTS: Using Nepali (ne-NP)");
        await flutterTts.setLanguage("ne-NP");
        setState(() => _isNepaliSupported = true);
      } else {
        debugPrint("TTS: Nepali not found. Using English (en-US) as fallback.");
        await flutterTts.setLanguage("en-US");
        setState(() => _isNepaliSupported = false);
      }

      await flutterTts.setVolume(1.0);
      await flutterTts.setPitch(1.0);
      await flutterTts.setSpeechRate(0.5);
      await flutterTts.awaitSpeakCompletion(true);

      // On iOS/macOS, we need to set the audio category
      try {
        await flutterTts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback,
            [IosTextToSpeechAudioCategoryOptions.duckOthers, IosTextToSpeechAudioCategoryOptions.defaultToSpeaker]);
      } catch (e) {
        // Silently ignore if not on iOS/macOS
      }

      flutterTts.setStartHandler(() => setState(() => _isSpeaking = true));
      flutterTts.setCompletionHandler(() => setState(() => _isSpeaking = false));
      flutterTts.setErrorHandler((msg) {
        debugPrint("TTS ERROR: $msg");
        setState(() => _isSpeaking = false);
      });

      setState(() => _isTtsReady = true);
      
      // Deep Voice Scan: Look for the best Nepali voice
      if (kIsWeb) {
        List<dynamic> voices = await flutterTts.getVoices;
        // Filter for voices that contain 'ne' or 'Nepali'
        var nepaliVoices = voices.where((v) => 
          v.toString().toLowerCase().contains('ne') || 
          v.toString().toLowerCase().contains('nepali')
        ).toList();
        
        if (nepaliVoices.isNotEmpty) {
          debugPrint("TTS Web: Found ${nepaliVoices.length} Nepali voices. Using the first one.");
          // On Web, the voice object is usually a Map or a String name
          await flutterTts.setVoice({"name": nepaliVoices.first['name'], "locale": "ne-NP"});
          setState(() => _isNepaliSupported = true);
        }
      }

      await flutterTts.setSpeechRate(0.8); // Faster rate for more human-like flow
      
      // Initial messages
      String welcomeMsg = "Hello! How can I assist you with this ${widget.product.title} today?";
      
      _addStaffMessage(welcomeMsg, !kIsWeb);
    } catch (e) {
      debugPrint("TTS Init Error: $e");
    }
  }

  void _speak(String text) async {
    if (!_isTtsReady) {
      debugPrint("TTS: Not ready yet.");
      return;
    }
    try {
      await flutterTts.stop(); // Stop any ongoing speech before starting new one
      await flutterTts.speak(text);
    } catch (e) {
      debugPrint("TTS Speak Error: $e");
    }
  }

  void _addStaffMessage(String text, bool shouldSpeak, {String? overrideSpeakText}) {
    setState(() {
      _messages.add({
        "sender": "staff", 
        "text": text,
        "speakText": overrideSpeakText ?? text,
      });
    });
    if (shouldSpeak) _speak(overrideSpeakText ?? text);
  }

  void _addUserMessage(String text) {
    setState(() {
      _messages.add({"sender": "user", "text": text, "speakText": text});
    });
  }

  void _handleQuestion(String question, String engAnswer, String nepaliAnswer) {
    _addUserMessage(question);
    
    // Check if we can speak Nepali
    if (!_isNepaliSupported && kIsWeb) {
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text("यो ब्राउजरमा नेपाली आवाज उपलब्ध छैन (Nepali voice not available)")),
       );
    }

    // Clean up the answer for better speech (replace NPR with Rupees phonetic)
    String phoneticAnswer = nepaliAnswer
      .replaceAll("NPR", "रुपैयाँ")
      .replaceAll("रु.", "रुपैयाँ");

    _addStaffMessage(nepaliAnswer, true, overrideSpeakText: phoneticAnswer);
  }

  @override
  void dispose() {
    flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Staff Assistant", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.close, color: Colors.black87), onPressed: () => Navigator.pop(context)),
      ),
      body: Column(
        children: [
          // Product Header
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(widget.product.image, width: 60, height: 60, fit: BoxFit.cover),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.product.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(widget.product.price, style: const TextStyle(color: Color(0xFFFF5C00), fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Chat View
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isStaff = msg['sender'] == 'staff';
                return Align(
                  alignment: isStaff ? Alignment.centerLeft : Alignment.centerRight,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    decoration: BoxDecoration(
                      color: isStaff ? Colors.white : const Color(0xFFFF5C00),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isStaff ? 4 : 16),
                        bottomRight: Radius.circular(isStaff ? 16 : 4),
                      ),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isStaff)
                          Padding(
                            padding: const EdgeInsets.only(right: 8, top: 2),
                            child: GestureDetector(
                              onTap: () => _speak(msg['speakText'] ?? msg['text']!),
                              child: Icon(Icons.volume_up, size: 14, color: _isSpeaking ? const Color(0xFFFF5C00) : Colors.grey),
                            ),
                          ),
                        Flexible(
                          child: Text(
                            msg['text']!,
                            style: TextStyle(color: isStaff ? Colors.black87 : Colors.white, fontWeight: FontWeight.w500, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          if (_isSpeaking)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.volume_up, color: Color(0xFFFF5C00), size: 16),
                  const SizedBox(width: 8),
                  const Text("Assistant is speaking...", style: TextStyle(color: Color(0xFFFF5C00), fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),

          if (kIsWeb && _messages.length == 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: ElevatedButton.icon(
                onPressed: () {
                   String textToSpeak = _messages.first['speakText'] ?? _messages.first['text']!;
                   _speak(textToSpeak);
                },
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text("सुरु गर्नुहोस् (Start Voice)"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5C00),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

          // Action Area
          Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Sodhnuhos (सोध्नुहोस्):", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildQuestionChip("Price?", "How much is it?", "The price is ${widget.product.price}.", "यसको मूल्य ${widget.product.price} हो।"),
                      _buildQuestionChip("Taste?", "What does it taste like?", "It is very delicious and fresh. You will surely like it.", "यो निकै स्वादिलो र ताजा छ। तपाईंलाई पक्कै मन पर्नेछ।"),
                      _buildQuestionChip("Portion?", "What is the portion size?", "The quantity is sufficient for one person.", "यसको मात्रा एक व्यक्तिको लागि पर्याप्त छ।"),
                      _buildQuestionChip("Rating?", "Is it good?", "It has a rating of ${widget.product.rating}, many customers have liked it.", "यसको रेटिङ ${widget.product.rating} छ, धेरै ग्राहकहरूले यसलाई मन पराएका छन्।"),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionChip(String label, String question, String engAnswer, String nepaliAnswer) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(label),
        backgroundColor: const Color(0xFFF1F5F9),
        labelStyle: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        onPressed: _isSpeaking ? null : () => _handleQuestion(question, engAnswer, nepaliAnswer),
      ),
    );
  }
}
