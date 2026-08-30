import 'package:flutter/material.dart';
import '../admin_theme.dart';

class AdminSettingsScreen extends StatefulWidget {
  final String section;
  const AdminSettingsScreen({super.key, required this.section});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  bool _autoPrint = true;
  bool _soundEnabled = true;
  double _volume = 0.8;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSettingsGroup("General Configuration", [
            _buildToggleTile("Automatic KOT Print", "Print tickets instantly when order is received", _autoPrint, (v) => setState(() => _autoPrint = v)),
            _buildToggleTile("Enable Sound Alerts", "Play sound for new incoming orders", _soundEnabled, (v) => setState(() => _soundEnabled = v)),
          ]),
          const SizedBox(height: 24),
          _buildSettingsGroup("Audio Levels", [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Notification Volume", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Slider(
                    value: _volume,
                    onChanged: (v) => setState(() => _volume = v),
                    activeColor: AdminTheme.royalBlue,
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 24),
          _buildSettingsGroup("Terminal Info", [
            _buildInfoTile("Terminal ID", "POS-TERM-0982"),
            _buildInfoTile("Connection", "Connected (Stable)"),
            _buildInfoTile("App Version", "v2.4.1 (Stable Build)"),
          ]),
          const SizedBox(height: 40),
          Center(
            child: TextButton(
              onPressed: () {},
              child: const Text("RESTORE DEFAULT SETTINGS", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsGroup(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(), style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AdminTheme.softShadow,
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildToggleTile(String title, String sub, bool value, Function(bool) onChanged) {
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      activeTrackColor: AdminTheme.emeraldGreen,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Text(sub, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    );
  }

  Widget _buildInfoTile(String title, String value) {
    return ListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      trailing: Text(value, style: const TextStyle(color: AdminTheme.royalBlue, fontWeight: FontWeight.bold, fontSize: 13)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
    );
  }
}
