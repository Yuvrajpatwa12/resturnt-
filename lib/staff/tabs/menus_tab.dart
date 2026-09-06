import 'dart:ui';
import 'package:flutter/material.dart';
import '../../cart_manager.dart';
import '../../app_data.dart';

import '../widgets/quantity_modal.dart';
import '../widgets/checkout_modal.dart';
import '../widgets/prep_timer_modal.dart';

class MenusTab extends StatefulWidget {
  final int tableId;
  const MenusTab({super.key, required this.tableId});

  @override
  State<MenusTab> createState() => _MenusTabState();
}

class _MenusTabState extends State<MenusTab> with SingleTickerProviderStateMixin {
  final String _searchQuery = "";
  String _selectedCategory = "Cold";

  void _confirmOrderWithTimer(int minutes) {
    final pending = ShopManager.instance.pendingTableOrders.value[widget.tableId] ?? {};
    if (pending.isEmpty) return;
    
    ShopManager.instance.addOrderToTable(widget.tableId, pending.values.toList());
    ShopManager.instance.startTableTimer(widget.tableId, minutes);
    
    // Clear pending for this table
    ShopManager.instance.clearPendingOrder(widget.tableId);
    
    if (widget.tableId != 0) {
      ShopManager.instance.activeStaffTableId.value = null;
      ShopManager.instance.waiterTabIndex.value = 0; 
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Text("Table 1F-0${widget.tableId % 100} synced! Prep: ${minutes}m"),
          ],
        ),
        backgroundColor: const Color(0xFFFF5C00),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }

  void _handleItemTap(Map<String, dynamic> p) {
    int currentQty = ShopManager.instance.pendingTableOrders.value[widget.tableId]?[p['title']]?.quantity ?? 0;

    QuantityModal.show(context, p, currentQty, (newQty) {
      ShopManager.instance.setPendingItem(widget.tableId, p, newQty);
    });
  }

  @override
  Widget build(BuildContext context) {
    final categories = ["Cold", "Hot", "Salad", "Drinks", "Desserts"];
    final filteredProducts = AppData.darazStyleProducts.where((p) {
      final matchesSearch = p['title'].toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == "All" || (p['tag'] ?? "").contains(_selectedCategory.toUpperCase());
      return matchesSearch && matchesCategory;
    }).toList();

    if (widget.tableId == 0) {
      // ... (No Table Selected view)
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(color: const Color(0xFFFF5C00).withValues(alpha: 0.05), shape: BoxShape.circle),
              child: const Icon(Icons.table_restaurant_rounded, size: 80, color: Color(0xFFFF5C00)),
            ),
            const SizedBox(height: 30),
            const Text("No Table Selected", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            const Text("Select a table from the floor plan to start.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () => ShopManager.instance.waiterTabIndex.value = 0,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5C00),
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              child: const Text("GO TO TABLES", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
      );
    }

    return ValueListenableBuilder<Map<int, Map<String, CartItem>>>(
      valueListenable: ShopManager.instance.pendingTableOrders,
      builder: (context, pendingOrders, child) {
        final tablePending = pendingOrders[widget.tableId] ?? {};
        
        return Stack(
          children: [
            // --- 1. MAIN CONTENT (Categories + Grid) ---
            Column(
              children: [
                Container(
                  color: Colors.white,
                  height: 60,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      bool isSel = _selectedCategory == categories[index];
                      return GestureDetector(
                        onTap: () => setState(() => _selectedCategory = categories[index]),
                        child: Container(
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                categories[index],
                                style: TextStyle(
                                  fontSize: 13, 
                                  fontWeight: isSel ? FontWeight.w900 : FontWeight.bold, 
                                  color: isSel ? Colors.black87 : Colors.grey[400]
                                ),
                              ),
                              if (isSel)
                                Container(margin: const EdgeInsets.only(top: 4), width: 20, height: 2, color: const Color(0xFFFF5C00)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 120), // Bottom padding for tray
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 15,
                      mainAxisSpacing: 15,
                      childAspectRatio: 0.8,
                    ),
                    itemCount: filteredProducts.length,
                    itemBuilder: (context, index) {
                      final p = filteredProducts[index];
                      bool isTicked = tablePending.containsKey(p['title']);
                      int currentTickedQty = isTicked ? tablePending[p['title']]!.quantity : 0;

                      return GestureDetector(
                        onTap: () => _handleItemTap(p),
                        child: Stack(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isTicked ? const Color(0xFFFF5C00) : Colors.transparent,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: isTicked 
                                        ? const Color(0xFFFF5C00).withValues(alpha: 0.1) 
                                        : Colors.black.withValues(alpha: 0.02), 
                                    blurRadius: 10
                                  )
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                                      child: Image.network(p['image'], width: double.infinity, fit: BoxFit.cover),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(p['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 4),
                                        Text(p['price'], style: const TextStyle(color: Color(0xFFFF5C00), fontWeight: FontWeight.w900, fontSize: 14)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Tick Icon with Quantity
                            Positioned(
                              top: 10,
                              right: 10,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: isTicked ? const Color(0xFFFF5C00) : Colors.white.withValues(alpha: 0.8),
                                  shape: BoxShape.circle,
                                  boxShadow: [if (isTicked) BoxShadow(color: Colors.black12, blurRadius: 4)],
                                ),
                                child: isTicked 
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.check, size: 10, color: Colors.white),
                                        const SizedBox(width: 2),
                                        Text("$currentTickedQty", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ],
                                    )
                                  : const Icon(Icons.add, size: 12, color: Colors.grey),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

            // --- 2. FLOATING TABLE PILL (Top) ---
            Positioned(
              top: 15,
              left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.table_bar_rounded, color: Color(0xFFFF5C00), size: 14),
                      const SizedBox(width: 8),
                      Text(
                        "TABLE ${widget.tableId < 200 ? '1F' : '2F'}-0${widget.tableId % 100}",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => ShopManager.instance.activeStaffTableId.value = null,
                        child: const Icon(Icons.close, color: Colors.white70, size: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // --- 3. FLOATING GLASS TRAY (Bottom) ---
            if (tablePending.isNotEmpty)
              Positioned(
                bottom: 25,
                left: 20,
                right: 20,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(25),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(color: const Color(0xFFFF5C00).withValues(alpha: 0.2)),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20)],
                      ),
                      child: Row(
                        children: [
                          // Item Preview Stack
                          SizedBox(
                            width: 100,
                            height: 40,
                            child: Stack(
                              children: tablePending.values.toList().asMap().entries.map((entry) {
                                final i = entry.key;
                                final item = entry.value;
                                if (i > 2) return const SizedBox.shrink();
                                return Positioned(
                                  left: i * 25.0,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                    child: CircleAvatar(
                                      radius: 18,
                                      backgroundImage: NetworkImage(item.product.image),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "${tablePending.length} ITEMS SELECTED",
                                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1),
                                ),
                                Text(
                                  "NPR ${_calculateTotal(tablePending)}",
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.black87),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              CheckoutModal.show(context, tablePending.values.toList(), () {
                                PrepTimerModal.show(context, (mins) {
                                  _confirmOrderWithTimer(mins);
                                });
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF5C00),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              elevation: 0,
                            ),
                            child: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  String _calculateTotal(Map<String, CartItem> pending) {
    double total = 0;
    for (var item in pending.values) {
      String priceStr = item.product.price.replaceAll('NPR ', '').replaceAll(',', '');
      double price = double.tryParse(priceStr) ?? 0;
      total += price * item.quantity;
    }
    return total.toStringAsFixed(0);
  }
}
