import 'package:flutter/material.dart';
import '../services/tenant_service.dart';
import '../services/api_service.dart';

class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
  final Color pearlWhite = const Color(0xFFF8FAFC);
  final Color royalBlue = const Color(0xFF0047AB);
  
  List<Tenant> _tenants = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final data = await ApiService.fetchTenants();
    if (data != null) {
      setState(() {
        _tenants = data.map((m) => Tenant.fromMap(m)).toList();
      });
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pearlWhite,
      appBar: AppBar(
        title: const Text('Chiyalaa Super Admin', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: royalBlue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadData,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: CircleAvatar(
              backgroundColor: Colors.white24,
              child: Icon(Icons.person, color: Colors.white),
            ),
          )
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 32),
                _buildMetricsGrid(),
                const SizedBox(height: 32),
                _buildTenantTable(),
                const SizedBox(height: 32),
                _buildAuditLogs(),
              ],
            ),
          ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('System Overview', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: royalBlue)),
        const Text('Manage tenants and monitor global system performance', style: TextStyle(color: Colors.grey)),
      ],
    );
  }

  Widget _buildMetricsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: MediaQuery.of(context).size.width > 900 ? 4 : 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildMetricCard('Total Revenue', 'NPR 1.2M', Icons.payments, Colors.green),
        _buildMetricCard('Active Tenants', _tenants.length.toString(), Icons.business, Colors.blue),
        _buildMetricCard('Storage Used', '850 GB', Icons.storage, Colors.orange),
        _buildMetricCard('System Health', '99.9%', Icons.speed, Colors.purple),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 28),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.grey, fontSize: 14)),
              Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTenantTable() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text('Client Manager', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Name')),
                DataColumn(label: Text('Plan')),
                DataColumn(label: Text('Expiry')),
                DataColumn(label: Text('Storage')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Actions')),
              ],
              rows: _tenants.map((tenant) => DataRow(cells: [
                DataCell(Text(tenant.name, style: const TextStyle(fontWeight: FontWeight.w500))),
                DataCell(Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: royalBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(tenant.plan, style: TextStyle(color: royalBlue, fontSize: 12)),
                )),
                DataCell(Text(tenant.expiry ?? 'N/A')),
                DataCell(Text(tenant.storage ?? '0.0 GB')),
                DataCell(Switch(
                  value: tenant.isActive,
                  activeTrackColor: royalBlue,
                  onChanged: (val) {
                    // Update locally for UI feedback
                    _loadData(); // Re-fetch to sync
                  },
                )),
                DataCell(IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () => _showSubscriptionModal(tenant),
                )),
              ])).toList(),
            ),
          ),
        ],
      ),
    );
  }

  void _showSubscriptionModal(Tenant tenant) {
    String selectedPlan = tenant.plan;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text('Edit Subscription: ${tenant.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedPlan,
                decoration: const InputDecoration(labelText: 'Plan'),
                items: ['Basic', 'Pro', 'Enterprise'].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                onChanged: (val) => setModalState(() => selectedPlan = val!),
              ),
              const SizedBox(height: 16),
              const ListTile(
                title: Text('Note: Expiry updates coming soon'),
                subtitle: Text('Current plan details can be modified here.'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: royalBlue),
              onPressed: () {
                Navigator.pop(context);
                _loadData();
              },
              child: const Text('Save Changes', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuditLogs() {
    final logs = [
      {'action': 'New Client', 'tenant': 'Everest Momo', 'user': 'Root Admin', 'time': 'Just now'},
      {'action': 'Suspended', 'tenant': 'Mountain Cafe', 'user': 'System', 'time': '2h ago'},
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Recent Audit Logs', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: logs.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final log = logs[index];
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.history, size: 18)),
                title: Text('${log['action']} - ${log['tenant']}'),
                subtitle: Text('By ${log['user']}'),
                trailing: Text(log['time']!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              );
            },
          ),
        ],
      ),
    );
  }
}
