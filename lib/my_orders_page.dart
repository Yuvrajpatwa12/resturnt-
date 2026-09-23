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

    if (_sessionOrders.isEmpty) {
      setState(() => _isLoading = true);
    }
    final myEmail = ShopManager.instance.customerEmail.value;
    final myGuestId = ShopManager.instance.guestId.value;
    final String uid = myEmail.isNotEmpty ? myEmail : myGuestId;

    // Fetch ALL orders (Live + History) using the new dedicated endpoint
    final data = await ApiService.fetchUserOrders(tenant.id, uid);
    
    if (data != null && data['status'] == 'success') {
      final newList = List<Map<String, dynamic>>.from(data['data']);
      setState(() {
        if (newList.isNotEmpty || _sessionOrders.isEmpty) {
          _sessionOrders = newList;
        }
        ShopManager.instance.totalOrdersCount.value = data['total_count'] ?? _sessionOrders.length;
      });
    } else {
      if (mounted && _sessionOrders.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Slow connection. Could not refresh orders."), duration: Duration(seconds: 2))
        );
      }
    }
    if (_isLoading) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text("My Orders", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            ShopManager.instance.currentTabIndex.value = 0;
            if (Navigator.canPop(context)) {
               Navigator.pop(context);
            }
          },
        ),
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
      return RefreshIndicator(
        onRefresh: _loadOrders,
        color: const Color(0xFFFF5C00),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.6,
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(isActive ? Icons.restaurant : Icons.history, size: 64, color: Colors.grey[200]),
                const SizedBox(height: 16),
                Text(isActive ? "No active orders found" : "No order history", style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadOrders,
      color: const Color(0xFFFF5C00),
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final o = filtered[index];
          return _buildOrderCard(o, isActive);
        },
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> o, bool isActive) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => LiveOrderTrackingScreen(orderId: int.parse(o['id'].toString())),
              ),
            );
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
                        Text("Order #${o['id']} • Table #${o['table_number'] ?? '1'}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                    TextButton.icon(
                      onPressed: () => _showOrderItemsModal(context, o),
                      icon: const Icon(Icons.visibility_outlined, size: 16, color: Color(0xFFFF5C00)),
                      label: const Text("View Items", style: TextStyle(color: Color(0xFFFF5C00), fontWeight: FontWeight.bold, fontSize: 12)),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text("Total Amount", style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                        Text("NPR ${o['total_amount']}", style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFFF5C00), fontSize: 15)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showOrderItemsModal(BuildContext context, Map<String, dynamic> order) {
    final List<dynamic> items = order['items'] ?? [];
    final String orderTime = order['created_at'] ?? 'Just now';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Order #${order['id']} Items", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text("Ordered on: $orderTime", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFFFF5C00).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: Text("${items.length} Items", style: const TextStyle(color: Color(0xFFFF5C00), fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(child: Text("No items found for this order.", style: TextStyle(color: Colors.grey))),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final itemName = item['product_name'] ?? item['name'] ?? 'Food Item';
                    final itemQty = item['quantity'] ?? '1';
                    final itemPrice = item['price'] ?? item['price_at_order'] ?? '0';
                    
                    // Look up product image from TenantService products list
                    String? foundImage;
                    final dbProducts = TenantService().products.value;
                    for (var p in dbProducts) {
                      final pTitle = (p['title'] ?? p['name'] ?? '').toString().toLowerCase();
                      if (pTitle == itemName.toLowerCase() || pTitle.contains(itemName.toLowerCase()) || itemName.toLowerCase().contains(pTitle)) {
                        foundImage = p['image_url'] ?? p['image'];
                        if (foundImage != null && foundImage.isNotEmpty) break;
                      }
                    }

                    final String? rawImage = foundImage ?? item['image'] ?? item['image_url'];
                    final String imageUrl = (rawImage != null && rawImage.toString().trim().isNotEmpty && rawImage.toString() != 'null')
                        ? rawImage.toString()
                        : _getDefaultFoodImage(itemName);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              imageUrl,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return _buildPlaceholderIcon();
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(itemName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                const SizedBox(height: 2),
                                Text("Quantity: x$itemQty", style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                          Text("NPR $itemPrice", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFFFF5C00))),
                        ],
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderIcon() {
    return Container(
      width: 48, height: 48,
      decoration: BoxDecoration(color: const Color(0xFFFF5C00).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
      child: const Icon(Icons.restaurant_menu_rounded, color: Color(0xFFFF5C00), size: 22),
    );
  }

  String _getDefaultFoodImage(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('thupa') || lower.contains('soup')) return 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=500';
    if (lower.contains('role') || lower.contains('roll') || lower.contains('wrap')) return 'https://images.unsplash.com/photo-1626777552726-4a6b54c97e46?w=500';
    if (lower.contains('momo') || lower.contains('dumpling')) return 'https://images.unsplash.com/photo-1534422298391-e4f8c172dddb?w=500';
    if (lower.contains('chowmein') || lower.contains('chaumin') || lower.contains('noodles')) return 'https://images.unsplash.com/photo-1585032226651-759b368d7246?w=500';
    if (lower.contains('burger')) return 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=500';
    if (lower.contains('pizza')) return 'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=500';
    if (lower.contains('tea') || lower.contains('chiya')) return 'https://images.unsplash.com/photo-1561336313-0bd5e0b27ec8?w=500';
    if (lower.contains('coffee')) return 'https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=500';
    return 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=500';
  }

  String _getFoodAssetImage(String name) {
    final int hash = name.hashCode.abs();
    final int index = (hash % 3) + 1;
    return 'assets/images/food$index.png';
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
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }
}
