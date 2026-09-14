import 'package:flutter/material.dart';
import 'package:chiyabreak/cart_manager.dart';

class HostHubScreen extends StatelessWidget {
  final String tablePin;
  const HostHubScreen({super.key, required this.tablePin});

  static const Color primaryBlue = Color(0xFF1E3A8A);
  static const Color accentOrange = Color(0xFFF97316);

  @override
  Widget build(BuildContext context) {
    final session = ShopManager.instance;

    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: session.liveSessionOrders,
      builder: (context, orders, _) {
        return ValueListenableBuilder<double>(
          valueListenable: session.liveSessionTotal,
          builder: (context, totalBill, _) {
            return ValueListenableBuilder<List<Map<String, dynamic>>>(
              valueListenable: session.liveSessionMembers,
              builder: (context, members, _) {
                return Scaffold(
                  backgroundColor: const Color(0xFFF4F6F9),
                  appBar: AppBar(
                    backgroundColor: Colors.white,
                    elevation: 0.5,
                    title: const Text("HOST HUB", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.2)),
                    centerTitle: true,
                    actions: [
                      Container(
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: primaryBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: primaryBlue.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          "PIN: $tablePin",
                          style: const TextStyle(color: primaryBlue, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1),
                        ),
                      ),
                    ],
                  ),
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // "YOU ARE TABLE HOST" Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.emoji_events_outlined, color: Colors.orange, size: 14),
                              SizedBox(width: 8),
                              Text("YOU ARE TABLE HOST", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 10)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Table #04", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                                Text("Himalayan Java • Jhamsikhel", style: TextStyle(color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                              child: Text("● ${members.length} Connected", style: const TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // 1. BLUE CUMULATIVE TOTAL CARD
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [primaryBlue, Color(0xFF2563EB)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [BoxShadow(color: primaryBlue.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("CUMULATIVE TABLE TOTAL", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5)),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("Rs. ${totalBill.toInt()}", style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900)),
                                  const Icon(Icons.receipt_long, color: Colors.white24, size: 48),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Divider(color: Colors.white24),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildMiniStat("Group Average", "Rs. ${members.isEmpty ? 0 : (totalBill/members.length).toStringAsFixed(0)} / person"),
                                  _buildMiniStat("Ordered Items", "${orders.length} Dishes"),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // 2. LIVE ORDER STREAM
                        const Text("LIVE ORDER STREAM", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black87, fontSize: 14)),
                        const SizedBox(height: 16),
                        
                        if (orders.isEmpty)
                          _buildEmptySessionState()
                        else
                          ...orders.map((o) => _buildOrderItem(
                            o['title'], 
                            "x1", 
                            "For: ${o['who'] ?? 'Table'}", 
                            o['price'] is double ? "Rs. ${o['price']}" : o['price'].toString(), 
                            o['status'], 
                            o['status'] == 'Served' ? Colors.green : Colors.orange
                          )).toList(),

                        const SizedBox(height: 40),
                        
                        // 3. TABLE CONTROL
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.withValues(alpha: 0.1))),
                          child: Row(
                            children: [
                              const Icon(Icons.lock_outline, color: Colors.grey),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Ordering is Open", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    Text("Guests can freely add items", style: TextStyle(color: Colors.grey, fontSize: 11)),
                                  ],
                                ),
                              ),
                              TextButton(onPressed: () {}, child: const Text("Lock Order", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
            );
          }
        );
      }
    );
  }

  Widget _buildEmptySessionState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Column(
        children: [
          Icon(Icons.restaurant_rounded, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text("No orders yet", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          const Text("Items you order will automatically appear here.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _buildOrderItem(String title, String qty, String forWhom, String price, String status, Color statusColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)]),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: accentOrange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.fastfood_outlined, color: accentOrange, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(qty, style: const TextStyle(color: primaryBlue, fontWeight: FontWeight.w900, fontSize: 10)),
                  ],
                ),
                Text(forWhom, style: const TextStyle(color: Colors.grey, fontSize: 10)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(price, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
              Text(status, style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.w900)),
            ],
          ),
        ],
      ),
    );
  }
}
