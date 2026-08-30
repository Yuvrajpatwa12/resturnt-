import 'package:flutter/material.dart';
import 'cart_manager.dart';
import 'live_order_tracking_screen.dart';
import 'services/tenant_service.dart';
import 'services/api_service.dart';

class MyOrdersPage extends StatefulWidget {
  const MyOrdersPage({super.key});

  @override
  State<MyOrdersPage> createState() => _MyOrdersPageState();
}

class _MyOrdersPageState extends State<MyOrdersPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _sessionOrders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return;

    setState(() => _isLoading = true);
    // Fetch all orders for this table session
    final data = await ApiService.fetchActiveOrders(tenant.id); // Reusing fetchActiveOrders but should ideally filter by table
    if (data != null) {
      setState(() {
        _sessionOrders = data.where((o) => o['table_number'].toString() == ShopManager.instance.selectedTableId.value.toString()).toList();
      });
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text("My Orders", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFFF5C00),
          indicatorColor: const Color(0xFFFF5C00),
          tabs: const [Tab(text: "Live Status"), Tab(text: "Order History")],
        ),
        actions: [
          IconButton(onPressed: _loadOrders, icon: const Icon(Icons.refresh, color: Color(0xFFFF5C00))),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : TabBarView(
            controller: _tabController,
            children: [
              _buildOrderList(isActive: true),
              _buildOrderList(isActive: false),
            ],
          ),
    );
  }

  Widget _buildOrderList({required bool isActive}) {
    final filtered = _sessionOrders.where((o) {
      bool isDone = o['status'] == 'Completed' || o['status'] == 'Cancelled';
      return isActive ? !isDone : isDone;
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isActive ? Icons.restaurant : Icons.history, size: 64, color: Colors.grey[200]),
            const SizedBox(height: 16),
            Text(isActive ? "No active orders" : "No order history", style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final o = filtered[index];
        return _buildOrderCard(o, isActive);
      },
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> o, bool isActive) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => LiveOrderTrackingScreen(orderId: int.parse(o['id'].toString()))));
        },
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Order #${o['id']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(o['created_at'] ?? 'Just now', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                    ],
                  ),
                  _buildStatusBadge(o['status']),
                ],
              ),
              const Divider(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Total Amount", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                  Text("NPR ${o['total_amount']}", style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFFF5C00))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = Colors.orange;
    if (status == 'Approved') color = Colors.blue;
    if (status == 'Preparing') color = Colors.purple;
    if (status == 'Ready') color = Colors.green;
    if (status == 'OnWay') color = const Color(0xFF6236FF);
    if (status == 'Completed') color = Colors.teal;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }
}
