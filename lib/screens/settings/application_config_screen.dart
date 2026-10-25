import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class ApplicationConfigScreen extends StatefulWidget {
  const ApplicationConfigScreen({super.key});

  @override
  State<ApplicationConfigScreen> createState() => _ApplicationConfigScreenState();
}

class _ApplicationConfigScreenState extends State<ApplicationConfigScreen> {
  bool _pushNotifications = true;
  bool _autoUpdate = true;
  bool _dataSaver = false;
  bool _soundHaptics = true;
  bool _analyticsOptIn = true;
  double _cacheSizeMb = 14.8;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        title: const Text("Application Configuration"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        children: [
          // Section 1: System Toggles
          _buildSectionHeader("SYSTEM PREFERENCES & TOGGLES"),

          _buildSwitchTile(
            icon: Icons.notifications_active_rounded,
            iconBgColor: const Color(0xFFEFF6FF),
            iconColor: const Color(0xFF2563EB),
            title: "Push Notifications",
            subtitle: "Receive real-time order & kitchen status alerts",
            value: _pushNotifications,
            onChanged: (val) => setState(() => _pushNotifications = val),
          ),
          const SizedBox(height: 10),

          _buildSwitchTile(
            icon: Icons.system_update_rounded,
            iconBgColor: const Color(0xFFF0FDF4),
            iconColor: const Color(0xFF16A34A),
            title: "Auto Update App",
            subtitle: "Automatically download latest feature patches",
            value: _autoUpdate,
            onChanged: (val) => setState(() => _autoUpdate = val),
          ),
          const SizedBox(height: 10),

          _buildSwitchTile(
            icon: Icons.data_saver_on_rounded,
            iconBgColor: const Color(0xFFFFF7ED),
            iconColor: const Color(0xFFEA580C),
            title: "Data Saver Mode",
            subtitle: "Reduce background data usage and image quality",
            value: _dataSaver,
            onChanged: (val) => setState(() => _dataSaver = val),
          ),
          const SizedBox(height: 10),

          _buildSwitchTile(
            icon: Icons.vibration_rounded,
            iconBgColor: const Color(0xFFFAF5FF),
            iconColor: const Color(0xFF9333EA),
            title: "Sound & Haptics",
            subtitle: "Enable audio tones and tactile feedback on tap",
            value: _soundHaptics,
            onChanged: (val) => setState(() => _soundHaptics = val),
          ),
          const SizedBox(height: 10),

          _buildSwitchTile(
            icon: Icons.analytics_outlined,
            iconBgColor: const Color(0xFFF5F3FF),
            iconColor: AppTheme.primaryPurple,
            title: "Crash Reporting & Analytics",
            subtitle: "Send anonymous diagnostics to help improve stability",
            value: _analyticsOptIn,
            onChanged: (val) => setState(() => _analyticsOptIn = val),
          ),

          const SizedBox(height: 24),

          // Section 2: Cache & Storage Management
          _buildSectionHeader("CACHE & STORAGE MANAGEMENT"),

          Container(
            decoration: AppTheme.cardDecoration(),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryPurpleLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.cleaning_services_rounded,
                        color: AppTheme.primaryPurple,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Temporary Cache Size",
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Images, localized translation files & temporary assets",
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      "${_cacheSizeMb.toStringAsFixed(1)} MB",
                      style: const TextStyle(
                        color: AppTheme.primaryPurple,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: AppTheme.primaryPurple),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _cacheSizeMb == 0
                        ? null
                        : () {
                            setState(() => _cacheSizeMb = 0.0);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text("Temporary application cache cleared successfully!"),
                                backgroundColor: AppTheme.primaryPurple,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          },
                    icon: const Icon(Icons.delete_sweep_rounded, color: AppTheme.primaryPurple, size: 20),
                    label: Text(
                      _cacheSizeMb == 0 ? "Cache Cleared" : "Clear Application Cache",
                      style: const TextStyle(
                        color: AppTheme.primaryPurple,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Section 3: App Version Info
          _buildSectionHeader("APPLICATION INFORMATION"),

          Container(
            decoration: AppTheme.cardDecoration(),
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.scaffoldBackground,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.info_outline_rounded,
                    color: AppTheme.textPrimary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "ChiyaBreak Enterprise POS",
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        "Version 3.2.0 (Build 108) • Channel: Stable",
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.successLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    "LATEST",
                    style: TextStyle(
                      color: AppTheme.success,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 10.0),
      child: Text(
        title,
        style: const TextStyle(
          color: AppTheme.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      decoration: AppTheme.cardDecoration(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              activeColor: AppTheme.primaryPurple,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}
