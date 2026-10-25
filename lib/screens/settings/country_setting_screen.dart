import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/tenant_service.dart';
import '../../services/api_service.dart';

class CountrySettingScreen extends StatefulWidget {
  const CountrySettingScreen({super.key});

  @override
  State<CountrySettingScreen> createState() => _CountrySettingScreenState();
}

class _CountrySettingScreenState extends State<CountrySettingScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  late String _selectedCountryCode;

  // Strictly 2 supported countries: Nepal & India
  final List<Map<String, String>> _countries = [
    {'code': 'NP', 'name': 'Nepal', 'flag': '🇳🇵', 'region': 'South Asia', 'dialCode': '+977', 'isDefault': 'true'},
    {'code': 'IN', 'name': 'India', 'flag': '🇮🇳', 'region': 'South Asia', 'dialCode': '+91', 'isDefault': 'false'},
  ];

  @override
  void initState() {
    super.initState();
    final currentCountry = TenantService().currentTenant.value?.country ?? 'Nepal';
    if (currentCountry.toLowerCase() == 'india') {
      _selectedCountryCode = 'IN';
    } else {
      _selectedCountryCode = 'NP';
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredCountries = _countries.where((c) {
      final name = c['name']!.toLowerCase();
      final code = c['code']!.toLowerCase();
      final region = c['region']!.toLowerCase();
      final q = _searchQuery.toLowerCase();
      return name.contains(q) || code.contains(q) || region.contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        title: const Text("Country Settings"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
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
                      Icons.public_rounded,
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
                          "Super Admin Location Sync",
                          style: TextStyle(
                            color: AppTheme.primaryPurple,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          "Selecting a country saves your location setup to the backend database.",
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

            // Search Input
            Container(
              decoration: AppTheme.cardDecoration(),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: "Search Nepal or India...",
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
                "SELECT PRIMARY COUNTRY (2 AVAILABLE)",
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            ),

            // Country List
            Expanded(
              child: filteredCountries.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      itemCount: filteredCountries.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final c = filteredCountries[index];
                        final isSelected = c['code'] == _selectedCountryCode;
                        final isDefault = c['isDefault'] == 'true';

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
                              onTap: () async {
                                setState(() {
                                  _selectedCountryCode = c['code']!;
                                });
                                final messenger = ScaffoldMessenger.of(context);
                                final tenantId = TenantService().currentTenant.value?.id;
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      "Country set to ${c['name']} ${c['flag']} (Synced with Database)",
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
                                if (tenantId != null && tenantId.isNotEmpty) {
                                  await ApiService.updateTenantLocation(tenantId, country: c['name']);
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      c['flag']!,
                                      style: const TextStyle(fontSize: 28),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                c['name']!,
                                                style: TextStyle(
                                                  color: isSelected
                                                      ? AppTheme.primaryPurple
                                                      : AppTheme.textPrimary,
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              if (isDefault) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.primaryPurpleLight,
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: const Text(
                                                    "DEFAULT",
                                                    style: TextStyle(
                                                      color: AppTheme.primaryPurple,
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      letterSpacing: 0.5,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            "${c['region']} • ${c['dialCode']}",
                                            style: const TextStyle(
                                              color: AppTheme.textSecondary,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isSelected
                                            ? AppTheme.primaryPurple
                                            : Colors.transparent,
                                        border: Border.all(
                                          color: isSelected
                                              ? AppTheme.primaryPurple
                                              : AppTheme.textMuted,
                                          width: 2,
                                        ),
                                      ),
                                      child: isSelected
                                          ? const Icon(
                                              Icons.check_rounded,
                                              size: 16,
                                              color: Colors.white,
                                            )
                                          : null,
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
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.flag_outlined, size: 48, color: AppTheme.textMuted),
          const SizedBox(height: 12),
          const Text(
            "No country found",
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "Search for Nepal or India",
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
