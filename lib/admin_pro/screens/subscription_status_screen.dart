import 'package:flutter/material.dart';
import '../../services/tenant_service.dart';
import '../admin_theme.dart';

class SubscriptionStatusScreen extends StatelessWidget {
  const SubscriptionStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Tenant?>(
      valueListenable: TenantService().currentTenant,
      builder: (context, tenant, child) {
        if (tenant == null) {
          return const Center(child: Text("No tenant data available."));
        }

        final now = DateTime.now();
        DateTime? expiryDate;
        DateTime? startDate;

        try {
          if (tenant.expiry != null) expiryDate = DateTime.parse(tenant.expiry!);
          if (tenant.startDate != null) startDate = DateTime.parse(tenant.startDate!);
        } catch (e) {
          debugPrint("Date Parsing Error: $e");
        }

        // Mock data for display if actual dates are missing
        startDate ??= now.subtract(const Duration(days: 15));
        expiryDate ??= now.add(const Duration(days: 13));

        final int totalDays = expiryDate.difference(startDate).inDays;
        final int daysPassed = now.difference(startDate).inDays.clamp(0, totalDays);
        final int daysLeft = expiryDate.difference(now).inDays.clamp(0, totalDays);
        final double progress = totalDays > 0 ? (daysPassed / totalDays).clamp(0.0, 1.0) : 0.0;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Subscription Status",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AdminTheme.darkNavy),
              ),
              const Text(
                "Monitor your SaaS plan details and renewal timeline.",
                style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 32),
              
              _buildPlanCard(tenant, daysLeft),
              const SizedBox(height: 24),
              
              _buildLifecycleCard(daysPassed, daysLeft, progress, startDate, expiryDate),
              const SizedBox(height: 24),
              
              _buildDetailsGrid(tenant),
              const SizedBox(height: 32),
              
              _buildActionButtons(context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlanCard(Tenant tenant, int daysLeft) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AdminTheme.royalBlue,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AdminTheme.softShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("CURRENT PLAN", style: TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                const SizedBox(height: 8),
                Text(
                  tenant.plan.toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    "$daysLeft Days Remaining",
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(color: Colors.white12, shape: BoxShape.circle),
            child: const Icon(Icons.verified_user_rounded, color: Colors.white, size: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildLifecycleCard(int passed, int left, double progress, DateTime start, DateTime end) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AdminTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem("Days Elapsed", "$passed Days", AdminTheme.royalBlue),
              _buildStatItem("Days Remaining", "$left Days", AdminTheme.emeraldGreen),
            ],
          ),
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: Colors.grey[100],
              color: AdminTheme.royalBlue,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDateInfo("Start Date", "${start.day}/${start.month}/${start.year}"),
              _buildDateInfo("Expiry Date", "${end.day}/${end.month}/${end.year}"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
      ],
    );
  }

  Widget _buildDateInfo(String label, String date) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
        Text(date, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AdminTheme.darkNavy)),
      ],
    );
  }

  Widget _buildDetailsGrid(Tenant tenant) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildDetailCard("Storage Usage", tenant.storage ?? "0.0 GB", Icons.storage_rounded),
        _buildDetailCard("Active Domain", tenant.domain.isNotEmpty ? tenant.domain : "Localhost", Icons.language_rounded),
        _buildDetailCard("Status", tenant.isActive ? "Active" : "Suspended", Icons.check_circle_rounded, isStatus: true),
        _buildDetailCard("Support tier", "Priority 24/7", Icons.headset_mic_rounded),
      ],
    );
  }

  Widget _buildDetailCard(String title, String value, IconData icon, {bool isStatus = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AdminTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: AdminTheme.royalBlue.withValues(alpha: 0.5)),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isStatus ? (value == "Active" ? AdminTheme.emeraldGreen : Colors.red) : AdminTheme.darkNavy,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminTheme.royalBlue,
              padding: const EdgeInsets.symmetric(vertical: 18),
            ),
            child: const Text("RENEW PLAN", style: TextStyle(letterSpacing: 1)),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 18),
              side: const BorderSide(color: AdminTheme.royalBlue),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("UPGRADE", style: TextStyle(color: AdminTheme.royalBlue, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}
