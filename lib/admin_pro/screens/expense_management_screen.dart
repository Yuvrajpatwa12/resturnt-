import 'package:flutter/material.dart';
import '../admin_theme.dart';

class ExpenseManagementScreen extends StatelessWidget {
  final String mode;
  const ExpenseManagementScreen({super.key, required this.mode});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (mode == "Add Expense") _buildAddExpenseForm()
          else if (mode == "Expense Statement") _buildStatementView()
          else _buildExpenseItemListView(),
        ],
      ),
    );
  }

  Widget _buildExpenseItemListView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(mode, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            IconButton(onPressed: () {}, icon: const Icon(Icons.add_circle_outline, color: AdminTheme.royalBlue)),
          ],
        ),
        const SizedBox(height: 16),
        ...List.generate(4, (index) => _buildExpenseCard(index)),
      ],
    );
  }

  Widget _buildExpenseCard(int index) {
    final types = ["Maintenance", "Electricity", "Internet", "Water"];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: AdminTheme.softShadow),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.outbound_outlined, color: Colors.redAccent, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(types[index % 4], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const Text("Monthly utility payment", style: TextStyle(color: Colors.grey, fontSize: 10)),
              ],
            ),
          ),
          const Text("NPR 4,500", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.redAccent)),
        ],
      ),
    );
  }

  Widget _buildAddExpenseForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Log New Expense", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 24),
        _buildTextField("Expense Category", "e.g. Utility Bills"),
        const SizedBox(height: 16),
        _buildTextField("Amount (NPR)", "2500"),
        const SizedBox(height: 16),
        _buildTextField("Date", "22/08/2026"),
        const SizedBox(height: 16),
        _buildTextField("Reference/Bill No.", "INV-9821"),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 54)),
          child: const Text("SAVE EXPENSE"),
        ),
      ],
    );
  }

  Widget _buildStatementView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Monthly Outflow", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: AdminTheme.darkNavy, borderRadius: BorderRadius.circular(24)),
          child: Column(
            children: [
              _buildStatRow("Total Fixed", "NPR 45,000"),
              const SizedBox(height: 12),
              _buildStatRow("Total Variable", "NPR 12,400"),
              const Divider(color: Colors.white10, height: 32),
              _buildStatRow("GROSS EXPENSE", "NPR 57,400", isBold: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatRow(String label, String val, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: isBold ? Colors.white : Colors.white60, fontSize: isBold ? 14 : 12, fontWeight: isBold ? FontWeight.w900 : FontWeight.bold)),
        Text(val, style: TextStyle(color: isBold ? AdminTheme.emeraldGreen : Colors.white, fontSize: isBold ? 18 : 13, fontWeight: isBold ? FontWeight.w900 : FontWeight.bold)),
      ],
    );
  }

  Widget _buildTextField(String label, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 8),
        TextField(
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 13),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }
}
