import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/tenant_service.dart';
import '../admin_theme.dart';

class IngredientStockScreen extends StatefulWidget {
  const IngredientStockScreen({super.key});

  @override
  State<IngredientStockScreen> createState() => _IngredientStockScreenState();
}

class _IngredientStockScreenState extends State<IngredientStockScreen> {
  List<Map<String, dynamic>> _alerts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return;
    
    setState(() => _isLoading = true);
    
    // 1. Fetch real reports from database
    final data = await ApiService.fetchStockReports(tenant.id);
    
    // 2. Mark them as seen to clear badges
    await ApiService.markStockAlertsAsSeen(tenant.id);

    if (mounted) {
      setState(() {
        if (data != null) _alerts = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _resolveAlert(int id, String newStatus) async {
    final res = await ApiService.updateStockReportStatus(id, newStatus);
    if (res['success'] == true) {
      _loadAlerts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Item marked as $newStatus"), backgroundColor: Colors.green),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: _loadAlerts,
        child: Column(
          children: [
            _buildAlertHeader(),
            Expanded(
              child: _alerts.isEmpty 
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(24),
                    itemCount: _alerts.length,
                    itemBuilder: (context, index) => _buildAlertCard(_alerts[index]),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.red[50], shape: BoxShape.circle),
                child: const Icon(Icons.notification_important_rounded, color: Colors.red, size: 20),
              ),
              const SizedBox(width: 12),
              const Text("PENDING KITCHEN REQUESTS", style: TextStyle(color: Colors.red, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 8),
          Text("${_alerts.length} ingredients require your immediate attention.", style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline_rounded, size: 80, color: Colors.green.withValues(alpha: 0.1)),
          const SizedBox(height: 20),
          const Text("ALL CLEAR", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AdminTheme.darkNavy)),
          const Text("No pending stock-out alerts from the kitchen.", style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> a) {
    final urgency = a['urgency'] ?? 'Medium';
    final status = a['status'] ?? 'Requested';
    Color urgencyColor = Colors.orange;
    if (urgency == 'Critical') urgencyColor = Colors.red;
    if (urgency == 'Low') urgencyColor = Colors.blue;

    bool isApproved = status == 'Approved';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 20, offset: const Offset(0, 10))],
        border: Border.all(color: isApproved ? Colors.green.withValues(alpha: 0.3) : urgencyColor.withValues(alpha: 0.1), width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          a['item_name'] ?? 'Unknown Item', 
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: AdminTheme.darkNavy),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: isApproved ? Colors.green.withValues(alpha: 0.1) : urgencyColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(30)),
                        child: Text(isApproved ? "APPROVED" : urgency.toUpperCase(), style: TextStyle(color: isApproved ? Colors.green : urgencyColor, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.person_outline_rounded, size: 12, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text("Reported by: ${a['reported_by']}", style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      const Icon(Icons.access_time_rounded, size: 12, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(a['created_at']?.toString().split(' ')[0] ?? 'Today', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                  if (a['notes'] != null && a['notes'].toString().isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(16)),
                      child: Text(
                        "\"${a['notes']}\"", 
                        style: const TextStyle(fontSize: 13, color: Colors.blueGrey, fontStyle: FontStyle.italic, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  _buildVisualStaper(status),
                ],
              ),
            ),
            if (!isApproved)
              Container(
                width: double.infinity,
                height: 60,
                decoration: BoxDecoration(color: AdminTheme.royalBlue.withValues(alpha: 0.02), border: Border(top: BorderSide(color: AdminTheme.royalBlue.withValues(alpha: 0.05)))),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _resolveAlert(int.parse(a['id'].toString()), 'Approved'),
                    child: const Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_rounded, color: AdminTheme.royalBlue, size: 18),
                          const SizedBox(width: 10),
                          const Text("APPROVE ORDER", style: TextStyle(color: AdminTheme.royalBlue, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                height: 60,
                color: Colors.green.withValues(alpha: 0.05),
                child: const Center(
                  child: Text("WAITING FOR WAITER RECEIPT", style: TextStyle(color: Colors.green, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisualStaper(String currentStatus) {
    bool isRequested = true;
    bool isApproved = currentStatus == 'Approved' || currentStatus == 'Received';
    bool isReceived = currentStatus == 'Received';

    return Row(
      children: [
        _buildStaperNode("Pending Approval", isRequested, isApproved),
        _buildStaperLine(isApproved),
        _buildStaperNode("Admin Approved", isApproved, isReceived),
        _buildStaperLine(isReceived),
        _buildStaperNode("Saman Aa Gaya", isReceived, false),
      ],
    );
  }

  Widget _buildStaperNode(String label, bool isActive, bool isNextActive) {
    return Column(
      children: [
        Container(
          width: 24, height: 24,
          decoration: BoxDecoration(
            color: isActive ? (isNextActive ? Colors.green : AdminTheme.royalBlue) : Colors.grey[200],
            shape: BoxShape.circle,
          ),
          child: Icon(
            isNextActive ? Icons.check : (isActive ? Icons.radio_button_checked : Icons.radio_button_off),
            color: isActive ? Colors.white : Colors.grey[400],
            size: 14,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: isActive ? AdminTheme.darkNavy : Colors.grey)),
      ],
    );
  }

  Widget _buildStaperLine(bool isActive) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 12),
        color: isActive ? Colors.green : Colors.grey[200],
      ),
    );
  }
}
