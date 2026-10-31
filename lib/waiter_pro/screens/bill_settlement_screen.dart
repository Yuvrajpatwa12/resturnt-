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
  final Set<String> _selectedPaymentModes = {'Fonepay QR'};
  String _splitMode = 'Equally';
  final Map<String, TextEditingController> _paymentAmounts = {
    'Cash': TextEditingController(),
    'Fonepay QR': TextEditingController(),
    'Card': TextEditingController(),
    'Credit': TextEditingController(),
  };
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _tipController = TextEditingController();
  late int tableIdInt;

  @override
  void initState() {
    super.initState();
    tableIdInt = ShopManager.parseTableId(widget.tableId);
  }

  @override
  void dispose() {
    for (final controller in _paymentAmounts.values) {
      controller.dispose();
    }
    _discountController.dispose();
    _tipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<int, List<CartItem>>>(
      valueListenable: ShopManager.instance.tableOrders,
      builder: (context, allOrders, child) {
        final orderItems = allOrders[tableIdInt] ?? [];

        double subtotal = 0;
        for (var item in orderItems) {
          double price =
              double.tryParse(
                item.product.price.replaceAll(RegExp(r'[^0-9.]'), ''),
              ) ??
              0;
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
                      const Text(
                        "Itemized Summary",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...orderItems.map((item) {
                        double price =
                            double.tryParse(
                              item.product.price.replaceAll(
                                RegExp(r'[^0-9.]'),
                                '',
                              ),
                            ) ??
                            0;
                        return _buildBillItem(
                          item.product.title,
                          item.quantity,
                          price,
                        );
                      }),
                      const Divider(height: 40),
                      _buildSummaryRow(
                        "Subtotal",
                        "NPR ${subtotal.toStringAsFixed(2)}",
                      ),
                      _buildSummaryRow(
                        "Service Charge (10%)",
                        "NPR ${serviceCharge.toStringAsFixed(2)}",
                      ),
                      _buildSummaryRow(
                        "VAT (13%)",
                        "NPR ${vat.toStringAsFixed(2)}",
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: WaiterProTheme.royalBlue.withValues(
                            alpha: 0.05,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _buildSummaryRow(
                          "GRAND TOTAL",
                          "NPR ${total.toStringAsFixed(2)}",
                          isTotal: true,
                        ),
                      ),
                      const SizedBox(height: 32),
                      _buildPreviewSection(
                        title: "Split bill",
                        subtitle:
                            "Preview only — split calculation is not connected.",
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: ['Equally', 'By item', 'By person']
                              .map(
                                (mode) => ChoiceChip(
                                  label: Text(mode),
                                  selected: _splitMode == mode,
                                  onSelected: (_) =>
                                      setState(() => _splitMode = mode),
                                  selectedColor: WaiterProTheme.royalBlue,
                                  labelStyle: TextStyle(
                                    color: _splitMode == mode
                                        ? Colors.white
                                        : WaiterProTheme.darkNavy,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildPreviewSection(
                        title: "Payment methods",
                        subtitle:
                            "Enter amounts for a split tender. Values are not applied to settlement.",
                        child: Column(
                          children: _paymentAmounts.entries.map((entry) {
                            final isSelected = _selectedPaymentModes.contains(
                              entry.key,
                            );
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: isSelected,
                                    onChanged: (selected) => setState(() {
                                      if (selected == true) {
                                        _selectedPaymentModes.add(entry.key);
                                      } else {
                                        _selectedPaymentModes.remove(entry.key);
                                      }
                                    }),
                                  ),
                                  Expanded(
                                    child: Text(
                                      entry.key,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 120,
                                    child: TextField(
                                      controller: entry.value,
                                      enabled: isSelected,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      decoration: const InputDecoration(
                                        prefixText: "NPR ",
                                        hintText: "Amount",
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildPreviewSection(
                        title: "Discount & tip",
                        subtitle:
                            "Preview fields only — totals and settlement are unchanged.",
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _discountController,
                                decoration: const InputDecoration(
                                  labelText: "Discount / coupon",
                                  hintText: "Code or amount",
                                  prefixIcon: Icon(Icons.local_offer_outlined),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _tipController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: "Tip",
                                  hintText: "NPR",
                                  prefixIcon: Icon(Icons.volunteer_activism),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        "KOT printing is not connected yet.",
                                      ),
                                    ),
                                  ),
                              icon: const Icon(Icons.print),
                              label: const Text("PRINT KOT"),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 54),
                                side: const BorderSide(
                                  color: WaiterProTheme.royalBlue,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                ShopManager.instance.settleTable(tableIdInt);
                                Navigator.pop(
                                  context,
                                ); // Go back after settlement
                              },
                              icon: const Icon(Icons.receipt),
                              label: const Text("SETTLE & FREE"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: WaiterProTheme.emeraldGreen,
                                minimumSize: const Size(0, 54),
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
          Expanded(
            child: Text(
              "$qty x $name",
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            "NPR ${(qty * price).toStringAsFixed(0)}",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewSection({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: WaiterProTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: WaiterProTheme.darkNavy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          child,
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
          Text(
            label,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.w900 : FontWeight.w500,
              fontSize: isTotal ? 18 : 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.w900 : FontWeight.bold,
              fontSize: isTotal ? 18 : 14,
              color: isTotal ? WaiterProTheme.royalBlue : null,
            ),
          ),
        ],
      ),
    );
  }
}
