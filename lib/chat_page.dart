import 'package:flutter/material.dart';

class ChatPage extends StatefulWidget {
  final String userName;
  final String userImage;

  const ChatPage({super.key, required this.userName, required this.userImage});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  bool _isRecording = false;
  
  final List<Map<String, dynamic>> _messages = [
    {'text': 'Hey! Are you at the restaurant?', 'isMe': false, 'time': '12:01 PM', 'type': 'text'},
    {'text': 'Yes! Just ordered a brisket sandwich. It\'s amazing.', 'isMe': true, 'time': '12:02 PM', 'type': 'text'},
    {'text': 'Nice! I\'m at the Lounge area. Come say hi later!', 'isMe': false, 'time': '12:03 PM', 'type': 'text'},
    {'text': '0:12', 'isMe': false, 'time': '12:03 PM', 'type': 'voice'},
  ];

  void _sendMessage() {
    if (_controller.text.trim().isEmpty) return;
    setState(() {
      _messages.add({
        'text': _controller.text.trim(),
        'isMe': true,
        'time': '12:04 PM',
        'type': 'text',
      });
      _controller.clear();
    });
  }

  void _sendVoiceNote() {
    setState(() {
      _messages.add({
        'text': '0:05',
        'isMe': true,
        'time': '12:05 PM',
        'type': 'voice',
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: NetworkImage(widget.userImage),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.userName, style: const TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold)),
                const Text('Online • In-House', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.star_outline, color: Colors.amber),
            onPressed: () => _showRatingDialog(context),
          ),
          IconButton(icon: const Icon(Icons.videocam_outlined, color: Colors.black87), onPressed: () {}),
          IconButton(icon: const Icon(Icons.call_outlined, color: Colors.black87), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final bool isMe = msg['isMe'];
                final bool isVoice = msg['type'] == 'voice';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 15),
                  child: Column(
                    crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isMe ? const Color(0xFFFF5C00) : Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(20),
                            topRight: const Radius.circular(20),
                            bottomLeft: Radius.circular(isMe ? 20 : 0),
                            bottomRight: Radius.circular(isMe ? 0 : 20),
                          ),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))
                          ],
                        ),
                        child: isVoice 
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  index == 3 ? Icons.pause : Icons.play_arrow, 
                                  color: isMe ? Colors.white : const Color(0xFFFF5C00)
                                ),
                                const SizedBox(width: 8),
                                _buildWaveform(isMe, isActive: index == 3),
                                const SizedBox(width: 8),
                                Text(
                                  msg['text'],
                                  style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ],
                            )
                          : Text(
                              msg['text'],
                              style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 14),
                            ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            msg['time'],
                            style: TextStyle(color: Colors.grey[500], fontSize: 9),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.done_all, size: 12, color: index == 1 ? Colors.blue : Colors.grey[400]),
                          ],
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          // Input Bar
          Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))],
            ),
            child: Row(
              children: [
                if (!_isRecording) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
                    child: const Icon(Icons.add, color: Colors.grey, size: 20),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: _isRecording 
                    ? Row(
                        children: [
                          const Icon(Icons.circle, color: Colors.deepOrange, size: 12),
                          const SizedBox(width: 8),
                          const Text("Recording...", style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          const Text("0:04", style: TextStyle(color: Colors.grey)),
                        ],
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(25)),
                        child: TextField(
                          controller: _controller,
                          decoration: const InputDecoration(
                            hintText: 'Type a message...',
                            hintStyle: TextStyle(fontSize: 14, color: Colors.grey),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onLongPress: () {
                    setState(() => _isRecording = true);
                  },
                  onLongPressEnd: (_) {
                    setState(() => _isRecording = false);
                    _sendVoiceNote();
                  },
                  onTap: _sendMessage,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _isRecording ? Colors.deepOrange : const Color(0xFFFF5C00),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isRecording ? Icons.mic : (_controller.text.isEmpty ? Icons.mic : Icons.send),
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showRatingDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        int rating = 0;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text("Rate your companion", textAlign: TextAlign.center),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          index < rating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 32,
                        ),
                        onPressed: () {
                          setDialogState(() => rating = index + 1);
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  const TextField(
                    decoration: InputDecoration(
                      hintText: "Add a comment (optional)",
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Thank you for your rating!")),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5C00),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text("Submit"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildWaveform(bool isMe, {bool isActive = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(12, (index) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 2,
          height: isActive ? (index % 3 + 2) * 6.0 : (index % 3 + 1) * 4.0,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: isMe 
              ? (isActive ? Colors.white : Colors.white.withValues(alpha: 0.5)) 
              : (isActive ? const Color(0xFFFF5C00) : const Color(0xFFFF5C00).withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(1),
          ),
        );
      }),
    );
  }
}
