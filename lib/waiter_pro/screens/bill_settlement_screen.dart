import 'package:flutter/material.dart';
import '../../cart_manager.dart';
import '../theme.dart';

class BillSettlementScreen extends StatefulWidget {
  final String tableId;
  const BillSettlementScreen({super.key, required this.tableId});

  @override
  State<BillSettlementScreen> createState() => _BillSettlementScreenState();
}

class _BillSettlementScreenState extends State<BillSettlementScreen> {
  String _selectedPaymentMode = 'Fonepay QR';
  late int tableIdInt;

  @override
  void initState() {
    super.initState();
    tableIdInt = ShopManager.parseTableId(widget.tableId);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<int, List<CartItem>>>(
      valueListenable: ShopManager.instance.tableOrders,
      builder: (context, allOrders, child) {
        final orderItems = allOrders[tableIdInt] ?? [];
        
        double subtotal = 0;
        for (var item in orderItems) {
          double price = double.tryParse(item.product.price.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
          subtotal += price * item.quantity;
        }

        double serviceCharge = subtotal * 0.10;
        double vat = (subtotal + serviceCharge) * 0.13;
        double total = subtotal + serviceCharge + vat;

        return Scaffold(
          appBar: AppBar(title: Text("Bill Settlement: ${widget.tableId}")),
          body: orderItems.isEmpty 
            ? const Center(child: Text("No items ordered for this table."))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Itemized Summary", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 16),
                    ...orderItems.map((item) {
                      double price = double.tryParse(item.product.price.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
                      return _buildBillItem(item.product.title, item.quantity, price);
                    }),
                    const Divider(height: 40),
                    _buildSummaryRow("Subtotal", "NPR ${subtotal.toStringAsFixed(2)}"),
                    _buildSummaryRow("Service Charge (10%)", "NPR ${serviceCharge.toStringAsFixed(2)}"),
                    _buildSummaryRow("VAT (13%)", "NPR ${vat.toStringAsFixed(2)}"),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: WaiterProTheme.royalBlue.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _buildSummaryRow("GRAND TOTAL", "NPR ${total.toStringAsFixed(2)}", isTotal: true),
                    ),
                    const SizedBox(height: 32),
                    const Text("Payment Mode", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: ['Cash', 'Fonepay QR', 'Card', 'Credit'].map((mode) {
                        bool isSelected = _selectedPaymentMode == mode;
                        return InkWell(
                          onTap: () => setState(() => _selectedPaymentMode = mode),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? WaiterProTheme.royalBlue : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isSelected ? WaiterProTheme.royalBlue : const Color(0xFFE2E8F0)),
                            ),
                            child: Text(
                              mode,
                              style: TextStyle(
                                color: isSelected ? Colors.white : WaiterProTheme.darkNavy,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 40),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.print),
                            label: const Text("PRINT KOT"),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: const BorderSide(color: WaiterProTheme.royalBlue),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              ShopManager.instance.settleTable(tableIdInt);
                              Navigator.pop(context); // Go back after settlement
                            },
                            icon: const Icon(Icons.receipt),
                            label: const Text("SETTLE & FREE"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: WaiterProTheme.emeraldGreen,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
        );
      },
    );
  }

  Widget _buildBillItem(String name, int qty, double price) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text("$qty x $name", style: const TextStyle(fontWeight: FontWeight.w500))),
          Text("NPR ${(qty * price).toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isTotal ? FontWeight.w900 : FontWeight.w500, fontSize: isTotal ? 18 : 14)),
          Text(value, style: TextStyle(fontWeight: isTotal ? FontWeight.w900 : FontWeight.bold, fontSize: isTotal ? 18 : 14, color: isTotal ? WaiterProTheme.royalBlue : null)),
        ],
      ),
    );
  }
}
