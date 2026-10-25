import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/tenant_service.dart';
import '../../services/api_service.dart';

class StateSettingScreen extends StatefulWidget {
  const StateSettingScreen({super.key});

  @override
  State<StateSettingScreen> createState() => _StateSettingScreenState();
}

class _StateSettingScreenState extends State<StateSettingScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  late String _selectedCountry;
  late String _selectedState;

  // Strictly Nepal & India state/province data
  final Map<String, List<Map<String, String>>> _stateData = {
    'Nepal': [
      {'name': 'Bagmati Province', 'code': 'P3', 'capital': 'Hetauda', 'type': 'Province'},
      {'name': 'Gandaki Province', 'code': 'P4', 'capital': 'Pokhara', 'type': 'Province'},
      {'name': 'Koshi Province', 'code': 'P1', 'capital': 'Biratnagar', 'type': 'Province'},
      {'name': 'Lumbini Province', 'code': 'P5', 'capital': 'Deukhuri', 'type': 'Province'},
      {'name': 'Madhesh Province', 'code': 'P2', 'capital': 'Janakpur', 'type': 'Province'},
      {'name': 'Karnali Province', 'code': 'P6', 'capital': 'Birendranagar', 'type': 'Province'},
      {'name': 'Sudurpashchim Province', 'code': 'P7', 'capital': 'Godawari', 'type': 'Province'},
    ],
    'India': [
      {'name': 'Delhi (NCT)', 'code': 'DL', 'capital': 'New Delhi', 'type': 'Union Territory'},
      {'name': 'Maharashtra', 'code': 'MH', 'capital': 'Mumbai', 'type': 'State'},
      {'name': 'Karnataka', 'code': 'KA', 'capital': 'Bengaluru', 'type': 'State'},
      {'name': 'Tamil Nadu', 'code': 'TN', 'capital': 'Chennai', 'type': 'State'},
      {'name': 'Uttar Pradesh', 'code': 'UP', 'capital': 'Lucknow', 'type': 'State'},
      {'name': 'West Bengal', 'code': 'WB', 'capital': 'Kolkata', 'type': 'State'},
    ],
  };

  @override
  void initState() {
    super.initState();
    final tenant = TenantService().currentTenant.value;
    final country = tenant?.country ?? 'Nepal';
    if (country.toLowerCase() == 'india') {
      _selectedCountry = 'India';
      _selectedState = tenant?.state ?? 'Delhi (NCT)';
    } else {
      _selectedCountry = 'Nepal';
      _selectedState = tenant?.state ?? 'Bagmati Province';
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentStates = _stateData[_selectedCountry] ?? [];
    final filteredStates = currentStates.where((s) {
      final name = s['name']!.toLowerCase();
      final code = s['code']!.toLowerCase();
      final capital = s['capital']!.toLowerCase();
      final q = _searchQuery.toLowerCase();
      return name.contains(q) || code.contains(q) || capital.contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        title: const Text("State / Region Settings"),
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
            // Country Filter Selector
            Container(
              decoration: AppTheme.cardDecoration(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.public_rounded, color: AppTheme.primaryPurple, size: 22),
                  const SizedBox(width: 12),
                  const Text(
                    "Country:",
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCountry,
                        icon: const Icon(Icons.arrow_drop_down_rounded, color: AppTheme.primaryPurple),
                        isExpanded: true,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        items: _stateData.keys.map((country) {
                          return DropdownMenuItem<String>(
                            value: country,
                            child: Text(country),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedCountry = val;
                              final firstState = _stateData[val]?.first['name'] ?? "";
                              _selectedState = firstState;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Search Input
            Container(
              decoration: AppTheme.cardDecoration(),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: "Search state or province in $_selectedCountry...",
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

            Padding(
              padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
              child: Text(
                "STATES & PROVINCES (${_selectedCountry.toUpperCase()})",
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            ),

            // States List
            Expanded(
              child: filteredStates.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      itemCount: filteredStates.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final stateItem = filteredStates[index];
                        final isSelected = stateItem['name'] == _selectedState;

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
                                  _selectedState = stateItem['name']!;
                                });
                                final messenger = ScaffoldMessenger.of(context);
                                final tenantId = TenantService().currentTenant.value?.id;
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      "Active State set to ${stateItem['name']} ($_selectedCountry) (Synced)",
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
                                  await ApiService.updateTenantLocation(
                                    tenantId,
                                    country: _selectedCountry,
                                    state: stateItem['name'],
                                  );
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppTheme.primaryPurple
                                            : AppTheme.scaffoldBackground,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.map_rounded,
                                        color: isSelected
                                            ? Colors.white
                                            : AppTheme.primaryPurple,
                                        size: 20,
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
                                                stateItem['name']!,
                                                style: TextStyle(
                                                  color: isSelected
                                                      ? AppTheme.primaryPurple
                                                      : AppTheme.textPrimary,
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.cardBorder,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  stateItem['code']!,
                                                  style: const TextStyle(
                                                    color: AppTheme.textSecondary,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            "Capital: ${stateItem['capital']} • ${stateItem['type']}",
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
          Icon(Icons.location_off_rounded, size: 48, color: AppTheme.textMuted),
          const SizedBox(height: 12),
          const Text(
            "No state/province found",
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "No match in $_selectedCountry for '$_searchQuery'",
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
