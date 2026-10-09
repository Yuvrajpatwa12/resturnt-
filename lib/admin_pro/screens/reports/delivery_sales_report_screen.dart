import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../services/tenant_service.dart';
import '../../../services/api_service.dart';
import '../../admin_theme.dart';

class DeliverySalesReportScreen extends StatefulWidget {
  const DeliverySalesReportScreen({super.key});

  @override
  State<DeliverySalesReportScreen> createState() => _DeliverySalesReportScreenState();
}

class _DeliverySalesReportScreenState extends State<DeliverySalesReportScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _deliveryData = [];

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
        double dineRev = 0; int dineOrd = 0;
        double takeawayRev = 0; int takeawayOrd = 0;
        double deliveryRev = 0; int deliveryOrd = 0;

        for (var ord in orders) {
          double amt = double.tryParse(ord['amount']?.toString() ?? ord['total_amount']?.toString() ?? ord['total_price']?.toString() ?? '0') ?? 0.0;
          String type = (ord['delivery_type'] ?? ord['type'] ?? 'Dine-In').toString().toLowerCase();

          if (type.contains('take') || type.contains('pickup')) {
            takeawayRev += amt; takeawayOrd++;
          } else if (type.contains('home') || type.contains('deliv') || type.contains('foodmandu') || type.contains('pathao')) {
            deliveryRev += amt; deliveryOrd++;
          } else {
            dineRev += amt; dineOrd++;
          }
        }

        _deliveryData = [
          {'type': 'Dine-In', 'orders': dineOrd, 'revenue': dineRev, 'color': const Color(0xFF2563EB)},
          {'type': 'Takeaway / Pickup', 'orders': takeawayOrd, 'revenue': takeawayRev, 'color': const Color(0xFF10B981)},
          {'type': 'Home Delivery (Foodmandu / Pathao)', 'orders': deliveryOrd, 'revenue': deliveryRev, 'color': const Color(0xFFF59E0B)},
        ];
      } else {
        _deliveryData = [];
      }
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Padding(padding: EdgeInsets.all(60), child: Center(child: CircularProgressIndicator(color: Color(0xFF2563EB))));

    double totalRevenue = _deliveryData.fold(0.0, (sum, d) => sum + (d['revenue'] as double));
    int totalOrders = _deliveryData.fold(0, (sum, d) => sum + (d['orders'] as int));

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
                  Text("Delivery Type Sales Report", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF1F2937))),
                  SizedBox(height: 4),
                  Text("Breakdown of sales revenue across Dine-In, Takeaway, and Home Delivery channels.", style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
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
              _buildMetricCard("Total Fulfillment Revenue", "NPR ${totalRevenue.toStringAsFixed(0)}", Icons.delivery_dining_rounded, const Color(0xFF2563EB)),
              _buildMetricCard("Total Orders Fulfilled", "$totalOrders", Icons.shopping_bag_rounded, const Color(0xFF10B981)),
              _buildMetricCard("Primary Channel", totalOrders > 0 ? "Dine-In" : "N/A", Icons.store_rounded, const Color(0xFFF59E0B)),
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
                const Text("DELIVERY TYPE REVENUE DISTRIBUTION", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF6B7280), letterSpacing: 0.5)),
                const SizedBox(height: 20),
                SizedBox(
                  height: 200,
                  child: totalRevenue <= 0
                      ? const Center(child: Text("No fulfillment orders found in database", style: TextStyle(color: Colors.grey, fontSize: 12)))
                      : PieChart(
                          PieChartData(
                            sectionsSpace: 4,
                            centerSpaceRadius: 40,
                            sections: _deliveryData.map((d) {
                              double rev = d['revenue'] as double;
                              double pct = totalRevenue > 0 ? (rev / totalRevenue * 100) : 0;
                              return PieChartSectionData(
                                color: d['color'] as Color,
                                value: rev > 0 ? rev : 1,
                                title: "${pct.toStringAsFixed(0)}%",
                                radius: 50,
                                titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                              );
                            }).toList(),
                          ),
                        ),
                ),
                const SizedBox(height: 28),

                _deliveryData.isEmpty
                    ? const Padding(padding: EdgeInsets.all(40), child: Center(child: Text("No delivery channel records found.", style: TextStyle(color: Colors.grey))))
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
                              DataColumn(label: Text("DELIVERY TYPE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280)))),
                              DataColumn(label: Text("TOTAL ORDERS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280)))),
                              DataColumn(label: Text("TOTAL REVENUE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280)))),
                              DataColumn(label: Text("SHARE %", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280)))),
                            ],
                            rows: _deliveryData.map((d) {
                              double rev = d['revenue'] as double;
                              double pct = totalRevenue > 0 ? (rev / totalRevenue * 100) : 0;
                              return DataRow(
                                cells: [
                                  DataCell(
                                    Row(
                                      children: [
                                        CircleAvatar(radius: 6, backgroundColor: d['color'] as Color),
                                        const SizedBox(width: 8),
                                        Text(d['type'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1F2937))),
                                      ],
                                    ),
                                  ),
                                  DataCell(Text("${d['orders']} orders", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF374151)))),
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
