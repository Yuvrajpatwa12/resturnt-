import 'package:flutter/material.dart';
import '../admin_theme.dart';

class AddonsManagementScreen extends StatelessWidget {
  final String mode;
  const AddonsManagementScreen({super.key, required this.mode});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (mode == "Add Add-ons") _buildAddAddonForm()
          else if (mode == "Add-ons List") _buildAddonListView()
          else _buildAddonAssignView(),
        ],
      ),
    );
  }

  Widget _buildAddonListView() {
    final List<Map<String, dynamic>> addons = [
      {'name': 'Extra Cheese', 'price': 80},
      {'name': 'Spicy Dip', 'price': 40},
      {'name': 'Extra Shot', 'price': 100},
      {'name': 'Honey Drizzle', 'price': 50},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Available Add-ons", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        ...addons.map((a) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AdminTheme.softShadow,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(a['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
              Text("NPR ${a['price']}", style: const TextStyle(color: AdminTheme.royalBlue, fontWeight: FontWeight.w900)),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildAddAddonForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Add New Extra", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 24),
        _buildTextField("Add-on Name", "e.g. Extra Butter"),
        const SizedBox(height: 16),
        _buildTextField("Price (NPR)", "50"),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 54)),
          child: const Text("CREATE ADD-ON"),
        ),
      ],
    );
  }

  Widget _buildAddonAssignView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Assign to Categories", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        const Text("Link your add-ons to food categories or specific items.", style: TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 32),
        Center(
          child: Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.withOpacity(0.1))),
            child: const Column(
              children: [
                Icon(Icons.link_outlined, size: 40, color: AdminTheme.royalBlue),
                SizedBox(height: 16),
                Text("Item Assignment Logic Placeholder", style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ],
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
