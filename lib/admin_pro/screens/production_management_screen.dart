import 'package:flutter/material.dart';
import '../admin_theme.dart';

class ProductionManagementScreen extends StatelessWidget {
  final String mode;
  const ProductionManagementScreen({super.key, required this.mode});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (mode == "Add Production") _buildAddProductionForm()
          else if (mode == "Set Production Unit") _buildSetUnitView()
          else if (mode == "Production Setting") _buildSettingView()
          else _buildProductionSetListView(),
        ],
      ),
    );
  }

  Widget _buildProductionSetListView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Production Batches", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            IconButton(onPressed: () {}, icon: const Icon(Icons.refresh, color: AdminTheme.royalBlue)),
          ],
        ),
        const SizedBox(height: 16),
        ...List.generate(3, (index) => _buildProductionBatchCard(index)),
      ],
    );
  }

  Widget _buildProductionBatchCard(int index) {
    final List<String> items = ["Masala Tea Base", "Momo Dough", "Marinated Chicken"];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AdminTheme.softShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AdminTheme.royalBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.precision_manufacturing_outlined, color: AdminTheme.royalBlue, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(items[index % items.length], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text("Batch #BT-00${index + 1} • Expected: 50 Units", style: const TextStyle(color: Colors.grey, fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text("IN PROGRESS", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w900, fontSize: 10)),
              const SizedBox(height: 4),
              SizedBox(
                width: 60,
                child: LinearProgressIndicator(
                  value: 0.6,
                  backgroundColor: Colors.grey[100],
                  color: Colors.orange,
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddProductionForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Start Production", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 24),
        _buildTextField("Target Item", "Select item to produce"),
        const SizedBox(height: 16),
        _buildTextField("Production Unit", "Kitchen Main / Bakery"),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildTextField("Target Quantity", "100")),
            const SizedBox(width: 16),
            Expanded(child: _buildTextField("Unit", "L/kg/Units")),
          ],
        ),
        const SizedBox(height: 16),
        _buildTextField("Estimated Completion Time", "45 mins"),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 54)),
          child: const Text("START BATCH"),
        ),
      ],
    );
  }

  Widget _buildSetUnitView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Production Units", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _buildUnitCard("Kitchen Main", "Hot Food, Momos", "Active"),
        _buildUnitCard("Bakery Station", "Bread, Desserts", "Active"),
        _buildUnitCard("Drink Station", "Tea, Coffee, Shakes", "Active"),
      ],
    );
  }

  Widget _buildUnitCard(String name, String focus, String status) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const Icon(Icons.factory_outlined, color: AdminTheme.royalBlue),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(focus, style: const TextStyle(fontSize: 12)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: AdminTheme.emeraldGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Text(status, style: const TextStyle(color: AdminTheme.emeraldGreen, fontSize: 9, fontWeight: FontWeight.w900)),
        ),
      ),
    );
  }

  Widget _buildSettingView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Production Control", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _buildToggleCard("Auto-Update Inventory on Completion", true),
        _buildToggleCard("Notify Chef for Low Stock Batches", true),
        _buildToggleCard("Enable Waste Tracking", false),
      ],
    );
  }

  Widget _buildToggleCard(String label, bool value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: SwitchListTile.adaptive(
        value: value,
        onChanged: (v) {},
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        activeTrackColor: AdminTheme.emeraldGreen,
      ),
    );
  }

  Widget _buildTextField(String label, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 8),
        TextField(
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 13),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }
}
