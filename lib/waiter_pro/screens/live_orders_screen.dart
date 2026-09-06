import 'package:flutter/material.dart';
import 'dart:async';

import '../../services/tenant_service.dart';
import '../../services/api_service.dart';
import '../theme.dart';

class LiveOrdersScreen extends StatefulWidget {
  const LiveOrdersScreen({super.key});

  @override
  State<LiveOrdersScreen> createState() => _LiveOrdersScreenState();
}

class _LiveOrdersScreenState extends State<LiveOrdersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _pendingOrders = [];
  List<Map<String, dynamic>> _activeOrders = [];
  bool _isLoading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _refreshAll(isInitial: true);
    
    // Start automatic polling every 10 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => _refreshAll());
  }

  Future<void> _refreshAll({bool isInitial = false}) async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return;

    if (isInitial) setState(() => _isLoading = true);
    
    // 1. Fetch Pending Requests (For Approval)
    final pData = await ApiService.fetchPendingOrders(tenant.id);
    // 2. Fetch Active Orders (Cooking/Ready)
    final aData = await ApiService.fetchActiveOrders(tenant.id);

    if (mounted) {
      setState(() {
        if (pData != null) _pendingOrders = pData;
        if (aData != null) _activeOrders = aData;
        _isLoading = false;
      });
    }
  }

  Future<void> _approveOrder(dynamic orderId) async {
    final staff = TenantService().currentStaff.value;
    if (staff == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Session expired. Please login again.")),
      );
      return;
    }

    final success = await ApiService.waiterApproveOrder(int.parse(orderId.toString()), staff.id); 
    if (success) {
      _refreshAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Order sent to Kitchen!"), backgroundColor: WaiterProTheme.emeraldGreen),
        );
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Approval failed. Please check connection."), backgroundColor: Colors.red),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text("Kitchen Status"),
        actions: [
          IconButton(onPressed: _refreshAll, icon: const Icon(Icons.refresh, color: WaiterProTheme.royalBlue)),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: WaiterProTheme.royalBlue,
          indicatorColor: WaiterProTheme.royalBlue,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: "New Requests"),
            Tab(text: "Cooking"),
            Tab(text: "Ready"),
            Tab(text: "Completed"),
          ],
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : TabBarView(
            controller: _tabController,
            children: [
              _buildApprovalQueue(),
              _buildActiveQueue("Preparing"),
              _buildActiveQueue("Ready"),
              _buildCompletedQueue(),
            ],
          ),
    );
  }

  Widget _buildApprovalQueue() {
    if (_pendingOrders.isEmpty) {
      return _buildEmptyState("No new requests", Icons.inbox_outlined);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pendingOrders.length,
      itemBuilder: (context, index) {
        final o = _pendingOrders[index];
        return _buildApprovalCard(o);
      },
    );
  }

  Widget _buildApprovalCard(Map<String, dynamic> o) {
    final List items = o['items'] ?? [];
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: WaiterProTheme.softShadow,
        border: Border.all(color: Colors.orange.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("TABLE T-${o['table_number']}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                      child: const Text("PENDING APPROVAL", style: TextStyle(color: Colors.orange, fontSize: 8, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...items.map((i) => _buildItemRow(i['product_name'], i['quantity'].toString())),
              ],
            ),
          ),
          InkWell(
            onTap: () => _approveOrder(o['id']),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFFFF5C00),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
              ),
              child: const Center(
                child: Text("APPROVE & SEND TO KITCHEN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveQueue(String status) {
    final filtered = _activeOrders.where((o) => o['status'] == status).toList();
    if (filtered.isEmpty) return _buildEmptyState("No orders in $status", Icons.restaurant);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final o = filtered[index];
        final List items = o['items'] ?? [];
        Color accentColor = status == 'Ready' ? WaiterProTheme.emeraldGreen : Colors.blue;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: WaiterProTheme.softShadow),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("TABLE T-${o['table_number']}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                        Text(o['status'].toString().toUpperCase(), style: TextStyle(color: accentColor, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ...items.map((i) => _buildItemRow(i['product_name'], i['quantity'].toString())),
                  ],
                ),
              ),
              if (status == 'Ready')
                InkWell(
                  onTap: () async {
                    await ApiService.updateOrderStatus(int.parse(o['id'].toString()), 'OnWay');
                    _refreshAll();
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(color: accentColor, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24))),
                    child: const Center(child: Text("ACCEPT DELIVERY", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompletedQueue() {
    final filtered = _activeOrders.where((o) => o['status'] == 'OnWay' || o['status'] == 'Completed').toList();
    if (filtered.isEmpty) return _buildEmptyState("No history yet", Icons.history);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final o = filtered[index];
        return ListTile(
          title: Text("Table T-${o['table_number']} - ${o['status']}"),
          subtitle: Text("Order Total: NPR ${o['total_amount']}"),
        );
      },
    );
  }

  Widget _buildItemRow(String name, String qty) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text("$qty x $name", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildEmptyState(String text, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: Colors.grey.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text(text, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
