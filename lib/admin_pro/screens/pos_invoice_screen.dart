import 'package:flutter/material.dart';

import '../admin_theme.dart';

class POSInvoiceScreen extends StatefulWidget {
  const POSInvoiceScreen({super.key});

  @override
  State<POSInvoiceScreen> createState() => _POSInvoiceScreenState();
}

class _POSInvoiceScreenState extends State<POSInvoiceScreen> {
  int _selectedTable = 101;
  String _paymentMethod = "Cash";

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTableSelectionHeader(),
          const SizedBox(height: 24),
          _buildLiveCartPreview(),
          const SizedBox(height: 24),
          _buildPaymentSelection(),
          const SizedBox(height: 32),
          _buildInvoiceSummary(),
          const SizedBox(height: 40),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildTableSelectionHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AdminTheme.softShadow,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Active Table", style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
              Text("Select for Billing", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AdminTheme.royalBlue.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButton<int>(
              value: _selectedTable,
              underline: const SizedBox(),
              icon: const Icon(Icons.keyboard_arrow_down, color: AdminTheme.royalBlue),
              items: [101, 102, 105, 201].map((int value) {
                return DropdownMenuItem<int>(
                  value: value,
                  child: Text("Table T-$value", style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.royalBlue)),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedTable = val!),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveCartPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Current Items", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AdminTheme.softShadow,
          ),
          child: Column(
            children: [
              _buildCartItemRow("Special Masala Tea", "2", "600"),
              const Divider(height: 1, indent: 20, endIndent: 20),
              _buildCartItemRow("Chicken Momo", "1", "450"),
              const Divider(height: 1, indent: 20, endIndent: 20),
              _buildCartItemRow("French Fries", "1", "350"),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCartItemRow(String name, String qty, String price) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Text("Quantity: $qty", style: const TextStyle(fontSize: 12, color: Colors.grey)),
      trailing: Text("NPR $price", style: const TextStyle(fontWeight: FontWeight.w900, color: AdminTheme.darkNavy)),
    );
  }

  Widget _buildPaymentSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Payment Method", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(
          children: ["Cash", "Fonepay", "Card"].map((method) {
            bool isSelected = _paymentMethod == method;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _paymentMethod = method),
                child: Container(
                  margin: EdgeInsets.only(right: method == "Card" ? 0 : 12),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: isSelected ? AdminTheme.royalBlue : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isSelected ? AdminTheme.royalBlue : Colors.grey.withOpacity(0.2)),
                  ),
                  child: Center(
                    child: Text(
                      method,
                      style: TextStyle(
                        color: isSelected ? Colors.white : AdminTheme.darkNavy,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildInvoiceSummary() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AdminTheme.darkNavy,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          _buildSummaryRow("Subtotal", "NPR 1,400", Colors.white70),
          const SizedBox(height: 12),
          _buildSummaryRow("Service Charge (10%)", "NPR 140", Colors.white70),
          const SizedBox(height: 12),
          _buildSummaryRow("Govt. VAT (13%)", "NPR 200", Colors.white70),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(color: Colors.white10),
          ),
          _buildSummaryRow("TOTAL AMOUNT", "NPR 1,740", Colors.white, isBold: true),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, Color color, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: color, fontSize: isBold ? 14 : 12, fontWeight: isBold ? FontWeight.w900 : FontWeight.bold)),
        Text(value, style: TextStyle(color: color, fontSize: isBold ? 18 : 13, fontWeight: isBold ? FontWeight.w900 : FontWeight.bold)),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.print, size: 18),
            label: const Text("PRINT KOT"),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: const BorderSide(color: AdminTheme.royalBlue),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.receipt_long, size: 18),
            label: const Text("GENERATE INVOICE"),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: AdminTheme.emeraldGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
          ),
        ),
      ],
    );
  }
}
