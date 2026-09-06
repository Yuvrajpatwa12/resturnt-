import 'package:flutter/material.dart';
import '../admin_theme.dart';

class ProductionDashboardScreen extends StatelessWidget {
  final String title;
  const ProductionDashboardScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryBar(),
          const SizedBox(height: 32),
          const Text("Live Stations", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildProductionGrid(),
          const SizedBox(height: 32),
          _buildEfficiencyCard(),
        ],
      ),
    );
  }

  Widget _buildSummaryBar() {
    return Row(
      children: [
        _buildMiniStatCard("Active Items", "24", AdminTheme.royalBlue),
        const SizedBox(width: 12),
        _buildMiniStatCard("Avg. Time", "12m", Colors.orange),
        const SizedBox(width: 12),
        _buildMiniStatCard("Delayed", "02", Colors.red),
      ],
    );
  }

  Widget _buildMiniStatCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AdminTheme.softShadow,
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildProductionGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 0.85,
      children: [
        _buildStationCard("T-105", "4 Items", "08:45", true),
        _buildStationCard("T-202", "2 Items", "05:12", false),
        _buildStationCard("T-110", "6 Items", "15:30", true),
        _buildStationCard("T-101", "1 Item", "02:10", false),
      ],
    );
  }

  Widget _buildStationCard(String table, String items, String time, bool isUrgent) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AdminTheme.softShadow,
        border: isUrgent ? Border.all(color: Colors.red.withValues(alpha: 0.3), width: 1.5) : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(table, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(items, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isUrgent ? Colors.red.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              time,
              style: TextStyle(color: isUrgent ? Colors.red : Colors.green, fontWeight: FontWeight.w900, fontSize: 14),
            ),
          ),
          const SizedBox(height: 12),
          const Icon(Icons.flash_on, size: 16, color: Colors.orange),
        ],
      ),
    );
  }

  Widget _buildEfficiencyCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AdminTheme.darkNavy,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Efficiency Rate", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text("Currently performing at 92%", style: TextStyle(color: Colors.white60, fontSize: 11)),
          const SizedBox(height: 20),
          LinearProgressIndicator(
            value: 0.92,
            backgroundColor: Colors.white10,
            color: AdminTheme.emeraldGreen,
            minHeight: 10,
            borderRadius: BorderRadius.circular(10),
          ),
        ],
      ),
    );
  }
}
