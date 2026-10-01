import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/tenant_service.dart';
import '../admin_theme.dart';

class OrderManagementScreen extends StatefulWidget {
  final String initialStatus;
  const OrderManagementScreen({super.key, this.initialStatus = "All"});

  @override
  State<OrderManagementScreen> createState() => _OrderManagementScreenState();
}

class _OrderManagementScreenState extends State<OrderManagementScreen> {
  late String _currentFilter;
  String _searchQuery = "";
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentFilter = widget.initialStatus;
    _loadOrders();
  }

  @override
  void didUpdateWidget(covariant OrderManagementScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialStatus != widget.initialStatus) {
      setState(() {
        _currentFilter = widget.initialStatus;
      });
      _loadOrders();
    }
  }

  Future<void> _loadOrders() async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return;

    setState(() => _isLoading = true);
    final data = await ApiService.fetchAllOrders(tenant.id);
    if (mounted) {
      if (data != null) setState(() => _orders = data);
      setState(() => _isLoading = false);
    }
  }

  bool _matchesStatus(String orderStatus, String filter) {
    if (filter == "All") return true;
    final st = orderStatus.trim().toLowerCase();
    final fl = filter.trim().toLowerCase();

    if (fl == "completed" || fl == "complete") {
      return st == "completed" || st == "complete";
    }
    if (fl == "cancelled" || fl == "cancel") {
      return st == "cancelled" || st == "cancel";
    }
    return st == fl;
  }

  int _countForStatus(String filter) {
    if (filter == "All") return _orders.length;
    return _orders
        .where((o) => _matchesStatus((o['status'] ?? 'Pending').toString(), filter))
        .length;
  }

  List<Map<String, dynamic>> get _filteredOrders {
    return _orders.where((o) {
      final status = (o['status'] ?? 'Pending').toString();
      if (!_matchesStatus(status, _currentFilter)) return false;

      if (_searchQuery.isEmpty) return true;

      final query = _searchQuery.toLowerCase();
      final idStr = "ord-${o['id']}".toLowerCase();
      final rawIdStr = o['id'].toString().toLowerCase();
      final tableStr =
          (o['table_number'] ?? o['table_id'] ?? '').toString().toLowerCase();
      final customerStr =
          (o['customer_email'] ?? o['user_id'] ?? '').toString().toLowerCase();

      final itemsStr = (o['items'] as List<dynamic>? ?? [])
          .map((i) => (i['name'] ?? '').toString().toLowerCase())
          .join(' ');

      return idStr.contains(query) ||
          rawIdStr.contains(query) ||
          tableStr.contains(query) ||
          customerStr.contains(query) ||
          itemsStr.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredOrders;

    return Column(
      children: [
        _buildSummaryHeader(),
        _buildSearchAndFilterHeader(),
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AdminTheme.royalBlue),
                )
              : filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_outlined,
                              size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            _searchQuery.isNotEmpty
                                ? "No orders found for \"$_searchQuery\""
                                : "No orders found under '$_currentFilter'",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        return _buildOrderTicketCard(filtered[index]);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildSummaryHeader() {
    int totalCount = _orders.length;
    int pendingCount = _countForStatus("Pending");
    int completedCount = _countForStatus("Completed");
    
    double totalRevenue = 0.0;
    for (var o in _orders) {
      if (_matchesStatus((o['status'] ?? '').toString(), "Completed")) {
        totalRevenue += double.tryParse(o['total_amount']?.toString() ?? '0') ?? 0.0;
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          bool isSmall = constraints.maxWidth < 600;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildStatCard("Total Orders", "$totalCount", Icons.shopping_bag_outlined, Colors.blue, isSmall),
              _buildStatCard("Pending", "$pendingCount", Icons.hourglass_top_rounded, Colors.orange, isSmall),
              _buildStatCard("Completed", "$completedCount", Icons.check_circle_outline_rounded, AdminTheme.emeraldGreen, isSmall),
              _buildStatCard("Revenue", "NPR ${totalRevenue.toStringAsFixed(0)}", Icons.payments_outlined, Colors.purple, isSmall),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, bool isSmall) {
    return Container(
      width: isSmall ? double.infinity : 150,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
        boxShadow: AdminTheme.softShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.grey.shade900), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterHeader() {
    final filters = [
      "All",
      "Pending",
      "Approved",
      "Preparing",
      "Ready",
      "Completed",
      "Cancelled"
    ];

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          TextField(
            onChanged: (v) {
              setState(() => _searchQuery = v.trim());
            },
            decoration: InputDecoration(
              hintText: "Search Order ID, Table, Item Name, Customer...",
              hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
              prefixIcon: const Icon(Icons.search, size: 20, color: AdminTheme.royalBlue),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => setState(() => _searchQuery = ""),
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AdminTheme.royalBlue, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: filters.map((f) {
                      bool isSel = _currentFilter.toLowerCase() == f.toLowerCase() ||
                          (_currentFilter.toLowerCase() == 'completed' && f == 'Completed') ||
                          (_currentFilter.toLowerCase() == 'complete' && f == 'Completed') ||
                          (_currentFilter.toLowerCase() == 'cancelled' && f == 'Cancelled') ||
                          (_currentFilter.toLowerCase() == 'cancel' && f == 'Cancelled');
                      int count = _countForStatus(f);

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(
                            "$f ($count)",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isSel ? Colors.white : Colors.black87,
                            ),
                          ),
                          selected: isSel,
                          onSelected: (v) {
                            if (v) setState(() => _currentFilter = f);
                          },
                          selectedColor: AdminTheme.royalBlue,
                          backgroundColor: Colors.white,
                          elevation: isSel ? 2 : 0,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isSel ? AdminTheme.royalBlue : Colors.grey.shade300,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: IconButton(
                  onPressed: _loadOrders,
                  tooltip: "Refresh Orders",
                  icon: const Icon(Icons.refresh_rounded, color: AdminTheme.royalBlue, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderTicketCard(Map<String, dynamic> order) {
    String id = "ORD-${order['id']}";
    String status = order['status'] ?? 'Pending';
    Color statusColor = _getStatusColor(status);
    String tableNum = (order['table_number'] ?? order['table_id'] ?? 'N/A').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 1.5),
        boxShadow: AdminTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AdminTheme.royalBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    id,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      color: AdminTheme.royalBlue,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.table_restaurant_outlined, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        "Table $tableNum",
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  tooltip: "Manage Status",
                  onSelected: (val) {
                    if (val == "Delete") {
                      _deleteOrder(order['id'].toString());
                    } else {
                      _updateStatus(order['id'], val);
                    }
                  },
                  itemBuilder: (ctx) => [
                    "Pending",
                    "Approved",
                    "Preparing",
                    "Ready",
                    "Completed",
                    "Cancelled"
                  ].map((s) => PopupMenuItem(
                    value: s,
                    child: Row(
                      children: [
                        Icon(
                          s == status ? Icons.check_circle : Icons.circle_outlined,
                          size: 16,
                          color: _getStatusColor(s),
                        ),
                        const SizedBox(width: 8),
                        Text(s, style: TextStyle(fontWeight: s == status ? FontWeight.bold : FontWeight.normal)),
                      ],
                    ),
                  )).toList()..add(
                    const PopupMenuItem(
                      value: "Delete",
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 16, color: Colors.red),
                          SizedBox(width: 8),
                          Text("Delete Order", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.more_vert_rounded, size: 20, color: Colors.black54),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Items & Details Body
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (order['created_at'] != null) ...[
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        "${order['created_at']}",
                        style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                const Text(
                  "Order Items",
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                const SizedBox(height: 8),

                ...(order['items'] as List<dynamic>? ?? []).map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: _buildItemSummaryRow(item['name'] ?? 'Item', "x${item['quantity'] ?? '1'}"),
                )),

                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),

                // Total Bill Footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Total Amount:",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                    ),
                    Text(
                      "NPR ${order['total_amount'] ?? '0'}",
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: AdminTheme.royalBlue,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateStatus(dynamic orderId, String newStatus) async {
    final result = await ApiService.updateOrderStatus(int.parse(orderId.toString()), newStatus);
    if (result['success'] == true) {
      _loadOrders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Order #$orderId updated to $newStatus."),
            backgroundColor: AdminTheme.emeraldGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to update status: ${result['message']}"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _deleteOrder(String id) async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Order?"),
        content: Text("Are you sure you want to permanently delete order #$id?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("CANCEL"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("DELETE", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final res = await ApiService.deleteOrder(tenant.id, id);
      if (res['success'] == true) {
        _loadOrders();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Order #$id deleted successfully."),
              backgroundColor: Colors.black,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.trim().toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.blue;
      case 'preparing':
        return Colors.purple;
      case 'ready':
        return Colors.cyan;
      case 'completed':
      case 'complete':
        return AdminTheme.emeraldGreen;
      case 'cancelled':
      case 'cancel':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildItemSummaryRow(String name, String qty) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AdminTheme.royalBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            qty,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 11,
              color: AdminTheme.royalBlue,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            name,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}
