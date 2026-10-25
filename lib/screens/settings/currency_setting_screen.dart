import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/currency_service.dart';
import '../../services/tenant_service.dart';

class CurrencySettingScreen extends StatefulWidget {
  const CurrencySettingScreen({super.key});

  @override
  State<CurrencySettingScreen> createState() => _CurrencySettingScreenState();
}

class _CurrencySettingScreenState extends State<CurrencySettingScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredCurrencies = CurrencyService.availableCurrencies.where((curr) {
      final code = curr['code']!.toLowerCase();
      final name = curr['name']!.toLowerCase();
      final country = curr['country']!.toLowerCase();
      final q = _searchQuery.toLowerCase();
      return code.contains(q) || name.contains(q) || country.contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        title: const Text("Currency Settings"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ValueListenableBuilder<String>(
        valueListenable: CurrencyService().currentCurrencyCode,
        builder: (context, activeCode, child) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryPurpleSubtle,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.primaryPurple.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryPurpleLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.payments_rounded,
                          color: AppTheme.primaryPurple,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Real-Time App Currency Sync",
                              style: TextStyle(
                                color: AppTheme.primaryPurple,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              "Selecting a currency updates price symbols across Admin & User apps.",
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Search Input Card
                Container(
                  decoration: AppTheme.cardDecoration(),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: "Search NPR, INR, or USD...",
                      prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primaryPurple),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 20),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = "");
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      fillColor: Colors.transparent,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                const Padding(
                  padding: EdgeInsets.only(left: 4.0, bottom: 8.0),
                  child: Text(
                    "SUPPORTED CURRENCIES (3 AVAILABLE)",
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),

                // Currency List
                Expanded(
                  child: filteredCurrencies.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          itemCount: filteredCurrencies.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final curr = filteredCurrencies[index];
                            final isSelected = curr['code'] == activeCode;

                            return Container(
                              decoration: AppTheme.cardDecoration(
                                borderColor: isSelected
                                    ? AppTheme.primaryPurple
                                    : AppTheme.cardBorder,
                                backgroundColor: isSelected
                                    ? AppTheme.primaryPurpleSubtle
                                    : AppTheme.cardBackground,
                              ),
                              child: Material(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () {
                                    final messenger = ScaffoldMessenger.of(context);
                                    final tenantId = TenantService().currentTenant.value?.id;
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          "Active Currency set to ${curr['code']} (${curr['symbol']})",
                                          style: const TextStyle(fontWeight: FontWeight.w500),
                                        ),
                                        backgroundColor: AppTheme.primaryPurple,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                    CurrencyService().setCurrency(
                                      curr['code']!,
                                      curr['symbol']!,
                                      tenantId: tenantId,
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                    child: Row(
                                      children: [
                                        // Symbol Badge
                                        Container(
                                          width: 46,
                                          height: 46,
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? AppTheme.primaryPurple
                                                : AppTheme.primaryPurpleLight,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Center(
                                            child: Text(
                                              curr['symbol']!,
                                              style: TextStyle(
                                                color: isSelected
                                                    ? Colors.white
                                                    : AppTheme.primaryPurple,
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    curr['code']!,
                                                    style: TextStyle(
                                                      color: isSelected
                                                          ? AppTheme.primaryPurple
                                                          : AppTheme.textPrimary,
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    curr['flag']!,
                                                    style: const TextStyle(fontSize: 16),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                "${curr['name']} • ${curr['country']}",
                                                style: const TextStyle(
                                                  color: AppTheme.textSecondary,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Radio<String>(
                                          value: curr['code']!,
                                          groupValue: activeCode,
                                          activeColor: AppTheme.primaryPurple,
                                          onChanged: (val) {
                                            if (val != null) {
                                              final tenantId = TenantService().currentTenant.value?.id;
                                              CurrencyService().setCurrency(
                                                val,
                                                curr['symbol']!,
                                                tenantId: tenantId,
                                              );
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 48, color: AppTheme.textMuted),
          const SizedBox(height: 12),
          const Text(
            "No currency found",
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "Search for NPR, INR, or USD",
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
