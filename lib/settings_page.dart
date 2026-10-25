import 'package:flutter/material.dart';
import 'cart_manager.dart';
import 'services/tenant_service.dart';
import 'services/api_service.dart';
import 'package:geolocator/geolocator.dart';
import 'account_settings_page.dart';
import 'staff/staff_hub.dart';
import 'super_admin_module/master_hub.dart';

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
            _buildSectionHeader("Email notifications"),
            const _EmailNotificationSettings(),

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
        onPressed: () async {
          await ShopManager.instance.logoutCustomer();
          if (!mounted) return;
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

class _EmailNotificationSettings extends StatefulWidget {
  const _EmailNotificationSettings();

  @override
  State<_EmailNotificationSettings> createState() =>
      _EmailNotificationSettingsState();
}

class _EmailNotificationSettingsState extends State<_EmailNotificationSettings> {
  bool _loading = true;
  bool _saving = false;
  final Map<String, bool> _preferences = {
    'email_enabled': false,
    'email_follow': true,
    'email_wave': true,
    'email_message': true,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tenant = TenantService().currentTenant.value;
    final manager = ShopManager.instance;
    if (tenant == null ||
        !manager.isEmailSynced.value ||
        manager.customerSessionToken.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final saved = await ApiService.fetchEmailNotificationPreferences(
      tenantId: tenant.id,
      sessionToken: manager.customerSessionToken,
    );
    if (!mounted) return;
    if (saved != null) {
      for (final key in _preferences.keys) {
        _preferences[key] =
            saved[key] == true || saved[key]?.toString() == '1';
      }
    }
    setState(() => _loading = false);
  }

  Future<void> _update(String key, bool value) async {
    final tenant = TenantService().currentTenant.value;
    final manager = ShopManager.instance;
    if (tenant == null || manager.customerSessionToken.isEmpty || _saving) {
      return;
    }
    final previous = Map<String, bool>.from(_preferences);
    setState(() {
      _preferences[key] = value;
      _saving = true;
    });
    final saved = await ApiService.saveEmailNotificationPreferences(
      tenantId: tenant.id,
      sessionToken: manager.customerSessionToken,
      preferences: _preferences,
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (!saved) {
        _preferences
          ..clear()
          ..addAll(previous);
      }
    });
    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save email alert settings.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final manager = ShopManager.instance;
    if (!manager.isEmailSynced.value ||
        manager.customerSessionToken.isEmpty) {
      return _settingsCard(
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Sign in with your email and PIN to manage email notifications.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),
      );
    }
    if (_loading) {
      return _settingsCard(
        const Padding(
          padding: EdgeInsets.all(20),
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }
    return _settingsCard(
      Column(
        children: [
          _emailSwitch(
            icon: Icons.alternate_email_rounded,
            title: 'Email me about app alerts',
            subtitle: 'Message emails send after 1 minute if not read or answered.',
            keyName: 'email_enabled',
          ),
          if (_preferences['email_enabled'] == true) ...[
            const Divider(height: 1, indent: 56),
            _emailSwitch(
              icon: Icons.person_add_alt_1_rounded,
              title: 'Follows and follow-backs',
              keyName: 'email_follow',
            ),
            _emailSwitch(
              icon: Icons.waving_hand_outlined,
              title: 'Waves',
              keyName: 'email_wave',
            ),
            _emailSwitch(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'New messages',
              subtitle: 'Email will not include private message text.',
              keyName: 'email_message',
            ),
          ],
        ],
      ),
    );
  }

  Widget _emailSwitch({
    required IconData icon,
    required String title,
    required String keyName,
    String? subtitle,
  }) {
    return SwitchListTile(
      value: _preferences[keyName] ?? false,
      onChanged: _saving ? null : (value) => _update(keyName, value),
      secondary: Icon(icon, color: const Color(0xFFFF5C00), size: 20),
      title: Text(title, style: const TextStyle(fontSize: 13)),
      subtitle: subtitle == null
          ? null
          : Text(subtitle, style: const TextStyle(fontSize: 11)),
      activeThumbColor: const Color(0xFFFF5C00),
    );
  }

  Widget _settingsCard(Widget child) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
