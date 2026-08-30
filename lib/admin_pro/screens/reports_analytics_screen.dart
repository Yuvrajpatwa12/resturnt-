import 'package:flutter/material.dart';
import '../../cart_manager.dart';
import '../admin_theme.dart';

class ReportsAnalyticsScreen extends StatelessWidget {
  const ReportsAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: ShopManager.instance.allHistoricalBills,
      builder: (context, bills, child) {
        double totalSales = 0;
        for (var bill in bills) {
          totalSales += double.tryParse(bill['total'].replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
        }

        double serviceCharge = totalSales * 0.10;
        double vat = (totalSales + serviceCharge) * 0.13;
        double netRevenue = totalSales - (totalSales * 0.4); // Mock 40% COGS

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Financial Reports", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 24),
              _buildRevenueSummaryCard(totalSales, serviceCharge, vat),
              const SizedBox(height: 24),
              _buildProfitAnalysisCard(totalSales, netRevenue),
              const SizedBox(height: 32),
              const Text("Settled Invoices", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ...bills.map((bill) => _buildInvoiceTile(bill)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRevenueSummaryCard(double sales, double sc, double vat) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AdminTheme.royalBlue, AdminTheme.darkNavy],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Gross Revenue", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
              Text("NPR ${sales.toStringAsFixed(0)}", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(color: Colors.white24),
          ),
          _buildRevenueRow("Service Charge (10%)", sc),
          const SizedBox(height: 8),
          _buildRevenueRow("Govt. VAT (13%)", vat),
        ],
      ),
    );
  }

  Widget _buildRevenueRow(String label, double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
        Text("NPR ${amount.toStringAsFixed(0)}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildProfitAnalysisCard(double total, double net) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AdminTheme.softShadow,
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 30,
            backgroundColor: Color(0xFFE8F5E9),
            child: Icon(Icons.trending_up, color: AdminTheme.emeraldGreen, size: 30),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Estimated Net Profit", style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                Text("NPR ${net.toStringAsFixed(0)}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AdminTheme.emeraldGreen)),
                const Text("Calculated after inventory & tax costs", style: TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceTile(Map<String, dynamic> bill) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("INV #${bill['id']} - ${bill['table']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text(bill['time'] ?? "", style: const TextStyle(color: Colors.grey, fontSize: 11)),
            ],
          ),
          Text(bill['total'], style: const TextStyle(fontWeight: FontWeight.w900, color: AdminTheme.royalBlue)),
        ],
      ),
    );
  }
}
