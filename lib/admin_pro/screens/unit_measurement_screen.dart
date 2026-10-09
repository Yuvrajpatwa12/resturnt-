import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/tenant_service.dart';
import '../admin_theme.dart';

class UnitMeasurementScreen extends StatefulWidget {
  const UnitMeasurementScreen({super.key});

  @override
  State<UnitMeasurementScreen> createState() => _UnitMeasurementScreenState();
}

class _UnitMeasurementScreenState extends State<UnitMeasurementScreen> {
  List<Map<String, dynamic>> _units = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUnits();
  }

  Future<void> _loadUnits() async {
    final tenant = TenantService().currentTenant.value;
    final tenantId = tenant?.id ?? 'startups_main';

    setState(() => _isLoading = true);
    final data = await ApiService.fetchUnits(tenantId);
    if (mounted) {
      setState(() {
        _units = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _openUnitDialog({Map<String, dynamic>? unit}) async {
    final nameController = TextEditingController(text: unit?['name'] ?? '');
    final symbolController = TextEditingController(text: unit?['symbol'] ?? '');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(unit == null ? "Add Measurement Unit" : "Edit Unit", style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.darkNavy)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: "Unit Name (e.g. Kilogram)",
                filled: true,
                fillColor: AdminTheme.pearlWhite,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: symbolController,
              decoration: InputDecoration(
                labelText: "Symbol (e.g. kg, ltr, pcs)",
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
              if (nameController.text.trim().isEmpty) return;
              final newUnit = {
                'id': unit?['id'],
                'name': nameController.text.trim(),
                'symbol': symbolController.text.trim(),
              };
              await ApiService.saveUnit(newUnit);
              Navigator.pop(ctx);
              _loadUnits();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Unit saved successfully!"), backgroundColor: AdminTheme.emeraldGreen));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.royalBlue),
            child: const Text("SAVE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteUnit(dynamic id) async {
    await ApiService.deleteUnit(id);
    _loadUnits();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Unit removed.")));
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  Text("Unit Measurement List", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AdminTheme.darkNavy)),
                  SizedBox(height: 4),
                  Text("Manage standard measurement units for inventory and kitchen stock tracking.", style: TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _openUnitDialog(),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text("ADD UNIT", style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5C00),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
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
                      columnSpacing: 24,
                      headingRowHeight: 45,
                      dataRowMinHeight: 60,
                      dataRowMaxHeight: 60,
                      headingRowColor: WidgetStateProperty.all(Colors.grey.shade50),
                      columns: const [
                        DataColumn(label: Text("SN", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.grey, fontSize: 11))),
                        DataColumn(label: Text("Unit Name", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.grey, fontSize: 11))),
                        DataColumn(label: Text("Symbol", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.grey, fontSize: 11))),
                        DataColumn(label: Text("Actions", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.grey, fontSize: 11))),
                      ],
                      rows: List.generate(_units.length, (index) {
                        final u = _units[index];
                        return DataRow(
                          cells: [
                            DataCell(Text("${index + 1}", style: const TextStyle(color: Colors.grey, fontSize: 13))),
                            DataCell(Text(u['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AdminTheme.darkNavy))),
                            DataCell(Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: AdminTheme.royalBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                              child: Text(u['symbol'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AdminTheme.royalBlue)),
                            )),
                            DataCell(Row(
                              children: [
                                InkWell(
                                  onTap: () => _openUnitDialog(unit: u),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: Colors.cyan, borderRadius: BorderRadius.circular(8)),
                                    child: const Icon(Icons.edit_outlined, color: Colors.white, size: 14),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () => _deleteUnit(u['id']),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(8)),
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
}
