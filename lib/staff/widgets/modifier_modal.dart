import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models.dart';
import '../../cart_manager.dart';

class ModifierModal extends StatefulWidget {
  final Map<String, dynamic> productData;
  final Function(CartItem) onAdd;

  const ModifierModal({
    super.key,
    required this.productData,
    required this.onAdd,
  });

  static void show(BuildContext context, Map<String, dynamic> productData, Function(CartItem) onAdd) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ModifierModal(productData: productData, onAdd: onAdd),
    );
  }

  @override
  State<ModifierModal> createState() => _ModifierModalState();
}

class _ModifierModalState extends State<ModifierModal> {
  String selectedSize = "Medium";
  List<String> selectedExtras = [];
  int quantity = 1;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
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
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.network(widget.productData['image'], width: 100, height: 100, fit: BoxFit.cover),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Change to Hot", style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                      Text(widget.productData['title'], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                      Text(widget.productData['price'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFFF5C00))),
                    ],
                  ),
                ),
                Row(
                  children: [
                    _buildCircleBtn(Icons.remove, () {
                      if (quantity > 1) {
                        HapticFeedback.lightImpact();
                        setState(() => quantity--);
                      }
                    }),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text("$quantity", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    _buildCircleBtn(Icons.add, () {
                      HapticFeedback.lightImpact();
                      setState(() => quantity++);
                    }, isOrange: true),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Size Up", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildModifierOption("Small", "NPR 100", selectedSize == "Small", () {
                        HapticFeedback.selectionClick();
                        setState(() => selectedSize = "Small");
                      }),
                      _buildModifierOption("Medium", "NPR 0", selectedSize == "Medium", () {
                        HapticFeedback.selectionClick();
                        setState(() => selectedSize = "Medium");
                      }),
                      _buildModifierOption("Large", "NPR 200", selectedSize == "Large", () {
                        HapticFeedback.selectionClick();
                        setState(() => selectedSize = "Large");
                      }),
                    ],
                  ),
                  const SizedBox(height: 30),
                  const Text("Add-ons", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildModifierOption("+ Syrup", "NPR 30", selectedExtras.contains("Syrup"), () {
                        HapticFeedback.selectionClick();
                        setState(() => selectedExtras.contains("Syrup") ? selectedExtras.remove("Syrup") : selectedExtras.add("Syrup"));
                      }),
                      _buildModifierOption("+ Ice", "NPR 30", selectedExtras.contains("Ice"), () {
                        HapticFeedback.selectionClick();
                        setState(() => selectedExtras.contains("Ice") ? selectedExtras.remove("Ice") : selectedExtras.add("Ice"));
                      }),
                      _buildModifierOption("+ Shot", "NPR 50", selectedExtras.contains("Shot"), () {
                        HapticFeedback.selectionClick();
                        setState(() => selectedExtras.contains("Shot") ? selectedExtras.remove("Shot") : selectedExtras.add("Shot"));
                      }),
                    ],
                  ),
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(30),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Product product = Product(
                    title: widget.productData['title'],
                    price: widget.productData['price'],
                    image: widget.productData['image'],
                    tag: widget.productData['tag'] ?? "Staff",
                    rating: widget.productData['rating'] ?? "N/A",
                    discount: widget.productData['discount'] ?? "",
                  );
                  widget.onAdd(CartItem(
                    product: product,
                    quantity: quantity,
                    size: selectedSize,
                    extras: List.from(selectedExtras),
                  ));
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5C00),
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: const Text("Add to Order", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleBtn(IconData icon, VoidCallback onTap, {bool isOrange = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isOrange ? const Color(0xFFFF5C00) : Colors.grey[100],
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: isOrange ? Colors.white : Colors.black87, size: 16),
      ),
    );
  }

  Widget _buildModifierOption(String label, String price, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF5C00).withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: isSelected ? const Color(0xFFFF5C00) : Colors.grey[200]!),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold)),
            Text(price, style: TextStyle(fontSize: 10, color: isSelected ? const Color(0xFFFF5C00) : Colors.grey)),
          ],
        ),
      ),
    );
  }
}
