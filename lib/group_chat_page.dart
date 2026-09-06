import 'package:flutter/material.dart';
import 'cart_manager.dart';

class GroupChatPage extends StatefulWidget {
  const GroupChatPage({super.key});

  @override
  State<GroupChatPage> createState() => _GroupChatPageState();
}

class _GroupChatPageState extends State<GroupChatPage> {
  final TextEditingController _controller = TextEditingController();
  bool _isRecording = false;
  
  final List<Map<String, dynamic>> _messages = [
    {'sender': 'Mark', 'text': 'Hey everyone! Brisket is great here.', 'isMe': false, 'time': '12:40 PM', 'type': 'text'},
    {'sender': 'Noah', 'text': 'I just ordered the same! 😋', 'isMe': false, 'time': '12:41 PM', 'type': 'text'},
    {'sender': 'You', 'text': 'Can\'t wait to try it.', 'isMe': true, 'time': '12:42 PM', 'type': 'text'},
    {'sender': 'Mark', 'text': '0:08', 'isMe': false, 'time': '12:43 PM', 'type': 'voice'},
  ];

  void _sendMessage() {
    if (_controller.text.trim().isEmpty) return;
    setState(() {
      _messages.add({
        'sender': 'You',
        'text': _controller.text.trim(),
        'isMe': true,
        'time': '12:44 PM',
        'type': 'text',
      });
      _controller.clear();
    });
  }

  void _sendVoiceNote() {
    setState(() {
      _messages.add({
        'sender': 'You',
        'text': '0:05',
        'isMe': true,
        'time': '12:45 PM',
        'type': 'voice',
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final members = ShopManager.instance.currentGroupMembers;

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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Dining Group", style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold)),
                Text(
                  "Table 12 • ${members.length + 1} People", 
                  style: const TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 24,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    return Container(
                      margin: const EdgeInsets.only(right: 4),
                      child: CircleAvatar(
                        radius: 10,
                        backgroundImage: NetworkImage(members[index]['image']),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_2_rounded, color: Colors.black87, size: 20),
            onPressed: () => _showGroupQR(context),
          ),
          IconButton(
            icon: const Icon(Icons.person_add_alt_1, color: Colors.blue),
            onPressed: () => _showAddMemberModal(context),
          ),
          IconButton(
            icon: const Icon(Icons.star_outline, color: Colors.amber),
            onPressed: () => _showTableRatingDialog(context),
          ),
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
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      if (!isMe)
                        Padding(
                          padding: const EdgeInsets.only(left: 8, bottom: 4),
                          child: Text(msg['sender'], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 0.5)),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isMe ? const Color(0xFFFF5C00) : Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(20),
                            topRight: const Radius.circular(20),
                            bottomLeft: Radius.circular(isMe ? 20 : 4),
                            bottomRight: Radius.circular(isMe ? 4 : 20),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isMe ? const Color(0xFFFF5C00).withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.03), 
                              blurRadius: 10, 
                              offset: const Offset(0, 4)
                            )
                          ],
                        ),
                        child: isVoice 
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.play_circle_fill, color: isMe ? Colors.white : const Color(0xFFFF5C00), size: 28),
                                const SizedBox(width: 8),
                                _buildWaveform(isMe),
                                const SizedBox(width: 12),
                                Text(
                                  msg['text'],
                                  style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 11, fontWeight: FontWeight.w900),
                                ),
                              ],
                            )
                          : Text(
                              msg['text'],
                              style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 14, height: 1.3),
                            ),
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(msg['time'], style: TextStyle(color: Colors.grey[400], fontSize: 9, fontWeight: FontWeight.bold)),
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
                    ? const Center(child: Text("Recording Group Note...", style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold)))
                    : Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(25)),
                        child: TextField(
                          controller: _controller,
                          decoration: const InputDecoration(
                            hintText: 'Message everyone...',
                            hintStyle: TextStyle(fontSize: 14, color: Colors.grey),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onLongPress: () => setState(() => _isRecording = true),
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

  void _showTableRatingDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text("Rate Table Vibe", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w900)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) => const Icon(Icons.star, color: Colors.amber, size: 36)),
              ),
              const SizedBox(height: 20),
              const Text(
                "How is the energy at your table right now?", 
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5C00),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: const Text("Submit Vibe", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showGroupQR(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          child: Container(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("TABLE INVITE QR", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2, color: Colors.grey, fontSize: 10)),
                const SizedBox(height: 20),
                const Text("Table 12 Group", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFFFF5C00))),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey[100]!, width: 2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.qr_code_2_rounded, size: 160, color: Colors.black87),
                ),
                const SizedBox(height: 24),
                const Text(
                  "Ask friends to scan this code to join your dining group instantly.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 30),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Close", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddMemberModal(BuildContext context) {
    final users = ShopManager.instance.nearbyUsers.where((u) {
      return !ShopManager.instance.currentGroupMembers.any((m) => m['name'] == u['name']);
    }).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              const Padding(
                padding: EdgeInsets.all(24.0),
                child: Text("Add Member to Table", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              ),
              Expanded(
                child: users.isEmpty 
                  ? const Center(child: Text("No more nearby friends available", style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final user = users[index];
                        return ListTile(
                          leading: CircleAvatar(backgroundImage: NetworkImage(user['image'])),
                          title: Text(user['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(user['location'], style: const TextStyle(fontSize: 11)),
                          trailing: const Icon(Icons.add_circle_outline, color: Color(0xFFFF5C00)),
                          onTap: () {
                            setState(() {
                              ShopManager.instance.addMembersToGroup([user]);
                            });
                            Navigator.pop(context);
                            final bonus = int.tryParse(ShopManager.instance.loyaltySettings.value?['group_join_bonus']?.toString() ?? '200') ?? 200;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("${user['name']} added! +$bonus Reward Points earned.")),
                            );
                          },
                        );
                      },
                    ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWaveform(bool isMe) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(8, (index) {
        return Container(
          width: 2,
          height: (index % 3 + 1) * 4.0,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: isMe ? Colors.white.withValues(alpha: 0.5) : const Color(0xFFFF5C00).withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(1),
          ),
        );
      }),
    );
  }
}
