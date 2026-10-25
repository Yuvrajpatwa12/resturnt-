import 'package:flutter/material.dart';
import 'dart:async';
import 'services/api_service.dart';
import 'services/tenant_service.dart';
import 'cart_manager.dart';
import 'package:flutter/services.dart';

class ChatPage extends StatefulWidget {
  final String userId;
  final String userName;
  final String userImage;

  const ChatPage({
    super.key,
    required this.userId,
    required this.userName,
    required this.userImage,
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
  bool _isMutualFollow = false;
  bool _isFollowing = false;
  bool _isSending = false;
  bool _hasLoadedRelationship = false;
  int _sentBeforeFollowBack = 0;
  Timer? _pollingTimer;
  int _lastId = 0;

  DateTime? _lastTypingSent;

  Map<String, dynamic>? _replyingTo;

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
    _syncMessages();
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 2),
      (timer) => _syncMessages(),
    );
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
      final bool isMutualFollow = data['is_mutual'] == true;
      final bool isFollowing = data['is_following'] == true;
      final int sentBeforeFollowBack =
          int.tryParse(data['sent_before_follow_back']?.toString() ?? '') ?? 0;
      final bool becameMutual =
          _hasLoadedRelationship && isMutualFollow && !_isMutualFollow;

      if (newMsgs.isNotEmpty ||
          typing != _isOtherTyping ||
          isMutualFollow != _isMutualFollow ||
          isFollowing != _isFollowing ||
          sentBeforeFollowBack != _sentBeforeFollowBack ||
          _isLoading) {
        if (mounted) {
          setState(() {
            if (newMsgs.isNotEmpty) {
              final merged = <String, Map<String, dynamic>>{
                for (final message in _messages)
                  message['id'].toString(): message,
                for (final message in newMsgs.cast<Map<String, dynamic>>())
                  message['id'].toString(): message,
              };
              _messages = merged.values.toList()
                ..sort(
                  (a, b) => int.parse(
                    a['id'].toString(),
                  ).compareTo(int.parse(b['id'].toString())),
                );
              _lastId = int.parse(_messages.last['id'].toString());
              _scrollToBottom();
              _markMessagesRead();
            }
            _isOtherTyping = typing;
            _isMutualFollow = isMutualFollow;
            _isFollowing = isFollowing;
            _hasLoadedRelationship = true;
            _sentBeforeFollowBack = sentBeforeFollowBack;
            _isLoading = false;
          });
          if (becameMutual) {
            setState(() {
              _messages = [];
              _lastId = 0;
            });
            await _syncMessages();
          }
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
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  void _onTyping(String value) {
    if (_lastTypingSent == null ||
        DateTime.now().difference(_lastTypingSent!).inSeconds > 2) {
      final tenant = TenantService().currentTenant.value;
      final myId = ShopManager.instance.currentUserId;
      if (tenant != null && myId.isNotEmpty) {
        ApiService.updateTypingStatus(tenant.id, myId, widget.userId);
        _lastTypingSent = DateTime.now();
      }
    }
  }

  Future<void> _sendMessage() async {
    if (_isSending ||
        (!_isMutualFollow && !_isFollowing) ||
        (!_isMutualFollow && _sentBeforeFollowBack >= 2)) {
      return;
    }
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final tenant = TenantService().currentTenant.value;
    final myId = ShopManager.instance.currentUserId;
    if (tenant == null || myId.isEmpty) return;

    final int? replyId = _replyingTo != null
        ? int.tryParse(_replyingTo!['id'].toString())
        : null;

    setState(() => _isSending = true);

    final result = await ApiService.sendMessage(
      tenantId: tenant.id,
      senderId: myId,
      receiverId: widget.userId,
      message: text,
      replyToId: replyId,
    );

    if (!mounted) return;
    setState(() => _isSending = false);
    if (result['success'] == true) {
      _controller.clear();
      setState(() => _replyingTo = null);
      await _syncMessages();
    } else {
      final message = result['message']?.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message?.isNotEmpty == true
                ? message!
                : 'Could not send message. Please try again.',
          ),
        ),
      );
      await _syncMessages();
    }
  }

  void _showOptions(Map<String, dynamic> msg) {
    final myId = ShopManager.instance.currentUserId;
    if (msg['sender_id'] != myId || msg['is_deleted'] == 1) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text("SAVE"),
          ),
        ],
      ),
    );

    if (newText != null &&
        newText.trim().isNotEmpty &&
        newText != msg['message']) {
      final tenant = TenantService().currentTenant.value;
      final myId = ShopManager.instance.currentUserId;
      if (tenant != null) {
        final success = await ApiService.editMessage(
          tenant.id,
          myId,
          int.parse(msg['id'].toString()),
          newText.trim(),
        );
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
      final success = await ApiService.deleteMessage(
        tenant.id,
        myId,
        int.parse(msgId.toString()),
      );
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
                  Text(
                    widget.userName,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _isOtherTyping ? 'typing...' : 'Online',
                    style: TextStyle(
                      color: _isOtherTyping
                          ? const Color(0xFFFF5C00)
                          : Colors.green,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () {
                setState(() {
                  _messages = [];
                  _lastId = 0;
                  _isLoading = true;
                });
                _syncMessages();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Refreshing chat..."),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              icon: const Icon(
                Icons.refresh_rounded,
                color: Colors.grey,
                size: 20,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFF5C00)),
                  )
                : _messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(20),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final bool isMe =
                          msg['sender_id'] ==
                          ShopManager.instance.currentUserId;
                      final bool isDeleted =
                          (msg['is_deleted'] == 1 || msg['is_deleted'] == true);
                      final bool isEdited =
                          (msg['is_edited'] == 1 || msg['is_edited'] == true);
                      final bool isPendingDelivery =
                          int.tryParse(
                            msg['is_delivered']?.toString() ?? '1',
                          ) ==
                          0;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GestureDetector(
                          onHorizontalDragUpdate: (details) {
                            // Custom smooth swipe logic for Mobile
                            if (details.primaryDelta! > 8 && !isDeleted) {
                              if (_replyingTo?['id'] != msg['id']) {
                                HapticFeedback.lightImpact();
                                setState(() => _replyingTo = msg);
                              }
                            }
                          },
                          child: Column(
                            crossAxisAlignment: isMe
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: isMe
                                    ? MainAxisAlignment.end
                                    : MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  if (!isMe && !isDeleted)
                                    _buildDesktopOptions(msg),
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isMe
                                            ? (isDeleted
                                                  ? Colors.grey[200]
                                                  : const Color(0xFFFF5C00))
                                            : Colors.white,
                                        borderRadius: BorderRadius.only(
                                          topLeft: const Radius.circular(20),
                                          topRight: const Radius.circular(20),
                                          bottomLeft: Radius.circular(
                                            isMe ? 20 : 0,
                                          ),
                                          bottomRight: Radius.circular(
                                            isMe ? 0 : 20,
                                          ),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.02,
                                            ),
                                            blurRadius: 5,
                                          ),
                                        ],
                                        border: isDeleted
                                            ? Border.all(
                                                color: Colors.grey[300]!,
                                              )
                                            : null,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Reply Preview
                                          if (msg['reply_to_id'] != null &&
                                              !isDeleted)
                                            _buildReplyPreviewInBubble(
                                              msg['reply_to_id'],
                                            ),

                                          Text(
                                            msg['message'],
                                            style: TextStyle(
                                              color: isMe
                                                  ? (isDeleted
                                                        ? Colors.grey
                                                        : Colors.white)
                                                  : (isDeleted
                                                        ? Colors.grey
                                                        : Colors.black87),
                                              fontSize: 14,
                                              fontStyle: isDeleted
                                                  ? FontStyle.italic
                                                  : FontStyle.normal,
                                            ),
                                          ),
                                          if (isEdited && !isDeleted)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 4,
                                              ),
                                              child: Text(
                                                "edited",
                                                style: TextStyle(
                                                  fontSize: 8,
                                                  color: isMe
                                                      ? Colors.white70
                                                      : Colors.grey,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (isMe && !isDeleted)
                                    _buildDesktopOptions(msg),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _formatMsgTime(msg['created_at']),
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 9,
                                    ),
                                  ),
                                  if (isMe && !isDeleted) ...[
                                    const SizedBox(width: 4),
                                    Icon(
                                      isPendingDelivery
                                          ? Icons.schedule_rounded
                                          : Icons.done_all,
                                      size: 14,
                                      color:
                                          (msg['is_read'] == 1 ||
                                              msg['is_read'] == true)
                                          ? Colors.blue
                                          : Colors.grey[400],
                                    ),
                                  ],
                                ],
                              ),
                              if (isMe && !isDeleted && isPendingDelivery)
                                const Padding(
                                  padding: EdgeInsets.only(top: 2),
                                  child: Text(
                                    'Waiting for follow-back',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 9,
                                    ),
                                  ),
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

  Widget _buildDesktopOptions(Map<String, dynamic> msg) {
    // Only show 3-dot for PC or Hover-like feel
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      icon: const Icon(Icons.more_vert_rounded, color: Colors.grey, size: 16),
      onSelected: (val) {
        if (val == 'reply') setState(() => _replyingTo = msg);
        if (val == 'edit') _editMessage(msg);
        if (val == 'delete') _deleteMessage(msg['id']);
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'reply',
          child: Text("Reply", style: TextStyle(fontSize: 12)),
        ),
        if (msg['sender_id'] == ShopManager.instance.currentUserId) ...[
          const PopupMenuItem(
            value: 'edit',
            child: Text("Edit", style: TextStyle(fontSize: 12)),
          ),
          const PopupMenuItem(
            value: 'delete',
            child: Text(
              "Delete",
              style: TextStyle(fontSize: 12, color: Colors.red),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildReplyPreviewInBubble(dynamic replyId) {
    final parent = _messages.firstWhere(
      (m) => m['id'].toString() == replyId.toString(),
      orElse: () => {},
    );
    if (parent.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: const Border(
          left: BorderSide(color: Color(0xFFFF5C00), width: 3),
        ),
      ),
      child: Text(
        parent['message'] ?? '',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11, color: Colors.grey),
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
          Text(
            "Say hello to ${widget.userName}!",
            style: const TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    final canSend = !_isSending && (_isMutualFollow || _isFollowing);
    final remainingRequests = (2 - _sentBeforeFollowBack).clamp(0, 2);
    final requestHint = !_isFollowing
        ? 'Follow ${widget.userName} before sending a message.'
        : remainingRequests > 0
        ? 'You can send $remainingRequests more ${remainingRequests == 1 ? 'message' : 'messages'} now; they will be delivered with notifications. Further messages will wait for follow-back.'
        : 'Your first 2 messages were delivered with notifications. New messages will wait for ${widget.userName} to follow you back.';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!_isMutualFollow)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: const Color(0xFFFFF4E8),
            child: Text(
              requestHint,
              style: const TextStyle(
                color: Color(0xFF8A4B08),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        if (_replyingTo != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            color: Colors.white,
            child: Row(
              children: [
                const Icon(
                  Icons.reply_rounded,
                  color: Color(0xFFFF5C00),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Replying to",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFF5C00),
                        ),
                      ),
                      Text(
                        _replyingTo!['message'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _replyingTo = null),
                  icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                ),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () {}, // Trigger system emoji picker
                icon: const Icon(
                  Icons.emoji_emotions_outlined,
                  color: Colors.grey,
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: TextField(
                    controller: _controller,
                    onChanged: canSend ? _onTyping : null,
                    onSubmitted: canSend ? (_) => _sendMessage() : null,
                    enabled: canSend,
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
                onTap: canSend ? _sendMessage : null,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: canSend ? const Color(0xFFFF5C00) : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                  child: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatMsgTime(String raw) {
    try {
      final dt = DateTime.parse(raw);
      return "${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return "";
    }
  }
}
