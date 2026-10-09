import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../services/tenant_service.dart';
import '../../../services/api_service.dart';
import '../../admin_theme.dart';

class StockFoodReportScreen extends StatefulWidget {
  const StockFoodReportScreen({super.key});

  @override
  State<StockFoodReportScreen> createState() => _StockFoodReportScreenState();
}

class _StockFoodReportScreenState extends State<StockFoodReportScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';
  bool _isLoading = true;

  List<Map<String, dynamic>> _foodItems = [];
  List<String> _categories = ['All'];

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
    final String tenantId = (tenant != null && tenant.id.isNotEmpty) ? tenant.id : 'startups_main';

    setState(() => _isLoading = true);
    final menuData = await ApiService.fetchMenu(tenantId);
    final products = menuData?['products'] as List?;

    if (mounted) {
      if (products != null && products.isNotEmpty) {
        final List<Map<String, dynamic>> productList = List<Map<String, dynamic>>.from(products);
        final cats = productList.map((p) => (p['category'] ?? 'General').toString()).toSet().toList();
        _categories = ['All', ...cats];

        _foodItems = productList.map((p) {
          int stock = int.tryParse(p['stock']?.toString() ?? p['quantity']?.toString() ?? '50') ?? 50;
          String status = stock == 0 ? 'Out of Stock' : (stock <= 10 ? 'Low Stock' : 'In Stock');
          return {
            'name': p['title'] ?? p['name'] ?? 'Food Item',
            'category': p['category'] ?? 'General',
            'stock': stock,
            'price': double.tryParse(p['price']?.toString().replaceAll(RegExp(r'[^0-9.]'), '') ?? '0') ?? 0.0,
            'status': status,
          };
        }).toList();
      } else {
        _foodItems = [];
      }
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Padding(padding: EdgeInsets.all(60), child: Center(child: CircularProgressIndicator(color: Color(0xFF2563EB))));

    final filtered = _foodItems.where((f) {
      final q = _searchQuery.toLowerCase();
      final name = (f['name'] ?? '').toString().toLowerCase();
      final cat = (f['category'] ?? '').toString().toLowerCase();
      final matchesSearch = name.contains(q) || cat.contains(q);
      final matchesCat = _selectedCategory == 'All' || f['category'] == _selectedCategory;
      return matchesSearch && matchesCat;
    }).toList();

    int totalItems = _foodItems.length;
    int lowStock = _foodItems.where((f) => f['status'] == 'Low Stock').length;
    int outOfStock = _foodItems.where((f) => f['status'] == 'Out of Stock').length;
    int inStock = totalItems - lowStock - outOfStock;

    int inStockPct = totalItems > 0 ? ((inStock / totalItems) * 100).round() : 0;
    int lowStockPct = totalItems > 0 ? ((lowStock / totalItems) * 100).round() : 0;
    int outStockPct = totalItems > 0 ? ((outOfStock / totalItems) * 100).round() : 0;

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
                  Text("Stock Report (Food Items)", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF1F2937))),
                  SizedBox(height: 4),
                  Text("Real-time finished food inventory, category availability, and low-stock alerts.", style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                ],
              ),
              IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh_rounded, color: Color(0xFF2563EB), size: 24)),
            ],
          ),
          const SizedBox(height: 24),

          // DONUT PERCENTAGE BADGES (IMAGE 1 RING BADGES: 75%, 15%, 10%)
          Wrap(
            spacing: 20,
            runSpacing: 16,
            children: [
              _buildDonutPercentageCard("In Stock Health", "$inStockPct%", "$inStock / $totalItems items", Colors.green),
              _buildDonutPercentageCard("Low Stock Warnings", "$lowStockPct%", "$lowStock / $totalItems items", Colors.orange),
              _buildDonutPercentageCard("Out of Stock Alerts", "$outStockPct%", "$outOfStock / $totalItems items", Colors.redAccent),
            ],
          ),
          const SizedBox(height: 28),

          // CHART & FILTER CARD
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
                const Text("FOOD ITEM STOCK LEVEL CHART", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF6B7280), letterSpacing: 0.5)),
                const SizedBox(height: 20),
                SizedBox(
                  height: 180,
                  child: filtered.isEmpty
                      ? const Center(child: Text("No product stock data found in database", style: TextStyle(color: Colors.grey, fontSize: 12)))
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
                              double stock = (e.value['stock'] as int).toDouble();
                              Color barColor = e.value['status'] == 'Out of Stock'
                                  ? Colors.redAccent
                                  : (e.value['status'] == 'Low Stock' ? Colors.orangeAccent : const Color(0xFF10B981));

                              return BarChartGroupData(
                                x: e.key,
                                barRods: [
                                  BarChartRodData(toY: stock, color: barColor, width: 20, borderRadius: BorderRadius.circular(6)),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                ),
                const SizedBox(height: 28),

                // SEARCH & DROPDOWN FILTER
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 44,
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: (val) => setState(() => _searchQuery = val.trim()),
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF9CA3AF), size: 20),
                            hintText: "Search food name or category...",
                            hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      height: 44,
                      width: 220,
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedCategory,
                        items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)))).toList(),
                        onChanged: (val) => setState(() => _selectedCategory = val!),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // DATA TABLE
                filtered.isEmpty
                    ? const Padding(padding: EdgeInsets.all(40), child: Center(child: Text("No food items found in database matching filter.", style: TextStyle(color: Colors.grey))))
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
                              DataColumn(label: Text("FOOD ITEM", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280)))),
                              DataColumn(label: Text("CATEGORY", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280)))),
                              DataColumn(label: Text("STOCK UNITS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280)))),
                              DataColumn(label: Text("SELLING PRICE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280)))),
                              DataColumn(label: Text("AVAILABILITY STATUS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280)))),
                            ],
                            rows: filtered.map((f) {
                              String st = f['status'];
                              Color stColor = st == 'In Stock'
                                  ? const Color(0xFF10B981)
                                  : (st == 'Low Stock' ? const Color(0xFFF59E0B) : const Color(0xFFEF4444));

                              return DataRow(
                                cells: [
                                  DataCell(Text(f['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1F2937)))),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(color: const Color(0xFF2563EB).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                                      child: Text(f['category'], style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 11)),
                                    ),
                                  ),
                                  DataCell(Text("${f['stock']} units", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF374151)))),
                                  DataCell(Text("NPR ${f['price']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green))),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(color: stColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                                      child: Text(st, style: TextStyle(color: stColor, fontWeight: FontWeight.bold, fontSize: 11)),
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

  Widget _buildDonutPercentageCard(String title, String pct, String subtitle, Color color) {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: AdminTheme.softShadow,
      ),
      child: Row(
        children: [
          Container(
            height: 60, width: 60,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Center(
              child: Text(pct, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 16)),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Color(0xFF1F2937), fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}
