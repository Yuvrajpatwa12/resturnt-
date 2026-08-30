import 'package:flutter/material.dart';
import 'cart_manager.dart';
import 'game_hub.dart';
import 'voice_order_page.dart';

class OrderStatusPage extends StatelessWidget {
  const OrderStatusPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ShopManager.instance.isOrderActive,
      builder: (context, isActive, child) {
        if (!isActive) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey[300]),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Order not available",
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        }

        return ValueListenableBuilder<OrderStatus>(
          valueListenable: ShopManager.instance.orderStatus,
          builder: (context, status, child) {
            return Scaffold(
              backgroundColor: const Color(0xFFF7F8FA),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    // Main Status Card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getStatusTitle(status),
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getStatusSubtitle(status),
                            style: const TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                          const SizedBox(height: 24),
                          
                          // Horizontal Stepper
                          Row(
                            children: [
                              _buildIconStep(Icons.timer_outlined, status == OrderStatus.pending, isPending: status == OrderStatus.pending),
                              _buildConnector(status != OrderStatus.pending),
                              _buildIconStep(Icons.check, status == OrderStatus.approved),
                              _buildConnector(status == OrderStatus.preparing || status == OrderStatus.ready),
                              _buildIconStep(Icons.restaurant, status == OrderStatus.preparing),
                              _buildConnector(status == OrderStatus.ready),
                              _buildIconStep(Icons.done_all, status == OrderStatus.ready),
                            ],
                          ),
                          const SizedBox(height: 24),
                          
                          Text(
                            _getStatusDetail(status),
                            style: const TextStyle(color: Colors.black54, fontSize: 13),
                          ),
                          
                          if (status == OrderStatus.preparing) ...[
                            const Divider(height: 40),
                            _buildBoredSection(context),
                          ],

                          if (status == OrderStatus.ready) ...[
                            const Divider(height: 40),
                            _buildReadySection(context),
                          ],

                          const Divider(height: 40),
                          
                          // Show Order Details Button
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () => _showOrderDetails(context),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFE91E63)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                              ),
                              child: const Text(
                                "Show Order Details",
                                style: TextStyle(color: Color(0xFFE91E63), fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Cancel Order Button - Only visible in pending/approved
                    if (status == OrderStatus.pending || status == OrderStatus.approved)
                      TextButton(
                        onPressed: () {
                          ShopManager.instance.clearActiveOrder();
                        },
                        child: const Text("Cancel Order", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _getStatusTitle(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending: return "Order Pending";
      case OrderStatus.approved: return "Order Placed";
      case OrderStatus.preparing: return "Preparing your order";
      case OrderStatus.ready: return "Order is Ready!";
    }
  }

  String _getStatusSubtitle(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending: return "Waiting for kitchen approval";
      case OrderStatus.approved: return "Kitchen has accepted your order";
      case OrderStatus.preparing: return "Arriving in 15-20 mins";
      case OrderStatus.ready: return "Please collect your order";
    }
  }

  String _getStatusDetail(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending: return "Our staff is checking your order items.";
      case OrderStatus.approved: return "Your order has been approved and moved to the kitchen.";
      case OrderStatus.preparing: return "Chuck's Donut Inc is preparing your order.";
      case OrderStatus.ready: return "Your food is fresh and ready for you!";
    }
  }

  Widget _buildBoredSection(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text("Are you bored?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              SizedBox(height: 4),
              Text(
                "Play a quick game while you wait!",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const GameHubPage()));
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6236FF),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          child: const Text("Yes", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildReadySection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Need anything else?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        Row(
          children: [
            const Expanded(
              child: Text(
                "Your order is ready! Do you need any additional services?",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
            IconButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const VoiceOrderPage()));
              },
              icon: const Icon(Icons.mic, color: Color(0xFFFF5C00), size: 30),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildIconStep(IconData icon, bool isActive, {bool isPending = false}) {
    Color color = isActive ? (isPending ? Colors.orange : const Color(0xFFE91E63)) : const Color(0xFFF2F2F2);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: isActive ? Colors.white : Colors.grey[400], size: 18),
    );
  }

  Widget _buildConnector(bool isActive) {
    return Expanded(
      child: Container(
        height: 3,
        color: isActive ? const Color(0xFFE91E63) : const Color(0xFFF2F2F2),
      ),
    );
  }

  void _showOrderDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Order Summary", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              ValueListenableBuilder<List<CartItem>>(
                valueListenable: ShopManager.instance.placedOrderItems,
                builder: (context, items, child) {
                  return Column(
                    children: items.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(item.product.image, width: 50, height: 50, fit: BoxFit.cover),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.product.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                Text("Qty: ${item.quantity}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                          ),
                          Text(item.product.price, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )).toList(),
                  );
                },
              ),
              const Divider(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5C00),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Close", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
