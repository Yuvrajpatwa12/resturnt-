import 'package:flutter/material.dart';
import '../styles.dart';

class GlobalCatalogScreen extends StatefulWidget {
  const GlobalCatalogScreen({super.key});

  @override
  State<GlobalCatalogScreen> createState() => _GlobalCatalogScreenState();
}

class _GlobalCatalogScreenState extends State<GlobalCatalogScreen> {
  final List<Map<String, String>> _items = [
    {'name': 'Masala Tea', 'cat': 'Beverages', 'price': '60'},
    {'name': 'Chicken Momo', 'cat': 'Fast Food', 'price': '450'},
    {'name': 'Iced Chiya', 'cat': 'Beverages', 'price': '150'},
    {'name': 'Veg Burger', 'cat': 'Burgers', 'price': '350'},
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 32),
          Expanded(child: _buildItemGrid()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Global Item Library", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text("Push default menus and categories to all restaurant tenants.", style: TextStyle(color: SAMStyles.textGrey)),
          ],
        ),
        ElevatedButton.icon(
          onPressed: () {}, 
          icon: const Icon(Icons.add), 
          label: const Text("ADD GLOBAL ITEM"),
        ),
      ],
    );
  }

  Widget _buildItemGrid() {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 24,
        mainAxisSpacing: 24,
        childAspectRatio: 2.2,
      ),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final i = _items[index];
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white, 
            borderRadius: BorderRadius.circular(24), 
            boxShadow: SAMStyles.softShadow,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: SAMStyles.royalBlue.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.restaurant_menu, color: SAMStyles.royalBlue),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(i['name']!, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                    Text(i['cat']!, style: const TextStyle(color: SAMStyles.textGrey, fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text("Base: NPR ${i['price']}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: SAMStyles.emeraldGreen)),
                  ],
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () => _showDeployWizard(context, i), 
                    icon: const Icon(Icons.cloud_upload_rounded, color: SAMStyles.royalBlue, size: 24),
                    tooltip: "Deploy to Stores",
                  ),
                  const Text("PUSH", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: SAMStyles.royalBlue)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDeployWizard(BuildContext context, Map<String, String> item) {
    List<String> selectedTenants = ["Cafe Himalaya"];
    final List<String> allTenants = ["Cafe Himalaya", "Momo Station", "Spice Garden", "Boudha Bakery"];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              const Icon(Icons.send_to_mobile, color: SAMStyles.royalBlue),
              const SizedBox(width: 12),
              Text("Deploy ${item['name']}"),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Select target restaurant tenants for this catalog update:", style: TextStyle(color: SAMStyles.textGrey, fontSize: 13)),
                const SizedBox(height: 20),
                ...allTenants.map((t) => CheckboxListTile(
                  title: Text(t, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  value: selectedTenants.contains(t),
                  activeColor: SAMStyles.royalBlue,
                  onChanged: (val) {
                    setModalState(() {
                      if (val!) {
                        selectedTenants.add(t);
                      } else {
                        selectedTenants.remove(t);
                      }
                    });
                  },
                )),
                const SizedBox(height: 20),
                const Divider(),
                const Text("Option: Overwrite existing prices if item exists?", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                SwitchListTile(
                  title: const Text("Overwrite Prices", style: TextStyle(fontSize: 12)),
                  value: true, 
                  onChanged: (v) {},
                  activeThumbColor: SAMStyles.emeraldGreen,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL", style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showPushSuccess(context, item['name']!);
              },
              child: const Text("DEPLOY UPDATE"),
            ),
          ],
        ),
      ),
    );
  }

  void _showPushSuccess(BuildContext context, String itemName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Global Push Complete: $itemName has been deployed!"),
        backgroundColor: SAMStyles.emeraldGreen,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(32),
      ),
    );
  }
}
