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
                    "Order Items",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ValueListenableBuilder<List<CartItem>>(
                    valueListenable: ShopManager.instance.items,
                    builder: (context, items, child) {
                      return Column(
                        children: items.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("${item.quantity}x ${item.product.title}", style: const TextStyle(color: Colors.grey)),
                              Text(item.product.price),
                            ],
                          ),
                        )).toList(),
                      );
                    },
                  ),
                  const Divider(height: 40),
                  const Text(
                    "Table Assignment",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Row(
                    children: [
                      Icon(Icons.restaurant, color: Color(0xFFFF5C00), size: 20),
                      SizedBox(width: 8),
                      Text("TABLE 12 - Main Hall", style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                  const Divider(height: 40),
                  const Text(
                    "Payment Method",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Row(
                    children: [
                      Icon(Icons.payment, color: Color(0xFFFF5C00), size: 20),
                      SizedBox(width: 8),
                      Text("Cash on Delivery", style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Subtotal", style: TextStyle(color: Colors.grey)),
                    Text("NPR ${ShopManager.instance.totalPrice.toStringAsFixed(0)}"),
                  ],
                ),
                const SizedBox(height: 8),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Delivery Fee", style: TextStyle(color: Colors.grey)),
                    Text("NPR 50"),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Total", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(
                      "NPR ${(ShopManager.instance.totalPrice + 50).toStringAsFixed(0)}",
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFFF5C00)),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const OrderSuccessPage()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5C00),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text("Confirm Order", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
