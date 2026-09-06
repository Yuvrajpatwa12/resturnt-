import 'package:flutter/material.dart';
import '../../cart_manager.dart';
import '../kitchen_theme.dart';

class KotTicketCard extends StatelessWidget {
  final int tableId;
  final List<CartItem> items;
  final int secondsElapsed;
  final String stage;
  final VoidCallback onAction;

  const KotTicketCard({
    super.key,
    required this.tableId,
    required this.items,
    required this.secondsElapsed,
    required this.stage,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final int minutes = (secondsElapsed / 60).floor();
    
    // Header Color based on Stage
    Color headerColor;
    if (stage == "Incoming") {
      headerColor = KitchenTheme.royalBlue;
    } else if (stage == "Preparing") {
      headerColor = Colors.orange;
    } else {
      headerColor = KitchenTheme.emeraldGreen;
    }

    // Urgency Icon Color based on time
    Color urgencyColor = minutes > 20 ? Colors.redAccent : (minutes > 10 ? Colors.orange : Colors.white);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: headerColor.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. SOLID HEADER
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: headerColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "TABLE T-$tableId",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5),
                      ),
                      const Text(
                        "DINE-IN ORDER",
                        style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.timer_outlined, size: 12, color: urgencyColor),
                      const SizedBox(width: 4),
                      Text(
                        "${minutes}M",
                        style: TextStyle(color: urgencyColor, fontWeight: FontWeight.w900, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. ITEM LIST (Scrollable Column)
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (context, index) => Divider(color: Colors.grey.withValues(alpha: 0.1), height: 20),
              itemBuilder: (context, index) {
                final item = items[index];
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: KitchenTheme.pearlWhite,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
                      ),
                      child: Text(
                        "${item.quantity}",
                        style: const TextStyle(fontWeight: FontWeight.w900, color: KitchenTheme.darkNavy, fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.product.title,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, height: 1.2),
                          ),
                          if (item.notes != null && item.notes!.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                "NOTE: ${item.notes}",
                                style: const TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // 3. ACTION FOOTER
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onAction,
                    icon: Icon(
                      stage == "Ready" ? Icons.notifications_active : (stage == "Incoming" ? Icons.play_arrow : Icons.check),
                      size: 18,
                    ),
                    label: Text(
                      stage == "Incoming" ? "START COOKING" : (stage == "Preparing" ? "MARK READY" : "NOTIFY WAITER"),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: headerColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                if (stage != "Ready") ...[
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.close, color: Colors.redAccent, size: 18),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
