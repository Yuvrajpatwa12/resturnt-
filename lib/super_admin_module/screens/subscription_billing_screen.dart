import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../styles.dart';

class SubscriptionBillingScreen extends StatefulWidget {
  const SubscriptionBillingScreen({super.key});

  @override
  State<SubscriptionBillingScreen> createState() =>
      _SubscriptionBillingScreenState();
}

class _SubscriptionBillingScreenState extends State<SubscriptionBillingScreen> {
  bool _isLoading = true;
  String _selectedFilter = 'All';

  List<Map<String, dynamic>> _packages = [];
  List<Map<String, dynamic>> _pendingRequests = [];
  List<Map<String, dynamic>> _storeSubscriptions = [];

  @override
  void initState() {
    super.initState();
    _loadAllSubscriptionData();
  }

  Future<void> _loadAllSubscriptionData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final pkgs = await ApiService.fetchSubscriptionPackages();
    final reqs = await ApiService.fetchPendingSubscriptionRequests();
    final tenants = await ApiService.fetchTenants();

    List<Map<String, dynamic>> processedStores = [];
    if (tenants != null) {
      final now = DateTime.now();
      for (var t in tenants) {
        final name = (t['restaurant_name'] ?? t['name'] ?? 'Restaurant')
            .toString();
        final plan = (t['plan'] ?? 'Basic').toString();
        final expStr = t['subscription_end'] ?? t['expiry_date'] ?? t['expiry'];
        final subStatus = (t['subscription_status'] ?? '').toString();

        DateTime? expDate;
        if (expStr != null) {
          try {
            expDate = DateTime.parse(expStr.toString());
          } catch (_) {}
        }

        int daysLeft = 14;
        if (expDate != null) {
          daysLeft = expDate.difference(now).inDays;
        }

        bool isExpired = daysLeft < 0;
        bool isTrial =
            subStatus.toLowerCase() == 'trial' || plan == '3 Days Free Trial';

        String statusLabel = isExpired ? 'Expired' : 'Active';
        String typeLabel = isTrial ? 'Trial' : 'Paid';

        processedStores.add({
          'name': name,
          'plan': plan,
          'daysPassed': '${14 - daysLeft < 0 ? 0 : 14 - daysLeft} Days',
          'daysLeft': isExpired ? 'Expired ($daysLeft d)' : '$daysLeft Days',
          'daysLeftInt': daysLeft,
          'status': statusLabel,
          'type': typeLabel,
          'domain': (t['custom_domain'] ?? t['domain'] ?? '').toString(),
        });
      }
    }

    if (mounted) {
      setState(() {
        _packages = pkgs;
        _pendingRequests = reqs;
        _storeSubscriptions = processedStores;
        _isLoading = false;
      });
    }
  }

  Future<void> _editPackageModal(Map<String, dynamic>? pkg) async {
    final isNew = pkg == null;
    final id = pkg?['id'];
    final nameCtrl = TextEditingController(
      text: pkg?['name']?.toString() ?? '',
    );
    final durationCtrl = TextEditingController(
      text: pkg?['duration_days']?.toString() ?? '30',
    );
    final priceCtrl = TextEditingController(
      text: pkg?['price']?.toString() ?? '999.00',
    );
    final perksCtrl = TextEditingController(
      text: pkg?['perks']?.toString() ?? 'Full POS & Multi-User Access',
    );

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isNew
              ? "Create Subscription Package"
              : "Edit Package: ${pkg['name']}",
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: "Package Title *"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: durationCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Duration in Days * (e.g. 28, 84, 168)",
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: "Price in NPR *"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: perksCtrl,
              decoration: const InputDecoration(labelText: "Perks & Features"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: SAMStyles.royalBlue,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final payload = {
                if (id != null) 'id': id,
                'name': nameCtrl.text.trim(),
                'duration_days': int.tryParse(durationCtrl.text.trim()) ?? 30,
                'price': double.tryParse(priceCtrl.text.trim()) ?? 0.0,
                'perks': perksCtrl.text.trim(),
              };

              Navigator.pop(ctx);
              final res = await ApiService.saveSubscriptionPackage(payload);

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res['message'] ?? 'Package saved'),
                    backgroundColor: res['success'] == true
                        ? SAMStyles.emeraldGreen
                        : Colors.red,
                  ),
                );
                _loadAllSubscriptionData();
              }
            },
            child: const Text("Save Package"),
          ),
        ],
      ),
    );
  }

  Future<void> _approveRequest(Map<String, dynamic> req) async {
    final reqId = int.tryParse(req['id']?.toString() ?? '0') ?? 0;
    if (reqId <= 0) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Approve Request #${req['id']}"),
        content: Text(
          "Approve subscription request for '${req['restaurant_name'] ?? req['tenant_id']}'?\n\nPackage: ${req['package_name']} (${req['duration_days']} days).\n\nThis will immediately extend the tenant's active subscription_end date.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: SAMStyles.emeraldGreen,
            ),
            child: const Text(
              "APPROVE NOW",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final res = await ApiService.approveSubscriptionRequest(reqId);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Action completed'),
          backgroundColor: res['success'] == true
              ? SAMStyles.emeraldGreen
              : Colors.red,
        ),
      );
      _loadAllSubscriptionData();
    }
  }

  Future<void> _rejectRequestModal(Map<String, dynamic> req) async {
    final reqId = int.tryParse(req['id']?.toString() ?? '0') ?? 0;
    if (reqId <= 0) return;

    final noteCtrl = TextEditingController(
      text: "Payment not verified / invalid request.",
    );

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Reject Request #${req['id']}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Reject subscription request for '${req['restaurant_name'] ?? req['tenant_id']}'?",
            ),
            const SizedBox(height: 16),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(
                labelText: "Rejection Reason / Note *",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final res = await ApiService.rejectSubscriptionRequest(
                reqId,
                note: noteCtrl.text.trim(),
              );

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res['message'] ?? 'Rejected'),
                    backgroundColor: res['success'] == true
                        ? SAMStyles.emeraldGreen
                        : Colors.red,
                  ),
                );
                _loadAllSubscriptionData();
              }
            },
            child: const Text(
              "REJECT REQUEST",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredStores = _storeSubscriptions.where((store) {
      if (_selectedFilter == 'Active') {
        return store['status'] == 'Active';
      } else if (_selectedFilter == 'Expired') {
        return store['status'] == 'Expired';
      } else if (_selectedFilter == 'Free Trial') {
        return store['type'] == 'Trial';
      }
      return true;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
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
                    "Subscription & Plan Manager",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "Manage pricing tiers, approve pending requests, and monitor all restaurant subscription cycles.",
                    style: TextStyle(color: SAMStyles.textGrey),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _loadAllSubscriptionData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: SAMStyles.royalBlue,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text("REFRESH LIVE DATA"),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // PENDING REQUESTS BANNER/SECTION (REQUIREMENT #4 & #5)
          _buildPendingRequestsSection(),
          const SizedBox(height: 32),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Configured Package Tiers",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              OutlinedButton.icon(
                onPressed: () => _editPackageModal(null),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text("ADD NEW TIER"),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildPlanTierGrid(),
          const SizedBox(height: 40),

          _buildActiveRestaurantsSubscriptionList(filteredStores),
        ],
      ),
    );
  }

  // ================= PENDING REQUESTS SECTION =================
  Widget _buildPendingRequestsSection() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_pendingRequests.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              color: Colors.green,
              size: 24,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                "No pending subscription activation requests right now. All tenant plans are up to date!",
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.shade300, width: 1.5),
        boxShadow: SAMStyles.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.pending_actions_rounded,
                color: Colors.amber,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                "Pending Subscription Activation Requests (${_pendingRequests.length})",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF78350F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _pendingRequests.length,
            separatorBuilder: (_, __) => const Divider(height: 16),
            itemBuilder: (ctx, idx) {
              final req = _pendingRequests[idx];
              final storeName =
                  req['restaurant_name'] ?? req['tenant_id'] ?? 'Store';
              final domain = req['custom_domain'] ?? req['tenant_id'] ?? '';
              final pkgName = req['package_name'] ?? 'Package';
              final duration = req['duration_days']?.toString() ?? '30';
              final price = req['price']?.toString() ?? '0.00';
              final reqAt = req['requested_at']?.toString() ?? '';

              return Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "$storeName ($domain)",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xFF78350F),
                          ),
                        ),
                        Text(
                          "Requested Package: $pkgName ($duration Days) • Price: NPR $price • Time: $reqAt",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => _approveRequest(req),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SAMStyles.emeraldGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text(
                      "APPROVE",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _rejectRequestModal(req),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text(
                      "REJECT",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ================= 4 SUBSCRIPTION PLANS GRID =================
  Widget _buildPlanTierGrid() {
    if (_isLoading) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          children: _packages.asMap().entries.map((entry) {
            final index = entry.key;
            final plan = entry.value;
            final name = plan['name'] ?? 'Plan';
            final duration = '${plan['duration_days']} Days';
            final price = 'NPR ${plan['price']}';
            final perks = plan['perks'] ?? 'Full Access';

            return Expanded(
              child: Container(
                margin: EdgeInsets.only(
                  right: index < _packages.length - 1 ? 16 : 0,
                ),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: SAMStyles.softShadow,
                  border: Border.all(
                    color: SAMStyles.royalBlue.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: SAMStyles.royalBlue,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      price,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      duration,
                      style: const TextStyle(
                        color: SAMStyles.textGrey,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      perks,
                      style: const TextStyle(
                        color: SAMStyles.textGrey,
                        fontSize: 11,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _editPackageModal(plan),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: SAMStyles.royalBlue),
                          foregroundColor: SAMStyles.royalBlue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.edit, size: 14),
                        label: const Text("EDIT TIER"),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ================= RESTAURANT SUBSCRIPTION MONITORING WITH FILTER =================
  Widget _buildActiveRestaurantsSubscriptionList(
    List<Map<String, dynamic>> filteredStores,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Restaurant Subscription Monitoring",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  "Filter by running, expired, or free trial users.",
                  style: TextStyle(color: SAMStyles.textGrey, fontSize: 12),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              children: ['All', 'Active', 'Expired', 'Free Trial'].map((
                filterName,
              ) {
                final isSelected = _selectedFilter == filterName;
                return ChoiceChip(
                  label: Text(filterName),
                  selected: isSelected,
                  selectedColor: SAMStyles.royalBlue,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                  onSelected: (selected) {
                    setState(() {
                      _selectedFilter = filterName;
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: SAMStyles.softShadow,
          ),
          child: filteredStores.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Center(
                    child: Text(
                      "No restaurants found for this filter.",
                      style: TextStyle(color: SAMStyles.textGrey),
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredStores.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  itemBuilder: (context, index) {
                    final store = filteredStores[index];
                    final isExpired = store['status'] == 'Expired';
                    final isTrial = store['type'] == 'Trial';

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: isExpired
                            ? Colors.red.withValues(alpha: 0.1)
                            : (isTrial
                                  ? Colors.teal.withValues(alpha: 0.1)
                                  : SAMStyles.royalBlue.withValues(alpha: 0.1)),
                        child: Icon(
                          Icons.store,
                          color: isExpired
                              ? Colors.red
                              : (isTrial ? Colors.teal : SAMStyles.royalBlue),
                        ),
                      ),
                      title: Row(
                        children: [
                          Text(
                            store['name']!,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          if (isTrial) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.teal.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                "TRIAL",
                                style: TextStyle(
                                  color: Colors.teal,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text(
                        "Domain: ${store['domain']} • Plan: ${store['plan']}",
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Passed: ${store['daysPassed']}",
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: SAMStyles.textGrey,
                                ),
                              ),
                              Text(
                                "Left: ${store['daysLeft']}",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isExpired
                                      ? Colors.red
                                      : SAMStyles.emeraldGreen,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 20),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  (isExpired
                                          ? Colors.red
                                          : SAMStyles.emeraldGreen)
                                      .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              store['status']!,
                              style: TextStyle(
                                color: isExpired
                                    ? Colors.red
                                    : SAMStyles.emeraldGreen,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
