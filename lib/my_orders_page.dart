import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'cart_manager.dart';
import 'live_order_tracking_screen.dart';
import 'services/tenant_service.dart';
import 'services/api_service.dart';

class MyOrdersPage extends StatefulWidget {
  const MyOrdersPage({super.key});

  @override
  State<MyOrdersPage> createState() => _MyOrdersPageState();
}

class _MyOrdersPageState extends State<MyOrdersPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _sessionOrders = [];
  bool _isLoading = true;
  bool _hasLoadError = false;
  bool _isOrderSyncPending = false;
  bool _isFetching = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadOrders();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _loadOrders(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    if (_isFetching) return;
    _isFetching = true;
    await ShopManager.instance.ensureInitialized();
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasLoadError = true;
        });
      }
      _isFetching = false;
      return;
    }

    if (_sessionOrders.isEmpty) {
      if (mounted) setState(() => _isLoading = true);
    }
    final uid = ShopManager.instance.orderUserId;
    final email = ShopManager.instance.customerEmail.value;
    final gid = ShopManager.instance.guestId.value;
    final activeId = ShopManager.instance.activeOrderId.value;
    final activeIds = ShopManager.instance.activeOrderIds.value;
    final orderIdsSet = <int>{
      if (activeId != null && activeId > 0) activeId,
      ...activeIds.where((i) => i > 0),
    };
    final orderIdsStr = orderIdsSet.isNotEmpty ? orderIdsSet.join(',') : null;

    final cachedOrders = await ApiService.getCachedUserOrders(tenant.id, uid);
    final cachedEmailOrders = email.isNotEmpty
        ? await ApiService.getCachedUserOrders(tenant.id, email)
        : <Map<String, dynamic>>[];
    final allCached = [...cachedOrders, ...cachedEmailOrders];
    final mergedCachedById = <String, Map<String, dynamic>>{
      for (final order in allCached)
        if (order['id'] != null) order['id'].toString(): order,
    };
    final cachedList = mergedCachedById.values.toList();

    if (!mounted) return;
    if (cachedList.isNotEmpty) {
      setState(() {
        _sessionOrders = cachedList;
        _isOrderSyncPending = false;
        _isLoading = false;
      });
    }

    try {
      var data = await ApiService.fetchUserOrders(
        tenant.id,
        uid,
        customerEmail: email,
        guestId: gid,
        orderIds: orderIdsStr,
      );
      if (!mounted) return;

      if (data != null && data['status'] == 'success') {
        var newList = _parseOrders(data);
        final hasKnownActiveOrder =
            ShopManager.instance.activeOrderId.value != null ||
            ShopManager.instance.activeOrderIds.value.isNotEmpty;

        // A newly placed order can become visible to the read endpoint shortly
        // after the order-confirmation response. Retry before showing an empty
        // state while this device already knows an active order ID.
        if (newList.isEmpty && hasKnownActiveOrder) {
          await Future<void>.delayed(const Duration(milliseconds: 800));
          if (!mounted) return;
          data = await ApiService.fetchUserOrders(
            tenant.id,
            uid,
            customerEmail: email,
            guestId: gid,
            orderIds: orderIdsStr,
          );
          if (!mounted) return;
          if (data != null && data['status'] == 'success') {
            newList = _parseOrders(data);
          }
        }

        final mergedById = <String, Map<String, dynamic>>{
          for (final order in cachedList)
            if (order['id'] != null) order['id'].toString(): order,
        };
        for (final order in newList) {
          final id = order['id']?.toString();
          if (id != null && id.isNotEmpty) mergedById[id] = order;
        }
        final mergedOrders = mergedById.values.toList()
          ..sort((a, b) {
            final aTime =
                DateTime.tryParse(a['created_at']?.toString() ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0);
            final bTime =
                DateTime.tryParse(b['created_at']?.toString() ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0);
            return bTime.compareTo(aTime);
          });
        if (mergedOrders.isNotEmpty) {
          await ApiService.cacheUserOrders(tenant.id, uid, mergedOrders);
          if (email.isNotEmpty && email != uid) {
            await ApiService.cacheUserOrders(tenant.id, email, mergedOrders);
          }
        }
        if (!mounted) return;
        setState(() {
          _sessionOrders = mergedOrders;
          _hasLoadError = false;
          _isOrderSyncPending = mergedOrders.isEmpty && hasKnownActiveOrder;
          ShopManager.instance.totalOrdersCount.value = math.max(
            ShopManager.instance.totalOrdersCount.value,
            math.max(
              mergedOrders.length,
              ShopManager.instance.activeOrderIds.value.length,
            ),
          );
          _isLoading = false;
        });
      } else {
        setState(() {
          _sessionOrders = cachedList;
          _hasLoadError = true;
          _isOrderSyncPending = false;
          _isLoading = false;
        });
      }
    } catch (error) {
      debugPrint("My Orders refresh failed: $error");
      if (mounted) {
        setState(() {
          _sessionOrders = cachedList;
          _hasLoadError = true;
          _isOrderSyncPending = false;
          _isLoading = false;
        });
      }
    } finally {
      _isFetching = false;
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Map<String, dynamic>> _parseOrders(Map<String, dynamic> response) {
    final rawOrders = response['data'] ?? response['orders'];
    if (rawOrders is! List) return [];
    return rawOrders
        .whereType<Map>()
        .map((order) => Map<String, dynamic>.from(order))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "My Orders",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
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
          labelColor: Theme.of(context).primaryColor,
          indicatorColor: Theme.of(context).primaryColor,
          tabs: const [
            Tab(text: "Live Status"),
            Tab(text: "Order History"),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loadOrders,
            icon: Icon(Icons.refresh, color: Theme.of(context).primaryColor),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_hasLoadError)
                  Material(
                    color: Colors.orange.shade50,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.cloud_off, color: Colors.deepOrange),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              "Could not refresh orders. Showing the last available results.",
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                          IconButton(
                            tooltip: "Retry",
                            onPressed: _loadOrders,
                            icon: const Icon(Icons.refresh),
                          ),
                        ],
                      ),
                    ),
                  ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOrderList(isActive: true),
                      _buildOrderList(isActive: false),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildOrderList({required bool isActive}) {
    final filtered = _sessionOrders.where((o) {
      final status = (o['status'] ?? '').toString().trim().toLowerCase();
      final isDone =
          status == 'completed' ||
          status == 'complete' ||
          status == 'cancelled' ||
          status == 'canceled';
      return isActive ? !isDone : isDone;
    }).toList();

    if (filtered.isEmpty) {
      if (_hasLoadError) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 52, color: Colors.grey),
              const SizedBox(height: 12),
              const Text(
                "Orders could not be loaded.",
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _loadOrders,
                icon: const Icon(Icons.refresh),
                label: const Text("Try again"),
              ),
            ],
          ),
        );
      }
      return RefreshIndicator(
        onRefresh: _loadOrders,
        color: Theme.of(context).primaryColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.6,
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isActive ? Icons.restaurant : Icons.history,
                  size: 64,
                  color: Colors.grey[200],
                ),
                const SizedBox(height: 16),
                Text(
                  isActive && _isOrderSyncPending
                      ? "Syncing your active order..."
                      : isActive
                      ? "No active orders found"
                      : "No order history",
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadOrders,
      color: Theme.of(context).primaryColor,
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => LiveOrderTrackingScreen(
                  orderId: int.parse(o['id'].toString()),
                  displayOrderNumber:
                      o['tenant_order_number']?.toString(),
                ),
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
                        Text(
                          "Order #${o['tenant_order_number'] ?? o['id']} • Table #${o['table_number'] ?? '1'}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          o['created_at'] ?? 'Just now',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 11,
                          ),
                        ),
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
                      icon: Icon(
                        Icons.visibility_outlined,
                        size: 16,
                        color: Theme.of(context).primaryColor,
                      ),
                      label: Text(
                        "View Items",
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          "Total Amount",
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "NPR ${o['total_amount']}",
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Theme.of(context).primaryColor,
                            fontSize: 15,
                          ),
                        ),
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
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Order #${order['tenant_order_number'] ?? order['id']} Items",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Ordered on: $orderTime",
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "${items.length} Items",
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(
                  child: Text(
                    "No items found for this order.",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final itemName =
                        item['product_name'] ?? item['name'] ?? 'Food Item';
                    final itemQty = item['quantity'] ?? '1';
                    final itemPrice =
                        item['price'] ?? item['price_at_order'] ?? '0';

                    // Look up product image from TenantService products list
                    String? foundImage;
                    final dbProducts = TenantService().products.value;
                    for (var p in dbProducts) {
                      final pTitle = (p['title'] ?? p['name'] ?? '')
                          .toString()
                          .toLowerCase();
                      if (pTitle == itemName.toLowerCase() ||
                          pTitle.contains(itemName.toLowerCase()) ||
                          itemName.toLowerCase().contains(pTitle)) {
                        foundImage = p['image_url'] ?? p['image'];
                        if (foundImage != null && foundImage.isNotEmpty) break;
                      }
                    }

                    final String? rawImage =
                        foundImage ?? item['image'] ?? item['image_url'];
                    final String imageUrl =
                        (rawImage != null &&
                            rawImage.toString().trim().isNotEmpty &&
                            rawImage.toString() != 'null')
                        ? rawImage.toString()
                        : _getDefaultFoodImage(itemName);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.grey.withValues(alpha: 0.1),
                        ),
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
                                Text(
                                  itemName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "Quantity: x$itemQty",
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            "NPR $itemPrice",
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
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
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        Icons.restaurant_menu_rounded,
        color: Theme.of(context).primaryColor,
        size: 22,
      ),
    );
  }

  String _getDefaultFoodImage(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('thupa') || lower.contains('soup'))
      return 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=500';
    if (lower.contains('role') ||
        lower.contains('roll') ||
        lower.contains('wrap'))
      return 'https://images.unsplash.com/photo-1626777552726-4a6b54c97e46?w=500';
    if (lower.contains('momo') || lower.contains('dumpling'))
      return 'https://images.unsplash.com/photo-1534422298391-e4f8c172dddb?w=500';
    if (lower.contains('chowmein') ||
        lower.contains('chaumin') ||
        lower.contains('noodles'))
      return 'https://images.unsplash.com/photo-1585032226651-759b368d7246?w=500';
    if (lower.contains('burger'))
      return 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=500';
    if (lower.contains('pizza'))
      return 'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=500';
    if (lower.contains('tea') || lower.contains('chiya'))
      return 'https://images.unsplash.com/photo-1561336313-0bd5e0b27ec8?w=500';
    if (lower.contains('coffee'))
      return 'https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=500';
    return 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=500';
  }

  String _getFoodAssetImage(String name) {
    final int hash = name.hashCode.abs();
    final int index = (hash % 3) + 1;
    return 'assets/images/food$index.png';
  }

  Widget _buildStatusBadge(dynamic rawStatus) {
    final statusStr = (rawStatus ?? 'Pending').toString().trim();
    final displayStatus = statusStr.isEmpty ? 'Pending' : statusStr;
    final lower = displayStatus.toLowerCase();

    Color color = Colors.orange;
    if (lower == 'approved') color = Colors.blue;
    if (lower == 'preparing') color = Colors.purple;
    if (lower == 'ready') color = Colors.green;
    if (lower == 'onway' || lower == 'on way') color = const Color(0xFF6236FF);
    if (lower == 'completed' || lower == 'complete') color = Colors.teal;
    if (lower == 'cancelled' || lower == 'canceled') color = Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        displayStatus.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
