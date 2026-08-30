import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/tenant_service.dart';
import '../theme.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  List<Map<String, dynamic>> _stockAlerts = [];
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
    final data = await ApiService.fetchStockReports(tenant.id);
    if (mounted) {
      setState(() {
        if (data != null) _stockAlerts = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _markReceived(int id) async {
    final res = await ApiService.updateStockReportStatus(id, 'Received');
    if (res['success'] == true) {
      _loadAlerts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Saman Received! Alert Closed."), backgroundColor: Colors.green),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Service & Stock Alerts"),
        actions: [
          IconButton(onPressed: _loadAlerts, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadAlerts,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_stockAlerts.isNotEmpty) ...[
                  const Text("KITCHEN STOCK REQUESTS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
                  const SizedBox(height: 12),
                  ..._stockAlerts.map((a) => _buildStockAlertCard(a)),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 24),
                ],
                const Text("SERVICE NOTIFICATIONS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
                const SizedBox(height: 12),
                _buildDemoServiceAlert("Order Ready - Table 104", "All items for Order #CH-981 are ready to serve.", true),
                _buildDemoServiceAlert("Customer Call - Table 205", "Guest is requesting assistance at the table.", false),
              ],
            ),
          ),
    );
  }

  Widget _buildStockAlertCard(Map<String, dynamic> a) {
    final status = a['status'] ?? 'Requested';
    final isApproved = status == 'Approved';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isApproved ? Colors.green.withValues(alpha: 0.02) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isApproved ? Colors.green.withValues(alpha: 0.3) : const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isApproved ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                  child: Icon(Icons.inventory_2_rounded, color: isApproved ? Colors.green : Colors.orange, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a['item_name'] ?? 'Item', style: const TextStyle(fontWeight: FontWeight.w900, color: WaiterProTheme.darkNavy)),
                      Text(isApproved ? "Approved by Admin" : "Waiting for Admin Approval", 
                           style: TextStyle(fontSize: 10, color: isApproved ? Colors.green : Colors.grey, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                if (isApproved)
                  ElevatedButton(
                    onPressed: () => _markReceived(int.parse(a['id'].toString())),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      minimumSize: const Size(80, 30),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text("RECEIVED", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  )
                else
                  const Icon(Icons.hourglass_empty_rounded, size: 16, color: Colors.grey),
              ],
            ),
            if (a['notes'] != null && a['notes'].toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text("Note: ${a['notes']}", style: const TextStyle(fontSize: 11, color: Colors.blueGrey, fontStyle: FontStyle.italic)),
            ],
            const SizedBox(height: 16),
            _buildVisualStaper(status),
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
          width: 20, height: 20,
          decoration: BoxDecoration(
            color: isActive ? (isNextActive ? Colors.green : WaiterProTheme.royalBlue) : Colors.grey[200],
            shape: BoxShape.circle,
          ),
          child: Icon(
            isNextActive ? Icons.check : (isActive ? Icons.radio_button_checked : Icons.radio_button_off),
            color: isActive ? Colors.white : Colors.grey[400],
            size: 10,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: isActive ? WaiterProTheme.darkNavy : Colors.grey)),
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

  Widget _buildDemoServiceAlert(String title, String sub, bool isKitchen) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isKitchen ? Colors.orange.withValues(alpha: 0.1) : WaiterProTheme.emeraldGreen.withValues(alpha: 0.1),
          child: Icon(isKitchen ? Icons.restaurant : Icons.notifications_active, color: isKitchen ? Colors.orange : WaiterProTheme.emeraldGreen, size: 18),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        subtitle: Text(sub, style: const TextStyle(fontSize: 11)),
        trailing: const Text("2m ago", style: TextStyle(fontSize: 10, color: Colors.grey)),
      ),
    );
  }
}
