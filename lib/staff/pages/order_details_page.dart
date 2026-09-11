import 'package:flutter/material.dart';
import '../../cart_manager.dart';
import '../../services/api_service.dart';
import '../../services/tenant_service.dart';
import 'staff_final_receipt_page.dart';

class OrderDetailsPage extends StatelessWidget {
  final int tableId;
  const OrderDetailsPage({super.key, required this.tableId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text("Table #1F-0$tableId", style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w900, fontSize: 16)),
            const Text("20/08/2026 • 14:45", style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
        centerTitle: true,
      ),
      body: ValueListenableBuilder<Map<int, List<CartItem>>>(
        valueListenable: ShopManager.instance.tableOrders,
        builder: (context, allOrders, child) {
          final items = allOrders[tableId] ?? [];
          return Column(
            children: [
              _buildStatusHeader(context),

              Expanded(
                child: items.isEmpty 
                  ? const Center(child: Text("No active orders for this table", style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(24),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return _buildOrderItem(item);
                      },
                    ),
              ),

              _buildBottomActions(context, items),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          ValueListenableBuilder<Map<int, int>>(
            valueListenable: ShopManager.instance.tableCountdownTimers,
            builder: (context, timers, child) {
              final secondsLeft = timers[tableId] ?? 0;
              final bool isReady = secondsLeft <= 0;
              final totalSeconds = ShopManager.instance.tableOriginalDurations.value[tableId] ?? 1;
              final double progress = secondsLeft / totalSeconds;
              
              return Column(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 100,
                        height: 100,
                        child: CircularProgressIndicator(
                          value: isReady ? 1.0 : progress,
                          strokeWidth: 8,
                          color: isReady ? Colors.green : const Color(0xFFFF5C00),
                          backgroundColor: Colors.grey[100],
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isReady ? Icons.check_circle : Icons.timer_outlined,
                            color: isReady ? Colors.green : const Color(0xFFFF5C00),
                            size: 20,
                          ),
                          Text(
                            isReady ? "READY" : "${(secondsLeft / 60).floor()}:${(secondsLeft % 60).toString().padLeft(2, '0')}",
                            style: TextStyle(
                              fontSize: 18, 
                              fontWeight: FontWeight.w900,
                              color: isReady ? Colors.green : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    isReady ? "Order is ready for serving" : "Chef is preparing the meal",
                    style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItem(CartItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(item.product.image, width: 50, height: 50, fit: BoxFit.cover),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.product.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Text(
                  "${item.size} • ${item.extras?.join(', ') ?? 'Original'}",
                  style: TextStyle(color: Colors.grey[400], fontSize: 10, fontWeight: FontWeight.bold),
                ),
                if (item.notes != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      "Note: ${item.notes}",
                      style: const TextStyle(color: Colors.blue, fontSize: 10, fontStyle: FontStyle.italic),
                    ),
                  ),
              ],
            ),
          ),
          Text(
            "x${item.quantity}",
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFFFF5C00)),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions(BuildContext context, List<CartItem> items) {
    double subtotal = 0;
    for (var item in items) {
      String priceStr = item.product.price.replaceAll('NPR ', '').replaceAll(',', '');
      double price = double.tryParse(priceStr) ?? 0;
      subtotal += price * item.quantity;
    }

    return Container(
      padding: const EdgeInsets.all(30),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("RUNNING TOTAL", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.grey)),
              Text("NPR ${subtotal.toStringAsFixed(0)}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFFFF5C00))),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>?>(
                  future: ApiService.fetchActiveOrders(TenantService().currentTenant.value?.id ?? ''),
                  builder: (context, snapshot) {
                    final order = (snapshot.data ?? []).firstWhere(
                      (o) => int.parse(o['table_number'].toString()) == tableId && o['status'] == 'Pending',
                      orElse: () => {},
                    );
                    
                    if (order.isEmpty) return const SizedBox.shrink();

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final result = await ApiService.updateOrderStatus(int.parse(order['id'].toString()), 'Approved');
                          if (result['success'] == true) {
                            ShopManager.instance.refreshLiveOrders();
                            if (context.mounted) Navigator.pop(context);
                          }
                        },
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text("APPROVE & START PREPARING"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                      ),
                    );
                  }
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    ShopManager.instance.activeStaffTableId.value = tableId;
                    ShopManager.instance.waiterTabIndex.value = 1; // Menus Tab
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text("ADD MORE ITEMS"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5C00).withValues(alpha: 0.1),
                    foregroundColor: const Color(0xFFFF5C00),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    ShopManager.instance.clearTable(tableId);
                    Navigator.pop(context);
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: const Text("CLEAR TABLE", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: ElevatedButton(
                  onPressed: items.isEmpty ? null : () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => StaffFinalReceiptPage(tableId: tableId)));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5C00),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 5,
                    shadowColor: const Color(0xFFFF5C00).withValues(alpha: 0.3),
                  ),
                  child: const Text("CREATE FINAL BILL", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
