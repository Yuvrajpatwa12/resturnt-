import 'package:flutter/material.dart';
import '../../cart_manager.dart';

class CheckoutModal extends StatelessWidget {
  final List<CartItem> tempCart;
  final VoidCallback onConfirm;

  const CheckoutModal({
    super.key,
    required this.tempCart,
    required this.onConfirm,
  });

  static void show(BuildContext context, List<CartItem> tempCart, VoidCallback onConfirm) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CheckoutModal(tempCart: tempCart, onConfirm: onConfirm),
    );
  }

  @override
  Widget build(BuildContext context) {
    double total = 0;
    for (var item in tempCart) {
      String priceStr = item.product.price.replaceAll('NPR ', '').replaceAll(',', '');
      double price = double.tryParse(priceStr) ?? 0;
      total += price * item.quantity;
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(2))),
          
          Padding(
            padding: const EdgeInsets.all(30),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("My Order", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),

          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              itemCount: tempCart.length,
              itemBuilder: (context, index) {
                final item = tempCart[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(item.product.image, width: 50, height: 50, fit: BoxFit.cover),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.product.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Text("${item.size} • ${item.extras?.join(', ') ?? 'No extras'}", style: TextStyle(fontSize: 10, color: Colors.grey[400])),
                          ],
                        ),
                      ),
                      Text("${item.quantity}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                );
              },
            ),
          ),

          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Total Estimate", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                    Text("NPR ${total.toStringAsFixed(0)}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFFFF5C00))),
                  ],
                ),
                const SizedBox(height: 30),
                const Text(
                  "Review items with the customer before sending to the kitchen. Payment will be handled at the table later.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.5),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onConfirm();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5C00),
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      elevation: 5,
                      shadowColor: const Color(0xFFFF5C00).withOpacity(0.3),
                    ),
                    child: const Text("CONFIRM & START PREP", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
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
