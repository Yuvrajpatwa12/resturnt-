import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/tenant_service.dart';
import '../admin_theme.dart';

class SupportTicketScreen extends StatefulWidget {
  const SupportTicketScreen({super.key});

  @override
  State<SupportTicketScreen> createState() => _SupportTicketScreenState();
}

class _SupportTicketScreenState extends State<SupportTicketScreen> {
  final _subjectController = TextEditingController();
  final _descController = TextEditingController();
  final _replyController = TextEditingController();
  String _selectedPriority = 'Medium';
  bool _isSubmitting = false;
  bool _isLoading = true;
  bool _isChatLoading = false;
  bool _showNewTicketForm = false;
  List<Map<String, dynamic>> _myTickets = [];
  Map<String, dynamic>? _selectedTicket;
  List<Map<String, dynamic>> _chatHistory = [];

  @override
  void initState() {
    super.initState();
    _loadMyTickets();
  }

  Future<void> _loadMyTickets() async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return;
    
    setState(() => _isLoading = true);
    final data = await ApiService.fetchMyTickets(tenant.id);
    if (data != null) {
      setState(() {
        _myTickets = data;
        // Auto-select first ticket if none selected
        if (_myTickets.isNotEmpty && _selectedTicket == null) {
          _selectedTicket = _myTickets.first;
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

  Future<void> _submitTicket() async {
    if (_subjectController.text.isEmpty || _descController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all fields.")));
      return;
    }

    setState(() => _isSubmitting = true);
    final tenant = TenantService().currentTenant.value;
    
    final success = await ApiService.createSupportTicket({
      'tenant_id': tenant?.id,
      'subject': _subjectController.text.trim(),
      'description': _descController.text.trim(),
      'priority': _selectedPriority,
    });

    setState(() => _isSubmitting = false);

    if (success && mounted) {
      _subjectController.clear();
      _descController.clear();
      _showNewTicketForm = false;
      _loadMyTickets();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ticket sent successfully!"), backgroundColor: Colors.green));
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to send ticket."), backgroundColor: Colors.red));
    }
  }

  Future<void> _handleSendReply() async {
    if (_replyController.text.isEmpty || _selectedTicket == null) return;

    final msg = _replyController.text.trim();
    final ticketId = int.parse(_selectedTicket!['id'].toString());

    _replyController.clear();
    final success = await ApiService.sendTicketReply(
      ticketId: ticketId, 
      message: msg,
      senderType: 'Tenant',
    );
    
    if (success && mounted) {
      _loadChatHistory(ticketId);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to send reply.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopBar(),
            const SizedBox(height: 32),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Side: Ticket List
                  Expanded(
                    flex: 3,
                    child: _buildTicketListPanel(),
                  ),
                  const SizedBox(width: 32),
                  // Right Side: Chat or Form
                  Expanded(
                    flex: 7,
                    child: _showNewTicketForm ? _buildTicketForm() : _buildChatPanel(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Support & Help Center", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AdminTheme.darkNavy)),
            Text(_showNewTicketForm ? "Create a new support request" : "Chat with our support team in real-time.", style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
        ElevatedButton.icon(
          onPressed: () => setState(() {
            _showNewTicketForm = !_showNewTicketForm;
            if (_showNewTicketForm) _selectedTicket = null;
          }),
          icon: Icon(_showNewTicketForm ? Icons.chat_bubble_outline : Icons.add, size: 18),
          label: Text(_showNewTicketForm ? "BACK TO CHAT" : "NEW TICKET"),
          style: ElevatedButton.styleFrom(
            backgroundColor: _showNewTicketForm ? AdminTheme.darkNavy : const Color(0xFFFF5C00),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ],
    );
  }

  Widget _buildTicketListPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AdminTheme.softShadow,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Your Tickets", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                IconButton(onPressed: _loadMyTickets, icon: const Icon(Icons.refresh, size: 20, color: AdminTheme.royalBlue)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _myTickets.isEmpty
                  ? const Center(child: Text("No tickets yet."))
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      itemCount: _myTickets.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, indent: 24, endIndent: 24),
                      itemBuilder: (context, index) {
                        final t = _myTickets[index];
                        bool isSelected = _selectedTicket?['id'] == t['id'];
                        return ListTile(
                          onTap: () {
                            setState(() {
                              _selectedTicket = t;
                              _showNewTicketForm = false;
                            });
                            _loadChatHistory(t['id']);
                          },
                          selected: isSelected,
                          selectedTileColor: const Color(0xFFF1F5F9),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: _getStatusColor(t['status']).withValues(alpha: 0.1),
                            child: Icon(Icons.confirmation_num_outlined, color: _getStatusColor(t['status']), size: 18),
                          ),
                          title: Text(t['subject'], style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, fontSize: 14)),
                          subtitle: Text(t['created_at'], style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 10, color: Colors.grey),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatPanel() {
    if (_selectedTicket == null) {
      return Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: AdminTheme.softShadow),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.chat_bubble_outline_rounded, size: 64, color: Color(0xFFE2E8F0)),
              SizedBox(height: 16),
              Text("Select a ticket to start chatting", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: AdminTheme.softShadow),
      child: Column(
        children: [
          _buildChatHeader(),
          const Divider(height: 1),
          // Chat Body
          Expanded(
            child: _isChatLoading && _chatHistory.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      _buildMessageBubble(text: _selectedTicket!['description'], isMe: true, subtitle: "Original Request", isInitial: true),
                      if (_chatHistory.isNotEmpty) ...[
                        const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Center(child: Text("CHAT HISTORY", style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)))),
                        ..._chatHistory.map((m) => _buildMessageBubble(
                          text: m['message'],
                          isMe: m['sender_type'] == 'Tenant',
                          subtitle: m['created_at'],
                        )),
                      ],
                    ],
                  ),
          ),
          // Chat Input
          _buildChatInput(),
        ],
      ),
    );
  }

  Widget _buildChatHeader() {
    if (_selectedTicket == null) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: _getStatusColor(_selectedTicket!['status']).withValues(alpha: 0.1), child: Icon(Icons.shield_outlined, color: _getStatusColor(_selectedTicket!['status']), size: 20)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_selectedTicket!['subject'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text("Status: ${_selectedTicket!['status']} • Ticket ID: #${_selectedTicket!['id']}", style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          IconButton(onPressed: () => _loadChatHistory(_selectedTicket!['id']), icon: const Icon(Icons.refresh, color: AdminTheme.royalBlue)),
        ],
      ),
    );
  }

  Widget _buildTicketForm() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: AdminTheme.softShadow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Create New Support Request", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          const SizedBox(height: 8),
          const Text("Our team usually responds within 2-4 hours.", style: TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 32),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTextField("Subject", _subjectController, "What is the issue about?"),
                  const SizedBox(height: 24),
                  const Text("Priority Level", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedPriority,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                    items: ['Low', 'Medium', 'High'].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                    onChanged: (v) => setState(() => _selectedPriority = v!),
                  ),
                  const SizedBox(height: 24),
                  _buildTextField("Detailed Description", _descController, "Explain your problem in detail so we can help you faster...", maxLines: 5),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitTicket,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5C00),
                padding: const EdgeInsets.symmetric(vertical: 22),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isSubmitting ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("SUBMIT SUPPORT REQUEST", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble({required String text, required bool isMe, required String subtitle, bool isInitial = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) CircleAvatar(radius: 16, backgroundColor: AdminTheme.royalBlue.withValues(alpha: 0.1), child: const Icon(Icons.admin_panel_settings, size: 16, color: AdminTheme.royalBlue)),
          if (!isMe) const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isMe ? (isInitial ? const Color(0xFFF1F5F9) : const Color(0xFFFF5C00)) : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: isMe ? const Radius.circular(20) : Radius.zero,
                      bottomRight: isMe ? Radius.zero : const Radius.circular(20),
                    ),
                    border: Border.all(color: isMe ? (isInitial ? const Color(0xFFE2E8F0) : const Color(0xFFFF5C00)) : const Color(0xFFE2E8F0)),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 4))],
                  ),
                  child: Text(text, style: TextStyle(fontSize: 15, height: 1.4, color: isMe && !isInitial ? Colors.white : const Color(0xFF1E293B))),
                ),
                const SizedBox(height: 6),
                Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 12),
          if (isMe) CircleAvatar(radius: 16, backgroundColor: isInitial ? Colors.grey[200] : const Color(0xFFFF5C00).withValues(alpha: 0.1), child: Icon(isInitial ? Icons.person : Icons.restaurant, size: 16, color: isInitial ? Colors.grey : const Color(0xFFFF5C00))),
        ],
      ),
    );
  }

  Widget _buildChatInput() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFF1F5F9)))),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _replyController,
              onSubmitted: (_) => _handleSendReply(),
              decoration: InputDecoration(
                hintText: "Write your message to Startups Go...",
                hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            height: 54, width: 54,
            decoration: const BoxDecoration(color: Color(0xFFFF5C00), shape: BoxShape.circle),
            child: IconButton(
              onPressed: _handleSendReply, 
              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 22)
            ),
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

  Widget _buildTextField(String label, TextEditingController controller, String hint, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          ),
        ),
      ],
    );
  }
}
