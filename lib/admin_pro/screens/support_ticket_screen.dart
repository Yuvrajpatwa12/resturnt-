import 'dart:async';
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
  String _selectedCategory = 'POS & Billing';
  String _listFilter = 'All';

  bool _isSubmitting = false;
  bool _isLoading = true;
  bool _isChatLoading = false;
  bool _showNewTicketForm = false;

  List<Map<String, dynamic>> _myTickets = [];
  Map<String, dynamic>? _selectedTicket;
  List<Map<String, dynamic>> _chatHistory = [];

  final List<String> _categories = [
    'POS & Billing',
    'General Inquiry',
    'Hardware / Printer',
    'Account & License',
    'Feature Request',
  ];

  final List<Map<String, dynamic>> _priorities = [
    {'name': 'Low', 'color': Colors.green, 'icon': Icons.arrow_downward_rounded},
    {'name': 'Medium', 'color': Colors.orange, 'icon': Icons.remove_rounded},
    {'name': 'High', 'color': Colors.deepOrange, 'icon': Icons.arrow_upward_rounded},
    {'name': 'Urgent', 'color': Colors.red, 'icon': Icons.flash_on_rounded},
  ];

  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadMyTickets(showLoading: true);
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _subjectController.dispose();
    _descController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      _loadMyTickets(showLoading: false);
      if (_selectedTicket != null) {
        _loadChatHistory(_selectedTicket!['id'], showLoading: false);
      }
    });
  }

  Future<void> _loadMyTickets({bool showLoading = true}) async {
    final tenant = TenantService().currentTenant.value;
    final tenantId = tenant?.id ?? '1';

    if (showLoading) setState(() => _isLoading = true);
    final data = await ApiService.fetchMyTickets(tenantId);
    if (mounted) {
      if (data != null) {
        setState(() {
          _myTickets = data;
          if (_myTickets.isNotEmpty && _selectedTicket == null && !_showNewTicketForm) {
            _selectedTicket = _myTickets.first;
            _loadChatHistory(_selectedTicket!['id'], showLoading: showLoading);
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

  Future<void> _submitTicket() async {
    if (_subjectController.text.trim().isEmpty || _descController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter both Subject and Detailed Description."),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final tenant = TenantService().currentTenant.value;
    final tenantId = tenant?.id ?? '1';

    final fullSubject = "[$_selectedCategory] ${_subjectController.text.trim()}";

    final res = await ApiService.createSupportTicket({
      'tenant_id': tenantId,
      'subject': fullSubject,
      'description': _descController.text.trim(),
      'priority': _selectedPriority,
    });

    setState(() => _isSubmitting = false);

    if (res['success'] == true && mounted) {
      _subjectController.clear();
      _descController.clear();
      setState(() {
        _showNewTicketForm = false;
      });
      _loadMyTickets();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Support request submitted successfully!"),
          backgroundColor: AdminTheme.emeraldGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? "Failed to submit support request. Please try again."),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
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
      senderType: 'Tenant',
    );

    if (success && mounted) {
      _loadChatHistory(ticketId);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to send reply."),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  List<Map<String, dynamic>> get _filteredTickets {
    if (_listFilter == 'All') return _myTickets;
    return _myTickets.where((t) {
      final st = (t['status'] ?? '').toString().toLowerCase();
      if (_listFilter == 'Open') return st == 'open' || st == 'pending' || st == 'urgent';
      if (_listFilter == 'Resolved') return st == 'resolved' || st == 'closed';
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopBar(),
            const SizedBox(height: 20),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  bool isNarrow = constraints.maxWidth < 900;
                  if (isNarrow) {
                    return Column(
                      children: [
                        SizedBox(
                          height: 200,
                          child: _buildTicketListPanel(),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: _showNewTicketForm ? _buildTicketForm() : _buildChatPanel(),
                        ),
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Side: Ticket List
                      SizedBox(
                        width: 320,
                        child: _buildTicketListPanel(),
                      ),
                      const SizedBox(width: 24),
                      // Right Side: Ticket Form or Chat Thread
                      Expanded(
                        child: _showNewTicketForm ? _buildTicketForm() : _buildChatPanel(),
                      ),
                    ],
                  );
                },
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
            const Text(
              "Support & Help Center",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: AdminTheme.darkNavy,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _showNewTicketForm
                  ? "Fill in details below to submit a new ticket"
                  : "View active tickets and chat with our technical support team.",
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        ElevatedButton.icon(
          onPressed: () => setState(() {
            _showNewTicketForm = !_showNewTicketForm;
            if (_showNewTicketForm) _selectedTicket = null;
          }),
          icon: Icon(
            _showNewTicketForm ? Icons.chat_bubble_outline_rounded : Icons.add_rounded,
            size: 18,
          ),
          label: Text(
            _showNewTicketForm ? "BACK TO CHAT" : "CREATE NEW TICKET",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _showNewTicketForm ? AdminTheme.darkNavy : const Color(0xFFFF5C00),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ],
    );
  }

  Widget _buildTicketListPanel() {
    final tickets = _filteredTickets;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: AdminTheme.softShadow,
      ),
      child: Column(
        children: [
          // Header & Refresh
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      "Your Tickets",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AdminTheme.darkNavy),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AdminTheme.royalBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "${_myTickets.length}",
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AdminTheme.royalBlue),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: _loadMyTickets,
                  icon: const Icon(Icons.refresh_rounded, size: 20, color: AdminTheme.royalBlue),
                  tooltip: "Refresh Tickets",
                ),
              ],
            ),
          ),

          // Filter Pills
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: ['All', 'Open', 'Resolved'].map((f) {
                bool isSel = _listFilter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: () => setState(() => _listFilter = f),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSel ? AdminTheme.royalBlue : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        f,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isSel ? Colors.white : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),

          // Ticket List items
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AdminTheme.royalBlue))
                : tickets.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.confirmation_number_outlined, size: 40, color: Colors.grey.shade300),
                            const SizedBox(height: 8),
                            Text(
                              "No tickets found.",
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: tickets.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
                        itemBuilder: (context, index) {
                          final t = tickets[index];
                          bool isSelected = _selectedTicket?['id'] == t['id'] && !_showNewTicketForm;
                          Color stColor = _getStatusColor(t['status']);

                          return ListTile(
                            onTap: () {
                              setState(() {
                                _selectedTicket = t;
                                _showNewTicketForm = false;
                              });
                              _loadChatHistory(t['id']);
                            },
                            selected: isSelected,
                            selectedTileColor: AdminTheme.royalBlue.withValues(alpha: 0.08),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: stColor.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.confirmation_num_outlined, color: stColor, size: 18),
                            ),
                            title: Text(
                              t['subject'] ?? 'Support Request',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                                fontSize: 13,
                                color: isSelected ? AdminTheme.royalBlue : Colors.black87,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: stColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      (t['status'] ?? 'Open').toString().toUpperCase(),
                                      style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: stColor),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      t['created_at'] ?? '',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketForm() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: AdminTheme.softShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF5C00).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.support_agent_rounded, color: Color(0xFFFF5C00), size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Create New Support Request",
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AdminTheme.darkNavy),
                      ),
                      SizedBox(height: 2),
                      Text(
                        "Our dedicated technical support team usually responds within 2-4 hours.",
                        style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(height: 1),
              const SizedBox(height: 24),

              // 1. Select Category
              const Text(
                "Select Issue Category",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AdminTheme.darkNavy),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories.map((cat) {
                  bool isSel = _selectedCategory == cat;
                  return ChoiceChip(
                    label: Text(
                      cat,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isSel ? Colors.white : Colors.black87,
                      ),
                    ),
                    selected: isSel,
                    onSelected: (val) {
                      if (val) setState(() => _selectedCategory = cat);
                    },
                    selectedColor: AdminTheme.royalBlue,
                    backgroundColor: const Color(0xFFF8FAFC),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: isSel ? AdminTheme.royalBlue : Colors.grey.shade300,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // 2. Subject
              const Text(
                "Subject",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AdminTheme.darkNavy),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _subjectController,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: "e.g., Thermal POS printer disconnected or Kitchen display frozen",
                  hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                  prefixIcon: const Icon(Icons.title_rounded, size: 20, color: AdminTheme.royalBlue),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AdminTheme.royalBlue, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 3. Priority Selector
              const Text(
                "Priority Level",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AdminTheme.darkNavy),
              ),
              const SizedBox(height: 10),
              Row(
                children: _priorities.map((p) {
                  String pName = p['name'];
                  Color pColor = p['color'];
                  IconData pIcon = p['icon'];
                  bool isSel = _selectedPriority == pName;

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: InkWell(
                        onTap: () => setState(() => _selectedPriority = pName),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isSel ? pColor.withValues(alpha: 0.12) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSel ? pColor : Colors.grey.shade300,
                              width: isSel ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(pIcon, size: 16, color: isSel ? pColor : Colors.grey),
                              const SizedBox(width: 6),
                              Text(
                                pName,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isSel ? pColor : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // 4. Detailed Description
              const Text(
                "Detailed Description",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AdminTheme.darkNavy),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descController,
                maxLines: 5,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: "Explain your issue step by step so our engineering team can reproduce and resolve it quickly...",
                  hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.all(16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AdminTheme.royalBlue, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submitTicket,
                  icon: _isSubmitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(
                    _isSubmitting ? "SUBMITTING REQUEST..." : "SUBMIT SUPPORT REQUEST",
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5C00),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatPanel() {
    if (_selectedTicket == null) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: AdminTheme.softShadow,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.mark_unread_chat_alt_outlined, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              const Text(
                "Select a ticket from the left panel to start chatting",
                style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => setState(() => _showNewTicketForm = true),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text("OR CREATE NEW TICKET"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFF5C00),
                  side: const BorderSide(color: Color(0xFFFF5C00)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: AdminTheme.softShadow,
      ),
      child: Column(
        children: [
          _buildChatHeader(),
          const Divider(height: 1),
          Expanded(
            child: _isChatLoading && _chatHistory.isEmpty
                ? const Center(child: CircularProgressIndicator(color: AdminTheme.royalBlue))
                : ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _buildMessageBubble(
                        text: _selectedTicket!['description'] ?? '',
                        isMe: true,
                        subtitle: "Original Support Request • ${_selectedTicket!['created_at'] ?? ''}",
                        isInitial: true,
                      ),
                      if (_chatHistory.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: Text(
                              "TICKET HISTORY & REPLIES",
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                        ..._chatHistory.map((m) => _buildMessageBubble(
                          text: m['message'] ?? '',
                          isMe: m['sender_type'] == 'Tenant',
                          subtitle: m['created_at'] ?? '',
                        )),
                      ],
                    ],
                  ),
          ),
          _buildChatInput(),
        ],
      ),
    );
  }

  Widget _buildChatHeader() {
    if (_selectedTicket == null) return const SizedBox();
    Color stColor = _getStatusColor(_selectedTicket!['status']);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: stColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.shield_outlined, color: stColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedTicket!['subject'] ?? 'Ticket Details',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AdminTheme.darkNavy),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: stColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        (_selectedTicket!['status'] ?? 'Open').toString().toUpperCase(),
                        style: TextStyle(color: stColor, fontSize: 9, fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Ticket ID: #${_selectedTicket!['id']} • Priority: ${_selectedTicket!['priority'] ?? 'Medium'}",
                      style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _loadChatHistory(_selectedTicket!['id']),
            icon: const Icon(Icons.refresh_rounded, color: AdminTheme.royalBlue),
            tooltip: "Refresh Chat",
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble({
    required String text,
    required bool isMe,
    required String subtitle,
    bool isInitial = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe)
            CircleAvatar(
              radius: 16,
              backgroundColor: AdminTheme.royalBlue.withValues(alpha: 0.1),
              child: const Icon(Icons.support_agent_rounded, size: 16, color: AdminTheme.royalBlue),
            ),
          if (!isMe) const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isMe
                        ? (isInitial ? const Color(0xFFF1F5F9) : const Color(0xFFFF5C00))
                        : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                      bottomRight: isMe ? Radius.zero : const Radius.circular(16),
                    ),
                    border: Border.all(
                      color: isMe
                          ? (isInitial ? const Color(0xFFE2E8F0) : const Color(0xFFFF5C00))
                          : const Color(0xFFE2E8F0),
                    ),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 3)),
                    ],
                  ),
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: isMe && !isInitial ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 10),
          if (isMe)
            CircleAvatar(
              radius: 16,
              backgroundColor: isInitial ? Colors.grey[200] : const Color(0xFFFF5C00).withValues(alpha: 0.1),
              child: Icon(
                isInitial ? Icons.person : Icons.store_rounded,
                size: 16,
                color: isInitial ? Colors.grey : const Color(0xFFFF5C00),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChatInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _replyController,
              onSubmitted: (_) => _handleSendReply(),
              decoration: InputDecoration(
                hintText: "Type your reply to tech support...",
                hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            height: 48,
            width: 48,
            decoration: const BoxDecoration(color: Color(0xFFFF5C00), shape: BoxShape.circle),
            child: IconButton(
              onPressed: _handleSendReply,
              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
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
      case 'urgent':
        return Colors.red;
      case 'resolved':
      case 'closed':
        return AdminTheme.emeraldGreen;
      default:
        return Colors.orange;
    }
  }
}
