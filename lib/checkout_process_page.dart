import 'package:flutter/material.dart';
import 'cart_manager.dart';
import 'order_success_page.dart';

class CheckoutProcessPage extends StatelessWidget {
  const CheckoutProcessPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "Checkout Summary",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Order Summary",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 24),
                  
                  // Table Assignment Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF5C00).withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFF5C00).withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.restaurant_menu_rounded, color: Color(0xFFFF5C00), size: 24),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("TABLE ASSIGNMENT", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
                            ValueListenableBuilder<int?>(
                              valueListenable: ShopManager.instance.selectedTableId,
                              builder: (context, tableId, child) => Text(
                                tableId != null ? "TABLE ${tableId.toString().padLeft(2, '0')}" : "NOT SELECTED",
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tableId != null ? Colors.black87 : Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  const Text(
                    "Selected Items",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ValueListenableBuilder<List<CartItem>>(
                    valueListenable: ShopManager.instance.items,
                    builder: (context, items, child) {
                      return Column(
                        children: items.map((item) => Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 5)],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 32, height: 32,
                                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                                    child: Center(child: Text("${item.quantity}x", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFFF5C00)))),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(item.product.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                ],
                              ),
                              Text(item.product.price, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                            ],
                          ),
                        )).toList(),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 32),
                  const Text(
                    "Service Info",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Row(
                    children: [
                      Icon(Icons.bolt_rounded, color: Colors.amber, size: 20),
                      SizedBox(width: 8),
                      Text("Instant In-House Processing", style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(32),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -5))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Bill Total", style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold)),
                    Text(
                      "NPR ${ShopManager.instance.totalPrice.toStringAsFixed(0)}",
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFFFF5C00)),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ValueListenableBuilder<int?>(
                    valueListenable: ShopManager.instance.selectedTableId,
                    builder: (context, tableId, child) => ElevatedButton(
                      onPressed: tableId == null ? null : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const OrderSuccessPage()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5C00),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 22),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 10,
                        shadowColor: const Color(0xFFFF5C00).withValues(alpha: 0.4),
                      ),
                      child: Text(
                        tableId == null ? "SELECT TABLE FIRST" : "Confirm & Place Order",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
