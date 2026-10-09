import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../services/tenant_service.dart';
import '../../../services/api_service.dart';
import '../../admin_theme.dart';

class OrderSourceReportScreen extends StatefulWidget {
  const OrderSourceReportScreen({super.key});

  @override
  State<OrderSourceReportScreen> createState() => _OrderSourceReportScreenState();
}

class _OrderSourceReportScreenState extends State<OrderSourceReportScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _sources = [];

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
        double posRev = 0; int posOrd = 0;
        double qrRev = 0; int qrOrd = 0;
        double appRev = 0; int appOrd = 0;
        double partnerRev = 0; int partnerOrd = 0;

        for (var ord in orders) {
          double amt = double.tryParse(ord['amount']?.toString() ?? ord['total_amount']?.toString() ?? ord['total_price']?.toString() ?? '0') ?? 0.0;
          String src = (ord['order_source'] ?? ord['source'] ?? 'POS').toString().toLowerCase();

          if (src.contains('qr') || src.contains('table_scan')) {
            qrRev += amt; qrOrd++;
          } else if (src.contains('app') || src.contains('web')) {
            appRev += amt; appOrd++;
          } else if (src.contains('partner') || src.contains('aggregator')) {
            partnerRev += amt; partnerOrd++;
          } else {
            posRev += amt; posOrd++;
          }
        }

        _sources = [
          {'source': 'In-House POS Terminal', 'orders': posOrd, 'revenue': posRev, 'color': const Color(0xFF2563EB)},
          {'source': 'QR Table Self-Scan', 'orders': qrOrd, 'revenue': qrRev, 'color': const Color(0xFF10B981)},
          {'source': 'Customer Web App', 'orders': appOrd, 'revenue': appRev, 'color': const Color(0xFFF59E0B)},
          {'source': 'Third-Party Aggregators', 'orders': partnerOrd, 'revenue': partnerRev, 'color': const Color(0xFF8B5CF6)},
        ];
      } else {
        _sources = [];
      }
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Padding(padding: EdgeInsets.all(60), child: Center(child: CircularProgressIndicator(color: Color(0xFF2563EB))));

    double totalRev = _sources.fold(0.0, (sum, s) => sum + (s['revenue'] as double));
    int totalOrd = _sources.fold(0, (sum, s) => sum + (s['orders'] as int));

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
                  Text("Order Source Report", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF1F2937))),
                  SizedBox(height: 4),
                  Text("Analyze order volumes and revenue originating from POS Terminals, QR Scans, Web App, and Partner Aggregators.", style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
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
              _buildMetricCard("Total Orders Source", "$totalOrd", Icons.devices_rounded, const Color(0xFF2563EB)),
              _buildMetricCard("Total Channel Sales", "NPR ${totalRev.toStringAsFixed(0)}", Icons.monetization_on_rounded, const Color(0xFF10B981)),
              _buildMetricCard("Top Channel", totalOrd > 0 ? "POS Terminal" : "N/A", Icons.point_of_sale_rounded, const Color(0xFFF59E0B)),
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
                const Text("ORDER SOURCE REVENUE BREAKDOWN", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF6B7280), letterSpacing: 0.5)),
                const SizedBox(height: 20),
                SizedBox(
                  height: 180,
                  child: totalRev <= 0
                      ? const Center(child: Text("No order source data found in database", style: TextStyle(color: Colors.grey, fontSize: 12)))
                      : BarChart(
                          BarChartData(
                            borderData: FlBorderData(show: false),
                            gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (val) => FlLine(color: const Color(0xFFF1F5F9), strokeWidth: 1)),
                            titlesData: const FlTitlesData(
                              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            barGroups: _sources.asMap().entries.map((e) {
                              return BarChartGroupData(
                                x: e.key,
                                barRods: [
                                  BarChartRodData(toY: e.value['revenue'] as double, color: e.value['color'] as Color, width: 22, borderRadius: BorderRadius.circular(6)),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                ),
                const SizedBox(height: 28),

                _sources.isEmpty
                    ? const Padding(padding: EdgeInsets.all(40), child: Center(child: Text("No order source records found.", style: TextStyle(color: Colors.grey))))
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
                              DataColumn(label: Text("ORDER SOURCE / CHANNEL", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280)))),
                              DataColumn(label: Text("ORDERS COUNT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280)))),
                              DataColumn(label: Text("CHANNEL REVENUE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280)))),
                              DataColumn(label: Text("REVENUE SHARE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280)))),
                            ],
                            rows: _sources.map((s) {
                              double rev = s['revenue'] as double;
                              double pct = totalRev > 0 ? (rev / totalRev * 100) : 0;
                              return DataRow(
                                cells: [
                                  DataCell(
                                    Row(
                                      children: [
                                        CircleAvatar(radius: 6, backgroundColor: s['color'] as Color),
                                        const SizedBox(width: 8),
                                        Text(s['source'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1F2937))),
                                      ],
                                    ),
                                  ),
                                  DataCell(Text("${s['orders']} orders", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF374151)))),
                                  DataCell(Text("NPR ${rev.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.green))),
                                  DataCell(Text("${pct.toStringAsFixed(1)}%", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF2563EB)))),
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
