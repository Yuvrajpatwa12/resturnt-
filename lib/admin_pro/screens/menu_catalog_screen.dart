import 'package:flutter/material.dart';
import '../../app_data.dart';
import '../admin_theme.dart';

class MenuCatalogScreen extends StatefulWidget {
  const MenuCatalogScreen({super.key});

  @override
  State<MenuCatalogScreen> createState() => _MenuCatalogScreenState();
}

class _MenuCatalogScreenState extends State<MenuCatalogScreen> {
  String _selectedCategory = 'All';
  final List<String> _categories = ['All', 'Sandwiches', 'Roast Beef', 'Sides', 'Drinks', 'Desserts'];

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> products = List.from(AppData.darazStyleProducts);
    if (_selectedCategory != 'All') {
      products = products.where((p) => p['title'].toString().toLowerCase().contains(_selectedCategory.toLowerCase()) || p['tag'].toString().toLowerCase().contains(_selectedCategory.toLowerCase())).toList();
    }

    return Column(
      children: [
        _buildTopActionHeader(),
        _buildCategoryFilter(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return _buildMenuManagementCard(product);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTopActionHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("Menu Catalog", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add, size: 18),
            label: const Text("ADD ITEM", style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              minimumSize: const Size(0, 45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final isSelected = _selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: ChoiceChip(
              label: Text(cat, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              selected: isSelected,
              onSelected: (val) => setState(() => _selectedCategory = cat),
              selectedColor: AdminTheme.royalBlue,
              labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMenuManagementCard(Map<String, dynamic> product) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AdminTheme.softShadow,
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(product['image'], width: 60, height: 60, fit: BoxFit.cover),
            ),
            title: Text(product['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(product['price'], style: const TextStyle(color: AdminTheme.royalBlue, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(6)),
                  child: Text(product['tag'], style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            trailing: PopupMenuButton(
              itemBuilder: (context) => [
                const PopupMenuItem(child: Text("Edit Item")),
                const PopupMenuItem(child: Text("Manage Variants")),
                const PopupMenuItem(child: Text("Delete", style: TextStyle(color: Colors.red))),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Item Availability", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    const Text("Out of Stock", style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Switch.adaptive(
                      value: true, 
                      onChanged: (val) {},
                      activeTrackColor: AdminTheme.emeraldGreen,
                    ),
                    const Text("In Stock", style: TextStyle(fontSize: 10, color: AdminTheme.emeraldGreen, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
