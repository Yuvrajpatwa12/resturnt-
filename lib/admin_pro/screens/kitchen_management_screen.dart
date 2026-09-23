import 'package:flutter/material.dart';
import '../admin_theme.dart';

class KitchenManagementScreen extends StatefulWidget {
  final String mode; // "Kitchen List", "Kitchen Assign", "Kitchen Dashboard Setting"
  const KitchenManagementScreen({super.key, required this.mode});

  @override
  State<KitchenManagementScreen> createState() => _KitchenManagementScreenState();
}

class _KitchenManagementScreenState extends State<KitchenManagementScreen> {
  // --- DEMO DATA ---
  final List<Map<String, dynamic>> _kitchens = [
    {
      'id': 'KTN-001',
      'name': 'Main Production Kitchen',
      'code': 'MPK-01',
      'category': 'Main Stations',
      'type': 'Production',
      'status': 'Online',
      'orders_today': 145,
      'staff': ['Arbind Patel', 'Sandhya Sharma', 'Ram Kumar', 'Sita Thapa', 'Rajesh Hamal', 'Gita Rai', 'Hari Kc', 'Maya Devi', 'Suraj Limbu', 'Puja Shah', 'Binod Chaudhary', 'Rita Gurung'],
      'icon': Icons.soup_kitchen
    },
    {
      'id': 'KTN-002',
      'name': 'Chinese & Wok Station',
      'code': 'CW-02',
      'category': 'Main Stations',
      'type': 'Specialty',
      'status': 'Online',
      'orders_today': 82,
      'staff': ['Krishna Pd', 'Anjali Bista', 'Madan Rai', 'Saru Magar', 'Dipesh Shah'],
      'icon': Icons.outdoor_grill
    },
    {
      'id': 'KTN-003',
      'name': 'Bakery & Pastry Unit',
      'code': 'BP-03',
      'category': 'Sub Stations',
      'type': 'Bakery',
      'status': 'Online',
      'orders_today': 45,
      'staff': ['Kabita Giri', 'Sunil Das', 'Rekha Kc', 'Om Pd'],
      'icon': Icons.bakery_dining
    },
    {
      'id': 'KTN-004',
      'name': 'Main Bar & Beverages',
      'code': 'BAR-01',
      'category': 'Bar & Beverage',
      'type': 'Beverages',
      'status': 'Online',
      'orders_today': 210,
      'staff': ['Sameer Rai', 'Nisha Lama', 'Prakash Poudel'],
      'icon': Icons.local_bar
    },
    {
      'id': 'KTN-005',
      'name': 'Outdoor BBQ Station',
      'code': 'BBQ-05',
      'category': 'Sub Stations',
      'type': 'Grill',
      'status': 'Offline',
      'orders_today': 0,
      'staff': [],
      'icon': Icons.fire_hydrant_alt
    },
  ];

  final List<Map<String, dynamic>> _assignments = [
    {'id': 'AS-001', 'category': 'Momo', 'item': 'Chicken Momo', 'kitchen': 'Main Production Kitchen', 'priority': 'High', 'status': 'Active'},
    {'id': 'AS-002', 'category': 'Pizza', 'item': 'Chicken Pizza', 'kitchen': 'Pizza Kitchen', 'priority': 'Medium', 'status': 'Active'},
    {'id': 'AS-003', 'category': 'Chowmein', 'item': 'Veg Chowmein', 'kitchen': 'Chinese & Wok Station', 'priority': 'Medium', 'status': 'Active'},
    {'id': 'AS-004', 'category': 'Cake', 'item': 'Chocolate Cake', 'kitchen': 'Bakery & Pastry Unit', 'priority': 'Low', 'status': 'Active'},
    {'id': 'AS-005', 'category': 'Coffee', 'item': 'Cappuccino', 'kitchen': 'Main Bar & Beverages', 'priority': 'Medium', 'status': 'Active'},
  ];

  // UI State
  String? _activeDetailView;
  String _searchQuery = "";
  String _stationFilter = "ALL";

  // Dashboard Settings State
  bool _showNew = true;
  bool _showPreparing = true;
  bool _showReady = true;
  bool _showCompleted = false;
  bool _showOrderTime = true;
  bool _showTableNo = true;
  bool _showCustomerName = false;
  bool _autoRefresh = true;
  int _refreshInterval = 15;
  bool _soundAlert = true;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildSummaryStats(),
          _buildDetailedSummaryView(),
          const SizedBox(height: 32),
          _buildContextualView(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: AdminTheme.softShadow),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AdminTheme.royalBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(_getModeIcon(), color: AdminTheme.royalBlue, size: 28),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.mode, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AdminTheme.darkNavy)),
              Text(_getModeSubtitle(), style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          const Spacer(),
          if (widget.mode != "Kitchen Dashboard Setting")
            ElevatedButton.icon(
              onPressed: () => _handleAddNew(),
              icon: const Icon(Icons.add, size: 18),
              label: Text("ADD ${_getModeBtnLabel()}", style: const TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminTheme.royalBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryStats() {
    if (widget.mode == "Kitchen Dashboard Setting") return const SizedBox();
    int totalStaff = _kitchens.fold(0, (sum, k) => sum + (k['staff'] as List).length);
    int totalOrders = _kitchens.fold(0, (sum, k) => sum + (k['orders_today'] as int));

    Map<String, int> statusCounts = {};
    for (var k in _kitchens) {
      String status = k['status'] ?? "Offline";
      statusCounts[status] = (statusCounts[status] ?? 0) + 1;
    }

    List<String> sortedStatuses = statusCounts.keys.toList()..sort();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildClickableStatCard("STAFF ENGAGED", totalStaff.toString(), Icons.people_outline, Colors.orange, "Staff Details"),
          ...sortedStatuses.map((status) {
            IconData icon = Icons.bolt;
            Color color = Colors.green;
            if (status == "Offline") {
              icon = Icons.power_off_outlined;
              color = Colors.redAccent;
            }
            return _buildClickableStatCard(
              "${status.toUpperCase()} STATIONS",
              statusCounts[status].toString(),
              icon,
              color,
              "Status: $status"
            );
          }),
          _buildClickableStatCard("TOTAL ORDERS", totalOrders.toString(), Icons.list_alt, AdminTheme.royalBlue, "Order Breakdown"),
        ],
      ),
    );
  }

  Widget _buildClickableStatCard(String label, String value, IconData icon, Color color, String detailKey) {
    bool isSelected = _activeDetailView == detailKey;
    return Container(
      width: 240,
      margin: const EdgeInsets.only(right: 20),
      child: InkWell(
        onTap: () => setState(() => _activeDetailView = isSelected ? null : detailKey),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.1) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isSelected ? color : color.withValues(alpha: 0.1), width: 2),
            boxShadow: AdminTheme.softShadow
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AdminTheme.darkNavy)),
                  Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailedSummaryView() {
    if (_activeDetailView == null || widget.mode == "Kitchen Dashboard Setting") return const SizedBox();
    String title = _activeDetailView!;
    if (title.startsWith("Status: ")) title = "${title.substring(8)} Stations Details";
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AdminTheme.softShadow,
        border: Border.all(color: AdminTheme.royalBlue.withValues(alpha: 0.1), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 4, height: 18, decoration: BoxDecoration(color: AdminTheme.royalBlue, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 12),
              Text(title.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AdminTheme.darkNavy)),
              const Spacer(),
              IconButton(
                onPressed: () => setState(() => _activeDetailView = null),
                icon: const Icon(Icons.close, size: 20, color: Colors.grey),
              ),
            ],
          ),
          const Divider(height: 32),
          _buildDetailedContent(),
        ],
      ),
    );
  }

  Widget _buildDetailedContent() {
    if (_activeDetailView == null) return const SizedBox();
    if (_activeDetailView!.startsWith("Status: ")) {
      String filterStatus = _activeDetailView!.substring(8);
      final filteredKitchens = _kitchens.where((k) => k['status'] == filterStatus).toList();
      return Column(
        children: filteredKitchens.map((k) {
          bool isOnline = k['status'] == 'Online';
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
            child: Row(
              children: [
                Icon(k['icon'], color: isOnline ? Colors.green : Colors.redAccent, size: 20),
                const SizedBox(width: 16),
                Text(k['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const Spacer(),
                _buildStatusTag(k['status'], isOnline ? Colors.green : Colors.red),
              ],
            ),
          );
        }).toList(),
      );
    }
    switch (_activeDetailView) {
      case "Staff Details":
        return Wrap(
          spacing: 24,
          runSpacing: 24,
          children: _kitchens.map((k) {
            List staff = k['staff'];
            if (staff.isEmpty) return const SizedBox();
            return Container(
              width: 300,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(k['icon'], size: 16, color: AdminTheme.royalBlue),
                      const SizedBox(width: 8),
                      Text(k['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: staff.map((s) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.grey.shade200)),
                      child: Text(s, style: const TextStyle(fontSize: 10, color: Colors.black87)),
                    )).toList(),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      case "Order Breakdown":
        return Column(
          children: _kitchens.map((k) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
              child: Row(
                children: [
                  Icon(k['icon'], color: AdminTheme.royalBlue, size: 20),
                  const SizedBox(width: 16),
                  Text(k['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const Spacer(),
                  Text("${k['orders_today']} Orders", style: const TextStyle(fontWeight: FontWeight.w900, color: AdminTheme.royalBlue, fontSize: 14)),
                ],
              ),
            );
          }).toList(),
        );
      default:
        return const SizedBox();
    }
  }

  Widget _buildContextualView() {
    switch (widget.mode) {
      case "Kitchen List":
        return _buildKitchenListView();
      case "Kitchen Assign":
        return _buildKitchenAssign();
      case "Kitchen Dashboard Setting":
        return _buildProfessionalDashboardSettings();
      default:
        return const SizedBox();
    }
  }

  // --- 1. KITCHEN LIST ---
  Widget _buildKitchenListView() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AdminTheme.softShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text("ACTIVE STATIONS", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                  const Spacer(),
                  _buildSearchField(),
                ],
              ),
              const SizedBox(height: 24),
              ..._kitchens.map((k) {
                bool isOnline = k['status'] == 'Online';
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(k['icon'], color: isOnline ? AdminTheme.royalBlue : Colors.grey, size: 24),
                      const SizedBox(width: 20),
                      Expanded(
                        flex: 3,
                        child: Text(k['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(k['code'], style: const TextStyle(color: AdminTheme.royalBlue, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text("${(k['staff'] as List).length} Staff", style: const TextStyle(fontSize: 12)),
                      ),
                      _buildStatusTag(k['status'], isOnline ? Colors.green : Colors.red),
                      const SizedBox(width: 16),
                      _buildActionBtn(Icons.edit_outlined, AdminTheme.royalBlue, () {}),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ],
    );
  }

  // --- 2. KITCHEN ASSIGN ---
  Widget _buildKitchenAssign() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: AdminTheme.softShadow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Category-to-Kitchen Mapping", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: DataTable(
              columns: const [
                DataColumn(label: Text("FOOD ITEM")),
                DataColumn(label: Text("KITCHEN")),
                DataColumn(label: Text("PRIORITY")),
                DataColumn(label: Text("STATUS")),
                DataColumn(label: Text("ACTION")),
              ],
              rows: _assignments.map((a) => DataRow(
                cells: [
                  DataCell(Text(a['item'], style: const TextStyle(fontWeight: FontWeight.bold))),
                  DataCell(Chip(label: Text(a['kitchen'], style: const TextStyle(fontSize: 10)))),
                  DataCell(_buildStatusTag(a['priority'], Colors.orange)),
                  DataCell(_buildStatusTag(a['status'], Colors.green)),
                  DataCell(_buildActionBtn(Icons.edit_outlined, AdminTheme.royalBlue, () {})),
                ],
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // --- 3. KDS SETTINGS ---
  Widget _buildProfessionalDashboardSettings() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: AdminTheme.softShadow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Kitchen Display System (KDS) Rules", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 32),
          _buildSettingsSwitchTile("Show New Orders", "Orders waiting acceptance", _showNew, (v) => setState(() => _showNew = v), Icons.fiber_new),
          _buildSettingsSwitchTile("Show Preparing", "Orders being cooked", _showPreparing, (v) => setState(() => _showPreparing = v), Icons.restaurant),
          _buildSettingsSwitchTile("Auto Refresh", "Refresh data every X seconds", _autoRefresh, (v) => setState(() => _autoRefresh = v), Icons.refresh),
          const SizedBox(height: 32),
          ElevatedButton(onPressed: () {}, child: const Text("SAVE KDS CONFIG")),
        ],
      ),
    );
  }

  Widget _buildSettingsSwitchTile(String title, String sub, bool val, Function(bool) onChanged, IconData icon) {
    return SwitchListTile(
      value: val,
      onChanged: onChanged,
      secondary: Icon(icon, color: AdminTheme.royalBlue),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Text(sub, style: const TextStyle(fontSize: 11)),
    );
  }

  Widget _buildStatusTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildSearchField() {
    return Container(
      width: 200,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: const InputDecoration(hintText: "Search...", border: InputBorder.none, icon: Icon(Icons.search, size: 16)),
      ),
    );
  }

  Widget _buildActionBtn(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }

  IconData _getModeIcon() {
    switch (widget.mode) {
      case "Kitchen List": return Icons.soup_kitchen;
      case "Kitchen Assign": return Icons.assignment_ind;
      case "Kitchen Dashboard Setting": return Icons.settings_display;
      default: return Icons.kitchen;
    }
  }

  String _getModeSubtitle() => "Manage your kitchen operations and stations.";
  String _getModeBtnLabel() => "STATION";
  void _handleAddNew() {}
}
