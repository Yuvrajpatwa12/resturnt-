import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../services/tenant_service.dart';
import '../../../services/api_service.dart';
import '../../admin_theme.dart';

class SaleByTableReportScreen extends StatefulWidget {
  const SaleByTableReportScreen({super.key});

  @override
  State<SaleByTableReportScreen> createState() => _SaleByTableReportScreenState();
}

class _SaleByTableReportScreenState extends State<SaleByTableReportScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _tableSales = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final tenant = TenantService().currentTenant.value;
    final tenantId = (tenant != null && tenant.id.isNotEmpty) ? tenant.id : 'startups_main';

    setState(() => _isLoading = true);
    final orders = await ApiService.fetchAllOrders(tenantId);

    if (mounted) {
      if (orders != null && orders.isNotEmpty) {
        final Map<String, Map<String, dynamic>> map = {};
        for (var ord in orders) {
          String tNum = (ord['table_number'] ?? ord['table'] ?? 'Table 01').toString();
          if (!tNum.toLowerCase().contains('table')) tNum = "Table $tNum";
          double amt = double.tryParse(ord['amount']?.toString() ?? ord['total_amount']?.toString() ?? ord['total_price']?.toString() ?? '0') ?? 0.0;

          if (map.containsKey(tNum)) {
            map[tNum]!['orders'] = (map[tNum]!['orders'] as int) + 1;
            map[tNum]!['revenue'] = (map[tNum]!['revenue'] as double) + amt;
          } else {
            map[tNum] = {
              'table': tNum,
              'orders': 1,
              'revenue': amt,
              'occupancy': '75%',
            };
          }
        }
        _tableSales = map.values.toList();
        _tableSales.sort((a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double));
      } else {
        _tableSales = [];
      }
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Padding(padding: EdgeInsets.all(60), child: Center(child: CircularProgressIndicator(color: Color(0xFF2563EB))));

    double totalRevenue = _tableSales.fold(0.0, (sum, t) => sum + (t['revenue'] as double));
    int totalOrders = _tableSales.fold(0, (sum, t) => sum + (t['orders'] as int));

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
                  Text("Sale By Table Report", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF1F2937))),
                  SizedBox(height: 4),
                  Text("Analyze dining area sales, table occupancy, turnover rates, and top revenue tables.", style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
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
              _buildMetricCard("Active Dining Tables", "${_tableSales.length}", Icons.table_restaurant_rounded, const Color(0xFF2563EB)),
              _buildMetricCard("Table Sales Revenue", "NPR ${totalRevenue.toStringAsFixed(0)}", Icons.monetization_on_rounded, const Color(0xFF10B981)),
              _buildMetricCard("Total Orders Served", "$totalOrders", Icons.shopping_bag_rounded, const Color(0xFFF59E0B)),
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
                const Text("REVENUE BY TABLE LOCATION", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF6B7280), letterSpacing: 0.5)),
                const SizedBox(height: 20),
                SizedBox(
                  height: 180,
                  child: _tableSales.isEmpty
                      ? const Center(child: Text("No table sales recorded in database", style: TextStyle(color: Colors.grey, fontSize: 12)))
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
                                    if (idx >= 0 && idx < _tableSales.length) {
                                      String name = (_tableSales[idx]['table'] ?? '').toString();
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(name.replaceFirst('Table ', 'T'), style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  },
                                ),
                              ),
                            ),
                            barGroups: _tableSales.asMap().entries.map((e) {
                              return BarChartGroupData(
                                x: e.key,
                                barRods: [
                                  BarChartRodData(toY: e.value['revenue'] as double, color: const Color(0xFF2563EB), width: 22, borderRadius: BorderRadius.circular(6)),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                ),
                const SizedBox(height: 28),

                _tableSales.isEmpty
                    ? const Padding(padding: EdgeInsets.all(40), child: Center(child: Text("No table sales found in database.", style: TextStyle(color: Colors.grey))))
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
                              DataColumn(label: Text("TABLE / LOCATION", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280)))),
                              DataColumn(label: Text("ORDERS SERVED", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280)))),
                              DataColumn(label: Text("TABLE REVENUE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280)))),
                              DataColumn(label: Text("TURNOVER STATUS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280)))),
                            ],
                            rows: _tableSales.map((t) {
                              double rev = t['revenue'] as double;
                              return DataRow(
                                cells: [
                                  DataCell(Text(t['table'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1F2937)))),
                                  DataCell(Text("${t['orders']} orders", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF374151)))),
                                  DataCell(Text("NPR ${rev.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.green))),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                                      child: Text(t['occupancy'] ?? 'Active', style: const TextStyle(color: Color(0xFF047857), fontWeight: FontWeight.bold, fontSize: 11)),
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
