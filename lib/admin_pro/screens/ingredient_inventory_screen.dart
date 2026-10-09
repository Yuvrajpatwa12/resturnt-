import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/tenant_service.dart';
import '../admin_theme.dart';

class IngredientInventoryScreen extends StatefulWidget {
  const IngredientInventoryScreen({super.key});

  @override
  State<IngredientInventoryScreen> createState() => _IngredientInventoryScreenState();
}

class _IngredientInventoryScreenState extends State<IngredientInventoryScreen> {
  List<Map<String, dynamic>> _ingredients = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadIngredients();
  }

  Future<void> _loadIngredients() async {
    final tenant = TenantService().currentTenant.value;
    final tenantId = tenant?.id ?? 'startups_main';

    setState(() => _isLoading = true);
    final data = await ApiService.fetchIngredients(tenantId);
    if (mounted) {
      setState(() {
        _ingredients = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _openIngredientDialog({Map<String, dynamic>? ingredient}) async {
    final nameController = TextEditingController(text: ingredient?['name'] ?? '');
    final unitController = TextEditingController(text: ingredient?['unit'] ?? 'KG');
    final totalStockController = TextEditingController(text: ingredient?['total_stock']?.toString() ?? '50');
    final consumedController = TextEditingController(text: ingredient?['consumed_today']?.toString() ?? '0');
    final costController = TextEditingController(text: ingredient?['cost_per_unit']?.toString() ?? '100');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(ingredient == null ? "Add New Ingredient" : "Edit Ingredient Stock", style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.darkNavy)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: "Ingredient Name (e.g. Sugar)",
                  filled: true,
                  fillColor: AdminTheme.pearlWhite,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: unitController,
                decoration: InputDecoration(
                  labelText: "Unit (e.g. KG, Ltr, g, Pcs)",
                  filled: true,
                  fillColor: AdminTheme.pearlWhite,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: totalStockController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Total Initial Stock",
                  filled: true,
                  fillColor: AdminTheme.pearlWhite,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: consumedController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Consumed Today",
                  filled: true,
                  fillColor: AdminTheme.pearlWhite,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: costController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Cost Per Unit (Rs)",
                  filled: true,
                  fillColor: AdminTheme.pearlWhite,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              final item = {
                'id': ingredient?['id'],
                'name': nameController.text.trim(),
                'unit': unitController.text.trim(),
                'total_stock': double.tryParse(totalStockController.text) ?? 0.0,
                'consumed_today': double.tryParse(consumedController.text) ?? 0.0,
                'cost_per_unit': double.tryParse(costController.text) ?? 0.0,
              };
              await ApiService.saveIngredient(item);
              Navigator.pop(ctx);
              _loadIngredients();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ingredient saved successfully!"), backgroundColor: AdminTheme.emeraldGreen));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.royalBlue),
            child: const Text("SAVE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _openLogConsumptionDialog(Map<String, dynamic> item) async {
    final qtyController = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Log Today's Usage: ${item['name']}", style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.darkNavy)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Remaining Stock: ${item['remaining_stock']} ${item['unit']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 16),
            TextField(
              controller: qtyController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: "Quantity Consumed Today (${item['unit']})",
                hintText: "e.g. 5",
                filled: true,
                fillColor: AdminTheme.pearlWhite,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () async {
              final qty = double.tryParse(qtyController.text) ?? 0.0;
              if (qty <= 0) return;
              await ApiService.logIngredientConsumption(item['id'], qty);
              Navigator.pop(ctx);
              _loadIngredients();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Logged $qty ${item['unit']} consumed today!"), backgroundColor: AdminTheme.emeraldGreen));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF5C00)),
            child: const Text("LOG USAGE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteIngredient(dynamic id) async {
    await ApiService.deleteIngredient(id);
    _loadIngredients();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ingredient removed.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    double totalStockVal = _ingredients.fold(0.0, (sum, i) => sum + ((i['remaining_stock'] as double) * (i['cost_per_unit'] as double)));
    double totalConsumedToday = _ingredients.fold(0.0, (sum, i) => sum + (i['consumed_today'] as double));

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
                  Text("Ingredient Stock & Consumption List", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AdminTheme.darkNavy)),
                  SizedBox(height: 4),
                  Text("Manage kitchen stock levels, track daily usage/consumption, and remaining balances.", style: TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _openIngredientDialog(),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text("ADD INGREDIENT", style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5C00),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // --- SUMMARY METRICS ---
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildMetricCard("Total Ingredients", "${_ingredients.length}", Icons.kitchen_rounded, AdminTheme.royalBlue),
              _buildMetricCard("Total Consumption Today", "$totalConsumedToday Units", Icons.trending_down_rounded, Colors.orange),
              _buildMetricCard("Inventory Valuation", "Rs. ${totalStockVal.toStringAsFixed(0)}", Icons.monetization_on_rounded, AdminTheme.emeraldGreen),
            ],
          ),
          const SizedBox(height: 28),

          _isLoading
              ? const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
              : Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: AdminTheme.softShadow,
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: DataTable(
                      horizontalMargin: 12,
                      columnSpacing: 20,
                      headingRowHeight: 45,
                      dataRowMinHeight: 65,
                      dataRowMaxHeight: 65,
                      headingRowColor: WidgetStateProperty.all(Colors.grey.shade50),
                      columns: const [
                        DataColumn(label: Text("INGREDIENT", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.grey, fontSize: 11))),
                        DataColumn(label: Text("TOTAL STOCK", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.grey, fontSize: 11))),
                        DataColumn(label: Text("CONSUMED TODAY", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.grey, fontSize: 11))),
                        DataColumn(label: Text("REMAINING STOCK", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.grey, fontSize: 11))),
                        DataColumn(label: Text("UNIT COST", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.grey, fontSize: 11))),
                        DataColumn(label: Text("ACTIONS", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.grey, fontSize: 11))),
                      ],
                      rows: List.generate(_ingredients.length, (index) {
                        final item = _ingredients[index];
                        final double remaining = double.tryParse(item['remaining_stock']?.toString() ?? '0') ?? 0.0;
                        final double total = double.tryParse(item['total_stock']?.toString() ?? '0') ?? 0.0;
                        final double consumed = double.tryParse(item['consumed_today']?.toString() ?? '0') ?? 0.0;
                        final unit = item['unit'] ?? 'KG';

                        return DataRow(
                          cells: [
                            DataCell(Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item['name'], style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AdminTheme.darkNavy)),
                                Text("Unit: $unit", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                              ],
                            )),
                            DataCell(Text("$total $unit", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                            DataCell(Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
                              child: Text("-$consumed $unit", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.orange.shade800)),
                            )),
                            DataCell(Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: remaining > 10 ? AdminTheme.emeraldGreen.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                "$remaining $unit",
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: remaining > 10 ? AdminTheme.emeraldGreen : Colors.red),
                              ),
                            )),
                            DataCell(Text("Rs. ${item['cost_per_unit']}", style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataCell(Row(
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () => _openLogConsumptionDialog(item),
                                  icon: const Icon(Icons.add_circle_outline, size: 14),
                                  label: const Text("LOG USAGE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AdminTheme.royalBlue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () => _openIngredientDialog(ingredient: item),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(color: Colors.cyan, borderRadius: BorderRadius.circular(6)),
                                    child: const Icon(Icons.edit_outlined, color: Colors.white, size: 14),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                InkWell(
                                  onTap: () => _deleteIngredient(item['id']),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(6)),
                                    child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 14),
                                  ),
                                ),
                              ],
                            )),
                          ],
                        );
                      }),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Container(
      width: 260,
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
                Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AdminTheme.darkNavy)),
                const SizedBox(height: 2),
                Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
