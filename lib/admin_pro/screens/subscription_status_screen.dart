import 'package:flutter/material.dart';
import '../../services/tenant_service.dart';
import '../../services/api_service.dart';
import '../admin_theme.dart';

class SubscriptionStatusScreen extends StatefulWidget {
  const SubscriptionStatusScreen({super.key});

  @override
  State<SubscriptionStatusScreen> createState() => _SubscriptionStatusScreenState();
}

class _SubscriptionStatusScreenState extends State<SubscriptionStatusScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _packages = [];
  List<Map<String, dynamic>> _myRequests = [];

  @override
  void initState() {
    super.initState();
    _loadSubscriptionData();
  }

  Future<void> _loadSubscriptionData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final tenant = TenantService().currentTenant.value;
    final tenantId = tenant?.id ?? 'startups_main';

    final pkgs = await ApiService.fetchSubscriptionPackages(tenantId: tenantId);
    final reqs = await ApiService.fetchMySubscriptionRequests(tenantId);

    if (mounted) {
      setState(() {
        _packages = pkgs;
        _myRequests = reqs;
        _isLoading = false;
      });
    }
  }

  Future<void> _requestPackage(Map<String, dynamic> pkg) async {
    final tenant = TenantService().currentTenant.value;
    final tenantId = tenant?.id ?? 'startups_main';
    final pkgId = int.tryParse(pkg['id']?.toString() ?? '0') ?? 0;

    if (pkgId <= 0) return;

    // Strict single pending request check
    final hasPending = _myRequests.any((r) => r['status']?.toString() == 'Pending');
    if (hasPending) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("You already have a pending subscription request. Please cancel it or wait for approval."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Active plan check (> 3 days remaining)
    final daysLeft = tenant?.daysRemaining ?? 0;
    if (daysLeft > 3) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Active Plan Warning"),
          content: Text(
            "You already have an active plan with $daysLeft days remaining. Are you sure you want to request a plan extension for '${pkg['name']}'?",
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCEL")),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text("PROCEED", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Request ${pkg['name']}"),
        content: Text(
          "Are you sure you want to request activation for '${pkg['name']}' (${pkg['duration_days']} days at NPR ${pkg['price']})?\n\nThis will send a request to Super Admin for approval.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.royalBlue),
            child: const Text("SUBMIT REQUEST", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final result = await ApiService.requestSubscriptionPackage(tenantId, pkgId);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Request processed'),
          backgroundColor: result['success'] == true ? AdminTheme.emeraldGreen : Colors.red,
        ),
      );
      _loadSubscriptionData();
    }
  }

  Future<void> _cancelRequest(int requestId) async {
    final tenant = TenantService().currentTenant.value;
    final tenantId = tenant?.id ?? 'startups_main';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Cancel Subscription Request"),
        content: const Text("Are you sure you want to cancel this pending subscription request?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("NO")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("YES, CANCEL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final result = await ApiService.cancelSubscriptionRequest(tenantId, requestId);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Request processed'),
          backgroundColor: result['success'] == true ? AdminTheme.emeraldGreen : Colors.red,
        ),
      );
      _loadSubscriptionData();
    }
  }

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
          final expStr = tenant.subscriptionEnd ?? tenant.expiry;
          final startStr = tenant.subscriptionStart ?? tenant.startDate;
          if (expStr != null) expiryDate = DateTime.parse(expStr);
          if (startStr != null) startDate = DateTime.parse(startStr);
        } catch (e) {
          debugPrint("Date Parsing Error: $e");
        }

        startDate ??= now.subtract(const Duration(days: 3));
        expiryDate ??= now.add(Duration(days: tenant.daysRemaining));

        final int totalDays = expiryDate.difference(startDate).inDays.clamp(1, 365);
        final int daysPassed = now.difference(startDate).inDays.clamp(0, totalDays);
        final int daysLeft = tenant.daysRemaining;
        final double progress = totalDays > 0 ? (daysPassed / totalDays).clamp(0.0, 1.0) : 0.0;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Subscription & Plan Center",
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AdminTheme.darkNavy),
                      ),
                      Text(
                        "Monitor real-time SaaS status and request plan extensions.",
                        style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: AdminTheme.royalBlue),
                    onPressed: _loadSubscriptionData,
                    tooltip: "Refresh Data",
                  ),
                ],
              ),
              const SizedBox(height: 24),

              _buildPlanCard(tenant, daysLeft),
              const SizedBox(height: 24),

              _buildLifecycleCard(daysPassed, daysLeft, progress, startDate, expiryDate),
              const SizedBox(height: 32),

              const Text(
                "Available Subscription Packages",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AdminTheme.darkNavy),
              ),
              const SizedBox(height: 12),
              _buildPackageSelectorGrid(),
              const SizedBox(height: 32),

              const Text(
                "Submitted Activation Requests History",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AdminTheme.darkNavy),
              ),
              const SizedBox(height: 12),
              _buildSubmittedRequestsList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlanCard(Tenant tenant, int daysLeft) {
    final bool isExpired = daysLeft < 0;
    final bool isTrial = tenant.subscriptionStatus == 'Trial' || tenant.plan == '3 Days Free Trial';

    List<Color> gradientColors = [const Color(0xFF2563EB), const Color(0xFF1D4ED8)]; // Vibrant Royal Blue
    String statusTag = "ACTIVE PLAN";
    Color badgeColor = Colors.white;

    if (isExpired) {
      gradientColors = [const Color(0xFF334155), const Color(0xFF1E293B)]; // Compact Sleek Slate
      statusTag = "EXPIRED PLAN";
      badgeColor = const Color(0xFFF87171);
    } else if (isTrial) {
      gradientColors = [const Color(0xFF0D9488), const Color(0xFF0F766E)]; // Teal
      statusTag = "3-DAY FREE TRIAL";
      badgeColor = const Color(0xFF5EEAD4);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      statusTag,
                      style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  tenant.plan,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isExpired ? "Expired ($daysLeft Days Ago)" : "$daysLeft Days Remaining",
                    style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isExpired ? Icons.warning_amber_rounded : (isTrial ? Icons.hourglass_top_rounded : Icons.verified_rounded),
              color: badgeColor,
              size: 28,
            ),
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
              _buildStatItem("Days Remaining", "${left < 0 ? 0 : left} Days", left <= 3 ? const Color(0xFFEF4444) : AdminTheme.emeraldGreen),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: Colors.grey[100],
              color: left <= 3 ? const Color(0xFFEF4444) : AdminTheme.royalBlue,
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
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
        Text(date, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AdminTheme.darkNavy)),
      ],
    );
  }

  Widget _buildPackageSelectorGrid() {
    if (_isLoading) {
      return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
    }

    if (_packages.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: const Center(child: Text("No subscription packages available currently.")),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        bool isWide = constraints.maxWidth > 800;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isWide ? 4 : 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.95,
          ),
          itemCount: _packages.length,
          itemBuilder: (ctx, index) {
            final pkg = _packages[index];
            final name = pkg['name'] ?? 'Package';
            final duration = pkg['duration_days']?.toString() ?? '30';
            final price = pkg['price']?.toString() ?? '0.00';
            final perks = pkg['perks'] ?? 'Full POS & Multi-User Access';

            return Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: AdminTheme.softShadow,
                border: Border.all(color: AdminTheme.royalBlue.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AdminTheme.darkNavy)),
                      const SizedBox(height: 6),
                      Text("NPR $price", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: AdminTheme.royalBlue)),
                      Text("$duration Days Duration", style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Text(perks, style: TextStyle(fontSize: 11, color: Colors.grey.shade700), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _requestPackage(pkg),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdminTheme.royalBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text("REQUEST ACTIVATION", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 0.5)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSubmittedRequestsList() {
    if (_isLoading) {
      return const SizedBox.shrink();
    }

    if (_myRequests.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AdminTheme.softShadow,
        ),
        child: const Center(
          child: Text(
            "No subscription activation requests submitted yet.",
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AdminTheme.softShadow,
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _myRequests.length,
        separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
        itemBuilder: (context, index) {
          final req = _myRequests[index];
          final pkgName = req['package_name'] ?? 'Package';
          final status = (req['status'] ?? 'Pending').toString();
          final reqAt = (req['requested_at'] ?? '').toString();
          final note = (req['rejection_note'] ?? '').toString();

          Color badgeColor = Colors.orange;
          if (status == 'Approved') badgeColor = AdminTheme.emeraldGreen;
          if (status == 'Rejected') badgeColor = Colors.red;

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            leading: CircleAvatar(
              backgroundColor: badgeColor.withValues(alpha: 0.12),
              child: Icon(
                status == 'Approved'
                    ? Icons.check_circle_rounded
                    : (status == 'Rejected' ? Icons.cancel_rounded : Icons.pending_rounded),
                color: badgeColor,
                size: 22,
              ),
            ),
            title: Text("Request: $pkgName", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Requested on: $reqAt", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                if (status == 'Rejected' && note.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text("Rejection Note: $note", style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold)),
                ],
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (status == 'Pending') ...[
                  OutlinedButton.icon(
                    onPressed: () {
                      final reqId = int.tryParse(req['id']?.toString() ?? '0') ?? 0;
                      if (reqId > 0) _cancelRequest(reqId);
                    },
                    icon: const Icon(Icons.close, size: 14, color: Colors.red),
                    label: const Text("Cancel", style: TextStyle(color: Colors.red, fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
