import 'dart:async';
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
  Timer? _pollTimer;

  List<Map<String, dynamic>> _tickets = [];
  Map<String, dynamic>? _selectedTicket;
  List<Map<String, dynamic>> _chatHistory = [];

  bool _isLoading = true;
  bool _isChatLoading = false;
  String _statusFilter = 'Active'; // Active, Resolved, All

  final _replyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTickets(showLoading: true);
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _tabController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      _loadTickets(showLoading: false);
      if (_selectedTicket != null) {
        _loadChatHistory(_selectedTicket!['id'], showLoading: false);
      }
    });
  }

  Future<void> _loadTickets({bool showLoading = true}) async {
    if (showLoading) setState(() => _isLoading = true);
    final data = await ApiService.fetchSupportTickets();
    if (mounted) {
      if (data != null) {
        setState(() {
          _tickets = data;
          if (_tickets.isNotEmpty) {
            if (_selectedTicket != null) {
              final match = _tickets.where((t) => t['id'].toString() == _selectedTicket!['id'].toString()).toList();
              if (match.isNotEmpty) {
                _selectedTicket = match.first;
              } else {
                _selectedTicket = _filteredTickets.isNotEmpty ? _filteredTickets.first : _tickets.first;
              }
            } else {
              _selectedTicket = _filteredTickets.isNotEmpty ? _filteredTickets.first : _tickets.first;
            }
          }
        });
      }
      if (showLoading) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadChatHistory(dynamic ticketId, {bool showLoading = true}) async {
    if (showLoading) setState(() => _isChatLoading = true);
    final data = await ApiService.fetchTicketHistory(int.parse(ticketId.toString()));
    if (mounted) {
      if (data != null) {
        setState(() => _chatHistory = data);
      }
      if (showLoading) setState(() => _isChatLoading = false);
    }
  }

  Future<void> _handleSendReply() async {
    if (_replyController.text.trim().isEmpty || _selectedTicket == null) return;

    final msg = _replyController.text.trim();
    final ticketId = int.parse(_selectedTicket!['id'].toString());

    _replyController.clear();
    final success = await ApiService.sendTicketReply(
      ticketId: ticketId,
      message: msg,
      senderType: 'SuperAdmin',
    );

    if (!mounted) return;
    if (success) {
      _loadChatHistory(ticketId, showLoading: false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to send reply to restaurant."),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _updateTicketStatus(String newStatus) async {
    if (_selectedTicket == null) return;
    final ticketId = int.parse(_selectedTicket!['id'].toString());

    final success = await ApiService.updateTicketStatus(ticketId: ticketId, status: newStatus);
    if (success && mounted) {
      setState(() {
        _selectedTicket!['status'] = newStatus;
      });
      _loadTickets(showLoading: false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Ticket #$ticketId marked as $newStatus."),
          backgroundColor: newStatus == 'Resolved' || newStatus == 'Closed' ? Colors.green : SAMStyles.royalBlue,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  List<Map<String, dynamic>> get _filteredTickets {
    return _tickets.where((t) {
      final st = (t['status'] ?? 'Open').toString().trim().toLowerCase();
      if (_statusFilter == 'Active') {
        return st != 'resolved' && st != 'closed';
      }
      if (_statusFilter == 'Resolved') {
        return st == 'resolved' || st == 'closed';
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Bar Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Support & CRM Center", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: SAMStyles.darkNavy)),
                  SizedBox(height: 2),
                  Text("Live chat with restaurant owners. Tickets stay active until resolved or closed.", style: TextStyle(color: SAMStyles.textGrey, fontSize: 12, fontWeight: FontWeight.w500)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _loadTickets(showLoading: true),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text("REFRESH TICKETS", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SAMStyles.royalBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Main Tabs & Status Filters Row
          Row(
            children: [
              SizedBox(
                width: 280,
                child: TabBar(
                  controller: _tabController,
                  labelColor: SAMStyles.royalBlue,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: SAMStyles.royalBlue,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  tabs: const [Tab(text: "Live Tickets"), Tab(text: "Global Broadcast")],
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  _buildFilterChip("Active", "Active Tickets"),
                  const SizedBox(width: 6),
                  _buildFilterChip("Resolved", "Resolved / Closed"),
                  const SizedBox(width: 6),
                  _buildFilterChip("All", "All Requests"),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Main Split Content View
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: SAMStyles.royalBlue))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTicketSplitView(),
                      const Center(child: Text("Broadcast Center Ready.", style: TextStyle(color: SAMStyles.textGrey, fontWeight: FontWeight.bold))),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String labelText) {
    bool isSel = _statusFilter == filterKey;
    int count = filterKey == 'Active'
        ? _tickets.where((t) => (t['status'] ?? '').toString().toLowerCase() != 'resolved' && (t['status'] ?? '').toString().toLowerCase() != 'closed').length
        : filterKey == 'Resolved'
            ? _tickets.where((t) => (t['status'] ?? '').toString().toLowerCase() == 'resolved' || (t['status'] ?? '').toString().toLowerCase() == 'closed').length
            : _tickets.length;

    return ChoiceChip(
      label: Text(
        "$labelText ($count)",
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isSel ? Colors.white : Colors.black87,
        ),
      ),
      selected: isSel,
      onSelected: (val) {
        if (val) setState(() => _statusFilter = filterKey);
      },
      selectedColor: SAMStyles.royalBlue,
      backgroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: isSel ? SAMStyles.royalBlue : Colors.grey.shade300),
      ),
    );
  }

  Widget _buildTicketSplitView() {
    final filtered = _filteredTickets;

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mark_email_read_outlined, size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              _statusFilter == 'Active'
                  ? "No active support tickets."
                  : "No tickets found under '$_statusFilter'",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: SAMStyles.darkNavy),
            ),
            const SizedBox(height: 4),
            const Text(
              "When restaurant owners submit support tickets, they will stay active here for live chat.",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => _loadTickets(showLoading: true),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text("RECHECK TICKETS", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                foregroundColor: SAMStyles.royalBlue,
                side: const BorderSide(color: SAMStyles.royalBlue),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Ticket List Left Panel
        SizedBox(
          width: 320,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: SAMStyles.softShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Text(
                    "Tickets (${filtered.length})",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
                    itemBuilder: (context, index) {
                      final t = filtered[index];
                      bool isSel = _selectedTicket?['id'].toString() == t['id'].toString();
                      Color stColor = _getStatusColor(t['status']);
                      String resName = (t['restaurant_name'] != null && t['restaurant_name'].toString().isNotEmpty)
                          ? t['restaurant_name'].toString()
                          : 'Restaurant #${t['tenant_id']}';

                      return ListTile(
                        onTap: () {
                          setState(() => _selectedTicket = t);
                          _loadChatHistory(t['id']);
                        },
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        tileColor: isSel ? SAMStyles.royalBlue.withValues(alpha: 0.08) : null,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: stColor.withValues(alpha: 0.12),
                          child: Icon(
                            t['priority'] == 'Urgent' ? Icons.flash_on_rounded : Icons.confirmation_num_outlined,
                            color: stColor,
                            size: 16,
                          ),
                        ),
                        title: Text(
                          resName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: isSel ? FontWeight.w900 : FontWeight.bold,
                            fontSize: 13,
                            color: isSel ? SAMStyles.royalBlue : SAMStyles.darkNavy,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            t['subject'] ?? 'No Subject',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.black87),
                          ),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: stColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                (t['status'] ?? 'Open').toString().toUpperCase(),
                                style: TextStyle(color: stColor, fontSize: 8, fontWeight: FontWeight.w900),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              t['created_at'] != null ? t['created_at'].toString().split(' ')[0] : '',
                              style: const TextStyle(fontSize: 9, color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),

        // Chat View Right Panel
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: SAMStyles.softShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildChatHeader(),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                Expanded(child: _buildChatBody()),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
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
    String resName = (_selectedTicket!['restaurant_name'] != null && _selectedTicket!['restaurant_name'].toString().isNotEmpty)
        ? _selectedTicket!['restaurant_name'].toString()
        : 'Restaurant #${_selectedTicket!['tenant_id']}';
    String currentStatus = _selectedTicket!['status'] ?? 'Open';
    Color stColor = _getStatusColor(currentStatus);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: SAMStyles.royalBlue.withValues(alpha: 0.1),
            child: Text(
              resName.isNotEmpty ? resName[0].toUpperCase() : 'R',
              style: const TextStyle(color: SAMStyles.royalBlue, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(resName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: SAMStyles.darkNavy)),
                const SizedBox(height: 2),
                Text(
                  "Subject: ${_selectedTicket!['subject'] ?? 'No Subject'} • Priority: ${_selectedTicket!['priority'] ?? 'Medium'}",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: SAMStyles.textGrey, fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),

          // Status Selector Popup Menu
          PopupMenuButton<String>(
            tooltip: "Change Ticket Status",
            onSelected: (newSt) => _updateTicketStatus(newSt),
            itemBuilder: (ctx) => ['Open', 'In Progress', 'Urgent', 'Resolved', 'Closed'].map((st) {
              return PopupMenuItem(
                value: st,
                child: Row(
                  children: [
                    Icon(
                      st == currentStatus ? Icons.check_circle : Icons.circle_outlined,
                      size: 16,
                      color: _getStatusColor(st),
                    ),
                    const SizedBox(width: 8),
                    Text(st, style: TextStyle(fontWeight: st == currentStatus ? FontWeight.bold : FontWeight.normal, fontSize: 12)),
                  ],
                ),
              );
            }).toList(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: stColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: stColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 8, color: stColor),
                  const SizedBox(width: 6),
                  Text(
                    currentStatus.toUpperCase(),
                    style: TextStyle(color: stColor, fontSize: 10, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_drop_down, size: 16, color: stColor),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatBody() {
    if (_selectedTicket == null) {
      return const Center(
        child: Text("Select a ticket to view details.", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
      );
    }
    if (_isChatLoading && _chatHistory.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: SAMStyles.royalBlue));
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(16)),
            child: Text(
              "Ticket Created on ${_selectedTicket!['created_at'] ?? 'N/A'}",
              style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Original Ticket Request Description from Restaurant
        _buildMessageBubble(
          text: _selectedTicket!['description'] ?? "No details provided.",
          isMe: false,
          subtitle: "Original Request from Restaurant Owner",
        ),

        if (_chatHistory.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: Text(
                "CHAT HISTORY & REPLIES",
                style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
            ),
          ),
          ..._chatHistory.map((m) => _buildMessageBubble(
                text: m['message'] ?? '',
                isMe: m['sender_type'] == 'Admin' || m['sender_type'] == 'SuperAdmin',
                subtitle: m['created_at'] ?? '',
              )),
        ],
      ],
    );
  }

  Widget _buildMessageBubble({required String text, required bool isMe, required String subtitle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe)
            CircleAvatar(
              radius: 12,
              backgroundColor: Colors.grey[200],
              child: const Icon(Icons.store_rounded, size: 12, color: Colors.grey),
            ),
          if (!isMe) const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe ? SAMStyles.royalBlue : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(14),
                      topRight: const Radius.circular(14),
                      bottomLeft: isMe ? const Radius.circular(14) : Radius.zero,
                      bottomRight: isMe ? Radius.zero : const Radius.circular(14),
                    ),
                    border: Border.all(color: isMe ? SAMStyles.royalBlue : const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: isMe ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 8),
          if (isMe)
            CircleAvatar(
              radius: 12,
              backgroundColor: SAMStyles.royalBlue.withValues(alpha: 0.1),
              child: const Icon(Icons.admin_panel_settings_rounded, size: 12, color: SAMStyles.royalBlue),
            ),
        ],
      ),
    );
  }

  Widget _buildChatInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                controller: _replyController,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  hintText: "Type your reply to the restaurant owner...",
                  hintStyle: TextStyle(fontSize: 12, color: Colors.grey),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
                onSubmitted: (_) => _handleSendReply(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            height: 40,
            width: 40,
            decoration: const BoxDecoration(color: SAMStyles.royalBlue, shape: BoxShape.circle),
            child: IconButton(
              onPressed: _handleSendReply,
              icon: const Icon(Icons.send_rounded, size: 16, color: Colors.white),
              tooltip: "Send Reply",
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.trim().toLowerCase()) {
      case 'open':
        return Colors.blue;
      case 'in progress':
        return Colors.orange;
      case 'urgent':
        return Colors.red;
      case 'resolved':
      case 'closed':
        return Colors.green;
      default:
        return Colors.orange;
    }
  }
}
