import 'package:flutter/material.dart';
import 'cart_manager.dart';
import 'services/tenant_service.dart';
import 'package:geolocator/geolocator.dart';
import 'account_settings_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Settings & Support",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader("Settings Hub"),
            _buildSettingsGroup([
              _buildSettingRow(
                icon: Icons.account_circle_outlined,
                title: "Account",
                onTap: () {
                  Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (context) => const AccountSettingsPage())
                  );
                },
              ),
            ]),
            
            const SizedBox(height: 32),
            _buildSectionHeader("Privacy Controls"),
            _buildSettingsGroup([
              _buildToggleRow(
                icon: Icons.visibility_outlined,
                title: "Public Profile",
                sub: "Visible to others on map",
                notifier: ShopManager.instance.isProfileVisible,
              ),
              _buildToggleRow(
                icon: Icons.back_hand_outlined,
                title: "Allow Waves",
                sub: "People can greet you",
                notifier: ShopManager.instance.isWaveEnabled,
              ),
              _buildToggleRow(
                icon: Icons.grid_view_rounded,
                title: "Show Table Number",
                sub: "Share where you sit",
                notifier: ShopManager.instance.showTableNumber,
              ),
            ]),

            const SizedBox(height: 32),
            _buildSectionHeader("Interactions"),
            _buildSettingsGroup([
              _buildToggleRow(
                icon: Icons.chat_bubble_outline_rounded,
                title: "Only Mutual Chat",
                sub: "Friends only messaging",
                notifier: ShopManager.instance.onlyMutualChat,
              ),
              _buildToggleRow(
                icon: Icons.vibration_rounded,
                title: "Social Vibration",
                sub: "Haptic feedback on waves",
                notifier: ShopManager.instance.socialVibration,
              ),
            ]),

            const SizedBox(height: 32),
            _buildSectionHeader("System Permissions"),
            _buildSettingsGroup([
              _buildActionRow(
                icon: Icons.location_on_outlined,
                title: "Location Access",
                onTap: _requestLocation,
              ),
              _buildActionRow(
                icon: Icons.notifications_none_rounded,
                title: "Notifications",
                onTap: () => ShopManager.instance.setupPushNotifications(),
              ),
            ]),

            const SizedBox(height: 32),
            _buildSectionHeader("Account Management"),
            _buildSettingsGroup([
              _buildSettingRow(
                icon: Icons.sync_rounded,
                title: "Sync Google Profile",
                onTap: () {},
              ),
              _buildSettingRow(
                icon: Icons.delete_outline_rounded,
                title: "Delete Account",
                titleColor: Colors.redAccent,
                onTap: () {},
              ),
            ]),

            const SizedBox(height: 40),
            _buildLogoutButton(),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12),
      child: Text(
        title,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildSettingsGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingRow({required IconData icon, required String title, required VoidCallback onTap, Color? titleColor}) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: titleColor ?? Colors.black87, size: 20),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: titleColor)),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
    );
  }

  Widget _buildToggleRow({required IconData icon, required String title, required String sub, required ValueNotifier<bool> notifier}) {
    return ValueListenableBuilder<bool>(
      valueListenable: notifier,
      builder: (context, val, _) => ListTile(
        leading: Icon(icon, color: val ? const Color(0xFFFF5C00) : Colors.grey, size: 20),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(sub, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        trailing: Switch(
          value: val,
          onChanged: (v) => notifier.value = v,
          activeThumbColor: const Color(0xFFFF5C00),
          activeTrackColor: const Color(0xFFFF5C00).withValues(alpha: 0.3),
        ),
      ),
    );
  }

  Widget _buildActionRow({required IconData icon, required String title, required VoidCallback onTap}) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: Colors.black87, size: 20),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: const Color(0xFFFF5C00).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
        child: const Text("ALLOW", style: TextStyle(color: Color(0xFFFF5C00), fontSize: 10, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        onPressed: () {
          TenantService().logout();
          Navigator.pop(context);
        },
        icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 18),
        label: const Text("LOGOUT ACCOUNT", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.redAccent, width: 1)),
        ),
      ),
    );
  }

  Future<void> _requestLocation() async {
    LocationPermission permission = await Geolocator.requestPermission();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Location permission: ${permission.name}")),
      );
    }
  }
}
