import 'package:flutter/material.dart';


import '../cart_manager.dart';
import 'theme.dart';
import 'screens/dashboard_screen.dart';
import 'screens/table_management_screen.dart';
import 'screens/live_orders_screen.dart';
import 'screens/alerts_screen.dart';
import 'screens/profile_screen.dart';

class WaiterHub extends StatefulWidget {
  const WaiterHub({super.key});

  @override
  State<WaiterHub> createState() => _WaiterHubState();
}

class _WaiterHubState extends State<WaiterHub> {
  final List<Widget> _screens = [
    const DashboardScreen(),
    const TableManagementScreen(),
    const LiveOrdersScreen(),
    const AlertsScreen(),
    const ProfileScreen(),
  ];

  Widget _buildKitchenAlertOverlay() {
    return ValueListenableBuilder<Map<int, bool>>(
      valueListenable: ShopManager.instance.tableReadyNotifications,
      builder: (context, notifications, child) {
        if (notifications.isEmpty) return const SizedBox.shrink();

        final tableIds = notifications.keys.toList()..sort();
        final int firstTableId = tableIds.first;

        return Positioned(
          top: MediaQuery.of(context).padding.top + 10,
          left: 16,
          right: 16,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 400),
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, (1 - value) * -50),
                child: Opacity(
                  opacity: value,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: WaiterProTheme.emeraldGreen,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: WaiterProTheme.emeraldGreen.withValues(alpha: 0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.notifications_active, color: Colors.white, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                "KITCHEN BELL",
                                style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1),
                              ),
                              Text(
                                "Table T-$firstTableId order is ready!",
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => ShopManager.instance.clearWaiterNotification(firstTableId),
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text("DISMISS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
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
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: ShopManager.instance.waiterTabIndex,
      builder: (context, selectedIndex, child) {
            return Scaffold(
              body: Stack(
                children: [
                  RepaintBoundary(
                    child: IndexedStack(
                      index: selectedIndex,
                      children: _screens,
                    ),
                  ),
                  _buildKitchenAlertOverlay(),
                ],
              ),
              bottomNavigationBar: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: NavigationBar(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (index) {
                    Future.microtask(() => ShopManager.instance.waiterTabIndex.value = index);
                  },
                  backgroundColor: Colors.white,
                  indicatorColor: WaiterProTheme.royalBlue.withValues(alpha: 0.1),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.dashboard_outlined),
                      selectedIcon: Icon(Icons.dashboard, color: WaiterProTheme.royalBlue),
                      label: 'Dashboard',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.table_restaurant_outlined),
                      selectedIcon: Icon(Icons.table_restaurant, color: WaiterProTheme.royalBlue),
                      label: 'Tables',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.list_alt_outlined),
                      selectedIcon: Icon(Icons.list_alt, color: WaiterProTheme.royalBlue),
                      label: 'Orders',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.notifications_outlined),
                      selectedIcon: Icon(Icons.notifications, color: WaiterProTheme.royalBlue),
                      label: 'Alerts',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.person_outline),
                      selectedIcon: Icon(Icons.person, color: WaiterProTheme.royalBlue),
                      label: 'Profile',
                    ),
                  ],
                ),
              ),
            );
          },
        );
  }
}
