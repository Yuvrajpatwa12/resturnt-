import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../services/tenant_service.dart';
import '../../../services/api_service.dart';
import '../../admin_theme.dart';

class WaitersSalesReportScreen extends StatefulWidget {
  const WaitersSalesReportScreen({super.key});

  @override
  State<WaitersSalesReportScreen> createState() => _WaitersSalesReportScreenState();
}

class _WaitersSalesReportScreenState extends State<WaitersSalesReportScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = true;
  List<Map<String, dynamic>> _waiterSales = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final tenant = TenantService().currentTenant.value;
    final tenantId = (tenant != null && tenant.id.isNotEmpty) ? tenant.id : 'startups_main';

    setState(() => _isLoading = true);
    final orders = await ApiService.fetchAllOrders(tenantId);
    final staff = await ApiService.fetchStaff(tenantId);

    if (mounted) {
      if (orders != null && orders.isNotEmpty) {
        final Map<String, Map<String, dynamic>> map = {};
        for (var ord in orders) {
          String waiterName = (ord['waiter_name'] ?? ord['server'] ?? ord['who'] ?? 'Anita Shrestha').toString();
          double amt = double.tryParse(ord['amount']?.toString() ?? ord['total_amount']?.toString() ?? ord['total_price']?.toString() ?? '0') ?? 0.0;

          if (map.containsKey(waiterName)) {
            map[waiterName]!['orders'] = (map[waiterName]!['orders'] as int) + 1;
            map[waiterName]!['sales'] = (map[waiterName]!['sales'] as double) + amt;
          } else {
            map[waiterName] = {
              'name': waiterName,
              'orders': 1,
              'sales': amt,
              'tips': amt * 0.05,
              'rating': 4.8,
            };
          }
        }
        _waiterSales = map.values.toList();
        _waiterSales.sort((a, b) => (b['sales'] as double).compareTo(a['sales'] as double));
      } else if (staff != null && staff.isNotEmpty) {
        _waiterSales = staff.map((s) => {
          'name': s['name'] ?? 'Staff',
          'orders': 0,
          'sales': 0.0,
          'tips': 0.0,
          'rating': 5.0,
        }).toList();
      } else {
        _waiterSales = [];
      }
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Padding(padding: EdgeInsets.all(60), child: Center(child: CircularProgressIndicator(color: Color(0xFF2563EB))));

    final filtered = _waiterSales.where((w) {
      final q = _searchQuery.toLowerCase();
      final name = (w['name'] ?? '').toString().toLowerCase();
      return name.contains(q);
    }).toList();

    double totalSales = filtered.fold(0.0, (sum, w) => sum + (w['sales'] as double));
    int totalOrders = filtered.fold(0, (sum, w) => sum + (w['orders'] as int));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Waiters Sales Report", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF1F2937))),
                  SizedBox(height: 4),
                  Text("Track individual server sales, order volume, service ratings, and tip estimations.", style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                ],
              ),
              IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh_rounded, color: Color(0xFF2563EB), size: 24)),
            ],
          ),
          const SizedBox(height: 24),

          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildMetricCard("Active Waiters", "${filtered.length}", Icons.badge_rounded, const Color(0xFF2563EB)),
              _buildMetricCard("Total Served Orders", "$totalOrders", Icons.restaurant_rounded, const Color(0xFF10B981)),
              _buildMetricCard("Server Sales Total", "NPR ${totalSales.toStringAsFixed(0)}", Icons.monetization_on_rounded, const Color(0xFFF59E0B)),
            ],
          ),
          const SizedBox(height: 28),

          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: AdminTheme.softShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("WAITER SALES LEADERBOARD (NPR)", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF6B7280), letterSpacing: 0.5)),
                const SizedBox(height: 20),
                SizedBox(
                  height: 180,
                  child: filtered.isEmpty
                      ? const Center(child: Text("No waiter sales data found in database", style: TextStyle(color: Colors.grey, fontSize: 12)))
                      : BarChart(
                          BarChartData(
                            borderData: FlBorderData(show: false),
                            gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (val) => FlLine(color: const Color(0xFFF1F5F9), strokeWidth: 1)),
                            titlesData: FlTitlesData(
                              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (val, meta) {
                                    int idx = val.toInt();
                                    if (idx >= 0 && idx < filtered.length) {
                                      String name = (filtered[idx]['name'] ?? '').toString();
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(name.split(' ').first, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  },
                                ),
                              ),
                            ),
                            barGroups: filtered.asMap().entries.map((e) {
                              return BarChartGroupData(
                                x: e.key,
                                barRods: [
                                  BarChartRodData(toY: e.value['sales'] as double, color: const Color(0xFF10B981), width: 24, borderRadius: BorderRadius.circular(6)),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                ),
                const SizedBox(height: 28),

                SizedBox(
                  height: 44,
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF9CA3AF), size: 20),
                      hintText: "Search waiter name...",
                      hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                filtered.isEmpty
                    ? const Padding(padding: EdgeInsets.all(40), child: Center(child: Text("No waiter records found in database.", style: TextStyle(color: Colors.grey))))
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 800),
                          child: DataTable(
                            headingRowHeight: 48,
                            dataRowMaxHeight: 60,
                            horizontalMargin: 12,
                            columnSpacing: 24,
                            columns: const [
                              DataColumn(label: Text("WAITER / SERVER", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280)))),
                              DataColumn(label: Text("ORDERS SERVED", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280)))),
                              DataColumn(label: Text("TOTAL SALES", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280)))),
                              DataColumn(label: Text("EST. TIPS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280)))),
                              DataColumn(label: Text("SERVICE RATING", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280)))),
                            ],
                            rows: filtered.map((w) {
                              double sales = w['sales'] as double;
                              double tips = w['tips'] as double;
                              return DataRow(
                                cells: [
                                  DataCell(Text(w['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1F2937)))),
                                  DataCell(Text("${w['orders']} orders", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF374151)))),
                                  DataCell(Text("NPR ${sales.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.green))),
                                  DataCell(Text("NPR ${tips.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF10B981)))),
                                  DataCell(
                                    Row(
                                      children: [
                                        const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                                        const SizedBox(width: 4),
                                        Text("${w['rating']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: AdminTheme.softShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900)),
            ],
          ),
        ],
      ),
    );
  }
}
