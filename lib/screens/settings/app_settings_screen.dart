import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'currency_setting_screen.dart';
import 'country_setting_screen.dart';
import 'state_setting_screen.dart';
import 'application_config_screen.dart';
import 'factory_reset_screen.dart';

class AppSettingsScreen extends StatelessWidget {
  const AppSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bool canPop = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Top App Bar / Header with Purple Gradient
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.all(16.0),
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  gradient: AppTheme.purpleGradient,
                  borderRadius: BorderRadius.circular(24.0),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryPurple.withOpacity(0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (canPop) ...[
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.tune_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "App Settings",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                "Manage preferences, locations & system config",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Settings Categories List
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Section 1: General Preferences
                  _buildSectionHeader("GENERAL PREFERENCES"),
                  _buildSettingCard(
                    context: context,
                    icon: Icons.payments_outlined,
                    iconBgColor: const Color(0xFFF0FDF4),
                    iconColor: const Color(0xFF16A34A),
                    title: "Currency Settings",
                    subtitle: "Choose default transaction currency and symbol format",
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CurrencySettingScreen()),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Section 2: Regional & Location
                  _buildSectionHeader("REGIONAL & LOCATION"),
                  _buildSettingCard(
                    context: context,
                    icon: Icons.public_rounded,
                    iconBgColor: const Color(0xFFFFF7ED),
                    iconColor: const Color(0xFFEA580C),
                    title: "Country Settings",
                    subtitle: "Select default country and regional standards",
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CountrySettingScreen()),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildSettingCard(
                    context: context,
                    icon: Icons.map_rounded,
                    iconBgColor: const Color(0xFFFAF5FF),
                    iconColor: const Color(0xFF9333EA),
                    title: "State / Region Settings",
                    subtitle: "Manage provinces, states and tax jurisdictions",
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const StateSettingScreen()),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Section 3: System & Maintenance
                  _buildSectionHeader("SYSTEM & MAINTENANCE"),
                  _buildSettingCard(
                    context: context,
                    icon: Icons.settings_suggest_rounded,
                    iconBgColor: const Color(0xFFF5F3FF),
                    iconColor: AppTheme.primaryPurple,
                    title: "Application Configuration",
                    subtitle: "Push notifications, updates, cache & storage limits",
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ApplicationConfigScreen()),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildSettingCard(
                    context: context,
                    icon: Icons.restart_alt_rounded,
                    iconBgColor: AppTheme.dangerSubtle,
                    iconColor: AppTheme.danger,
                    title: "Factory Reset",
                    subtitle: "Reset preferences, clear local storage & restore defaults",
                    isWarning: true,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const FactoryResetScreen()),
                    ),
                  ),

                  const SizedBox(height: 32),
                ]),
              ),
            ),
          ],
        ),
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

  Widget _buildSettingCard({
    required BuildContext context,
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isWarning = false,
  }) {
    return Container(
      decoration: AppTheme.cardDecoration(
        borderColor: isWarning ? AppTheme.danger.withOpacity(0.2) : AppTheme.cardBorder,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: iconColor.withOpacity(0.08),
          highlightColor: iconColor.withOpacity(0.04),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: isWarning ? AppTheme.danger : AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
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
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.scaffoldBackground,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: isWarning ? AppTheme.danger : AppTheme.textMuted,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
