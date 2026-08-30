import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../styles.dart';

class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  Map<String, dynamic>? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    final data = await ApiService.fetchAdminStats();
    if (data != null) {
      setState(() => _stats = data);
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _loadStats,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 32),
            _buildMetricsGrid(),
            const SizedBox(height: 32),
            _buildInfrastructureMonitor(),
            const SizedBox(height: 32),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: _buildRevenueChart()),
                const SizedBox(width: 32),
                Expanded(child: _buildRecentActivity()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Global Overview", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
            Text("Real-time performance metrics across all restaurant tenants.", style: TextStyle(color: SAMStyles.textGrey)),
          ],
        ),
        IconButton(onPressed: _loadStats, icon: const Icon(Icons.refresh, color: SAMStyles.royalBlue)),
      ],
    );
  }

  Widget _buildMetricsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      crossAxisSpacing: 24,
      mainAxisSpacing: 24,
      childAspectRatio: 1.4,
      children: [
        _buildMetricCard("Total Tenants", _stats?['total_restaurants']?.toString() ?? "0", Icons.business, SAMStyles.royalBlue),
        _buildMetricCard("Active Now", _stats?['active_restaurants']?.toString() ?? "0", Icons.store_rounded, SAMStyles.emeraldGreen),
        _buildMetricCard("Monthly Revenue", _stats?['monthly_revenue'] ?? "NPR 0", Icons.payments, Colors.orange),
        _buildMetricCard("System Health", _stats?['system_health'] ?? "100%", Icons.speed, Colors.purple),
      ],
    );
  }

  Widget _buildMetricCard(String title, String val, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: SAMStyles.pureWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: SAMStyles.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(val, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              Text(title, style: const TextStyle(color: SAMStyles.textGrey, fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfrastructureMonitor() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: SAMStyles.darkNavy,
        borderRadius: BorderRadius.circular(24),
        boxShadow: SAMStyles.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Infrastructure Node Status", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                child: const Row(children: [CircleAvatar(radius: 3, backgroundColor: Colors.green), SizedBox(width: 8), Text("STABLE", style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold))]),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _buildHealthBar("Server CPU", 0.42, Colors.blue),
              const SizedBox(width: 32),
              _buildHealthBar("Memory Usage", 0.68, Colors.orange),
              const SizedBox(width: 32),
              _buildHealthBar("DB Latency", 0.15, Colors.green),
              const SizedBox(width: 32),
              _buildHealthBar("Network Load", 0.35, Colors.purple),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHealthBar(String label, double val, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
              Text("${(val * 100).toInt()}%", style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: val,
              backgroundColor: Colors.white.withOpacity(0.05),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueChart() {
    final chartData = _stats?['revenue_chart'] as List<dynamic>? ?? [0,0,0,0,0,0,0];
    return Container(
      height: 400,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: SAMStyles.pureWhite,
        borderRadius: BorderRadius.circular(24),
        boxShadow: SAMStyles.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Weekly Revenue Trend", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 32),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final double h = chartData[i].toDouble();
                return Column(
                  children: [
                    const Spacer(),
                    Container(
                      width: 40,
                      height: h,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [SAMStyles.royalBlue, SAMStyles.royalBlue.withOpacity(0.7)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][i], style: const TextStyle(color: SAMStyles.textGrey, fontSize: 10)),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Container(
      height: 400,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: SAMStyles.pureWhite,
        borderRadius: BorderRadius.circular(24),
        boxShadow: SAMStyles.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Live System Pulse", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              children: [
                _buildActivityItem("Database Sync Complete", "Just now", Icons.check_circle, Colors.green),
                _buildActivityItem("API Request Spiked (Everest)", "5m ago", Icons.trending_up, Colors.orange),
                _buildActivityItem("New Resource Node Added", "15m ago", Icons.hub, Colors.blue),
                _buildActivityItem("Routine Backup Started", "1h ago", Icons.storage, Colors.purple),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(String title, String time, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(time, style: const TextStyle(color: SAMStyles.textGrey, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
