import 'package:flutter/material.dart';
import '../../services/tenant_service.dart';
import '../../services/api_service.dart';
import '../admin_theme.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Map<String, dynamic>> _orders = [];
  bool _isLoadingOrders = true;
  bool _orderLoadFailed = false;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) {
      if (mounted) {
        setState(() {
          _isLoadingOrders = false;
          _orderLoadFailed = true;
        });
      }
      return;
    }

    final orders = await ApiService.fetchAllOrders(tenant.id);
    if (!mounted) return;
    setState(() {
      _isLoadingOrders = false;
      _orderLoadFailed = orders == null;
      if (orders != null) _orders = orders;
    });
  }

  double _orderAmount(Map<String, dynamic> order) {
    return double.tryParse(
          (order['total_amount'] ??
                  order['total_price'] ??
                  order['amount'] ??
                  '0')
              .toString()
              .replaceAll(RegExp(r'[^0-9.]'), ''),
        ) ??
        0;
  }

  DateTime? _orderDate(Map<String, dynamic> order) {
    final rawDate =
        order['created_at'] ?? order['order_date'] ?? order['date'] ?? '';
    if (rawDate is DateTime) return rawDate;
    return DateTime.tryParse(rawDate.toString());
  }

  bool _isCompleted(Map<String, dynamic> order) {
    final status = (order['status'] ?? '').toString().toLowerCase();
    return status == 'complete' || status == 'completed';
  }

  double _salesFor(Iterable<Map<String, dynamic>> orders) => orders
      .where(_isCompleted)
      .fold(0.0, (total, order) => total + _orderAmount(order));

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        MediaQuery.sizeOf(context).width < 600 ? 12 : 24,
        8,
        MediaQuery.sizeOf(context).width < 600 ? 12 : 24,
        40,
      ),
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
          if (_orderLoadFailed) ...[
            const SizedBox(height: 16),
            Center(
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _isLoadingOrders = true;
                    _orderLoadFailed = false;
                  });
                  _loadOrders();
                },
                icon: const Icon(Icons.refresh),
                label: const Text("Could not load restaurant orders. Retry"),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUserInfoHeader() {
    return ValueListenableBuilder<Tenant?>(
      valueListenable: TenantService().currentTenant,
      builder: (context, tenant, child) {
        final tenantName = tenant?.name ?? "Restaurant Admin";
        final tenantId = tenant?.id ?? "tenant_id";
        return Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Hi, $tenantName",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: MediaQuery.sizeOf(context).width < 600
                          ? 20
                          : 24,
                      fontWeight: FontWeight.w900,
                      color: AdminTheme.darkNavy,
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.store_mall_directory,
                        size: 12,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          "ID: $tenantId",
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const CircleAvatar(
              radius: 22,
              backgroundColor: AdminTheme.royalBlue,
              child: Icon(Icons.person, color: Colors.white, size: 24),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSubscriptionSummaryCard() {
    return ValueListenableBuilder<Tenant?>(
      valueListenable: TenantService().currentTenant,
      builder: (context, tenant, child) {
        if (tenant == null) return const SizedBox.shrink();

        final now = DateTime.now();
        final expiryDate = tenant.expiry == null
            ? null
            : DateTime.tryParse(tenant.expiry!);
        final daysLeft = expiryDate?.difference(now).inDays.clamp(0, 365);
        final bool isWarning = daysLeft != null && daysLeft < 7;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isWarning
                ? Colors.red[50]
                : AdminTheme.emeraldGreen.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: (isWarning ? Colors.red : AdminTheme.emeraldGreen)
                  .withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isWarning ? Colors.red : AdminTheme.emeraldGreen,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.timer_outlined,
                  color: Colors.white,
                  size: 16,
                ),
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
                        color: isWarning
                            ? Colors.red[900]
                            : AdminTheme.darkNavy,
                      ),
                    ),
                    Text(
                      daysLeft == null
                          ? "Expiry date unavailable."
                          : "$daysLeft days remaining in your subscription.",
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
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayOrders = _orders.where((order) {
      final date = _orderDate(order);
      return date != null &&
          !date.isBefore(today) &&
          date.isBefore(today.add(const Duration(days: 1)));
    }).length;
    final monthOrders = _orders.where((order) {
      final date = _orderDate(order);
      return date != null && date.year == now.year && date.month == now.month;
    }).toList();
    final pendingOrders = _orders
        .where(
          (order) => (order['status'] ?? 'Pending')
              .toString()
              .toLowerCase()
              .contains('pending'),
        )
        .length;
    String displayOrderCount(int number) => _isLoadingOrders
        ? "Loading"
        : (_orderLoadFailed ? "Unavailable" : "$number");

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        final columns = constraints.maxWidth < 600 ? 2 : 4;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            SizedBox(
              width: width,
              child: _buildTintedActionCard(
                "Today's Orders",
                "Restaurant orders received today",
                displayOrderCount(todayOrders),
                AdminTheme.royalBlue,
                Icons.receipt_long,
              ),
            ),
            SizedBox(
              width: width,
              child: _buildTintedActionCard(
                "Pending Orders",
                "Awaiting restaurant processing",
                displayOrderCount(pendingOrders),
                AdminTheme.emeraldGreen,
                Icons.pending_actions,
              ),
            ),
            SizedBox(
              width: width,
              child: _buildTintedActionCard(
                "This Month",
                "Orders received this month",
                displayOrderCount(monthOrders.length),
                const Color(0xFF8833FF),
                Icons.calendar_month,
              ),
            ),
            SizedBox(
              width: width,
              child: _buildTintedActionCard(
                "Completed Sales",
                "This month's completed orders",
                _isLoadingOrders
                    ? "Loading"
                    : _orderLoadFailed
                    ? "Unavailable"
                    : "NPR ${_salesFor(monthOrders).toStringAsFixed(0)}",
                const Color(0xFFEA580C),
                Icons.trending_up,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTintedActionCard(
    String title,
    String subtitle,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 20),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: color.withValues(alpha: 0.7),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildWalletCard() {
    final now = DateTime.now();
    final monthOrders = _orders.where((order) {
      final date = _orderDate(order);
      return date != null && date.year == now.year && date.month == now.month;
    }).toList();
    final amount = _orderLoadFailed
        ? "Unavailable"
        : _isLoadingOrders
        ? "Loading"
        : "NPR ${_salesFor(_orders).toStringAsFixed(0)}";
    final monthAmount = _orderLoadFailed
        ? "Unavailable"
        : _isLoadingOrders
        ? "Loading"
        : "NPR ${_salesFor(monthOrders).toStringAsFixed(0)}";
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
                decoration: BoxDecoration(
                  color: AdminTheme.royalBlue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.account_balance_wallet,
                  color: AdminTheme.royalBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Completed Sales",
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      amount,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
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
              _buildSubWalletInfo("This Month", monthAmount),
              _buildSubWalletInfo(
                "Total Orders",
                _isLoadingOrders
                    ? "Loading"
                    : _orderLoadFailed
                    ? "Unavailable"
                    : "${_orders.length}",
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubWalletInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AdminTheme.darkNavy,
          ),
        ),
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
                const Text(
                  "Recent Kitchen Alerts",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red[100],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "${alerts.length} NEW",
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: AdminTheme.softShadow,
              ),
              child: Column(
                children: alerts
                    .take(3)
                    .map(
                      (a) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor:
                                  (a['urgency'] == 'Critical'
                                          ? Colors.red
                                          : Colors.orange)
                                      .withValues(alpha: 0.1),
                              child: Icon(
                                Icons.warning_amber_rounded,
                                size: 14,
                                color: a['urgency'] == 'Critical'
                                    ? Colors.red
                                    : Colors.orange,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    a['item_name'] ?? 'Item',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    a['notes'] ?? 'Out of stock',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              a['urgency'] ?? 'Medium',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: a['urgency'] == 'Critical'
                                    ? Colors.red
                                    : Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActivitySection() {
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    final weekCounts = List<int>.generate(7, (index) {
      final date = startOfToday.subtract(Duration(days: 6 - index));
      return _orders.where((order) {
        final orderDate = _orderDate(order);
        return orderDate != null &&
            orderDate.year == date.year &&
            orderDate.month == date.month &&
            orderDate.day == date.day;
      }).length;
    });
    final weekTotal = weekCounts.fold<int>(0, (sum, count) => sum + count);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Orders this week",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            if (_isLoadingOrders)
              const Text("Loading", style: TextStyle(color: Colors.grey))
            else if (_orderLoadFailed)
              const Text("Unavailable", style: TextStyle(color: Colors.red)),
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
                    _buildStatCol(
                      _isLoadingOrders || _orderLoadFailed ? "—" : "$weekTotal",
                      "Orders in the last 7 days",
                    ),
                  ],
                ),
                const Spacer(),
                _buildSimpleChart(weekCounts),
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
        Text(
          main,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        Text(
          sub,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSimpleChart(List<int> counts) {
    final maxCount = counts.fold<int>(
      0,
      (max, count) => count > max ? count : max,
    );
    final today = DateTime.now();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(counts.length, (index) {
        final height = maxCount == 0 ? 4.0 : 64 * counts[index] / maxCount;
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              width: 12,
              height: height,
              decoration: BoxDecoration(
                color: index == counts.length - 1
                    ? AdminTheme.royalBlue
                    : AdminTheme.royalBlue.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              [
                "M",
                "T",
                "W",
                "T",
                "F",
                "S",
                "S",
              ][today.subtract(Duration(days: 6 - index)).weekday - 1],
              style: const TextStyle(fontSize: 9, color: Colors.grey),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildMonthlyGrowthCard() {
    final now = DateTime.now();
    final monthOrders = _orders.where((order) {
      final date = _orderDate(order);
      return date != null && date.year == now.year && date.month == now.month;
    }).toList();
    final revenue = _orderLoadFailed
        ? "Unavailable"
        : _isLoadingOrders
        ? "Loading"
        : "NPR ${_salesFor(monthOrders).toStringAsFixed(0)}";
    final completedCount = monthOrders.where(_isCompleted).length;

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
              const Text(
                "This Month's Performance",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            revenue,
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            "$completedCount completed orders",
            style: TextStyle(color: Colors.white60, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
