import 'dart:async';
import 'package:flutter/material.dart';
import '../admin_theme.dart';
import '../../services/tenant_service.dart';
import '../../services/api_service.dart';

class ProductionDashboardScreen extends StatefulWidget {
  final String title;
  const ProductionDashboardScreen({super.key, required this.title});

  @override
  State<ProductionDashboardScreen> createState() => _ProductionDashboardScreenState();
}

class _ProductionDashboardScreenState extends State<ProductionDashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  String _selectedTab = "All Active"; // "All Active", "Incoming", "Preparing", "Ready", "History", "Stock Out"

  List<Map<String, dynamic>> _liveOrders = [];
  List<Map<String, dynamic>> _historyOrders = [];
  List<Map<String, dynamic>> _stockReports = [];
  bool _isLoading = true;
  Timer? _refreshTimer;
  int _lastMod = 0;

  @override
  void initState() {
    super.initState();
    _refreshDashboard(isInitial: true);
    // Auto-sync polling every 8 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 8), (_) => _syncDashboard());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _syncDashboard() async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return;

    final serverMod = await ApiService.checkOrderChange(tenant.id);
    if (serverMod > _lastMod) {
      _refreshDashboard();
      _lastMod = serverMod;
    }
  }

  Future<void> _refreshDashboard({bool isInitial = false}) async {
    final tenant = TenantService().currentTenant.value;
    final tenantId = tenant?.id ?? 'startups_main';

    if (isInitial) {
      setState(() => _isLoading = true);
    }

    final results = await Future.wait([
      ApiService.fetchActiveOrders(tenantId),
      ApiService.fetchOrderHistory(tenantId),
      ApiService.fetchStockReports(tenantId),
    ]);

    if (mounted) {
      setState(() {
        _liveOrders = (results[0] as List<Map<String, dynamic>>?) ?? [];
        _historyOrders = (results[1] as List<Map<String, dynamic>>?) ?? [];
        _stockReports = (results[2] as List<Map<String, dynamic>>?) ?? [];
        _isLoading = false;
      });
    }
  }

  Future<void> _updateStatus(int orderId, String newStatus) async {
    final res = await ApiService.updateOrderStatus(orderId, newStatus);
    if (res['status'] == 'success' || res['success'] == true) {
      _refreshDashboard();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Order #$orderId marked as ${newStatus.toUpperCase()}"),
            backgroundColor: AdminTheme.emeraldGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to update status: ${res['message'] ?? 'Unknown error'}"),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Helper to normalize stage name
  String _getOrderStage(Map<String, dynamic> order) {
    final st = (order['status'] ?? order['stage'] ?? 'incoming').toString().toLowerCase().trim();
    if (st == 'incoming' || st == 'pending' || st == 'placed' || st == 'new') {
      return 'Incoming';
    } else if (st == 'preparing' || st == 'cooking' || st == 'in_progress' || st == 'in progress') {
      return 'Preparing';
    } else if (st == 'ready' || st == 'cooked' || st == 'prepared') {
      return 'Ready';
    } else if (st == 'completed' || st == 'delivered' || st == 'served' || st == 'closed') {
      return 'Completed';
    } else if (st == 'cancelled' || st == 'rejected') {
      return 'Cancelled';
    }
    return 'Incoming';
  }

  // Calculate elapsed minutes since created_at or timestamp
  int _getElapsedMinutes(Map<String, dynamic> order) {
    final createdStr = order['created_at'] ?? order['time'] ?? order['date'];
    if (createdStr != null) {
      final dt = DateTime.tryParse(createdStr.toString());
      if (dt != null) {
        return DateTime.now().difference(dt).inMinutes;
      }
    }
    final sec = int.tryParse(order['secondsElapsed']?.toString() ?? '');
    if (sec != null) return (sec / 60).floor();
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    // 1. Calculate Live Stats
    final incomingList = _liveOrders.where((o) => _getOrderStage(o) == 'Incoming').toList();
    final preparingList = _liveOrders.where((o) => _getOrderStage(o) == 'Preparing').toList();
    final readyList = _liveOrders.where((o) => _getOrderStage(o) == 'Ready').toList();
    final stockOutCount = _stockReports.length;

    int totalActive = incomingList.length + preparingList.length + readyList.length;

    double avgMinutes = 0;
    if (_liveOrders.isNotEmpty) {
      int totalMins = 0;
      for (var o in _liveOrders) {
        totalMins += _getElapsedMinutes(o);
      }
      avgMinutes = totalMins / _liveOrders.length;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. HEADER & REFRESH BAR
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AdminTheme.darkNavy)),
                  const Text("Live Kitchen Monitor (Read-Only • Status updates managed in Kitchen App)", style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
              IconButton(
                onPressed: _refreshDashboard,
                icon: const Icon(Icons.refresh, color: AdminTheme.royalBlue),
                tooltip: "Refresh KDS",
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 2. LIVE SUMMARY METRICS BAR
          _buildMetricsBar(
            incomingCount: incomingList.length,
            preparingCount: preparingList.length,
            readyCount: readyList.length,
            totalActiveCount: totalActive,
            avgMinutes: avgMinutes,
            stockOutCount: stockOutCount,
          ),
          const SizedBox(height: 24),

          // 3. SEARCH BOX FOR ORDER TRACKING / POSITION LOOKUP
          _buildOrderSearchBox(),
          const SizedBox(height: 16),

          // 4. SEARCH RESULT TRACKER CARD (IF QUERY PRESENT)
          if (_searchQuery.isNotEmpty) ...[
            _buildSearchResultsSection(),
            const SizedBox(height: 24),
          ],

          // 5. STAGE FILTER TABS
          _buildStageTabs(
            allCount: totalActive,
            incomingCount: incomingList.length,
            preparingCount: preparingList.length,
            readyCount: readyList.length,
            historyCount: _historyOrders.length,
            stockOutCount: stockOutCount,
          ),
          const SizedBox(height: 20),

          // 6. MAIN CONTENT DISPLAY (GRID / LIST)
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator(color: AdminTheme.royalBlue)),
            )
          else if (_selectedTab == "Stock Out")
            _buildStockOutView()
          else
            _buildOrdersGrid(),
        ],
      ),
    );
  }

  // --- 1. METRICS BAR ---
  Widget _buildMetricsBar({
    required int incomingCount,
    required int preparingCount,
    required int readyCount,
    required int totalActiveCount,
    required double avgMinutes,
    required int stockOutCount,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double cardWidth = (constraints.maxWidth - (12 * 5)) / 6;
        final bool isCompact = cardWidth < 120;

        if (isCompact) {
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildMetricCard("Incoming", "$incomingCount", Colors.orange, Icons.inbox),
              _buildMetricCard("Preparing", "$preparingCount", AdminTheme.royalBlue, Icons.soup_kitchen),
              _buildMetricCard("Ready", "$readyCount", AdminTheme.emeraldGreen, Icons.check_circle_outline),
              _buildMetricCard("Total Active", "$totalActiveCount", AdminTheme.darkNavy, Icons.restaurant),
              _buildMetricCard("Avg. Time", "${avgMinutes.round()}m", Colors.purple, Icons.timer_outlined),
              _buildMetricCard("Stock Out", "$stockOutCount", Colors.redAccent, Icons.inventory_2_outlined),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: _buildMetricCard("Incoming", "$incomingCount", Colors.orange, Icons.inbox)),
            const SizedBox(width: 12),
            Expanded(child: _buildMetricCard("Preparing", "$preparingCount", AdminTheme.royalBlue, Icons.soup_kitchen)),
            const SizedBox(width: 12),
            Expanded(child: _buildMetricCard("Ready", "$readyCount", AdminTheme.emeraldGreen, Icons.check_circle_outline)),
            const SizedBox(width: 12),
            Expanded(child: _buildMetricCard("Total Active", "$totalActiveCount", AdminTheme.darkNavy, Icons.restaurant)),
            const SizedBox(width: 12),
            Expanded(child: _buildMetricCard("Avg. Time", "${avgMinutes.round()}m", Colors.purple, Icons.timer_outlined)),
            const SizedBox(width: 12),
            Expanded(child: _buildMetricCard("Stock Out", "$stockOutCount", Colors.redAccent, Icons.inventory_2_outlined)),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AdminTheme.softShadow,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
            ],
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  // --- 2. SEARCH BOX FOR ORDER TRACKING ---
  Widget _buildOrderSearchBox() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AdminTheme.softShadow,
        border: Border.all(color: _searchQuery.isNotEmpty ? AdminTheme.royalBlue : Colors.grey.shade200, width: 1.5),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) {
          setState(() {
            _searchQuery = val.trim();
          });
        },
        decoration: InputDecoration(
          hintText: "Search Order ID, Table # (e.g. 105, T-12), or Customer Name...",
          hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
          icon: const Icon(Icons.search, color: AdminTheme.royalBlue, size: 22),
          border: InputBorder.none,
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = "");
                  },
                )
              : null,
        ),
      ),
    );
  }

  // --- 3. SEARCH RESULTS & QUEUE POSITION TRACKER ---
  Widget _buildSearchResultsSection() {
    final q = _searchQuery.toLowerCase().replaceAll('#', '').replaceAll('t-', '').replaceAll('t', '');

    // Combine active & history orders
    final allCombined = [..._liveOrders, ..._historyOrders];

    final matches = allCombined.where((o) {
      final idStr = (o['id'] ?? o['order_id'] ?? '').toString().toLowerCase();
      final tblStr = (o['table_id'] ?? o['table_number'] ?? o['table'] ?? '').toString().toLowerCase();
      final custStr = (o['customer_name'] ?? o['customer'] ?? '').toString().toLowerCase();

      return idStr.contains(q) || tblStr.contains(q) || custStr.contains(q);
    }).toList();

    if (matches.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.amber.shade200),
        ),
        child: Row(
          children: [
            const Icon(Icons.search_off, color: Colors.amber, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "No order found matching \"$_searchQuery\". Check the Order ID or Table Number and try again.",
                style: TextStyle(color: Colors.amber.shade900, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.my_location, size: 18, color: AdminTheme.royalBlue),
            const SizedBox(width: 8),
            Text(
              "Order Tracking Results (${matches.length} found)",
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AdminTheme.darkNavy),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: matches.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            return _buildOrderTrackerCard(matches[index]);
          },
        ),
      ],
    );
  }

  Widget _buildOrderTrackerCard(Map<String, dynamic> order) {
    final orderId = order['id'] ?? order['order_id'] ?? 'N/A';
    final tableId = order['table_id'] ?? order['table_number'] ?? order['table'] ?? 'N/A';
    final customer = order['customer_name'] ?? order['customer'] ?? 'Dine-In Customer';
    final stage = _getOrderStage(order);
    final elapsedMins = _getElapsedMinutes(order);

    // Calculate queue position if order is active
    int queuePos = -1;
    if (stage != 'Completed' && stage != 'Cancelled') {
      final sameStageOrders = _liveOrders.where((o) => _getOrderStage(o) == stage).toList();
      queuePos = sameStageOrders.indexWhere((o) => (o['id'] ?? o['order_id']) == orderId);
      if (queuePos != -1) queuePos += 1;
    }

    // Step index for progress bar: 1: Incoming, 2: Preparing, 3: Ready, 4: Completed
    int stepIndex = 1;
    if (stage == 'Preparing') stepIndex = 2;
    if (stage == 'Ready') stepIndex = 3;
    if (stage == 'Completed') stepIndex = 4;

    Color stageColor;
    IconData stageIcon;
    if (stage == 'Incoming') {
      stageColor = Colors.orange;
      stageIcon = Icons.inbox;
    } else if (stage == 'Preparing') {
      stageColor = AdminTheme.royalBlue;
      stageIcon = Icons.soup_kitchen;
    } else if (stage == 'Ready') {
      stageColor = AdminTheme.emeraldGreen;
      stageIcon = Icons.check_circle_outline;
    } else if (stage == 'Completed') {
      stageColor = Colors.grey;
      stageIcon = Icons.done_all;
    } else {
      stageColor = Colors.redAccent;
      stageIcon = Icons.cancel_outlined;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AdminTheme.softShadow,
        border: Border.all(color: stageColor.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: stageColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(stageIcon, color: stageColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("ORDER #$orderId", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      Text("Table T-$tableId • $customer", style: const TextStyle(color: Colors.grey, fontSize: 11)),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: stageColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      stage.toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text("$elapsedMins mins elapsed", style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Queue Position Badge
          if (queuePos > 0)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AdminTheme.royalBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AdminTheme.royalBlue.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.format_list_numbered_outlined, size: 16, color: AdminTheme.royalBlue),
                  const SizedBox(width: 8),
                  Text(
                    "Current Position in $stage Queue: Position #$queuePos",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AdminTheme.royalBlue),
                  ),
                ],
              ),
            ),

          // Step Progress Tracker Bar
          _buildProgressTrackerBar(stepIndex, stage == 'Cancelled'),
          const SizedBox(height: 16),

          // Items summary
          const Text("Ordered Items:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 6),
          _buildOrderItemsList(order['items']),

          const SizedBox(height: 12),
          // Read-only Status Info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: stageColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: stageColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(stageIcon, size: 16, color: stageColor),
                const SizedBox(width: 8),
                Text(
                  "STATUS: ${stage.toUpperCase()} (Kitchen View-Only)",
                  style: TextStyle(color: stageColor, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressTrackerBar(int currentStep, bool isCancelled) {
    if (isCancelled) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
        child: const Text("Order Cancelled", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
      );
    }

    final steps = [
      {"name": "Incoming", "icon": Icons.inbox},
      {"name": "Preparing", "icon": Icons.soup_kitchen},
      {"name": "Ready", "icon": Icons.check_circle_outline},
      {"name": "Served", "icon": Icons.done_all},
    ];

    return Row(
      children: List.generate(steps.length, (index) {
        final stepNum = index + 1;
        final isPassed = stepNum <= currentStep;
        final isCurrent = stepNum == currentStep;

        final color = isPassed
            ? (isCurrent ? AdminTheme.royalBlue : AdminTheme.emeraldGreen)
            : Colors.grey.shade300;

        return Expanded(
          child: Row(
            children: [
              Column(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isPassed ? color : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: color, width: 2),
                    ),
                    child: Icon(
                      steps[index]['icon'] as IconData,
                      size: 14,
                      color: isPassed ? Colors.white : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    steps[index]['name'] as String,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: isCurrent ? FontWeight.w900 : FontWeight.bold,
                      color: isPassed ? color : Colors.grey,
                    ),
                  ),
                ],
              ),
              if (index < steps.length - 1)
                Expanded(
                  child: Container(
                    height: 3,
                    margin: const EdgeInsets.only(bottom: 14),
                    color: (stepNum < currentStep) ? AdminTheme.emeraldGreen : Colors.grey.shade300,
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildOrderItemsList(dynamic itemsData) {
    if (itemsData == null) return const Text("- No item details -", style: TextStyle(fontSize: 11, color: Colors.grey));

    List itemsList = [];
    if (itemsData is List) {
      itemsList = itemsData;
    } else if (itemsData is String) {
      itemsList = [itemsData];
    }

    if (itemsList.isEmpty) return const Text("- Empty order -", style: TextStyle(fontSize: 11, color: Colors.grey));

    return Column(
      children: itemsList.map((item) {
        String name = 'Item';
        int qty = 1;
        String notes = '';

        if (item is Map) {
          name = item['name'] ?? item['title'] ?? item['product_name'] ?? 'Item';
          qty = int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
          notes = item['notes'] ?? item['customization'] ?? '';
        } else if (item is String) {
          name = item;
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
                child: Text("${qty}x", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              if (notes.isNotEmpty)
                Text("($notes)", style: const TextStyle(fontSize: 10, color: Colors.orange, fontStyle: FontStyle.italic)),
            ],
          ),
        );
      }).toList(),
    );
  }

  // --- 4. STAGE TABS BAR ---
  Widget _buildStageTabs({
    required int allCount,
    required int incomingCount,
    required int preparingCount,
    required int readyCount,
    required int historyCount,
    required int stockOutCount,
  }) {
    final tabs = [
      {"label": "All Active", "count": allCount},
      {"label": "Incoming", "count": incomingCount},
      {"label": "Preparing", "count": preparingCount},
      {"label": "Ready", "count": readyCount},
      {"label": "History", "count": historyCount},
      {"label": "Stock Out", "count": stockOutCount},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tabs.map((t) {
          final label = t['label'] as String;
          final count = t['count'] as int;
          final isSelected = _selectedTab == label;

          Color badgeColor = AdminTheme.royalBlue;
          if (label == 'Incoming') badgeColor = Colors.orange;
          if (label == 'Preparing') badgeColor = AdminTheme.royalBlue;
          if (label == 'Ready') badgeColor = AdminTheme.emeraldGreen;
          if (label == 'Stock Out') badgeColor = Colors.redAccent;

          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: InkWell(
              onTap: () => setState(() => _selectedTab = label),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? badgeColor : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: AdminTheme.softShadow,
                  border: Border.all(
                    color: isSelected ? badgeColor : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: isSelected ? Colors.white : AdminTheme.darkNavy,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white.withValues(alpha: 0.25) : badgeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "$count",
                        style: TextStyle(
                          color: isSelected ? Colors.white : badgeColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // --- 5. ORDERS GRID ---
  Widget _buildOrdersGrid() {
    List<Map<String, dynamic>> displayList = [];

    if (_selectedTab == "All Active") {
      displayList = _liveOrders;
    } else if (_selectedTab == "Incoming") {
      displayList = _liveOrders.where((o) => _getOrderStage(o) == 'Incoming').toList();
    } else if (_selectedTab == "Preparing") {
      displayList = _liveOrders.where((o) => _getOrderStage(o) == 'Preparing').toList();
    } else if (_selectedTab == "Ready") {
      displayList = _liveOrders.where((o) => _getOrderStage(o) == 'Ready').toList();
    } else if (_selectedTab == "History") {
      displayList = _historyOrders;
    }

    if (displayList.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AdminTheme.softShadow,
        ),
        child: Column(
          children: [
            Icon(Icons.restaurant_outlined, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              "No orders in \"$_selectedTab\" stage right now.",
              style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              "New live orders placed by customers or waiters will appear here automatically.",
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: displayList.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 380,
        mainAxisExtent: 260,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
      ),
      itemBuilder: (context, index) {
        return _buildKitchenTicketCard(displayList[index]);
      },
    );
  }

  Widget _buildKitchenTicketCard(Map<String, dynamic> order) {
    final orderId = order['id'] ?? order['order_id'] ?? '0';
    final tableId = order['table_id'] ?? order['table_number'] ?? order['table'] ?? '1';
    final stage = _getOrderStage(order);
    final elapsed = _getElapsedMinutes(order);

    Color headerColor;
    if (stage == 'Incoming') {
      headerColor = Colors.orange;
    } else if (stage == 'Preparing') {
      headerColor = AdminTheme.royalBlue;
    } else if (stage == 'Ready') {
      headerColor = AdminTheme.emeraldGreen;
    } else {
      headerColor = AdminTheme.darkNavy;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AdminTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: headerColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "TABLE T-$tableId",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
                    ),
                    Text(
                      "ORDER #$orderId",
                      style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 12, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        "${elapsed}M",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Items List
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SingleChildScrollView(
                child: _buildOrderItemsList(order['items']),
              ),
            ),
          ),

          // Read-Only Status Badge
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: SizedBox(
              width: double.infinity,
              child: _buildTicketStatusBadge(stage),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketStatusBadge(String stage) {
    Color badgeBg;
    Color badgeText;
    String label;
    IconData icon;

    if (stage == 'Incoming') {
      badgeBg = Colors.orange.shade50;
      badgeText = Colors.orange.shade800;
      label = "INCOMING (In Queue)";
      icon = Icons.inbox;
    } else if (stage == 'Preparing') {
      badgeBg = AdminTheme.royalBlue.withValues(alpha: 0.1);
      badgeText = AdminTheme.royalBlue;
      label = "PREPARING (Cooking)";
      icon = Icons.soup_kitchen;
    } else if (stage == 'Ready') {
      badgeBg = AdminTheme.emeraldGreen.withValues(alpha: 0.1);
      badgeText = AdminTheme.emeraldGreen;
      label = "READY FOR SERVICE";
      icon = Icons.check_circle_outline;
    } else {
      badgeBg = Colors.grey.shade100;
      badgeText = Colors.grey.shade700;
      label = "SERVED / COMPLETED";
      icon = Icons.done_all;
    }

    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: badgeBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: badgeText),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: badgeText, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // --- 6. STOCK OUT VIEW ---
  Widget _buildStockOutView() {
    if (_stockReports.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AdminTheme.softShadow,
        ),
        child: const Column(
          children: [
            Icon(Icons.check_circle_outline, size: 48, color: AdminTheme.emeraldGreen),
            SizedBox(height: 12),
            Text(
              "All kitchen ingredients are in stock!",
              style: TextStyle(fontSize: 14, color: AdminTheme.darkNavy, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text(
              "There are no stock-out items reported currently.",
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AdminTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Stock Out / Low Quantity Items", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AdminTheme.darkNavy)),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _stockReports.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = _stockReports[index];
              final name = item['ingredient_name'] ?? item['name'] ?? 'Ingredient';
              final stock = item['current_stock'] ?? '0';
              final unit = item['unit'] ?? 'kg';

              return ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.redAccent,
                  child: Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
                ),
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Text("Current Stock: $stock $unit", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                  child: const Text("STOCK OUT", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 10)),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
