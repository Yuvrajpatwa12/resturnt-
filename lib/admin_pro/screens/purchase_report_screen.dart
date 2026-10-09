import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/tenant_service.dart';
import '../../cart_manager.dart';
import '../admin_theme.dart';

class PurchaseReportScreen extends StatefulWidget {
  const PurchaseReportScreen({super.key});

  @override
  State<PurchaseReportScreen> createState() => _PurchaseReportScreenState();
}

class _PurchaseReportScreenState extends State<PurchaseReportScreen> {
  bool _isLoading = true;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

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
    setState(() => _isLoading = true);

    if (tenant == null) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      await ShopManager.instance.syncProcurementData(tenant.id);
      if (mounted) setState(() => _isLoading = false);
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Padding(padding: EdgeInsets.all(60), child: Center(child: CircularProgressIndicator(color: Color(0xFF2563EB))));

    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: ShopManager.instance.allPurchases,
      builder: (context, purchases, _) {
        final filtered = purchases.where((p) {
          final q = _searchQuery.toLowerCase();
          final ing = (p['ingredient_name'] ?? p['item_name'] ?? '').toString().toLowerCase();
          final sup = (p['supplier_name'] ?? p['supplier'] ?? '').toString().toLowerCase();
          return ing.contains(q) || sup.contains(q);
        }).toList();

        double totalCost = filtered.fold(0.0, (sum, p) => sum + (double.tryParse(p['total_amount']?.toString() ?? p['total_price']?.toString() ?? '0') ?? 0.0));
        double vatTax = totalCost * 0.13;
        double netCost = totalCost - vatTax;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Purchase Report", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF1F2937))),
                      SizedBox(height: 4),
                      Text("Detailed procurement logs, supplier cost distribution, and VAT breakdown.", style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                    ],
                  ),
                  IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh_rounded, color: Color(0xFF2563EB), size: 24)),
                ],
              ),
              const SizedBox(height: 24),

              // METRICS ROW WITH SPARKLINE BADGES (IMAGE 1 & 2 STYLE)
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _buildMetricCard("Total Purchase Expense", "NPR ${totalCost.toStringAsFixed(0)}", Icons.shopping_bag_rounded, const Color(0xFF2563EB)),
                  _buildMetricCard("Estimated VAT (13%)", "NPR ${vatTax.toStringAsFixed(0)}", Icons.receipt_rounded, const Color(0xFF10B981)),
                  _buildMetricCard("Net Procurement Cost", "NPR ${netCost.toStringAsFixed(0)}", Icons.account_balance_wallet_rounded, const Color(0xFFF59E0B)),
                ],
              ),
              const SizedBox(height: 28),

              // DUAL COLOR BARCHART (IMAGE 1 DUAL BARS)
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("DUAL COST COMPARISON: NET COST VS VAT TAX", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF6B7280), letterSpacing: 0.5)),
                        Row(
                          children: [
                            _buildLegendDot("Net Cost", const Color(0xFF2563EB)),
                            const SizedBox(width: 12),
                            _buildLegendDot("VAT 13%", const Color(0xFF10B981)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 200,
                      child: filtered.isEmpty
                          ? const Center(child: Text("No procurement items in database", style: TextStyle(color: Colors.grey, fontSize: 12)))
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
                                          String name = (filtered[idx]['ingredient_name'] ?? filtered[idx]['item_name'] ?? '').toString();
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
                                  double amt = double.tryParse(e.value['total_amount']?.toString() ?? e.value['total_price']?.toString() ?? '0') ?? 0;
                                  double itemVat = amt * 0.13;
                                  double itemNet = amt - itemVat;

                                  return BarChartGroupData(
                                    x: e.key,
                                    barRods: [
                                      BarChartRodData(toY: itemNet, color: const Color(0xFF2563EB), width: 12, borderRadius: BorderRadius.circular(4)),
                                      BarChartRodData(toY: itemVat, color: const Color(0xFF10B981), width: 12, borderRadius: BorderRadius.circular(4)),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                    ),
                    const SizedBox(height: 28),

                    // SEARCH INPUT
                    SizedBox(
                      height: 44,
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (val) => setState(() => _searchQuery = val.trim()),
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF9CA3AF), size: 20),
                          hintText: "Search item name or supplier...",
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

                    // DATA TABLE
                    filtered.isEmpty
                        ? const Padding(padding: EdgeInsets.all(40), child: Center(child: Text("No purchase logs found in database.", style: TextStyle(color: Colors.grey))))
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
                                  DataColumn(label: Text("INGREDIENT / ITEM", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280)))),
                                  DataColumn(label: Text("SUPPLIER", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280)))),
                                  DataColumn(label: Text("QUANTITY", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280)))),
                                  DataColumn(label: Text("PURCHASE DATE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280)))),
                                  DataColumn(label: Text("TOTAL AMOUNT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280)))),
                                ],
                                rows: filtered.map((p) {
                                  double amt = double.tryParse(p['total_amount']?.toString() ?? p['total_price']?.toString() ?? '0') ?? 0;
                                  return DataRow(
                                    cells: [
                                      DataCell(Text(p['ingredient_name'] ?? p['item_name'] ?? 'Item', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1F2937)))),
                                      DataCell(Text(p['supplier_name'] ?? p['supplier'] ?? 'Supplier', style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563)))),
                                      DataCell(Text("${p['quantity'] ?? '1'} ${p['unit_name'] ?? p['unit'] ?? 'units'}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)))),
                                      DataCell(Text(p['purchase_date'] ?? p['created_at'] ?? 'N/A', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
                                      DataCell(Text("NPR ${amt.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.green))),
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
      },
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: 230,
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

  Widget _buildLegendDot(String label, Color color) {
    return Row(
      children: [
        CircleAvatar(radius: 5, backgroundColor: color),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
      ],
    );
  }
}
