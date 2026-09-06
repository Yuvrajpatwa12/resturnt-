import 'package:flutter/material.dart';
import '../../cart_manager.dart';
import '../theme.dart';
import 'digital_menu_screen.dart';
import 'running_order_summary_screen.dart';

class TableManagementScreen extends StatefulWidget {
  const TableManagementScreen({super.key});

  @override
  State<TableManagementScreen> createState() => _TableManagementScreenState();
}

class _TableManagementScreenState extends State<TableManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Table Management", style: TextStyle(fontSize: 18)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: WaiterProTheme.royalBlue,
          indicatorColor: WaiterProTheme.royalBlue,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: "Indoor"),
            Tab(text: "Roof"),
            Tab(text: "VIP"),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Search Table...",
                hintStyle: const TextStyle(fontSize: 13),
                prefixIcon: const Icon(Icons.search, size: 18),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                fillColor: Colors.white,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTableGrid(100),
                _buildTableGrid(200),
                _buildTableGrid(300),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4))],
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.merge_type, size: 16),
                label: const Text("Merge", style: TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  side: const BorderSide(color: WaiterProTheme.royalBlue),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.cleaning_services, size: 16),
                label: const Text("Clear Dirty", style: TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableGrid(int offset) {
    return ValueListenableBuilder<Map<int, String>>(
      valueListenable: ShopManager.instance.tableStatuses,
      builder: (context, statuses, child) {
        if (statuses.isEmpty) {
          ShopManager.instance.initializeTables(20);
          return const Center(child: CircularProgressIndicator());
        }

        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.0,
          ),
          itemCount: 12,
          itemBuilder: (context, index) {
            final tableId = offset + index + 1;
            String status = statuses[tableId] ?? "Available";
            bool isOccupied = status == "Dining";

            return InkWell(
              onTap: () {
                if (isOccupied) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => RunningOrderSummaryScreen(tableId: "T-$tableId")),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => DigitalMenuScreen(tableId: "T-$tableId")),
                  );
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  color: isOccupied ? WaiterProTheme.royalBlue.withValues(alpha: 0.05) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isOccupied ? WaiterProTheme.royalBlue : const Color(0xFFE2E8F0),
                    width: 1.2,
                  ),
                  boxShadow: WaiterProTheme.softShadow,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "T-$tableId",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isOccupied ? WaiterProTheme.royalBlue : WaiterProTheme.darkNavy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isOccupied ? "Occupied" : status,
                      style: TextStyle(
                        fontSize: 9,
                        color: isOccupied ? WaiterProTheme.royalBlue : Colors.grey,
                      ),
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
}
