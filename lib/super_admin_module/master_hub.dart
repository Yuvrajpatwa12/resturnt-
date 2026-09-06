import 'package:flutter/material.dart';
import 'styles.dart';
import 'screens/overview_screen.dart';
import 'screens/client_management_screen.dart';
import 'screens/subscription_billing_screen.dart';
import 'screens/resource_monitoring_screen.dart';
import 'screens/global_catalog_screen.dart';
import 'screens/support_communication_screen.dart';
import 'screens/system_config_screen.dart';
import 'screens/auth_security_screens.dart';

class SuperAdminMasterHub extends StatefulWidget {
  const SuperAdminMasterHub({super.key});

  @override
  State<SuperAdminMasterHub> createState() => _SuperAdminMasterHubState();
}

class _SuperAdminMasterHubState extends State<SuperAdminMasterHub> {
  int _selectedIndex = 0;
  bool _isSidebarCollapsed = false;

  final List<Map<String, dynamic>> _menuItems = [
    {'title': 'Command Center', 'icon': Icons.dashboard_rounded, 'screen': const OverviewScreen()},
    {'title': 'Client Directory', 'icon': Icons.business_center_rounded, 'screen': const ClientManagementScreen()},
    {'title': 'SaaS Subscriptions', 'icon': Icons.credit_card_rounded, 'screen': const SubscriptionBillingScreen()},
    {'title': 'Node Resources', 'icon': Icons.analytics_rounded, 'screen': const ResourceMonitoringScreen()},
    {'title': 'Global Catalog', 'icon': Icons.library_books_rounded, 'screen': const GlobalCatalogScreen()},
    {'title': 'Support & CRM', 'icon': Icons.forum_rounded, 'screen': const SupportCommunicationScreen()},
    {'title': 'Platform Config', 'icon': Icons.settings_suggest_rounded, 'screen': const SystemConfigScreen()},
    {'title': 'Security Audit', 'icon': Icons.shield_rounded, 'screen': const AuthSecurityScreens(mode: 'Audit')},
  ];

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: SAMStyles.theme,
      child: Scaffold(
        body: Row(
          children: [
            _buildSidebar(),
            Expanded(
              child: Column(
                children: [
                  _buildTopBar(),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Container(
                        key: ValueKey(_selectedIndex),
                        child: _menuItems[_selectedIndex]['screen'] as Widget,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: _isSidebarCollapsed ? 80 : 280,
      decoration: BoxDecoration(
        color: const Color(0xFF002D62), // High-end SaaS Navy
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 30)],
      ),
      child: Column(
        children: [
          _buildSidebarHeader(),
          const SizedBox(height: 40),
          Expanded(
            child: ListView.builder(
              itemCount: _menuItems.length,
              itemBuilder: (context, index) {
                final item = _menuItems[index];
                bool isSelected = _selectedIndex == index;
                return _buildSidebarItem(index, item['icon'], item['title'], isSelected);
              },
            ),
          ),
          _buildSidebarFooter(),
        ],
      ),
    );
  }

  Widget _buildSidebarHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Row(
        mainAxisAlignment: _isSidebarCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFFFF5C00), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.hub_rounded, color: Colors.white, size: 24),
          ),
          if (!_isSidebarCollapsed) ...[
            const SizedBox(width: 16),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("CHIYALAA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.5)),
                Text("ROOT ADMIN HUB", style: TextStyle(color: Colors.white30, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSidebarItem(int index, IconData icon, String title, bool isSelected) {
    return InkWell(
      onTap: () => setState(() => _selectedIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: _isSidebarCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            const SizedBox(width: 16),
            Icon(icon, color: isSelected ? const Color(0xFFFF5C00) : Colors.white54, size: 20),
            if (!_isSidebarCollapsed) ...[
              const SizedBox(width: 16),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white54,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarFooter() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: IconButton(
        onPressed: () => setState(() => _isSidebarCollapsed = !_isSidebarCollapsed),
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(border: Border.all(color: Colors.white10), shape: BoxShape.circle),
          child: Icon(_isSidebarCollapsed ? Icons.chevron_right : Icons.chevron_left, color: Colors.white30, size: 18),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.08))),
      ),
      child: Row(
        children: [
          IconButton(onPressed: () => Navigator.pushReplacementNamed(context, '/customer'), icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20)),
          const SizedBox(width: 16),
          Text(
            _menuItems[_selectedIndex]['title'],
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF002D62)),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.blue.withValues(alpha: 0.1))),
            child: const Row(
              children: [
                CircleAvatar(radius: 3, backgroundColor: Colors.blue),
                SizedBox(width: 8),
                Text("NETWORK: SECURE (VPN)", style: TextStyle(color: Colors.blue, fontSize: 9, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          const SizedBox(width: 24),
          const Icon(Icons.notifications_none_rounded, color: Color(0xFF64748B), size: 22),
          const SizedBox(width: 24),
          const CircleAvatar(
            backgroundColor: Color(0xFF0047AB), 
            radius: 18, 
            child: Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 20)
          ),
        ],
      ),
    );
  }
}
