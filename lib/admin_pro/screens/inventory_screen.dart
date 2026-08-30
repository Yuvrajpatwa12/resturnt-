import 'package:flutter/material.dart';
import '../../cart_manager.dart';
import '../admin_theme.dart';

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, dynamic>>(
      valueListenable: ShopManager.instance.inventoryStock,
      builder: (context, stock, child) {
        return Column(
          children: [
            _buildInventoryHeader(),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: stock.keys.length,
                itemBuilder: (context, index) {
                  String name = stock.keys.elementAt(index);
                  Map<String, dynamic> data = stock[name];
                  return _buildInventoryItemCard(name, data);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInventoryHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("Stock Control", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.add_box_outlined, color: AdminTheme.royalBlue),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryItemCard(String name, Map<String, dynamic> data) {
    Color statusColor;
    switch (data['status']) {
      case 'Critical': statusColor = Colors.red; break;
      case 'Low': statusColor = Colors.orange; break;
      default: statusColor = AdminTheme.emeraldGreen;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AdminTheme.softShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.inventory_2_outlined, color: statusColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text("Supplier: ${data['supplier']}", style: const TextStyle(color: Colors.grey, fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text("${data['amount']}${data['unit']}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(6)),
                child: Text(data['status'].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
