import 'package:flutter/material.dart';
import 'cart_manager.dart';
import 'chat_page.dart';

class MessagesListPage extends StatefulWidget {
  const MessagesListPage({super.key});

  @override
  State<MessagesListPage> createState() => _MessagesListPageState();
}

class _MessagesListPageState extends State<MessagesListPage> {
  @override
  void initState() {
    super.initState();
    ShopManager.instance.refreshConversations();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Messages",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFFFF5C00), size: 20),
            onPressed: () => ShopManager.instance.refreshConversations(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar (Optional)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(15),
              ),
              child: const TextField(
                decoration: InputDecoration(
                  icon: Icon(Icons.search, color: Colors.grey, size: 20),
                  hintText: "Search chats...",
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          
          Expanded(
            child: ValueListenableBuilder<List<Map<String, dynamic>>>(
              valueListenable: ShopManager.instance.conversations,
              builder: (context, conversations, _) {
                if (conversations.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          const Text(
                            "No Mutual Friends Yet",
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Follow other diners and wait for them to follow back to start chatting.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: conversations.length,
                  itemBuilder: (context, index) {
                    final chat = conversations[index];
                    final String gender = chat['gender'] ?? 'Male';
                    final String avatarUrl = gender == 'Female'
                        ? 'https://img.freepik.com/free-vector/beauty-woman-face-concept_23-2148679462.jpg'
                        : 'https://img.freepik.com/free-vector/businessman-character-avatar-isolated_24877-60111.jpg';

                    final bool hasUnread = (int.tryParse(chat['unread']?.toString() ?? '0') ?? 0) > 0;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                      leading: CircleAvatar(
                        radius: 28,
                        backgroundImage: NetworkImage(avatarUrl),
                      ),
                      title: Text(
                        chat['name'] ?? 'Guest',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      subtitle: Text(
                        chat['last_msg'] ?? 'Start a conversation',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: hasUnread ? Colors.black87 : Colors.grey,
                          fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (chat['last_time'] != null)
                            Text(
                              _formatChatTime(chat['last_time']),
                              style: TextStyle(color: Colors.grey[500], fontSize: 10),
                            ),
                          const SizedBox(height: 4),
                          if (hasUnread)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: const BoxDecoration(
                                color: Color(0xFFFF5C00),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                chat['unread'].toString(),
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatPage(
                              userId: chat['uid'],
                              userName: chat['name'],
                              userImage: avatarUrl,
                            ),
                          ),
                        );
                        ShopManager.instance.refreshConversations();
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatChatTime(String rawDate) {
    try {
      final DateTime dt = DateTime.parse(rawDate);
      final now = DateTime.now();
      if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
        return "${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
      }
      return "${dt.day}/${dt.month}";
    } catch (e) { return ""; }
  }
}
