import 'package:flutter/material.dart';
import 'dart:async';
import 'services/api_service.dart';
import 'services/tenant_service.dart';
import 'cart_manager.dart';

class ChatPage extends StatefulWidget {
  final String userId;
  final String userName;
  final String userImage;

  const ChatPage({
    super.key, 
    required this.userId, 
    required this.userName, 
    required this.userImage
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isOtherTyping = false;
  Timer? _pollingTimer;
  int _lastId = 0;
  
  DateTime? _lastTypingSent;

  @override
  void initState() {
    super.initState();
    _startPolling();
    _markMessagesRead();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startPolling() {
    // Initial fetch
    _syncMessages();
    // Poll every 3 seconds (optimized for active chat)
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) => _syncMessages());
  }

  Future<void> _syncMessages() async {
    final tenant = TenantService().currentTenant.value;
    final myId = ShopManager.instance.currentUserId;
    if (tenant == null || myId.isEmpty) return;

    final data = await ApiService.syncMessages(
      tenantId: tenant.id,
      myId: myId,
      friendId: widget.userId,
      lastId: _lastId,
    );

    if (data != null && data['status'] == 'success') {
      final List<dynamic> newMsgs = data['messages'] ?? [];
      final bool typing = data['is_typing'] ?? false;

      if (newMsgs.isNotEmpty || typing != _isOtherTyping || _isLoading) {
        if (mounted) {
          setState(() {
            if (newMsgs.isNotEmpty) {
              _messages.addAll(newMsgs.cast<Map<String, dynamic>>());
              _lastId = int.parse(_messages.last['id'].toString());
              _scrollToBottom();
            }
            _isOtherTyping = typing;
            _isLoading = false;
          });
        }
      }
    }
  }

  void _markMessagesRead() {
    final tenant = TenantService().currentTenant.value;
    final myId = ShopManager.instance.currentUserId;
    if (tenant != null && myId.isNotEmpty) {
      ApiService.markMessagesRead(tenant.id, myId, widget.userId);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 100,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _onTyping(String value) {
    if (_lastTypingSent == null || DateTime.now().difference(_lastTypingSent!).inSeconds > 5) {
      final tenant = TenantService().currentTenant.value;
      final myId = ShopManager.instance.currentUserId;
      if (tenant != null && myId.isNotEmpty) {
        ApiService.updateTypingStatus(tenant.id, myId, widget.userId);
        _lastTypingSent = DateTime.now();
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final tenant = TenantService().currentTenant.value;
    final myId = ShopManager.instance.currentUserId;
    if (tenant == null || myId.isEmpty) return;

    _controller.clear();
    final success = await ApiService.sendMessage(
      tenantId: tenant.id,
      senderId: myId,
      receiverId: widget.userId,
      message: text,
    );

    if (success) {
      _syncMessages(); // Immediate sync after sending
    }
  }

  void _showOptions(Map<String, dynamic> msg) {
    final myId = ShopManager.instance.currentUserId;
    if (msg['sender_id'] != myId || msg['is_deleted'] == 1) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.edit_outlined, color: Colors.blue),
            title: const Text("Edit Message"),
            onTap: () {
              Navigator.pop(ctx);
              _editMessage(msg);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text("Unsend Message"),
            onTap: () {
              Navigator.pop(ctx);
              _deleteMessage(msg['id']);
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _editMessage(Map<String, dynamic> msg) async {
    final controller = TextEditingController(text: msg['message']);
    final newText = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Edit Message"),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text("SAVE")),
        ],
      ),
    );

    if (newText != null && newText.trim().isNotEmpty && newText != msg['message']) {
      final tenant = TenantService().currentTenant.value;
      final myId = ShopManager.instance.currentUserId;
      if (tenant != null) {
        final success = await ApiService.editMessage(tenant.id, myId, int.parse(msg['id'].toString()), newText.trim());
        if (success) {
          setState(() {
            _messages = [];
            _lastId = 0;
          });
          _syncMessages();
        }
      }
    }
  }

  Future<void> _deleteMessage(dynamic msgId) async {
    final tenant = TenantService().currentTenant.value;
    final myId = ShopManager.instance.currentUserId;
    if (tenant != null) {
      final success = await ApiService.deleteMessage(tenant.id, myId, int.parse(msgId.toString()));
      if (success) {
        setState(() {
          _messages = [];
          _lastId = 0;
        });
        _syncMessages();
      }
    }
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.userName, style: const TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                  Text(
                    _isOtherTyping ? 'Typing...' : 'Online', 
                    style: TextStyle(color: _isOtherTyping ? const Color(0xFFFF5C00) : Colors.green, fontSize: 10, fontWeight: FontWeight.bold)
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF5C00)))
              : _messages.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(20),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        final bool isMe = msg['sender_id'] == ShopManager.instance.currentUserId;
                        final bool isDeleted = (msg['is_deleted'] == 1 || msg['is_deleted'] == true);
                        final bool isEdited = (msg['is_edited'] == 1 || msg['is_edited'] == true);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: GestureDetector(
                            onLongPress: () => _showOptions(msg),
                            child: Column(
                              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                                  decoration: BoxDecoration(
                                    color: isMe 
                                      ? (isDeleted ? Colors.grey[200] : const Color(0xFFFF5C00)) 
                                      : Colors.white,
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(20),
                                      topRight: const Radius.circular(20),
                                      bottomLeft: Radius.circular(isMe ? 20 : 0),
                                      bottomRight: Radius.circular(isMe ? 0 : 20),
                                    ),
                                    border: isDeleted ? Border.all(color: Colors.grey[300]!) : null,
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        msg['message'],
                                        style: TextStyle(
                                          color: isMe 
                                            ? (isDeleted ? Colors.grey : Colors.white) 
                                            : (isDeleted ? Colors.grey : Colors.black87),
                                          fontSize: 14,
                                          fontStyle: isDeleted ? FontStyle.italic : FontStyle.normal,
                                        ),
                                      ),
                                      if (isEdited && !isDeleted)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Text(
                                            "edited", 
                                            style: TextStyle(fontSize: 8, color: isMe ? Colors.white70 : Colors.grey),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _formatMsgTime(msg['created_at']),
                                      style: TextStyle(color: Colors.grey[500], fontSize: 9),
                                    ),
                                    if (isMe && !isDeleted) ...[
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.done_all, 
                                        size: 12, 
                                        color: (msg['is_read'] == 1) ? Colors.blue : Colors.grey[400]
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          ),
          // Input Bar
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text("Say hello to ${widget.userName}!", style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(25)),
              child: TextField(
                controller: _controller,
                onChanged: _onTyping,
                onSubmitted: (_) => _sendMessage(),
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
            onTap: _sendMessage,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(color: Color(0xFFFF5C00), shape: BoxShape.circle),
              child: const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  String _formatMsgTime(String raw) {
    try {
      final dt = DateTime.parse(raw);
      return "${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
    } catch (e) { return ""; }
  }
}
