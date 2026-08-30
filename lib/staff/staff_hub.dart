import 'package:flutter/material.dart';
import '../cart_manager.dart';
import 'tabs/tables_tab.dart';
import 'tabs/menus_tab.dart';
import 'tabs/bills_tab.dart';
import 'tabs/admin_tab.dart';
import 'tabs/settings_tab.dart';
import 'widgets/staff_bottom_bar.dart';

class StaffHub extends StatefulWidget {
  const StaffHub({super.key});

  @override
  State<StaffHub> createState() => _StaffHubState();
}

class _StaffHubState extends State<StaffHub> {
  @override
  void initState() {
    super.initState();
    ShopManager.instance.initializeTables(20);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: ShopManager.instance.waiterTabIndex,
      builder: (context, selectedIndex, child) {
        return Scaffold(
          backgroundColor: const Color(0xFFF7F8FA),
          body: Stack(
            children: [
              Column(
                children: [
                  _buildTopNavigationBar(selectedIndex),
                  
                  Expanded(
                    child: IndexedStack(
                      index: selectedIndex,
                      children: [
                        const TablesTab(),
                        ValueListenableBuilder<int?>(
                          valueListenable: ShopManager.instance.activeStaffTableId,
                          builder: (context, activeTableId, child) {
                            return MenusTab(tableId: activeTableId ?? 0);
                          },
                        ),
                        const BillsTab(),
                        const AdminTab(),
                        const SettingsTab(),
                      ],
                    ),
                  ),

                  const StaffBottomBar(),
                ],
              ),
              
              // --- GLOBAL ALERT OVERLAY ---
              _buildGlobalAlertOverlay(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGlobalAlertOverlay() {
    return ValueListenableBuilder<Map<int, String>>(
      valueListenable: ShopManager.instance.tableStatuses,
      builder: (context, statuses, child) {
        // Find tables that need help
        final helpNeeded = statuses.entries.where((e) => e.value == "Help Needed").toList();
        
        return ValueListenableBuilder<Map<int, int>>(
          valueListenable: ShopManager.instance.tableCountdownTimers,
          builder: (context, timers, child) {
            // Find tables that are ready
            final readyTables = timers.entries.where((e) => e.value <= 0 && statuses[e.key] == "Dining").toList();
            
            if (helpNeeded.isEmpty && readyTables.isEmpty) return const SizedBox.shrink();

            final int tableId = helpNeeded.isNotEmpty ? helpNeeded.first.key : readyTables.first.key;
            final bool isReady = readyTables.any((e) => e.key == tableId);
            final String floor = tableId < 200 ? "1F" : "2F";
            final String tableNum = (tableId % 100).toString().padLeft(2, '0');

            return Positioned(
              top: 50,
              left: 20,
              right: 20,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 500),
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(0, (1 - value) * -100),
                    child: Opacity(
                      opacity: value,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        decoration: BoxDecoration(
                          color: isReady ? Colors.green : const Color(0xFFFF5C00),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 15, offset: const Offset(0, 5))],
                        ),
                        child: Row(
                          children: [
                            Icon(isReady ? Icons.check_circle : Icons.notifications_active, color: Colors.white),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    isReady ? "ORDER READY" : "HELP NEEDED",
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1),
                                  ),
                                  Text(
                                    "Table $floor - $tableNum is waiting",
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                ShopManager.instance.activeStaffTableId.value = tableId;
                                ShopManager.instance.waiterTabIndex.value = 0; // Go to tables to see it
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: isReady ? Colors.green : const Color(0xFFFF5C00),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                elevation: 0,
                              ),
                              child: const Text("VIEW", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTopNavigationBar(int selectedIndex) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "PayDevice Duo",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black87),
              ),
              Container(
                width: 200,
                height: 35,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const TextField(
                  decoration: InputDecoration(
                    hintText: "Search...",
                    hintStyle: TextStyle(fontSize: 12, color: Colors.grey),
                    prefixIcon: Icon(Icons.search, size: 16, color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildNavItem(0, "Tables", Icons.table_restaurant_rounded, selectedIndex),
              _buildNavItem(1, "Menus", Icons.restaurant_menu_rounded, selectedIndex),
              _buildNavItem(2, "Bills", Icons.receipt_long_rounded, selectedIndex),
              _buildNavItem(3, "Admin", Icons.dashboard_rounded, selectedIndex),
              _buildNavItem(4, "Settings", Icons.settings_rounded, selectedIndex),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, String label, IconData icon, int selectedIndex) {
    bool isSelected = selectedIndex == index;
    return GestureDetector(
      onTap: () => ShopManager.instance.waiterTabIndex.value = index,
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: isSelected ? const Color(0xFFFF5C00) : Colors.grey[400]),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.black87 : Colors.grey[400],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (isSelected)
            Container(width: 40, height: 2, color: const Color(0xFFFF5C00)),
        ],
      ),
    );
  }
}
