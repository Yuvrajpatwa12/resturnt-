import 'package:flutter/material.dart';
import 'dart:async';
import '../services/tenant_service.dart';
import '../services/api_service.dart';
import '../admin_pro/admin_login_screen.dart';
import '../../cart_manager.dart';
import '../../models.dart';
import 'kitchen_theme.dart';
import 'widgets/kot_ticket_card.dart';

class KitchenHub extends StatefulWidget {
  const KitchenHub({super.key});

  @override
  State<KitchenHub> createState() => _KitchenHubState();
}

class _KitchenHubState extends State<KitchenHub> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _stages = ["Incoming", "Preparing", "Ready", "History", "Stock Out"];
  List<Map<String, dynamic>> _liveOrders = [];
  List<Map<String, dynamic>> _historyOrders = []; // Added
  List<Map<String, dynamic>> _stockReports = [];
  bool _isLoading = true;
  Timer? _refreshTimer;
  int _lastMod = 0; // Track last database change

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _refreshKitchen(isInitial: true);
    
    // Start automatic light polling every 8 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 8), (_) => _syncKDS());
  }

  Future<void> _syncKDS() async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return;
    
    final serverMod = await ApiService.checkOrderChange(tenant.id);
    if (serverMod > _lastMod) {
      debugPrint("KDS: Change detected ($serverMod > $_lastMod). Refreshing...");
      _refreshKitchen();
      _lastMod = serverMod;
    }
  }

  Future<void> _refreshKitchen({bool isInitial = false}) async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return;

    if (isInitial) setState(() => _isLoading = true);
    
    final results = await Future.wait([
      ApiService.fetchActiveOrders(tenant.id),
      ApiService.fetchOrderHistory(tenant.id),
      ApiService.fetchStockReports(tenant.id),
    ]);

    if (mounted) {
      setState(() {
        if (results[0] != null) _liveOrders = results[0] as List<Map<String, dynamic>>;
        if (results[1] != null) _historyOrders = results[1] as List<Map<String, dynamic>>;
        if (results[2] != null) _stockReports = results[2] as List<Map<String, dynamic>>;
        _isLoading = false;
      });
    }
  }

  Future<void> _changeStatus(int orderId, String newStatus) async {
    final res = await ApiService.updateOrderStatus(orderId, newStatus);
    if (res['success'] == true) {
      _refreshKitchen();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Order marked as $newStatus"), backgroundColor: KitchenTheme.emeraldGreen),
        );
      }
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${res['message']}"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Staff?>(
      valueListenable: TenantService().currentStaff,
      builder: (context, currentStaff, child) {
        if (currentStaff == null) {
          return const AdminLoginScreen(roleHint: "Kitchen");
        }

        return Theme(
          data: KitchenTheme.lightTheme,
          child: Scaffold(
            appBar: AppBar(
              titleSpacing: 16,
              title: Row(
                children: [
                  const Icon(Icons.restaurant_menu, color: KitchenTheme.royalBlue, size: 24),
                  const SizedBox(width: 10),
                  Text("KDS: ${currentStaff.name}", style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: KitchenTheme.emeraldGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: KitchenTheme.emeraldGreen.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(radius: 3, backgroundColor: KitchenTheme.emeraldGreen),
                          SizedBox(width: 4),
                          Flexible(child: Text("LIVE", style: TextStyle(color: KitchenTheme.emeraldGreen, fontSize: 9, fontWeight: FontWeight.w900))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  onPressed: _showStockOutDialog,
                  icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  tooltip: "Report Stock Out",
                ),
                IconButton(
                  onPressed: _refreshKitchen,
                  icon: const Icon(Icons.refresh_rounded, color: KitchenTheme.royalBlue),
                  tooltip: "Sync Orders",
                ),
                const SizedBox(width: 16),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(100),
                child: Column(
                  children: [
                    _buildQuickSummary(),
                    TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      labelColor: KitchenTheme.royalBlue,
                      indicatorColor: KitchenTheme.royalBlue,
                      unselectedLabelColor: Colors.grey,
                      tabAlignment: TabAlignment.start,
                      dividerColor: Colors.transparent,
                      tabs: _stages.map((s) {
                        if (s == "Stock Out") {
                          return Tab(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text("Stock Out"),
                                if (_stockReports.any((r) => r['status'] != 'Received')) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                    child: Text("${_stockReports.where((r) => r['status'] != 'Received').length}", style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }
                        return Tab(text: s);
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            body: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildStageView("Pending"),
                    _buildStageView("Preparing"),
                    _buildStageView("Ready"),
                    _buildHistoryView(),
                    _buildStockLogView(),
                  ],
                ),
          ),
        );
      },
    );
  }

  Widget _buildQuickSummary() {
    final pending = _liveOrders.where((o) => o['status'] == 'Pending').length;
    final cooking = _liveOrders.where((o) => o['status'] == 'Preparing').length;
    final ready = _liveOrders.where((o) => o['status'] == 'Ready').length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildSummaryChip("PENDING", pending.toString().padLeft(2, '0'), Colors.orange),
            const SizedBox(width: 8),
            _buildSummaryChip("COOKING", cooking.toString().padLeft(2, '0'), KitchenTheme.royalBlue),
            const SizedBox(width: 8),
            _buildSummaryChip("READY", ready.toString().padLeft(2, '0'), KitchenTheme.emeraldGreen),
            const SizedBox(width: 8),
            _buildSummaryChip("TOTAL", _liveOrders.length.toString().padLeft(2, '0'), KitchenTheme.darkNavy),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryChip(String label, String count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withValues(alpha: 0.1))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(count, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 14)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 8)),
        ],
      ),
    );
  }

  Widget _buildStageView(String filterStatus) {
    // KITCHEN LOGIC: 
    // If we are looking for 'Incoming' orders, we actually check for 'Approved' status in DB
    final dbFilterStatus = filterStatus == 'Pending' ? 'Approved' : filterStatus;
    
    final filteredOrders = _liveOrders.where((o) => o['status'] == dbFilterStatus).toList();

    if (filteredOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.grey.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            Text("No orders currently in $filterStatus", style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 380,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.8, 
      ),
      itemCount: filteredOrders.length,
      itemBuilder: (context, index) {
        final order = filteredOrders[index];
        final List<dynamic> rawItems = order['items'] ?? [];
        
        final List<CartItem> cartItems = rawItems.map((i) => CartItem(
          product: Product(
            title: i['product_name'] ?? "Unknown", 
            price: i['price_at_order']?.toString() ?? "0", 
            image: "",
            tag: "Kitchen",
            rating: "5.0",
          ),
          quantity: int.tryParse(i['quantity']?.toString() ?? '1') ?? 1,
        )).toList();

        return KotTicketCard(
          tableId: int.parse(order['table_number'].toString()),
          items: cartItems,
          secondsElapsed: 0,
          stage: filterStatus == 'Pending' ? 'Incoming' : filterStatus,
          onAction: () {
             if (filterStatus == 'Pending') {
               _changeStatus(int.parse(order['id'].toString()), 'Preparing');
             } else if (filterStatus == 'Preparing') {
               _changeStatus(int.parse(order['id'].toString()), 'Ready');
             } else if (filterStatus == 'Ready') {
               _changeStatus(int.parse(order['id'].toString()), 'Completed');
             }
          },
        );
      },
    );
  }

  Widget _buildHistoryView() {
    if (_historyOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_rounded, size: 64, color: Colors.grey.withValues(alpha: 0.1)),
            const SizedBox(height: 16),
            const Text("No order history found.", style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _historyOrders.length,
      itemBuilder: (context, index) {
        final order = _historyOrders[index];
        final List<dynamic> rawItems = order['items'] ?? [];
        final status = order['status'] ?? 'Completed';
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ExpansionTile(
            shape: const RoundedRectangleBorder(side: BorderSide.none),
            leading: CircleAvatar(
              backgroundColor: status == 'Completed' ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
              child: Icon(
                status == 'Completed' ? Icons.check_circle_outline : Icons.cancel_outlined,
                color: status == 'Completed' ? Colors.green : Colors.red,
                size: 20,
              ),
            ),
            title: Text(
              "Table T-${order['table_number']} • #ORD-${order['id']}", 
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)
            ),
            subtitle: Text(
              "Closed at: ${order['updated_at']}", 
              style: const TextStyle(fontSize: 10, color: Colors.grey)
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  children: [
                    const Divider(),
                    ...rawItems.map((i) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Text("${i['quantity']}x", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: KitchenTheme.royalBlue)),
                          const SizedBox(width: 12),
                          Expanded(child: Text(i['product_name'] ?? 'Item', style: const TextStyle(fontSize: 12))),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStockLogView() {
    if (_stockReports.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.withValues(alpha: 0.1)),
            const SizedBox(height: 16),
            const Text("No stock reports found.", style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshKitchen,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _stockReports.length,
        itemBuilder: (context, index) => _buildStockReportCard(_stockReports[index]),
      ),
    );
  }

  Future<void> _markAsReceived(int id) async {
    final res = await ApiService.updateStockReportStatus(id, 'Received');
    if (res['success'] == true) {
      _refreshKitchen();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Saman Received! Alert Closed."), backgroundColor: Colors.green),
        );
      }
    }
  }

  Widget _buildStockReportCard(Map<String, dynamic> r) {
    final status = r['status'] ?? 'Requested';
    final urgency = r['urgency'] ?? 'Medium';
    final int reportId = int.parse(r['id'].toString());
    
    IconData statusIcon = Icons.hourglass_empty_rounded;
    Color statusColor = Colors.orange;
    String statusText = "Requested";

    if (status == 'Approved') {
      statusIcon = Icons.check_circle_outline_rounded;
      statusColor = Colors.blue;
      statusText = "Admin Approved";
    } else if (status == 'Received') {
      statusIcon = Icons.inventory_2_rounded;
      statusColor = Colors.green;
      statusText = "Saman Aa Gaya";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)],
        border: Border.all(color: statusColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: statusColor.withValues(alpha: 0.1),
                      child: Icon(statusIcon, color: statusColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r['item_name'] ?? 'Item', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                          Text(statusText, style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    _buildUrgencyBadge(urgency),
                  ],
                ),
                if (r['notes'] != null && r['notes'].toString().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text("Notes: ${r['notes']}", style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontStyle: FontStyle.italic)),
                ],
                const SizedBox(height: 20),
                
                // --- VISUAL STAPER (PROGRESS LINE) ---
                _buildVisualStaper(status),
              ],
            ),
          ),
          if (status == 'Approved')
            Container(
              width: double.infinity,
              height: 54,
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A).withValues(alpha: 0.05),
                border: Border(top: BorderSide(color: const Color(0xFF16A34A).withValues(alpha: 0.1))),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _markAsReceived(reportId),
                  child: const Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 18),
                        SizedBox(width: 8),
                        Text("CONFIRM SAMAN RECEIVED", style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVisualStaper(String currentStatus) {
    bool isRequested = true; // Always true if in log
    bool isApproved = currentStatus == 'Approved' || currentStatus == 'Received';
    bool isReceived = currentStatus == 'Received';

    return Row(
      children: [
        _buildStaperNode("Requested", isRequested, isApproved),
        _buildStaperLine(isApproved),
        _buildStaperNode("Approved", isApproved, isReceived),
        _buildStaperLine(isReceived),
        _buildStaperNode("Received", isReceived, false),
      ],
    );
  }

  Widget _buildStaperNode(String label, bool isActive, bool isNextActive) {
    String displayLabel = label;
    if (label == "Requested") displayLabel = "Pending Approval";
    if (label == "Approved") displayLabel = "Admin Approved";
    if (label == "Received") displayLabel = "Saman Aa Gaya";

    return Column(
      children: [
        Container(
          width: 24, height: 24,
          decoration: BoxDecoration(
            color: isActive ? (isNextActive ? Colors.green : KitchenTheme.royalBlue) : Colors.grey[200],
            shape: BoxShape.circle,
          ),
          child: Icon(
            isNextActive ? Icons.check : (isActive ? Icons.radio_button_checked : Icons.radio_button_off),
            color: isActive ? Colors.white : Colors.grey[400],
            size: 14,
          ),
        ),
        const SizedBox(height: 4),
        Text(displayLabel, style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.w900, color: isActive ? KitchenTheme.darkNavy : Colors.grey)),
      ],
    );
  }

  Widget _buildStaperLine(bool isActive) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 12),
        color: isActive ? Colors.green : Colors.grey[200],
      ),
    );
  }

  Widget _buildUrgencyBadge(String urgency) {
    Color color = Colors.orange;
    if (urgency == 'Critical') color = Colors.red;
    if (urgency == 'Low') color = Colors.blue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(urgency.toUpperCase(), style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900)),
    );
  }

  void _showStockOutDialog() {
    final itemController = TextEditingController();
    final notesController = TextEditingController();
    String urgency = "Medium";

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text("Detailed Stock Report", style: TextStyle(fontWeight: FontWeight.w900)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("ITEM NAME", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey)),
                const SizedBox(height: 8),
                TextField(
                  controller: itemController,
                  decoration: InputDecoration(
                    hintText: "e.g. Fresh Milk, Sugar",
                    filled: true, fillColor: Colors.grey[100],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 20),
                const Text("URGENCY LEVEL", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: urgency,
                      isExpanded: true,
                      items: ["Low", "Medium", "Critical"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (v) => setModalState(() => urgency = v!),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text("ADDITIONAL NOTES", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey)),
                const SizedBox(height: 8),
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: "e.g. Need 10L for evening rush...",
                    filled: true, fillColor: Colors.grey[100],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
            ElevatedButton(
              onPressed: () async {
                if (itemController.text.trim().isEmpty) return;
                final tenant = TenantService().currentTenant.value;
                final staff = TenantService().currentStaff.value;
                if (tenant == null) return;

                final res = await ApiService.reportStockOut({
                  'tenant_id': tenant.id,
                  'item_name': itemController.text.trim(),
                  'notes': notesController.text.trim(),
                  'urgency': urgency,
                  'reported_by': staff?.name ?? 'Kitchen',
                });

                if (res['success'] == true) {
                  if (context.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Alert sent to Admin!"), backgroundColor: KitchenTheme.emeraldGreen));
                  }
                }
              },
              child: const Text("SEND REPORT"),
            ),
          ],
        ),
      ),
    );
  }
}
