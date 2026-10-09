import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import '../admin_theme.dart';
import '../../services/api_service.dart';
import '../../services/tenant_service.dart';

class CustomerManagementScreen extends StatefulWidget {
  final String mode; // "Customer List", "Type List", "Third-Party Customers", "Card Terminal List"
  const CustomerManagementScreen({super.key, required this.mode});

  @override
  State<CustomerManagementScreen> createState() => _CustomerManagementScreenState();
}

class _CustomerManagementScreenState extends State<CustomerManagementScreen> {
  // --- DATA SOURCES ---
  List<Map<String, dynamic>> _customers = [];
  bool _isLoading = true;
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalCount = 0;

  @override
  void initState() {
    super.initState();
    _loadRealTimeCustomers(page: 1);
  }

  Future<void> _loadRealTimeCustomers({int page = 1}) async {
    final tenant = TenantService().currentTenant.value;
    final tenantId = tenant?.id ?? 'startups_main';

    if (mounted) setState(() => _isLoading = true);
    _currentPage = page;
    final res = await ApiService.fetchCustomersPaged(tenantId, page: _currentPage, limit: 40);

    if (mounted) {
      final rawCustomers = res['data'] as List<Map<String, dynamic>>;
      _totalPages = res['totalPages'] as int;
      _totalCount = res['totalCount'] as int;

      _customers = rawCustomers.map((c) {
        String email = (c['email'] ?? '').toString().trim();
        String name = (c['name'] ?? 'Valued Customer').toString().trim();
        int isAnonymous = int.tryParse(c['is_anonymous']?.toString() ?? '0') ?? 0;
        int points = int.tryParse(c['points']?.toString() ?? '0') ?? 0;
        int orderCount = int.tryParse(c['order_count']?.toString() ?? '0') ?? 0;
        double totalSpent = orderCount * 850.0;

        bool isVip = isAnonymous == 0 && email.contains('@') && !email.toLowerCase().contains('guest');
        String tier = isVip ? 'VIP' : 'Guest / Regular';

        return {
          'id': email,
          'name': name.isEmpty ? 'Valued Customer' : name,
          'email': email,
          'phone': isAnonymous == 1 ? 'Guest ID: $email' : 'Active Account',
          'type': tier,
          'points': points,
          'total_spent': totalSpent,
          'orders_count': orderCount,
          'last_login': c['last_login'] ?? 'Recent',
        };
      }).toList();

      setState(() => _isLoading = false);
    }
  }

  final List<Map<String, dynamic>> _customerTypes = [
    {'name': 'VIP', 'category': 'Registered & Verified Members', 'status': 'Most Active', 'performance': '94%', 'color': Colors.amber.shade800},
    {'name': 'Guest / Regular', 'category': 'Walk-in Diners & Anonymous', 'status': 'High Volume', 'performance': '82%', 'color': Colors.teal},
  ];

  final List<Map<String, dynamic>> _thirdPartyPlatforms = [
    {'name': 'Foodmandu', 'contact': 'Rajesh Hamal', 'phone': '9851000000', 'commission': 20.00, 'comm_type': '%', 'status': true, 'address': 'Kathmandu'},
    {'name': 'Pathao Food', 'contact': 'Sita Thapa', 'phone': '9841000000', 'commission': 50.00, 'comm_type': 'Rs', 'status': true, 'address': 'Lalitpur'},
    {'name': 'Bhoj Deals', 'contact': 'Ram Sah', 'phone': '9801000000', 'commission': 18.00, 'comm_type': '%', 'status': true, 'address': 'Dhaka'},
    {'name': 'Facebook/Meta', 'contact': 'Direct', 'phone': 'N/A', 'commission': 0.00, 'comm_type': '%', 'status': true, 'address': 'Online'},
  ];

  final List<Map<String, dynamic>> _terminals = [
    {
      'id': 'QR-101',
      'name': 'Fonepay QR',
      'category': 'QR Merchant',
      'model': 'Dynamic/Static QR',
      'status': 'Online',
      'today_total': 8450.00,
      'customer_count': 12,
      'last_settle': 'Today 11:30 AM',
      'icon': Icons.qr_code_scanner
    },
    {
      'id': 'ES-502',
      'name': 'e-Sewa Wallet',
      'category': 'Digital Wallet',
      'model': 'Merchant API',
      'status': 'Online',
      'today_total': 3200.00,
      'customer_count': 5,
      'last_settle': 'Today 10:00 AM',
      'icon': Icons.account_balance_wallet_outlined
    },
    {
      'id': 'T-1001',
      'name': 'Nabil Bank POS',
      'category': 'Card Terminal',
      'model': 'Pax A920 (Android)',
      'status': 'Online',
      'today_total': 12450.00,
      'customer_count': 8,
      'last_settle': 'Yesterday 10:30 PM',
      'icon': Icons.credit_card
    },
    {
      'id': 'KH-201',
      'name': 'Khalti Payment',
      'category': 'Digital Wallet',
      'model': 'SDK Integration',
      'status': 'Online',
      'today_total': 1500.00,
      'customer_count': 3,
      'last_settle': 'Today 09:00 AM',
      'icon': Icons.wallet_membership_outlined
    },
    {
      'id': 'CASH-01',
      'name': 'Main Counter Cash',
      'category': 'Cash Account',
      'model': 'Physical Drawer',
      'status': 'Online',
      'today_total': 25600.00,
      'customer_count': 45,
      'last_settle': 'Today 08:30 AM',
      'icon': Icons.payments_outlined
    },
  ];

  String _searchQuery = "";
  int _rowsPerPage = 10;
  String _selectedTier = "All Tiers";
  String _paymentCategoryFilter = "ALL";

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
          const SizedBox(height: 32),
          _buildContextualView(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AdminTheme.softShadow,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final headerContent = [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AdminTheme.royalBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(_getModeIcon(), color: AdminTheme.royalBlue, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.mode, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AdminTheme.darkNavy), overflow: TextOverflow.ellipsis),
                  Text(_getModeSubtitle(), style: const TextStyle(fontSize: 12, color: Colors.grey), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ];

          final bool isCustomerTypeList = widget.mode == "Customer Type List";

          if (isCustomerTypeList) {
            return Row(children: headerContent);
          }

          final addButton = ElevatedButton.icon(
            onPressed: () => _handleAddNew(),
            icon: const Icon(Icons.add_circle_outline, size: 18),
            label: Text("ADD ${_getModeBtnLabel()}", style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminTheme.royalBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );

          if (constraints.maxWidth < 620) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: headerContent),
                const SizedBox(height: 16),
                addButton,
              ],
            );
          }
          return Row(children: [...headerContent, const SizedBox(width: 16), addButton]);
        },
      ),
    );
  }

  Widget _buildSummaryStats() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: _getModeStats(),
      ),
    );
  }

  List<Widget> _getModeStats() {
    switch (widget.mode) {
      case "Customer List":
        int vipCount = _customers.where((c) => c['type'] == 'VIP').length;
        int guestCount = _customers.where((c) => c['type'] == 'Guest / Regular').length;
        int totalPoints = _customers.fold(0, (sum, c) => sum + (c['points'] as int));
        return [
          _buildStatCard("Total Customers", _totalCount.toString(), Icons.people, Colors.blue),
          _buildStatCard("VIP Members", vipCount.toString(), Icons.star, Colors.orange),
          _buildStatCard("Guest / Regular", guestCount.toString(), Icons.person_outline, Colors.teal),
          _buildStatCard("Total Points", totalPoints.toString(), Icons.card_giftcard, Colors.green),
        ];
      case "Customer Type List":
        return [
          _buildStatCard("Defined Types", _customerTypes.length.toString(), Icons.category, Colors.purple),
          _buildStatCard("Active Discounts", "4 Types", Icons.percent, Colors.red),
        ];
      case "Third-Party Customers":
        return [
          _buildStatCard("Integrated Apps", _thirdPartyPlatforms.length.toString(), Icons.app_shortcut, Colors.indigo),
          _buildStatCard("Active Status", "4 Online", Icons.check_circle, Colors.green),
        ];
      case "Card Terminal List":
        return [
          _buildStatCard("Active Terminals", _terminals.length.toString(), Icons.terminal, Colors.blue),
          _buildStatCard("Today's Digital", "Rs. 45,600", Icons.account_balance_wallet, Colors.green),
        ];
      default:
        return [];
    }
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      width: 240,
      margin: const EdgeInsets.only(right: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.1), width: 2),
        boxShadow: AdminTheme.softShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AdminTheme.darkNavy)),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContextualView() {
    switch (widget.mode) {
      case "Customer List":
        return _buildCustomerList();
      case "Customer Type List":
        return _buildTypeList();
      case "Third-Party Customers":
        return _buildThirdPartyList();
      case "Card Terminal List":
        return _buildTerminalList();
      default:
        return const Center(child: Text("Feature under development..."));
    }
  }

  // --- 1. CUSTOMER LIST VIEW ---
  Widget _buildCustomerList() {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(48),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: AdminTheme.softShadow),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final filteredList = _customers.where((c) {
      final matchesSearch = c['name'].toLowerCase().contains(_searchQuery.toLowerCase()) || c['phone'].contains(_searchQuery) || c['email'].toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesTier = _selectedTier == "All Tiers" || c['type'].toString().toUpperCase() == _selectedTier.toUpperCase();
      return matchesSearch && matchesTier;
    }).toList();

    Set<String> tiers = {"All Tiers", "VIP", "Guest / Regular"};

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: AdminTheme.softShadow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: tiers.map((t) => Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: _buildTierChip(t),
                      )).toList(),
                ),
              ),
              IconButton(
                onPressed: _loadRealTimeCustomers,
                icon: const Icon(Icons.sync_rounded, color: AdminTheme.royalBlue),
                tooltip: "Sync Real-Time Customers",
              ),
            ],
          ),
          const SizedBox(height: 24),
          filteredList.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      "No real customer orders found yet.\nCustomers will appear here automatically when they place orders.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ),
                )
              : SizedBox(
                  width: double.infinity,
                  child: DataTable(
                    horizontalMargin: 0,
                    columnSpacing: 20,
                    headingRowColor: WidgetStateProperty.all(Colors.grey[50]),
                    columns: const [
                      DataColumn(label: Text("CUSTOMER NAME", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      DataColumn(label: Text("CONTACT / EMAIL", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      DataColumn(label: Text("TIER", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      DataColumn(label: Text("POINTS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      DataColumn(label: Text("TOTAL SPENT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      DataColumn(label: Text("ACTIONS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    ],
                    rows: filteredList.take(_rowsPerPage).map((c) => DataRow(
                          cells: [
                            DataCell(Text(c['name'], style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14))),
                            DataCell(Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c['phone'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                Text(c['email'], style: const TextStyle(fontSize: 10, color: Colors.grey)),
                              ],
                            )),
                            DataCell(_buildStatusTag(c['type'], c['type'] == 'VIP' ? Colors.amber.shade800 : Colors.teal)),
                            DataCell(Text(c['points'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.royalBlue))),
                            DataCell(Text("Rs. ${(c['total_spent'] as double).toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataCell(Row(
                              children: [
                                _buildMiniActionBtn(Icons.history, Colors.cyan, () {}),
                                const SizedBox(width: 8),
                                _buildMiniActionBtn(Icons.edit_outlined, AdminTheme.royalBlue, () {}),
                              ],
                            )),
                          ],
                        )).toList(),
                  ),
                ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Page $_currentPage of $_totalPages (Total: $_totalCount customers)", style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
              Row(
                children: List.generate(_totalPages > 15 ? 15 : _totalPages, (index) {
                  int p = index + 1;
                  bool isActive = p == _currentPage;
                  return Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: ElevatedButton(
                      onPressed: () => _loadRealTimeCustomers(page: p),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isActive ? AdminTheme.royalBlue : Colors.white,
                        foregroundColor: isActive ? Colors.white : Colors.black87,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: const Size(36, 36),
                      ),
                      child: Text("$p", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  );
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- 2. CUSTOMER TYPE LIST VIEW ---
  Widget _buildTypeList() {
    int vipCount = _customers.where((c) => c['type'] == 'VIP').length;
    int guestCount = _customers.where((c) => c['type'] == 'Guest / Regular').length;
    int total = (vipCount + guestCount == 0) ? 1 : (vipCount + guestCount);
    double vipRatio = vipCount / total;
    double guestRatio = guestCount / total;

    bool vipIsHigher = vipCount >= guestCount;
    double vipBase = (vipCount > 0 ? vipCount : 5).toDouble();
    double guestBase = (guestCount > 0 ? guestCount : 5).toDouble();

    List<FlSpot> vipSpots = [
      FlSpot(1, vipBase * 300),
      FlSpot(2, vipBase * 700),
      FlSpot(3, vipBase * 1200),
      FlSpot(4, vipBase * 1800 + (vipIsHigher ? 800 : 0)),
    ];

    List<FlSpot> guestSpots = [
      FlSpot(1, guestBase * 250),
      FlSpot(2, guestBase * 600),
      FlSpot(3, guestBase * 1050),
      FlSpot(4, guestBase * 1500 + (!vipIsHigher ? 800 : 0)),
    ];

    return Column(
      children: [
        // --- CURVED PERFORMANCE TREND CHART (STRICTLY 2 REAL LINES) ---
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AdminTheme.softShadow,
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("CUSTOMER ENGAGEMENT & TREND ANALYTICS", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1, color: AdminTheme.darkNavy)),
                  Row(
                    children: const [
                      Icon(Icons.circle, size: 10, color: Color(0xFFEF4444)),
                      SizedBox(width: 4),
                      Text("VIP", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                      SizedBox(width: 12),
                      Icon(Icons.circle, size: 10, color: Color(0xFF3B82F6)),
                      SizedBox(width: 4),
                      Text("Guest / Regular", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 220,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (val) => FlLine(color: const Color(0xFFF1F5F9), strokeWidth: 1)),
                    titlesData: const FlTitlesData(
                      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      // VIP Line (Red/Orange)
                      LineChartBarData(
                        spots: vipSpots,
                        isCurved: true,
                        color: const Color(0xFFEF4444),
                        barWidth: 4,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFFEF4444).withValues(alpha: 0.3),
                              const Color(0xFFEF4444).withValues(alpha: 0.0),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                      // Guest / Regular Line (Blue)
                      LineChartBarData(
                        spots: guestSpots,
                        isCurved: true,
                        color: const Color(0xFF3B82F6),
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: true),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // --- PERFORMANCE ANALYTICS COMPARISON CARD ---
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AdminTheme.softShadow,
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("TIER PERFORMANCE & ACTIVITY ANALYTICS", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1, color: AdminTheme.darkNavy)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: AdminTheme.royalBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Text("LIVE COMPARISON", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AdminTheme.royalBlue)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("VIP Members Performance", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amber)),
                            Text("${(vipRatio * 100).toStringAsFixed(1)}% Activity", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: vipRatio,
                            minHeight: 12,
                            backgroundColor: Colors.amber.shade50,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.amber.shade700),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text("$vipCount active VIP customers generating high loyalty engagement.", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 32),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Guest / Regular Performance", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.teal)),
                            Text("${(guestRatio * 100).toStringAsFixed(1)}% Volume", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: guestRatio,
                            minHeight: 12,
                            backgroundColor: Colors.teal.shade50,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.teal.shade600),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text("$guestCount guest diners driving broad order volume.", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // --- SYSTEM CUSTOMER TYPES TABLE ---
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AdminTheme.softShadow,
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("SYSTEM CUSTOMER TIERS", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1, color: AdminTheme.darkNavy)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: DataTable(
                  horizontalMargin: 16,
                  columnSpacing: 24,
                  headingRowHeight: 45,
                  dataRowMinHeight: 60,
                  dataRowMaxHeight: 60,
                  headingRowColor: WidgetStateProperty.all(Colors.grey.shade50),
                  columns: const [
                    DataColumn(label: Text("SN", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.grey, fontSize: 11))),
                    DataColumn(label: Text("Customer Tier Name", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.grey, fontSize: 11))),
                    DataColumn(label: Text("Category Description", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.grey, fontSize: 11))),
                    DataColumn(label: Text("Performance Status", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.grey, fontSize: 11))),
                    DataColumn(label: Text("System Protection", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.grey, fontSize: 11))),
                  ],
                  rows: List.generate(_customerTypes.length, (index) {
                    final type = _customerTypes[index];
                    return DataRow(
                      cells: [
                        DataCell(Text("${index + 1}", style: const TextStyle(color: Colors.grey, fontSize: 13))),
                        DataCell(Text(type['name'], style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: type['color']))),
                        DataCell(Text(type['category'], style: const TextStyle(fontSize: 12, color: Colors.black87))),
                        DataCell(_buildStatusTag(type['status'], type['color'])),
                        DataCell(Row(
                          children: const [
                            Icon(Icons.lock_rounded, size: 14, color: Colors.grey),
                            SizedBox(width: 6),
                            Text("System Locked", style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                          ],
                        )),
                      ],
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- 3. THIRD PARTY LIST VIEW ---
  Widget _buildThirdPartyList() {
    final filteredPlatforms = _thirdPartyPlatforms.where((p) {
      return p['name'].toLowerCase().contains(_searchQuery.toLowerCase()) || (p['address'] ?? "").toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: AdminTheme.softShadow,
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text("Display ", style: TextStyle(fontSize: 11, color: Colors.black87)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(4)),
                    child: DropdownButton<int>(
                      value: _rowsPerPage,
                      underline: const SizedBox(),
                      icon: const Icon(Icons.arrow_drop_down, size: 18),
                      items: [10, 25, 50, 100].map((v) => DropdownMenuItem(value: v, child: Text("$v", style: const TextStyle(fontSize: 11)))).toList(),
                      onChanged: (v) => setState(() => _rowsPerPage = v!),
                    ),
                  ),
                  const Text(" records per page", style: TextStyle(fontSize: 11, color: Colors.black87)),
                ],
              ),
              Row(
                children: [
                  _buildMiniExportBtn("CSV"),
                  _buildMiniExportBtn("Pdf"),
                  _buildMiniExportBtn("Print"),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: DataTable(
              horizontalMargin: 12,
              columnSpacing: 20,
              headingRowHeight: 45,
              dataRowMinHeight: 50,
              dataRowMaxHeight: 50,
              headingRowColor: WidgetStateProperty.all(Colors.grey.shade50),
              border: TableBorder.all(color: Colors.grey.shade200, width: 0.5),
              columns: const [
                DataColumn(label: Text("SN", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                DataColumn(label: Text("Third Party Name", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                DataColumn(label: Text("Commission", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                DataColumn(label: Text("Contact Info", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                DataColumn(label: Text("Status", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                DataColumn(label: Text("Action", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
              ],
              rows: List.generate(
                filteredPlatforms.length > _rowsPerPage ? _rowsPerPage : filteredPlatforms.length,
                (index) {
                  final p = filteredPlatforms[index];
                  return DataRow(
                    cells: [
                      DataCell(Text("${index + 1}", style: const TextStyle(fontSize: 12))),
                      DataCell(Text(p['name'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
                      DataCell(Text("${p['commission']} ${p['comm_type']}", style: const TextStyle(fontSize: 12, color: Colors.redAccent, fontWeight: FontWeight.bold))),
                      DataCell(Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p['contact'] ?? "", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                          Text(p['phone'] ?? "", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      )),
                      DataCell(Transform.scale(
                        scale: 0.7,
                        child: Switch(
                          value: p['status'],
                          onChanged: (v) => setState(() => p['status'] = v),
                          activeColor: Colors.green,
                        ),
                      )),
                      DataCell(Row(
                        children: [
                          _buildMiniActionBtn(Icons.edit, Colors.cyan, () {}),
                          const SizedBox(width: 6),
                          _buildMiniActionBtn(Icons.delete, Colors.redAccent, () {}),
                        ],
                      )),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 4. TERMINAL LIST VIEW ---
  Widget _buildTerminalList() {
    final filteredTerminals = _terminals.where((t) {
      final matchesSearch = t['name'].toLowerCase().contains(_searchQuery.toLowerCase()) || t['id'].toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCat = _paymentCategoryFilter == "ALL" || t['category'].toUpperCase().contains(_paymentCategoryFilter);
      return matchesSearch && matchesCat;
    }).toList();

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [AdminTheme.royalBlue.withValues(alpha: 0.05), Colors.white], begin: Alignment.topCenter, end: Alignment.bottomCenter),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AdminTheme.royalBlue.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.analytics_outlined, color: AdminTheme.royalBlue, size: 20),
                  const SizedBox(width: 12),
                  const Text("TERMINAL ENGAGEMENT", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.2, color: AdminTheme.darkNavy)),
                  const Spacer(),
                  _buildSearchField(),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  _buildEngagementCard("ALL", _terminals.length, Icons.groups_outlined, Colors.grey, filterKey: "ALL"),
                  _buildEngagementCard("QR", _terminals.where((t) => t['category'] == 'QR Merchant').length, Icons.qr_code, Colors.green, filterKey: "QR"),
                  _buildEngagementCard("POS", _terminals.where((t) => t['category'] == 'Card Terminal').length, Icons.credit_card, Colors.blue, filterKey: "CARD"),
                ],
              ),
            ],
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
            childAspectRatio: 1.5,
          ),
          itemCount: filteredTerminals.length,
          itemBuilder: (context, index) {
            final t = filteredTerminals[index];
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: AdminTheme.softShadow),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(t['icon'], color: AdminTheme.royalBlue),
                      const SizedBox(width: 12),
                      Expanded(child: Text(t['name'], style: const TextStyle(fontWeight: FontWeight.bold))),
                      _buildStatusTag(t['status'], Colors.green),
                    ],
                  ),
                  const Spacer(),
                  Text("Total Today: Rs. ${t['today_total']}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AdminTheme.royalBlue)),
                  Text("Transactions: ${t['customer_count']}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildEngagementCard(String label, int count, IconData icon, Color color, {required String filterKey}) {
    bool isSelected = _paymentCategoryFilter == filterKey;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _paymentCategoryFilter = filterKey),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.1) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? color : Colors.grey.shade100, width: 1.5),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 8),
              Text("$count", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
              Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      width: 200,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: const InputDecoration(hintText: "Search...", border: InputBorder.none, icon: Icon(Icons.search, size: 16, color: Colors.grey)),
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  Widget _buildTierChip(String label) {
    bool isSelected = _selectedTier == label;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (v) => setState(() => _selectedTier = label),
      selectedColor: AdminTheme.royalBlue,
      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildStatusTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildMiniExportBtn(String label) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      child: OutlinedButton(onPressed: () {}, child: Text(label, style: const TextStyle(fontSize: 11))),
    );
  }

  Widget _buildPaginationBtn(String label, bool active) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: ElevatedButton(
        onPressed: () {},
        style: ElevatedButton.styleFrom(backgroundColor: active ? AdminTheme.royalBlue : Colors.white, foregroundColor: active ? Colors.white : Colors.black87),
        child: Text(label),
      ),
    );
  }

  Widget _buildMiniActionBtn(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
        child: Icon(icon, color: Colors.white, size: 14),
      ),
    );
  }

  IconData _getModeIcon() {
    switch (widget.mode) {
      case "Customer List": return Icons.people;
      case "Customer Type List": return Icons.category;
      case "Third-Party Customers": return Icons.language;
      case "Card Terminal List": return Icons.credit_card;
      default: return Icons.settings;
    }
  }

  String _getModeSubtitle() {
    return "Manage and track ${widget.mode.toLowerCase()} records.";
  }

  String _getModeBtnLabel() {
    return widget.mode.replaceAll(" List", "").toUpperCase();
  }

  void _handleAddNew() {}
  void _showToast(String msg) {}
  Color _getTierColor(String tier) {
    if (tier == 'VIP') return Colors.orange;
    if (tier == 'Corporate') return Colors.purple;
    return Colors.blue;
  }

  void _openCustomerDialog({Map<String, dynamic>? existingCustomer}) {}
  void _openCustomerTypeDialog({Map<String, dynamic>? existingType}) {}
  void _deleteCustomerType(Map<String, dynamic> type) {}
  void _openThirdPartyDialog({Map<String, dynamic>? existingPlatform}) {}
  void _deleteThirdParty(Map<String, dynamic> platform) {}
}
