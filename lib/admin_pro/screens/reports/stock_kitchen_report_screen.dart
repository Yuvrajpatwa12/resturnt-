import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../services/tenant_service.dart';
import '../../../cart_manager.dart';
import '../../admin_theme.dart';

class StockKitchenReportScreen extends StatefulWidget {
  const StockKitchenReportScreen({super.key});

  @override
  State<StockKitchenReportScreen> createState() => _StockKitchenReportScreenState();
}

class _StockKitchenReportScreenState extends State<StockKitchenReportScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = true;

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
      builder: (context, ingredients, _) {
        final filtered = ingredients.where((i) {
          final q = _searchQuery.toLowerCase();
          final name = (i['ingredient_name'] ?? i['name'] ?? '').toString().toLowerCase();
          final type = (i['unit_name'] ?? i['unit'] ?? '').toString().toLowerCase();
          return name.contains(q) || type.contains(q);
        }).toList();

        int totalIng = filtered.length;
        int healthy = filtered.where((i) => (double.tryParse(i['quantity']?.toString() ?? '0') ?? 0) > 10).length;
        int lowStock = totalIng - healthy;

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
                      Text("Stock Report (Kitchen Ingredients)", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF1F2937))),
                      SizedBox(height: 4),
                      Text("Raw kitchen ingredients, consumption rates, expiry dates, and supplier reorders.", style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                    ],
                  ),
                  IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh_rounded, color: Color(0xFF2563EB), size: 24)),
                ],
              ),
              const SizedBox(height: 24),

              // METRICS
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _buildMetricCard("Total Raw Ingredients", "$totalIng", Icons.kitchen_rounded, const Color(0xFF2563EB)),
                  _buildMetricCard("Healthy Stock Level", "$healthy", Icons.check_circle_rounded, const Color(0xFF10B981)),
                  _buildMetricCard("Low Stock Reorders", "$lowStock", Icons.warning_amber_rounded, const Color(0xFFF59E0B)),
                ],
              ),
              const SizedBox(height: 28),

              // CONSUMPTION TREND GRADIENT LINE CHART (IMAGE 2 SMOOTH AREA STYLE)
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
                    const Text("KITCHEN INGREDIENT CONSUMPTION & STOCK TREND", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF6B7280), letterSpacing: 0.5)),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 180,
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
                            LineChartBarData(
                              spots: filtered.isEmpty
                                  ? const [FlSpot(1, 0), FlSpot(2, 0)]
                                  : filtered.asMap().entries.map((e) {
                                      double qty = double.tryParse(e.value['quantity']?.toString() ?? '0') ?? 0.0;
                                      return FlSpot(e.key.toDouble() + 1, qty);
                                    }).toList(),
                              isCurved: true,
                              color: const Color(0xFF2563EB),
                              barWidth: 3.5,
                              belowBarData: BarAreaData(
                                show: true,
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF2563EB).withValues(alpha: 0.3),
                                    const Color(0xFF2563EB).withValues(alpha: 0.02),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // SEARCH BAR
                    SizedBox(
                      height: 44,
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (val) => setState(() => _searchQuery = val.trim()),
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF9CA3AF), size: 20),
                          hintText: "Search ingredient name or unit...",
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

                    // INGREDIENTS TABLE
                    filtered.isEmpty
                        ? const Padding(padding: EdgeInsets.all(40), child: Center(child: Text("No kitchen ingredients found in database.", style: TextStyle(color: Colors.grey))))
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
                                  DataColumn(label: Text("INGREDIENT NAME", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280)))),
                                  DataColumn(label: Text("UNIT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280)))),
                                  DataColumn(label: Text("CURRENT STOCK", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280)))),
                                  DataColumn(label: Text("STOCK HEALTH", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280)))),
                                ],
                                rows: filtered.map((i) {
                                  double qty = double.tryParse(i['quantity']?.toString() ?? '0') ?? 0;
                                  bool isHealthy = qty > 10;

                                  return DataRow(
                                    cells: [
                                      DataCell(Text(i['ingredient_name'] ?? i['name'] ?? 'Ingredient', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1F2937)))),
                                      DataCell(
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(color: const Color(0xFF2563EB).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                                          child: Text(i['unit_name'] ?? i['unit'] ?? 'kg', style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 11)),
                                        ),
                                      ),
                                      DataCell(Text("$qty ${i['unit_name'] ?? 'units'}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF374151)))),
                                      DataCell(
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: isHealthy ? const Color(0xFFDEF7EC) : const Color(0xFFFDE8E8),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            isHealthy ? 'Healthy' : 'Low Stock',
                                            style: TextStyle(
                                              color: isHealthy ? const Color(0xFF03543F) : const Color(0xFF9B1C1C),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                            ),
                                          ),
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
      },
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: 210,
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
