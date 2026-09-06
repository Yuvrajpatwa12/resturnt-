import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../services/api_service.dart';
import '../../services/tenant_service.dart';
import '../admin_theme.dart';

import '../../services/app_config.dart';

class TableConfigurationScreen extends StatefulWidget {
  final String mode;
  const TableConfigurationScreen({super.key, required this.mode});

  @override
  State<TableConfigurationScreen> createState() => _TableConfigurationScreenState();
}

class _TableConfigurationScreenState extends State<TableConfigurationScreen> {
  List<Map<String, dynamic>> _tables = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.mode == "Table List") {
      _loadTables();
    }
  }

  Future<void> _loadTables() async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return;

    if (mounted) setState(() => _isLoading = true);
    final data = await ApiService.fetchTables(tenant.id);
    if (mounted) {
      if (data != null) {
        setState(() => _tables = data);
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addTable() async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return;

    final controller = TextEditingController();
    
    final bool? shouldAdd = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text("Add New Table"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Enter a unique table number for this floor.", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 20),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: "Table Number", 
                      hintText: "e.g. 5",
                      filled: true,
                      fillColor: Colors.grey[50],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx, false), 
                  child: const Text("CANCEL"),
                ),
                ElevatedButton(
                  onPressed: isSaving ? null : () async {
                    if (controller.text.isEmpty) return;
                    
                    setModalState(() => isSaving = true);
                    final num = int.tryParse(controller.text);
                    if (num != null) {
                      final success = await ApiService.addTable(tenant.id, num);
                      if (ctx.mounted) Navigator.pop(ctx, success);
                    } else {
                      setModalState(() => isSaving = false);
                    }
                  },
                  child: isSaving 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text("SAVE TABLE"),
                ),
              ],
            );
          },
        );
      }
    );

    if (shouldAdd == true) {
      _loadTables();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Table registered successfully!"), backgroundColor: AdminTheme.emeraldGreen),
        );
      }
    }
  }

  Future<void> _deleteTable(int tableId, int num) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Remove Table?"),
        content: Text("Are you sure you want to permanently delete Table T-$num?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCEL")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("DELETE", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await ApiService.deleteTable(tableId);
      if (success) {
        _loadTables();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Table removed.")));
      }
    }
  }

  void _showQRCode(Map<String, dynamic> table) {
    // UNIFIED CONFIG: Now using the central AppConfig file
    final String orderUrl = "${AppConfig.fullBaseUrl}/?table=${table['table_number']}";
    
    debugPrint("QR GENERATED FROM CONFIG: $orderUrl");

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Center( // Wrap in Center to ensure visibility on all browsers
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          child: AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
            contentPadding: const EdgeInsets.all(32),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.qr_code_scanner_rounded, color: AdminTheme.royalBlue, size: 40),
                const SizedBox(height: 16),
                const Text("Table Order QR", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22)),
                Text("TABLE T-${table['table_number']}", style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1)),
                const SizedBox(height: 32),
                
                // QR Container with Fixed size to prevent layout issues
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.grey[100]!, width: 2),
                  ),
                  child: SizedBox(
                    width: 200, height: 200,
                    child: QrImageView(
                      data: orderUrl,
                      version: QrVersions.auto,
                      size: 200.0,
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                Text(orderUrl, style: const TextStyle(fontSize: 9, color: Colors.blue, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 32),
                
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx), 
                        child: const Text("CLOSE"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {}, 
                        icon: const Icon(Icons.print, size: 16),
                        label: const Text("PRINT", style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.royalBlue),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.mode == "Table List") _buildTableListView()
          else if (widget.mode == "Table Setting") _buildTableSettings()
          else _buildGenericConfigView(),
        ],
      ),
    );
  }

  Widget _buildTableListView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Floor Layout", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            Row(
              children: [
                IconButton(
                  onPressed: _loadTables, 
                  icon: const Icon(Icons.sync_rounded, color: AdminTheme.royalBlue),
                  tooltip: "Sync with Backend",
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _addTable,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text("ADD TABLE", style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5C00),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (_isLoading)
          const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
        else if (_tables.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(40), child: Text("No tables configured yet. Click 'ADD TABLE' to start.")))
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 20,
              crossAxisSpacing: 20,
              childAspectRatio: 1.1,
            ),
            itemCount: _tables.length,
            itemBuilder: (context, index) {
              final t = _tables[index];
              return Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                child: InkWell(
                  onTap: () => _showQRCode(t),
                  onLongPress: () {
                    final id = int.tryParse(t['id']?.toString() ?? '');
                    final num = int.tryParse(t['table_number']?.toString() ?? '');
                    if (id != null && num != null) {
                      _deleteTable(id, num);
                    }
                  },
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AdminTheme.royalBlue.withValues(alpha: 0.05)),
                      boxShadow: AdminTheme.softShadow,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: AdminTheme.royalBlue.withValues(alpha: 0.08), shape: BoxShape.circle),
                          child: const Icon(Icons.qr_code_2_rounded, color: AdminTheme.royalBlue, size: 24),
                        ),
                        const SizedBox(height: 12),
                        Text("T-${t['table_number']}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AdminTheme.darkNavy)),
                        const Text("TAP FOR QR", style: TextStyle(color: Colors.grey, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildTableSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Layout Controls", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _buildToggleTile("Enable Table Merging", true),
        _buildToggleTile("Show QR Ordering on Tables", true),
        _buildToggleTile("Automated Table Clean Alert", false),
      ],
    );
  }

  Widget _buildToggleTile(String label, bool val) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: SwitchListTile.adaptive(
        value: val, 
        onChanged: (v) {},
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        activeTrackColor: AdminTheme.emeraldGreen,
      ),
    );
  }

  Widget _buildGenericConfigView() {
    return const Center(child: Text("Configuration Module Placeholder"));
  }
}
