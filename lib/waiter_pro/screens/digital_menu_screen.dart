import 'package:flutter/material.dart';
import '../../cart_manager.dart';
import '../../app_data.dart';
import '../theme.dart';
import '../widgets/order_customization_dialog.dart';
import 'running_order_summary_screen.dart';

class DigitalMenuScreen extends StatefulWidget {
  final String tableId;
  const DigitalMenuScreen({super.key, required this.tableId});

  @override
  State<DigitalMenuScreen> createState() => _DigitalMenuScreenState();
}

class _DigitalMenuScreenState extends State<DigitalMenuScreen> {
  String _selectedCategory = 'All';
  final List<String> _categories = ['All', 'Sandwiches', 'Roast Beef', 'Sides', 'Drinks', 'Desserts'];
  
  late int tableIdInt;

  @override
  void initState() {
    super.initState();
    tableIdInt = ShopManager.parseTableId(widget.tableId);
  }

  List<Map<String, dynamic>> _getFilteredProducts() {
    List<Map<String, dynamic>> products = List.from(AppData.darazStyleProducts);
    if (_selectedCategory != 'All') {
      products = products.where((item) {
        final tag = (item['tag'] ?? '').toString().toLowerCase();
        final title = (item['title'] ?? '').toString().toLowerCase();
        final cat = _selectedCategory.toLowerCase();
        return tag.contains(cat) || title.contains(cat);
      }).toList();
    }
    return products;
  }

  @override
  Widget build(BuildContext context) {
    final filteredProducts = _getFilteredProducts();

    return ValueListenableBuilder<Map<int, String>>(
      valueListenable: ShopManager.instance.tableStatuses,
      builder: (context, statuses, _) {
        final bool isOccupied = statuses[tableIdInt] == "Dining";

        return ValueListenableBuilder<Map<int, List<CartItem>>>(
          valueListenable: ShopManager.instance.tableOrders,
          builder: (context, allOrders, child) {
            final tableOrders = allOrders[tableIdInt] ?? [];

            return ValueListenableBuilder<Map<int, Map<String, CartItem>>>(
              valueListenable: ShopManager.instance.pendingTableOrders,
              builder: (context, allPending, child) {
                final tablePending = allPending[tableIdInt] ?? {};
                int cartCount = 0;
                double cartTotal = 0.0;
                
                tablePending.forEach((_, item) {
                  cartCount += item.quantity;
                  double price = double.tryParse(item.product.price.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
                  cartTotal += price * item.quantity;
                });

                return Scaffold(
                  appBar: AppBar(
                    title: Text("Order: ${widget.tableId}", style: const TextStyle(fontSize: 18)),
                    actions: [
                      if (isOccupied)
                        TextButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => RunningOrderSummaryScreen(tableId: widget.tableId)),
                            );
                          },
                          icon: const Icon(Icons.list_alt, size: 16),
                          label: const Text("VIEW ORDER", style: TextStyle(fontSize: 11)),
                          style: TextButton.styleFrom(foregroundColor: WaiterProTheme.royalBlue),
                        ),
                      IconButton(onPressed: () {}, icon: const Icon(Icons.search, size: 20)),
                    ],
                  ),
                  body: Column(
                    children: [
                      // Category Slider
                      SizedBox(
                        height: 50,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          itemCount: _categories.length,
                          itemBuilder: (context, index) {
                            bool isSelected = _selectedCategory == _categories[index];
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(_categories[index], style: const TextStyle(fontSize: 12)),
                                selected: isSelected,
                                onSelected: (val) => setState(() => _selectedCategory = _categories[index]),
                                selectedColor: WaiterProTheme.royalBlue,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.white : WaiterProTheme.darkNavy,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      // Items Grid
                      Expanded(
                        child: GridView.builder(
                          padding: const EdgeInsets.all(12),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 0.65,
                          ),
                          itemCount: filteredProducts.length,
                          itemBuilder: (context, index) {
                            final productMap = filteredProducts[index];
                            final title = productMap['title'];
                            
                            final pendingQty = tablePending[title]?.quantity ?? 0;
                            final existingQty = tableOrders.fold<int>(0, (sum, item) => item.product.title == title ? sum + item.quantity : sum);

                            return _buildItemCard(productMap, pendingQty, existingQty);
                          },
                        ),
                      ),
                      // Sticky Cart Bar
                      if (cartCount > 0)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: WaiterProTheme.royalBlue,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, -2))],
                          ),
                          child: SafeArea(
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "$cartCount New Items",
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      Text(
                                        "Total: NPR ${cartTotal.toStringAsFixed(0)}",
                                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    ShopManager.instance.addOrderToTable(tableIdInt, tablePending.values.toList());
                                    ShopManager.instance.clearPendingOrder(tableIdInt);
                                    
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text("Order updated for Table ${widget.tableId}")),
                                    );
                                    
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(builder: (context) => RunningOrderSummaryScreen(tableId: widget.tableId)),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: WaiterProTheme.royalBlue,
                                    minimumSize: const Size(120, 40),
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                  ),
                                  child: const Text("SEND KOT", style: TextStyle(fontSize: 13)),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildItemCard(Map<String, dynamic> p, int pendingQty, int existingQty) {
    String title = p['title'];
    String price = p['price'];
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: WaiterProTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: WaiterProTheme.pearlWhite,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    image: DecorationImage(
                      image: NetworkImage(p['image']),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                if (existingQty > 0)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        "On Table: $existingQty",
                        style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(6.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, height: 1.1),
                ),
                const SizedBox(height: 2),
                Text(
                  price.replaceAll("NPR ", ""),
                  style: const TextStyle(color: WaiterProTheme.royalBlue, fontWeight: FontWeight.w900, fontSize: 11),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => OrderCustomizationDialog(
                            itemName: title,
                            onSave: (notes) {
                              ShopManager.instance.setPendingItem(tableIdInt, p, pendingQty + 1);
                            },
                          ),
                        );
                      },
                      child: const Icon(Icons.settings_outlined, size: 16, color: Colors.grey),
                    ),
                    Container(
                      height: 24,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: WaiterProTheme.royalBlue,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          InkWell(
                            onTap: () {
                              if (pendingQty > 0) ShopManager.instance.setPendingItem(tableIdInt, p, pendingQty - 1);
                            },
                            child: const Icon(Icons.remove, color: Colors.white, size: 14),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text("$pendingQty", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                          InkWell(
                            onTap: () => ShopManager.instance.setPendingItem(tableIdInt, p, pendingQty + 1),
                            child: const Icon(Icons.add, color: Colors.white, size: 14),
                          ),
                        ],
                      ),
                    ),
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
