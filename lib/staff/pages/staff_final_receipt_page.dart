import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../cart_manager.dart';

class StaffFinalReceiptPage extends StatefulWidget {
  final int tableId;
  const StaffFinalReceiptPage({super.key, required this.tableId});

  @override
  State<StaffFinalReceiptPage> createState() => _StaffFinalReceiptPageState();
}

class _StaffFinalReceiptPageState extends State<StaffFinalReceiptPage> {
  bool _isSending = false;
  double _billY = 0;
  double _billOpacity = 1.0;

  void _sendBill() {
    HapticFeedback.heavyImpact();
    setState(() {
      _isSending = true;
      _billY = -500;
      _billOpacity = 0.0;
    });

    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      ShopManager.instance.updateTableStatus(widget.tableId, "Billed");
      Navigator.pop(context); // Close receipt
      Navigator.pop(context); // Return to tables
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Bill sent to customer's phone! 📱✨"),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final orderItems = ShopManager.instance.tableOrders.value[widget.tableId] ?? [];
    double subtotal = 0;
    for (var item in orderItems) {
      String priceStr = item.product.price.replaceAll('NPR ', '').replaceAll(',', '');
      double price = double.tryParse(priceStr) ?? 0;
      subtotal += price * item.quantity;
    }
    double cgst = subtotal * 0.05;
    double sgst = subtotal * 0.05;
    double total = subtotal + cgst + sgst;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text("Digital Receipt", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        leading: IconButton(icon: const Icon(Icons.close, color: Colors.black87), onPressed: () => Navigator.pop(context)),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeInBack,
                  transform: Matrix4.translationValues(0, _billY, 0),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 500),
                    opacity: _billOpacity,
                    child: Container(
                      padding: const EdgeInsets.all(30),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20)],
                      ),
                      child: Column(
                        children: [
                          const Text("ChiyaBreak Downtown", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                          const Text("88 Sunrise Avenue, Kathmandu", style: TextStyle(fontSize: 11, color: Colors.grey)),
                          const Text("CONTACT NO: 9812345678", style: TextStyle(fontSize: 11, color: Colors.grey)),
                          const Divider(height: 40),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildMetaItem("Date", "20/08/2026"),
                              _buildMetaItem("Time", "14:45"),
                              _buildMetaItem("Table", widget.tableId.toString()),
                            ],
                          ),
                          const Divider(height: 40),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildMetaItem("RECEIPT NO", "INV-2026-9042"),
                              _buildMetaItem("CUSTOMER", "Guest User"),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildMetaItem("PAYMENT", "Mobile Pay"),
                            ],
                          ),
                          const Divider(height: 40),
                          
                          // Itemized List
                          ...orderItems.map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("${item.quantity} x ${item.product.title}", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                Text(item.product.price, style: const TextStyle(fontSize: 13)),
                              ],
                            ),
                          )),
                          
                          const Divider(height: 40),
                          _buildSummaryItem("SUBTOTAL", "NPR ${subtotal.toStringAsFixed(0)}"),
                          _buildSummaryItem("CGST (5%)", "NPR ${cgst.toStringAsFixed(0)}"),
                          _buildSummaryItem("SGST (5%)", "NPR ${sgst.toStringAsFixed(0)}"),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("TOTAL", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                              Text("NPR ${total.toStringAsFixed(0)}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFFFF5C00))),
                            ],
                          ),
                          const SizedBox(height: 40),
                          const Text("THANK YOU. VISIT AGAIN.", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
          
          // Floating Send Button
          Positioned(
            bottom: 40,
            left: 30,
            right: 30,
            child: ElevatedButton.icon(
              onPressed: _isSending ? null : _sendBill,
              icon: const Icon(Icons.send_rounded, size: 20),
              label: Text(_isSending ? "SENDING..." : "SEND TO CUSTOMER'S PHONE"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5C00),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                elevation: 10,
                shadowColor: const Color(0xFFFF5C00).withValues(alpha: 0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
