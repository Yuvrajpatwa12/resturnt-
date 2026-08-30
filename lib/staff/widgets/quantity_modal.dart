import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class QuantityModal extends StatefulWidget {
  final Map<String, dynamic> productData;
  final int initialQuantity;
  final Function(int) onConfirm;

  const QuantityModal({
    super.key,
    required this.productData,
    required this.initialQuantity,
    required this.onConfirm,
  });

  static void show(BuildContext context, Map<String, dynamic> productData, int initialQuantity, Function(int) onConfirm) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => QuantityModal(
        productData: productData,
        initialQuantity: initialQuantity,
        onConfirm: onConfirm,
      ),
    );
  }

  @override
  State<QuantityModal> createState() => _QuantityModalState();
}

class _QuantityModalState extends State<QuantityModal> {
  late int _quantity;

  @override
  void initState() {
    super.initState();
    _quantity = widget.initialQuantity > 0 ? widget.initialQuantity : 1;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 30),
          
          Text(
            widget.productData['title'],
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            widget.productData['price'],
            style: const TextStyle(fontSize: 16, color: Color(0xFFFF5C00), fontWeight: FontWeight.bold),
          ),
          
          const SizedBox(height: 40),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildCounterBtn(Icons.remove, () {
                if (_quantity > 1) {
                  HapticFeedback.lightImpact();
                  setState(() => _quantity--);
                }
              }),
              Container(
                width: 100,
                alignment: Alignment.center,
                child: Text(
                  "$_quantity",
                  style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: Colors.black87),
                ),
              ),
              _buildCounterBtn(Icons.add, () {
                HapticFeedback.lightImpact();
                setState(() => _quantity++);
              }, isPrimary: true),
            ],
          ),
          
          const SizedBox(height: 50),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                widget.onConfirm(_quantity);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5C00),
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                elevation: 0,
              ),
              child: const Text("SET QUANTITY", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () {
              widget.onConfirm(0); // Removing item
              Navigator.pop(context);
            },
            child: const Text("REMOVE FROM ORDER", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildCounterBtn(IconData icon, VoidCallback onTap, {bool isPrimary = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isPrimary ? const Color(0xFFFF5C00) : Colors.grey[100],
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: isPrimary ? Colors.white : Colors.black87, size: 28),
      ),
    );
  }
}
