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
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentFilter = widget.initialStatus;
    _loadOrders();
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

  @override
  Widget build(BuildContext context) {
    final filtered = _currentFilter == "All" 
        ? _orders 
        : _orders.where((o) => o['status'] == _currentFilter).toList();

    return Column(
      children: [
        _buildSearchAndFilterHeader(),
        Expanded(
          child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : filtered.isEmpty 
                  ? const Center(child: Text("No orders found."))
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

  Widget _buildSearchAndFilterHeader() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          TextField(
            onChanged: (v) {
              // Implementation of local search if needed
            },
            decoration: InputDecoration(
              hintText: "Search Order ID, Table...",
              prefixIcon: const Icon(Icons.search, size: 20),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ["All", "Pending", "Approved", "Preparing", "Ready", "Completed", "Cancel"].map((f) {
                      bool isSel = _currentFilter == f;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(f, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          selected: isSel,
                          onSelected: (v) => setState(() => _currentFilter = f),
                          selectedColor: AdminTheme.royalBlue,
                          labelStyle: TextStyle(color: isSel ? Colors.white : Colors.black87),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              IconButton(onPressed: _loadOrders, icon: const Icon(Icons.refresh, color: AdminTheme.royalBlue)),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AdminTheme.softShadow,
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            title: Row(
              children: [
                Text(id, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                  child: Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 8, fontWeight: FontWeight.w900)),
                ),
              ],
            ),
            subtitle: Text("Table ${order['table_number']} • ${order['created_at']}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
            trailing: PopupMenuButton<String>(
              onSelected: (val) {
                if (val == "Delete") {
                  _deleteOrder(order['id'].toString());
                } else {
                  _updateStatus(order['id'], val);
                }
              },
              itemBuilder: (ctx) => [
                "Pending", "Approved", "Preparing", "Ready", "Completed", "Cancel"
              ].map((s) => PopupMenuItem(value: s, child: Text(s))).toList()..add(
                const PopupMenuItem(value: "Delete", child: Text("Delete", style: TextStyle(color: Colors.red)))
              ),
              icon: const Icon(Icons.more_vert, size: 20),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                ...(order['items'] as List<dynamic>? ?? []).map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: _buildItemSummaryRow(item['name'] ?? 'Item', "x${item['quantity'] ?? '1'}"),
                )),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Total Bill:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    Text("NPR ${order['total_amount']}", style: const TextStyle(fontWeight: FontWeight.w900, color: AdminTheme.royalBlue, fontSize: 14)),
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Status updated."), backgroundColor: Colors.green));
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed: ${result['message']}"), backgroundColor: Colors.red));
    }
  }

  Future<void> _deleteOrder(String id) async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Order?"),
        content: const Text("This will permanently remove the order record."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCEL")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("DELETE", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      final res = await ApiService.deleteOrder(tenant.id, id);
      if (res['success'] == true) {
        _loadOrders();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Order deleted.")));
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending': return Colors.orange;
      case 'Approved': return Colors.blue;
      case 'Preparing': return Colors.purple;
      case 'Ready': return Colors.cyan;
      case 'Completed': return AdminTheme.emeraldGreen;
      case 'Cancel': return Colors.red;
      default: return Colors.grey;
    }
  }

  Widget _buildItemSummaryRow(String name, String qty) {
    return Row(
      children: [
        Text(qty, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: AdminTheme.royalBlue)),
        const SizedBox(width: 12),
        Expanded(child: Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
      ],
    );
  }
}
