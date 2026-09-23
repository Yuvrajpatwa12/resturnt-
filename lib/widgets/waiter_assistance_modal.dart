import 'package:flutter/material.dart';
import '../cart_manager.dart';
import '../services/tenant_service.dart';
import '../services/api_service.dart';

class WaiterAssistanceModal extends StatefulWidget {
  const WaiterAssistanceModal({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const WaiterAssistanceModal(),
    );
  }

  @override
  State<WaiterAssistanceModal> createState() => _WaiterAssistanceModalState();
}

class _WaiterAssistanceModalState extends State<WaiterAssistanceModal> {
  String _selectedOption = 'Call Waiter';
  final TextEditingController _notesController = TextEditingController();
  bool _isSending = false;

  final List<Map<String, String>> _assistanceOptions = [
    {
      'title': 'Call Waiter',
      'subtitle': 'General assistance at your table',
      'icon': '🔔',
    },
    {
      'title': 'Water / Refill',
      'subtitle': 'Request fresh drinking water',
      'icon': '🥤',
    },
    {
      'title': 'Request Bill',
      'subtitle': 'Ask waiter to bring final bill',
      'icon': '🧾',
    },
    {
      'title': 'Clean Table',
      'subtitle': 'Table cleaning or extra napkins',
      'icon': '🧹',
    },
    {
      'title': 'Cutlery & Sauces',
      'subtitle': 'Spoons, forks, ketchup, or spices',
      'icon': '🌶️',
    },
    {
      'title': 'Order Query',
      'subtitle': 'Inquire about order status/items',
      'icon': '❓',
    },
  ];

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _sendAssistanceRequest() async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return;

    setState(() => _isSending = true);

    final int tableNum = ShopManager.instance.selectedTableId.value ?? 1;
    final String name = ShopManager.instance.customerName.value.isNotEmpty
        ? ShopManager.instance.customerName.value
        : "Guest Diner";

    final String requestText = "$_selectedOption - ${
        _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : 'Immediate assistance requested'
    }";

    await ApiService.uploadVoiceOrder(
      tenantId: tenant.id,
      tableNumber: tableNum,
      customerName: name,
      transcript: "ASSISTANCE: $requestText",
    );

    setState(() => _isSending = false);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text("Waiter notified for Table $tableNum ($_selectedOption)!"),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF002D62),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final int tableNum = ShopManager.instance.selectedTableId.value ?? 1;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF002D62), Color(0xFF0047AB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF002D62).withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.support_agent_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        "Need Waiter Assistance?",
                        style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 2),
                      Text(
                        "1-Tap quick actions notify your waiter instantly.",
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "Table #$tableNum",
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // Quick Action Options List
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "SELECT ASSISTANCE TYPE:",
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1),
                  ),
                  const SizedBox(height: 12),
                  ..._assistanceOptions.map((opt) {
                    final isSelected = _selectedOption == opt['title'];
                    return GestureDetector(
                      onTap: () => setState(() => _selectedOption = opt['title']!),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF002D62).withValues(alpha: 0.05) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF002D62) : const Color(0xFFE2E8F0),
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Text(opt['icon']!, style: const TextStyle(fontSize: 22)),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    opt['title']!,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: isSelected ? const Color(0xFF002D62) : Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    opt['subtitle']!,
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            Radio<String>(
                              value: opt['title']!,
                              groupValue: _selectedOption,
                              activeColor: const Color(0xFF002D62),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedOption = val);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 12),
                  // Optional Note Field
                  TextField(
                    controller: _notesController,
                    decoration: InputDecoration(
                      hintText: "Optional note (e.g. Please bring 2 extra glasses...)",
                      hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Send Request Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSending ? null : _sendAssistanceRequest,
                      icon: _isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.notifications_active_rounded),
                      label: Text(
                        _isSending ? "NOTIFYING WAITER..." : "NOTIFY WAITER NOW",
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF002D62),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
