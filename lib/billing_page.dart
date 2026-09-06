import 'package:flutter/material.dart';
import 'cart_manager.dart';

class BillingPage extends StatefulWidget {
  const BillingPage({super.key});

  @override
  State<BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends State<BillingPage> {
  @override
  Widget build(BuildContext context) {
    final orderItems = ShopManager.instance.placedOrderItems.value;
    double subtotal = 0;
    for (var item in orderItems) {
      String priceStr = item.product.price.replaceAll('NPR ', '').replaceAll(',', '');
      subtotal += (double.tryParse(priceStr) ?? 0) * item.quantity;
    }
    const double serviceCharge = 50.0;
    final double total = subtotal + serviceCharge;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Official Invoice",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w900, letterSpacing: 0.5),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // --- 1. PREMIUM BILL HEADER ---
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 15, offset: const Offset(0, 8))],
              ),
              child: Column(
                children: [
                  const Text("CHIYABREAK DOWNTOWN HUB", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 2, color: Color(0xFFFF5C00))),
                  const SizedBox(height: 12),
                  const Text("TABLE 12", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.black87)),
                  const SizedBox(height: 8),
                  Text("Order ID: #CB-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}", style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w600)),
                  const Divider(height: 40),
                  
                  // Item List
                  ...orderItems.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8)),
                          child: Text("${item.quantity}x", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54, fontSize: 12)),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Text(item.product.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                        ),
                        Text(item.product.price, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.black87)),
                      ],
                    ),
                  )),
                  
                  const Divider(height: 30),
                  
                  // Summary
                  _buildSummaryRow("Subtotal", "NPR ${subtotal.toStringAsFixed(0)}"),
                  const SizedBox(height: 12),
                  _buildSummaryRow("Service Charge", "NPR ${serviceCharge.toStringAsFixed(0)}"),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Grand Total", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black87)),
                      Text(
                        "NPR ${total.toStringAsFixed(0)}", 
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFFFF5C00))
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // --- 2. QR PAYMENT SECTION ---
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.3), width: 2), // Champagne Gold touch
                boxShadow: [BoxShadow(color: const Color(0xFFD4AF37).withValues(alpha: 0.05), blurRadius: 20)],
              ),
              child: Column(
                children: [
                  const Text("SCAN & PAY AT TABLE", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.5, color: Colors.amber)),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey[100]!),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.qr_code_2_rounded, size: 180, color: Colors.black87),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "You can also pay digitally using the button below.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // --- 3. PAY BUTTON ---
            ValueListenableBuilder<bool>(
              valueListenable: ShopManager.instance.isOrderPaid,
              builder: (context, isPaid, child) {
                return SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isPaid ? null : () {
                      setState(() => ShopManager.instance.isOrderPaid.value = true);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Payment Successful! Receipt emailed.")));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isPaid ? Colors.green : const Color(0xFFFF5C00),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 0,
                    ),
                    child: Text(
                      isPaid ? "PAID SUCCESSFULLY" : "COMPLETE PAYMENT",
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.w600)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
      ],
    );
  }
}
