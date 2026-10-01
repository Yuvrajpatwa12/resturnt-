import 'package:flutter/material.dart';
import '../admin_theme.dart';

class ProductionSettingsScreen extends StatefulWidget {
  const ProductionSettingsScreen({super.key});

  @override
  State<ProductionSettingsScreen> createState() => _ProductionSettingsScreenState();
}

class _ProductionSettingsScreenState extends State<ProductionSettingsScreen> {
  bool _addonControl = true;
  bool _lowStockAlert = true;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Production Settings", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 4),
          Text("Configure inventory triggers and low stock alerts for production", style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          const SizedBox(height: 20),
          _buildToggleCard("Add-on Inventory Control", _addonControl, (val) => setState(() => _addonControl = val)),
          _buildToggleCard("Low Stock Alert", _lowStockAlert, (val) => setState(() => _lowStockAlert = val)),
        ],
      ),
    );
  }

  Widget _buildToggleCard(String label, bool value, ValueChanged<bool> onChanged) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: Colors.white,
      child: SwitchListTile.adaptive(
        value: value,
        onChanged: onChanged,
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        activeTrackColor: AdminTheme.emeraldGreen,
      ),
    );
  }
}
