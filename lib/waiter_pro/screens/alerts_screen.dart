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
  List<Map<String, dynamic>> _voiceOrders = [];
  final Set<String> _dismissedVoiceOrderIds = {};
  bool _isLoading = true;
  int? _playingIndex;

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
    final voiceData = await ApiService.fetchVoiceOrders(tenant.id);

    if (mounted) {
      setState(() {
        if (data != null) _stockAlerts = data;
        if (voiceData != null) {
          _voiceOrders = voiceData.where((v) => !_dismissedVoiceOrderIds.contains(v['id']?.toString())).toList();
        }
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

  Future<void> _completeVoiceOrder(dynamic rawId) async {
    final String strId = rawId?.toString() ?? '';
    if (strId.isEmpty || strId == 'null') return;

    // Instantly & permanently remove from UI
    setState(() {
      _dismissedVoiceOrderIds.add(strId);
      _voiceOrders.removeWhere((v) => (v['id']?.toString() ?? '') == strId);
    });

    final int id = int.tryParse(strId) ?? 0;
    if (id > 0) {
      ApiService.deleteVoiceOrder(id);
      ApiService.updateVoiceOrderStatus(id, 'Completed');
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Request OK! Permanently deleted from database."),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final realVoiceOrders = _voiceOrders.where((v) {
      final t = (v['transcript'] ?? '').toString();
      return !t.startsWith('ASSISTANCE:');
    }).toList();

    final assistanceCalls = _voiceOrders.where((v) {
      final t = (v['transcript'] ?? '').toString();
      return t.startsWith('ASSISTANCE:');
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Service & Voice Alerts"),
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
                // VOICE ORDERS SECTION (ONLY REAL VOICE ORDERS)
                if (realVoiceOrders.isNotEmpty) ...[
                  const Text("LIVE CUSTOMER VOICE ORDERS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF4C6FFF), letterSpacing: 1)),
                  const SizedBox(height: 12),
                  ...realVoiceOrders.asMap().entries.map((entry) => _buildVoiceOrderCard(entry.key, entry.value)),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 24),
                ],

                // SERVICE NOTIFICATIONS & ASSISTANCE CALLS
                if (assistanceCalls.isNotEmpty) ...[
                  const Text("SERVICE NOTIFICATIONS & ASSISTANCE CALLS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
                  const SizedBox(height: 12),
                  ...assistanceCalls.map((a) => _buildAssistanceAlertCard(a)),
                  const SizedBox(height: 16),
                ],

                if (_stockAlerts.isNotEmpty) ...[
                  const Text("KITCHEN STOCK REQUESTS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
                  const SizedBox(height: 12),
                  ..._stockAlerts.map((a) => _buildStockAlertCard(a)),
                  const SizedBox(height: 16),
                ],

                if (realVoiceOrders.isEmpty && assistanceCalls.isEmpty && _stockAlerts.isEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 40),
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Column(
                      children: const [
                        Icon(Icons.notifications_off_rounded, size: 48, color: Colors.grey),
                        SizedBox(height: 12),
                        Text(
                          "No Active Alerts",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: WaiterProTheme.darkNavy),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Customer assistance calls and voice orders will appear here live.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
    );
  }

  Widget _buildAssistanceAlertCard(Map<String, dynamic> v) {
    final String table = v['table_number']?.toString() ?? '1';
    final String name = v['customer_name'] ?? 'Guest Diner';
    String text = (v['transcript'] ?? 'Assistance requested').toString();
    if (text.startsWith('ASSISTANCE:')) {
      text = text.replaceFirst('ASSISTANCE:', '').trim();
    }

    IconData icon = Icons.notifications_active_rounded;
    Color iconColor = WaiterProTheme.emeraldGreen;

    final lowerText = text.toLowerCase();
    if (lowerText.contains('water')) {
      icon = Icons.water_drop_rounded;
      iconColor = Colors.blue;
    } else if (lowerText.contains('bill')) {
      icon = Icons.receipt_long_rounded;
      iconColor = Colors.purple;
    } else if (lowerText.contains('clean')) {
      icon = Icons.cleaning_services_rounded;
      iconColor = Colors.teal;
    } else if (lowerText.contains('cutlery') || lowerText.contains('sauce')) {
      icon = Icons.flatware_rounded;
      iconColor = Colors.deepOrange;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: iconColor.withValues(alpha: 0.1),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text("Table $table • $name", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(text, style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w500)),
        ),
        trailing: ElevatedButton.icon(
          onPressed: () => _completeVoiceOrder(v['id']),
          icon: const Icon(Icons.check_circle_rounded, size: 16),
          label: const Text("OK", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            minimumSize: const Size(65, 32),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
    );
  }

  Widget _buildVoiceOrderCard(int index, Map<String, dynamic> v) {
    final String table = v['table_number']?.toString() ?? '1';
    final String name = v['customer_name'] ?? 'Guest Diner';
    final String transcript = v['transcript'] ?? 'Voice Order Message';
    final bool isPlaying = _playingIndex == index;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF6B8CFF).withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4C6FFF).withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Color(0xFF4C6FFF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.record_voice_over_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Table $table • $name", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: WaiterProTheme.darkNavy)),
                      const Text("Recorded Voice Command", style: TextStyle(fontSize: 10, color: Color(0xFF4C6FFF), fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDF2FD),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text("VOICE AI", style: TextStyle(color: Color(0xFF4C6FFF), fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                "\"$transcript\"",
                style: const TextStyle(color: Colors.black87, fontSize: 13, fontStyle: FontStyle.italic, height: 1.3),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _playingIndex = isPlaying ? null : index;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isPlaying ? "Audio paused" : "Playing Table $table Voice Recording..."),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: Icon(isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded, size: 16),
                  label: Text(isPlaying ? "PAUSE" : "PLAY VOICE", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPlaying ? Colors.orange : const Color(0xFF4C6FFF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _completeVoiceOrder(v['id']),
                  icon: const Icon(Icons.check_circle_rounded, size: 16),
                  label: const Text("OK, DONE", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                ),
              ],
            ),
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


}
