import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/tenant_service.dart';
import '../../cart_manager.dart';
import '../admin_theme.dart';

class ReportManagementScreen extends StatefulWidget {
  final String mode;
  const ReportManagementScreen({super.key, required this.mode});

  @override
  State<ReportManagementScreen> createState() => _ReportManagementScreenState();
}

class _ReportManagementScreenState extends State<ReportManagementScreen> {
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> get _purchases => ShopManager.instance.allPurchases.value;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return;
    setState(() => _isLoading = true);
    final orderData = await ApiService.fetchAllOrders(tenant.id);
    await ShopManager.instance.syncProcurementData(tenant.id);
    if (mounted) {
      setState(() {
        if (orderData != null) _orders = orderData;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: ShopManager.instance.allPurchases,
      builder: (context, purchases, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.mode.contains("Sales Report")) _buildSalesAnalyticsView()
              else if (widget.mode.contains("Stock Report")) _buildStockReportView()
              else if (widget.mode == "Purchase Report") _buildPurchaseReportView()
              else _buildGenericReportList(),
            ],
          ),
        );
      }
    );
  }

  Widget _buildSalesAnalyticsView() {
    double netSales = _orders.fold(0, (sum, o) => sum + (double.tryParse(o['total_amount'].toString()) ?? 0));
    double avgOrder = _orders.isEmpty ? 0 : netSales / _orders.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.mode, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AdminTheme.darkNavy)),
        const SizedBox(height: 24),
        _buildTrendChart(),
        const SizedBox(height: 24),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2.2,
          children: [
            _buildMiniReportCard("Net Revenue", "NPR ${netSales.toStringAsFixed(0)}", AdminTheme.royalBlue),
            _buildMiniReportCard("Avg. Ticket", "NPR ${avgOrder.toStringAsFixed(0)}", Colors.orange),
            _buildMiniReportCard("Order Count", "${_orders.length}", AdminTheme.emeraldGreen),
            _buildMiniReportCard("Cancelled", "${_orders.where((o) => o['status'] == 'Cancel').length}", Colors.red),
          ],
        ),
        const SizedBox(height: 32),
        const Text("Revenue Breakdown by Table", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        ..._orders.take(5).map((o) => _buildOrderDataRow(o)),
      ],
    );
  }

  Widget _buildOrderDataRow(Map<String, dynamic> o) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.withValues(alpha: 0.1))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("Table ${o['table_number']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          Text("NPR ${o['total_amount']}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AdminTheme.royalBlue)),
        ],
      ),
    );
  }

  Widget _buildTrendChart() {
    final now = DateTime.now();
    List<double> weeklySales = List.filled(7, 0.0);
    
    for (var o in _orders) {
      try {
        final date = DateTime.parse(o['created_at']);
        final diff = now.difference(date).inDays;
        if (diff < 7) {
          weeklySales[6 - diff] += double.tryParse(o['total_amount'].toString()) ?? 0;
        }
      } catch (_) {}
    }

    double maxVal = weeklySales.fold(0, (max, v) => v > max ? v : max);
    if (maxVal == 0) maxVal = 1000;

    return Container(
      height: 200,
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AdminTheme.darkNavy, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Last 7 Days Revenue", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (i) {
              final h = (weeklySales[i] / maxVal) * 100;
              return Column(
                children: [
                  Container(
                    width: 12, height: h.clamp(5, 100).toDouble(),
                    decoration: BoxDecoration(
                      color: i == 6 ? AdminTheme.emeraldGreen : Colors.white24,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(["S", "M", "T", "W", "T", "F", "S"][(now.weekday - 6 + i) % 7], style: const TextStyle(color: Colors.white38, fontSize: 8)),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniReportCard(String label, String val, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: AdminTheme.softShadow),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
          Text(val, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildStockReportView() {
    Map<String, double> stockMap = {};
    for (var p in _purchases) {
      String name = p['ingredient_name'] ?? 'Unknown';
      double qty = double.tryParse(p['quantity'].toString()) ?? 0;
      stockMap[name] = (stockMap[name] ?? 0) + qty;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.mode, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AdminTheme.darkNavy)),
        const Text("Current inventory levels calculated from procurement history.", style: TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: AdminTheme.softShadow),
          child: Column(
            children: stockMap.isEmpty 
                ? [const Center(child: Text("No stock data available."))]
                : stockMap.entries.map((e) => Column(
                    children: [
                      _StockRow(e.key, e.value.toStringAsFixed(1), e.value < 5 ? "Low Stock" : "Stable"),
                      const Divider(),
                    ],
                  )).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildPurchaseReportView() {
    return Column(
      children: [
        const Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey),
        const SizedBox(height: 16),
        const Text("Detailed Purchase History", style: TextStyle(fontWeight: FontWeight.bold)),
        const Text("Monthly procurement summaries and vendor costs.", style: TextStyle(color: Colors.grey, fontSize: 11)),
        const SizedBox(height: 32),
        ElevatedButton(onPressed: () {}, child: const Text("EXPORT AS PDF")),
      ],
    );
  }

  Widget _buildGenericReportList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.mode, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        const Center(child: Text("No records found for this period.", style: TextStyle(color: Colors.grey))),
      ],
    );
  }
}

class _StockRow extends StatelessWidget {
  final String name, qty, note;
  const _StockRow(this.name, this.qty, this.note);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(note, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ]),
          Text(qty, style: const TextStyle(fontWeight: FontWeight.w900, color: AdminTheme.royalBlue)),
        ],
      ),
    );
  }
}
