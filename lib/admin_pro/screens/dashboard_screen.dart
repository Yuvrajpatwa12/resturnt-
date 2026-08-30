import 'package:flutter/material.dart';
import '../../services/tenant_service.dart';
import '../../services/api_service.dart';
import '../../cart_manager.dart';
import '../admin_theme.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildUserInfoHeader(),
          const SizedBox(height: 24),
          _buildSubscriptionSummaryCard(),
          const SizedBox(height: 24),
          _buildQuickActionRow(),
          const SizedBox(height: 24),
          _buildWalletCard(),
          const SizedBox(height: 32),
          _buildKitchenAlertsWidget(),
          const SizedBox(height: 32),
          _buildActivitySection(),
          const SizedBox(height: 32),
          _buildMonthlyGrowthCard(),
        ],
      ),
    );
  }

  Widget _buildUserInfoHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Hi, Admin",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AdminTheme.darkNavy),
            ),
            Row(
              children: const [
                Icon(Icons.phone, size: 12, color: Colors.grey),
                SizedBox(width: 4),
                Text("REST-CHY-001", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
        const CircleAvatar(
          radius: 22,
          backgroundColor: AdminTheme.royalBlue,
          child: Icon(Icons.person, color: Colors.white, size: 24),
        ),
      ],
    );
  }

  Widget _buildSubscriptionSummaryCard() {
    return ValueListenableBuilder<Tenant?>(
      valueListenable: TenantService().currentTenant,
      builder: (context, tenant, child) {
        if (tenant == null) return const SizedBox.shrink();

        final now = DateTime.now();
        DateTime expiryDate = now.add(const Duration(days: 10)); // Fallback
        try {
          if (tenant.expiry != null) expiryDate = DateTime.parse(tenant.expiry!);
        } catch (_) {}
        
        final daysLeft = expiryDate.difference(now).inDays.clamp(0, 365);
        final bool isWarning = daysLeft < 7;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isWarning ? Colors.red[50] : AdminTheme.emeraldGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: (isWarning ? Colors.red : AdminTheme.emeraldGreen).withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isWarning ? Colors.red : AdminTheme.emeraldGreen,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.timer_outlined, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Plan: ${tenant.plan}",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isWarning ? Colors.red[900] : AdminTheme.darkNavy,
                      ),
                    ),
                    Text(
                      "$daysLeft days remaining in your subscription.",
                      style: TextStyle(
                        fontSize: 10,
                        color: isWarning ? Colors.red[700] : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  // This is a bit tricky since we are in a sub-screen. 
                  // In a real app, we'd use a provider or callback.
                  // For now, it just shows info.
                },
                child: Text(
                  "DETAILS",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: isWarning ? Colors.red : AdminTheme.emeraldGreen,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickActionRow() {
    return Row(
      children: [
        _buildTintedActionCard(
          "Quick Tips",
          "Increase your sales conversion rate",
          AdminTheme.royalBlue,
          Icons.tips_and_updates,
        ),
        const SizedBox(width: 16),
        _buildTintedActionCard(
          "Task Status",
          "Weekly tasks completed 85%",
          AdminTheme.emeraldGreen,
          Icons.check_circle_outline,
        ),
      ],
    );
  }

  Widget _buildTintedActionCard(String title, String subtitle, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 20),
                const Icon(Icons.play_circle_fill, color: Colors.white, size: 18),
              ],
            ),
            const SizedBox(height: 12),
            Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(color: color.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.w500),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletCard() {
    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: ShopManager.instance.allHistoricalBills,
      builder: (context, bills, child) {
        double totalRevenue = 0;
        for (var bill in bills) {
          totalRevenue += double.tryParse(bill['total'].replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
        }

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: AdminTheme.softShadow,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AdminTheme.royalBlue.withOpacity(0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.account_balance_wallet, color: AdminTheme.royalBlue, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Revenue Balance", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                        Text("NPR ${totalRevenue.toStringAsFixed(0)}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Divider(height: 1),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSubWalletInfo("Monthly Target", "NPR 150K"),
                  _buildSubWalletInfo("Total Orders", "${bills.length}"),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSubWalletInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AdminTheme.darkNavy)),
      ],
    );
  }

  Widget _buildKitchenAlertsWidget() {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return const SizedBox.shrink();

    return FutureBuilder<List<Map<String, dynamic>>?>(
      future: ApiService.fetchStockReports(tenant.id),
      builder: (context, snapshot) {
        final alerts = snapshot.data ?? [];
        if (alerts.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Recent Kitchen Alerts", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.red[100], borderRadius: BorderRadius.circular(10)),
                  child: Text("${alerts.length} NEW", style: const TextStyle(color: Colors.red, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: AdminTheme.softShadow),
              child: Column(
                children: alerts.take(3).map((a) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: (a['urgency'] == 'Critical' ? Colors.red : Colors.orange).withOpacity(0.1),
                        child: Icon(Icons.warning_amber_rounded, size: 14, color: a['urgency'] == 'Critical' ? Colors.red : Colors.orange),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a['item_name'] ?? 'Item', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text(a['notes'] ?? 'Out of stock', style: const TextStyle(fontSize: 10, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      Text(a['urgency'] ?? 'Medium', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: a['urgency'] == 'Critical' ? Colors.red : Colors.orange)),
                    ],
                  ),
                )).toList(),
              ),
            ),
          ],
        );
      }
    );
  }

  Widget _buildActivitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Activities this week", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            const Text("-7.6%", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          height: 180,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: AdminTheme.softShadow,
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatCol("136", "Avg. 26 per day"),
                    const Icon(Icons.trending_down, color: Colors.red, size: 20),
                  ],
                ),
                const Spacer(),
                // Simple Line Chart Mock
                _buildSimpleChart(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCol(String main, String sub) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(main, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        Text(sub, style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildSimpleChart() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(7, (index) {
        final double h = [40.0, 60.0, 30.0, 80.0, 50.0, 90.0, 45.0][index];
        return Container(
          width: 8,
          height: h,
          decoration: BoxDecoration(
            color: index == 5 ? AdminTheme.royalBlue : AdminTheme.royalBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  Widget _buildMonthlyGrowthCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AdminTheme.royalBlue,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Monthly Performance", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
                child: const Text("+12.4%", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text("NPR 84,200", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
          const Text("Projected growth for October", style: TextStyle(color: Colors.white60, fontSize: 11)),
          const SizedBox(height: 24),
          LinearProgressIndicator(
            value: 0.76,
            backgroundColor: Colors.white10,
            color: AdminTheme.emeraldGreen,
            minHeight: 8,
            borderRadius: BorderRadius.circular(10),
          ),
        ],
      ),
    );
  }
}
