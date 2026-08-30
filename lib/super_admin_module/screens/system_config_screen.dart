import 'package:flutter/material.dart';
import '../styles.dart';

class SystemConfigScreen extends StatelessWidget {
  const SystemConfigScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Global Configuration", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 32),
          _buildSettingsGroup("Default Financials", [
            _buildSettingTile("Global VAT (%)", "13.0"),
            _buildSettingTile("Global Service Charge (%)", "10.0"),
            _buildSettingTile("Platform Commission (%)", "2.5"),
          ]),
          const SizedBox(height: 32),
          _buildSettingsGroup("Infrastructure & API", [
            _buildSettingTile("Firebase Project ID", "chiyalaa-pos-v2"),
            _buildSettingTile("Kitchen APK Version", "v1.4.2"),
            _buildSettingTile("Backup Interval", "Daily (00:00)"),
          ]),
          const SizedBox(height: 48),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildSettingsGroup(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(), style: const TextStyle(color: SAMStyles.textGrey, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: SAMStyles.softShadow),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSettingTile(String label, String val) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      trailing: SizedBox(
        width: 150,
        child: TextField(
          textAlign: TextAlign.right,
          decoration: InputDecoration(
            hintText: val,
            border: InputBorder.none,
          ),
          style: const TextStyle(color: SAMStyles.royalBlue, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.cloud_download_outlined), label: const Text("EXPORT GLOBAL BACKUP")),
        const SizedBox(width: 16),
        OutlinedButton(onPressed: () {}, child: const Text("SAVE GLOBAL SETTINGS")),
      ],
    );
  }
}
