import 'package:flutter/material.dart';
import '../../cart_manager.dart';
import '../theme.dart';
import 'digital_menu_screen.dart';
import 'running_order_summary_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Chiyalaa Hub"),
        actions: [
          IconButton(
            onPressed: () {
              Future.microtask(() => ShopManager.instance.waiterTabIndex.value = 3); // Switch to Alerts
            },
            icon: const Icon(Icons.notifications_none),
          ),
          const SizedBox(width: 4),
          const CircleAvatar(
            radius: 14,
            backgroundColor: WaiterProTheme.royalBlue,
            child: Text("YP", style: TextStyle(color: Colors.white, fontSize: 10)),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quick Stats
            ValueListenableBuilder<Map<int, String>>(
              valueListenable: ShopManager.instance.tableStatuses,
              builder: (context, statuses, child) {
                final activeCount = statuses.values.where((s) => s == "Dining").length;
                final availableCount = statuses.values.where((s) => s == "Available").length;
                
                return Row(
                  children: [
                    _buildStatChip(context, "Occupied", "$activeCount", WaiterProTheme.royalBlue, 1),
                    const SizedBox(width: 10),
                    _buildStatChip(context, "Available", "$availableCount", WaiterProTheme.emeraldGreen, 1),
                    const SizedBox(width: 10),
                    _buildStatChip(context, "Alerts", "03", Colors.orange, 3),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Floor Status",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () {
                    Future.microtask(() => ShopManager.instance.waiterTabIndex.value = 1); // Go to Tables
                  },
                  child: const Text("View All", style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Interactive Table Grid
            ValueListenableBuilder<Map<int, String>>(
              valueListenable: ShopManager.instance.tableStatuses,
              builder: (context, statuses, child) {
                if (statuses.isEmpty) {
                  ShopManager.instance.initializeTables(20);
                  return const Center(child: Padding(
                    padding: EdgeInsets.all(40.0),
                    child: CircularProgressIndicator(),
                  ));
                }

                final sortedIds = statuses.keys.toList()..sort();
                final previewIds = sortedIds.take(9).toList();

                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: previewIds.map((id) {
                    String status = statuses[id] ?? "Available";
                    bool isDining = status == "Dining";
                    return SizedBox(
                      width: (MediaQuery.of(context).size.width - 24 - 20) / 3,
                      child: _buildTableCard(context, id.toString(), isDining ? "Occupied" : status, isDining),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(BuildContext context, String label, String value, Color color, int targetIndex) {
    return Expanded(
      child: InkWell(
        onTap: () => Future.microtask(() => ShopManager.instance.waiterTabIndex.value = targetIndex),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
              Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableCard(BuildContext context, String tableNum, String status, bool isOccupied) {
    Color statusColor;
    IconData icon;
    switch (status) {
      case "Occupied":
        statusColor = WaiterProTheme.royalBlue;
        icon = Icons.people_alt;
        break;
      case "Dirty":
        statusColor = Colors.orange;
        icon = Icons.cleaning_services;
        break;
      default:
        statusColor = WaiterProTheme.emeraldGreen;
        icon = Icons.event_available;
    }

    return InkWell(
      onTap: () {
        if (isOccupied) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => RunningOrderSummaryScreen(tableId: "T-$tableNum")),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => DigitalMenuScreen(tableId: "T-$tableNum")),
          );
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: WaiterProTheme.softShadow,
          border: Border.all(color: statusColor.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: statusColor, size: 20),
            const SizedBox(height: 4),
            Text(
              "T-$tableNum",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            Text(
              status,
              style: TextStyle(fontSize: 9, color: statusColor, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
