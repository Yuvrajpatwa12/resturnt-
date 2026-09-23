import 'package:flutter/material.dart';
import 'cart_manager.dart';
import 'models.dart';
import 'checkout_process_page.dart';

class CartPage extends StatelessWidget {
  const CartPage({super.key});

  void _showDeleteConfirmationDialog(BuildContext context, Product product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text("Remove Item?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text(
          "Are you sure you want to delete '${product.title}' from your cart?",
          style: const TextStyle(fontSize: 14, color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () {
              ShopManager.instance.removeFromCart(product);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("'${product.title}' removed from cart"),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Yes, Remove", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItemImage(String imagePath) {
    if (imagePath.isEmpty) {
      return Container(
        width: 80,
        height: 80,
        color: const Color(0xFFFFF0E5),
        child: const Icon(Icons.fastfood, color: Colors.orange, size: 28),
      );
    }
    if (imagePath.startsWith('assets/')) {
      return Image.asset(
        imagePath,
        width: 80,
        height: 80,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: 80,
          height: 80,
          color: const Color(0xFFFFF0E5),
          child: const Icon(Icons.fastfood, color: Colors.orange, size: 28),
        ),
      );
    }
    return Image.network(
      imagePath,
      width: 80,
      height: 80,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        width: 80,
        height: 80,
        color: const Color(0xFFFFF0E5),
        child: const Icon(Icons.fastfood, color: Colors.orange, size: 28),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "My Cart",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => ShopManager.instance.currentTabIndex.value = 0,
        ),
      ),
      body: ValueListenableBuilder<List<CartItem>>(
        valueListenable: ShopManager.instance.items,
        builder: (context, items, child) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text("Your cart is empty", style: TextStyle(fontSize: 18, color: Colors.grey)),
                ],
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: _buildCartItemImage(item.product.image),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.product.title,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.product.price,
                                  style: const TextStyle(color: Color(0xFFFF5C00), fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    _quantityBtn(Icons.remove, () {
                                      if (item.quantity > 1) {
                                        ShopManager.instance.updateQuantity(item.product, item.quantity - 1);
                                      } else {
                                        _showDeleteConfirmationDialog(context, item.product);
                                      }
                                    }),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      child: Text("${item.quantity}", style: const TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                    _quantityBtn(Icons.add, () {
                                      ShopManager.instance.updateQuantity(item.product, item.quantity + 1);
                                    }),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _showDeleteConfirmationDialog(context, item.product),
                          ),
                        ],
                      ),
                    );
                  },
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
                        const Text("Total Amount", style: TextStyle(fontSize: 16, color: Colors.grey)),
                        Text(
                          "NPR ${ShopManager.instance.totalPrice.toStringAsFixed(0)}",
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFFF5C00)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          if (ShopManager.instance.selectedTableId.value == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Please select your table number first!"),
                                backgroundColor: Color(0xFFFF5C00),
                              ),
                            );
                            ShopManager.instance.currentTabIndex.value = 0; // Go Home to select table
                            return;
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const CheckoutProcessPage()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF5C00),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text("Proceed to Checkout", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _quantityBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: Colors.black),
      ),
    );
  }
}
