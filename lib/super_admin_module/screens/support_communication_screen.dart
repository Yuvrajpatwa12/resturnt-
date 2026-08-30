import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../styles.dart';

class SupportCommunicationScreen extends StatefulWidget {
  const SupportCommunicationScreen({super.key});

  @override
  State<SupportCommunicationScreen> createState() => _SupportCommunicationScreenState();
}

class _SupportCommunicationScreenState extends State<SupportCommunicationScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _tickets = [];
  Map<String, dynamic>? _selectedTicket;
  List<Map<String, dynamic>> _chatHistory = [];
  bool _isLoading = true;
  bool _isChatLoading = false;
  final _replyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    setState(() => _isLoading = true);
    final data = await ApiService.fetchSupportTickets();
    if (data != null) {
      setState(() {
        _tickets = data;
        if (_tickets.isNotEmpty) {
           if (_selectedTicket != null) {
             _selectedTicket = _tickets.firstWhere((t) => t['id'] == _selectedTicket!['id'], orElse: () => _tickets.first);
           } else {
             _selectedTicket = _tickets.first;
           }
           _loadChatHistory(_selectedTicket!['id']);
        }
      });
    }
    setState(() => _isLoading = false);
  }

  Future<void> _loadChatHistory(dynamic ticketId) async {
    setState(() => _isChatLoading = true);
    final data = await ApiService.fetchTicketHistory(int.parse(ticketId.toString()));
    if (data != null) {
      setState(() => _chatHistory = data);
    }
    setState(() => _isChatLoading = false);
  }

  Future<void> _handleSendReply() async {
    if (_replyController.text.isEmpty || _selectedTicket == null) return;

    final msg = _replyController.text.trim();
    final ticketId = int.parse(_selectedTicket!['id'].toString());

    _replyController.clear();
    final success = await ApiService.sendTicketReply(ticketId: ticketId, message: msg);
    
    if (success) {
      _loadChatHistory(ticketId);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to send reply.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Support & CRM Center", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  Text("Manage restaurant issues and live chat with owners.", style: TextStyle(color: SAMStyles.textGrey)),
                ],
              ),
              IconButton(onPressed: _loadTickets, icon: const Icon(Icons.refresh, color: SAMStyles.royalBlue)),
            ],
          ),
          const SizedBox(height: 24),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: SAMStyles.royalBlue,
            indicatorColor: SAMStyles.royalBlue,
            tabAlignment: TabAlignment.start,
            tabs: const [Tab(text: "Live Tickets"), Tab(text: "Global Broadcast")],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTicketSplitView(),
                    const Center(child: Text("Broadcast Center Ready.")),
                  ],
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketSplitView() {
    if (_tickets.isEmpty) return const Center(child: Text("No active support tickets."));

    return Row(
      children: [
        // Ticket List
        Expanded(
          flex: 4,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white, 
              borderRadius: BorderRadius.circular(16), 
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: SAMStyles.softShadow,
            ),
            child: ListView.separated(
              itemCount: _tickets.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final t = _tickets[index];
                bool isSel = _selectedTicket?['id'] == t['id'];
                return ListTile(
                  onTap: () {
                    setState(() => _selectedTicket = t);
                    _loadChatHistory(t['id']);
                  },
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  tileColor: isSel ? const Color(0xFFEFF6FF) : null,
                  leading: CircleAvatar(
                    backgroundColor: t['status'] == 'Urgent' ? Colors.red : SAMStyles.royalBlue, 
                    child: const Icon(Icons.mail_outline, color: Colors.white, size: 16)
                  ),
                  title: Text(t['restaurant_name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text(t['subject'] ?? 'No Subject', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), 
                    decoration: BoxDecoration(color: _getStatusColor(t['status']).withOpacity(0.1), borderRadius: BorderRadius.circular(8)), 
                    child: Text(t['status'] ?? 'Open', style: TextStyle(color: _getStatusColor(t['status']), fontSize: 8, fontWeight: FontWeight.bold))
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 24),
        // Chat View
        Expanded(
          flex: 6,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white, 
              borderRadius: BorderRadius.circular(16), 
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: SAMStyles.softShadow,
            ),
            child: Column(
              children: [
                _buildChatHeader(),
                const Divider(height: 1),
                Expanded(child: _buildChatBody()),
                const Divider(height: 1),
                _buildChatInput(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChatHeader() {
    if (_selectedTicket == null) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20, 
            backgroundColor: SAMStyles.royalBlue.withOpacity(0.1), 
            child: Text(_selectedTicket!['restaurant_name']?[0] ?? 'R', style: const TextStyle(color: SAMStyles.royalBlue, fontWeight: FontWeight.bold))
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, 
              children: [
                Text(_selectedTicket!['restaurant_name'] ?? 'Select Ticket', style: const TextStyle(fontWeight: FontWeight.bold)), 
                Text("Subject: ${_selectedTicket!['subject']}", style: const TextStyle(color: SAMStyles.textGrey, fontSize: 11)),
              ]
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: const Text("LIVE SESSION", style: TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildChatBody() {
    if (_selectedTicket == null) return const Center(child: Text("Select a ticket to view details."));
    if (_isChatLoading && _chatHistory.isEmpty) return const Center(child: CircularProgressIndicator());

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // 1. System Info & Original Message
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(20)),
            child: Text(
              "Ticket Created on ${_selectedTicket!['created_at']}",
              style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 24),
        
        // Original Ticket Description from Tenant
        _buildMessageBubble(
          text: _selectedTicket!['description'] ?? "No details provided.",
          isMe: false,
          subtitle: "Original Request",
        ),
        
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 16),

        // 2. Chat History
        if (_chatHistory.isEmpty)
           const Center(child: Text("No replies yet. Send a message below.", style: TextStyle(color: Colors.grey, fontSize: 11)))
        else
          ..._chatHistory.map((m) => _buildMessageBubble(
            text: m['message'],
            isMe: m['sender_type'] == 'Admin',
            subtitle: m['created_at'],
          )),
      ],
    );
  }

  Widget _buildMessageBubble({required String text, required bool isMe, required String subtitle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) CircleAvatar(radius: 14, backgroundColor: Colors.grey[200], child: const Icon(Icons.person, size: 14, color: Colors.grey)),
          if (!isMe) const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isMe ? SAMStyles.royalBlue : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                      bottomRight: isMe ? Radius.zero : const Radius.circular(16),
                    ),
                    border: Border.all(color: isMe ? SAMStyles.royalBlue : const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    text,
                    style: TextStyle(fontSize: 14, height: 1.5, color: isMe ? Colors.white : const Color(0xFF1E293B)),
                  ),
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 9)),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 12),
          if (isMe) CircleAvatar(radius: 14, backgroundColor: SAMStyles.royalBlue.withOpacity(0.1), child: const Icon(Icons.admin_panel_settings, size: 14, color: SAMStyles.royalBlue)),
        ],
      ),
    );
  }

  Widget _buildChatInput() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _replyController,
              decoration: const InputDecoration(
                hintText: "Type your reply to the owner...", 
                hintStyle: TextStyle(fontSize: 13),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 12),
              ),
              onSubmitted: (_) => _handleSendReply(),
            )
          ), 
          const SizedBox(width: 12), 
          Container(
            decoration: BoxDecoration(color: SAMStyles.royalBlue, borderRadius: BorderRadius.circular(12)),
            child: IconButton(
              onPressed: _handleSendReply, 
              icon: const Icon(Icons.send_rounded, size: 18, color: Colors.white)
            )
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'Open': return Colors.blue;
      case 'Urgent': return Colors.red;
      case 'Resolved': return Colors.green;
      default: return Colors.orange;
    }
  }
}
