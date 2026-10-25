import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class FactoryResetScreen extends StatefulWidget {
  const FactoryResetScreen({super.key});

  @override
  State<FactoryResetScreen> createState() => _FactoryResetScreenState();
}

class _FactoryResetScreenState extends State<FactoryResetScreen> {
  bool _understandWarning = false;
  bool _isResetting = false;

  final List<Map<String, String>> _resetDataItems = [
    {
      'title': 'Local Storage & Preferences',
      'subtitle': 'All customized app settings, language preferences, and dark/light mode toggles.',
      'icon': 'storage',
    },
    {
      'title': 'Cached Images & Translation Packs',
      'subtitle': 'Offline cached menu images, asset previews, and downloaded language files.',
      'icon': 'cached',
    },
    {
      'title': 'Authentication & Session Tokens',
      'subtitle': 'Active login credentials, tenant session tokens, and saved user profiles.',
      'icon': 'lock_reset',
    },
    {
      'title': 'Offline Order Buffers',
      'subtitle': 'Locally queued unsynced transaction logs and temporary cart state.',
      'icon': 'receipt_long',
    },
  ];

  void _showConfirmationModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: AppTheme.cardBackground,
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppTheme.danger, size: 28),
              SizedBox(width: 10),
              Text(
                "Confirm Factory Reset",
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: const Text(
            "Are you absolutely sure you want to perform a factory reset? All local configuration, cached assets, and saved tokens will be permanently erased.",
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.4),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                "Cancel",
                style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.danger,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                setState(() => _isResetting = true);

                await Future.delayed(const Duration(seconds: 2));

                if (!mounted) return;
                setState(() => _isResetting = false);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text("Factory Reset Completed. All settings restored to defaults."),
                    backgroundColor: AppTheme.success,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );

                Navigator.pop(context);
              },
              icon: const Icon(Icons.restart_alt_rounded, size: 18),
              label: const Text("Yes, Reset Everything"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        title: const Text("Factory Reset"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        children: [
          // Danger Warning Banner Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.dangerSubtle,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.danger.withOpacity(0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.dangerLight,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.report_problem_rounded,
                    color: AppTheme.danger,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Irreversible System Action",
                        style: TextStyle(
                          color: AppTheme.danger,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Performing a factory reset will erase all local configurations, preferences, and cached session details. This process cannot be undone.",
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          const Padding(
            padding: EdgeInsets.only(left: 4.0, bottom: 10.0),
            child: Text(
              "DATA THAT WILL BE RESTORED TO DEFAULTS",
              style: TextStyle(
                color: AppTheme.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
          ),

          // Items List
          ..._resetDataItems.map((item) {
            IconData iconData = Icons.storage_rounded;
            if (item['icon'] == 'cached') iconData = Icons.cached_rounded;
            if (item['icon'] == 'lock_reset') iconData = Icons.lock_reset_rounded;
            if (item['icon'] == 'receipt_long') iconData = Icons.receipt_long_rounded;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: AppTheme.cardDecoration(),
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.dangerSubtle,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(iconData, color: AppTheme.danger, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['title']!,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item['subtitle']!,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 20),

          // Checkbox Acknowledgement
          Container(
            decoration: AppTheme.cardDecoration(
              borderColor: _understandWarning ? AppTheme.danger : AppTheme.cardBorder,
              backgroundColor: _understandWarning ? AppTheme.dangerSubtle.withOpacity(0.5) : AppTheme.cardBackground,
            ),
            child: CheckboxListTile(
              activeColor: AppTheme.danger,
              value: _understandWarning,
              onChanged: (val) => setState(() => _understandWarning = val ?? false),
              title: const Text(
                "I understand that this action is permanent and cannot be undone.",
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            ),
          ),

          const SizedBox(height: 24),

          // Action Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _understandWarning ? AppTheme.danger : AppTheme.cardBorder,
                foregroundColor: Colors.white,
                elevation: _understandWarning ? 2 : 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: (_understandWarning && !_isResetting) ? _showConfirmationModal : null,
              icon: _isResetting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.restart_alt_rounded, size: 22),
              label: Text(
                _isResetting ? "Resetting Application..." : "Reset All App Settings",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
