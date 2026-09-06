import 'package:flutter/material.dart';
import '../super_admin_module/master_hub.dart';
import 'staff_gateway.dart';
import 'tenant_service.dart';

class DevLauncherScreen extends StatelessWidget {
  const DevLauncherScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 60),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Icon(Icons.developer_mode_rounded, size: 40, color: Color(0xFF002D62)),
                    IconButton(
                      onPressed: () {
                        TenantService().logout();
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Session cleared. You can now login as a different role.")));
                      },
                      icon: const Icon(Icons.logout_rounded, color: Colors.red),
                      tooltip: "Logout & Clear Session",
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  "SaaS Development Portal",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF002D62)),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Access all modules for testing and development.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 48),
                
                _buildLargeButton(
                  context,
                  title: "Super Admin (Master Hub)",
                  subtitle: "Platform-level management & infrastructure.",
                  icon: Icons.hub_rounded,
                  color: const Color(0xFF002D62),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SuperAdminMasterHub())),
                ),
                
                const SizedBox(height: 20),
                
                _buildLargeButton(
                  context,
                  title: "Restaurant Admin",
                  subtitle: "Manage catalog, staff, and branding.",
                  icon: Icons.admin_panel_settings_rounded,
                  color: const Color(0xFFFF5C00),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const StaffGateway())),
                ),
                
                const SizedBox(height: 20),

                _buildLargeButton(
                  context,
                  title: "Waiter App",
                  subtitle: "Table management and digital ordering.",
                  icon: Icons.person_pin_circle_rounded,
                  color: const Color(0xFF00C49F),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const StaffGateway())),
                ),

                const SizedBox(height: 20),

                _buildLargeButton(
                  context,
                  title: "Kitchen Display (KDS)",
                  subtitle: "Live order prep and ticket tracking.",
                  icon: Icons.restaurant_menu_rounded,
                  color: Colors.redAccent,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const StaffGateway())),
                ),

                const SizedBox(height: 20),

                _buildLargeButton(
                  context,
                  title: "Customer Experience App",
                  subtitle: "Scan QR, browse menu, and place orders.",
                  icon: Icons.shopping_bag_rounded,
                  color: Colors.blueAccent,
                  onTap: () => Navigator.pushNamed(context, '/customer'),
                ),
                
                const SizedBox(height: 40),
                const Divider(),
                const SizedBox(height: 20),
                const Text(
                  "Startups Go Hub © 2026",
                  style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLargeButton(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withValues(alpha: 0.1), width: 2),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 10)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: color, size: 16),
          ],
        ),
      ),
    );
  }
}
