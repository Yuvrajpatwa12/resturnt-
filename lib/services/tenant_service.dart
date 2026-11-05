import 'dart:async';
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'currency_service.dart';

class Tenant {
  final String id;
  final String name;
  final String logo;
  final String color;
  final String domain; // Added domain field
  final bool isActive;
  final String plan;
  final String currencyCode;
  final String currencySymbol;
  final String country;
  final String state;
  final String? expiry;
  final String? startDate;
  final String? subscriptionStatus;
  final String? trialStart;
  final String? trialEnd;
  final String? subscriptionStart;
  final String? subscriptionEnd;
  final String? storage;
  final double? latitude; // Added
  final double? longitude; // Added
  final String? googleMapsLink; // Added
  final String? instagramLink; // Added
  final String? facebookLink; // Added
  final String? tiktokLink; // Added
  final String? contactEmail; // Restaurant Admin Notification Email
  final String? contactPhone; // Support Phone
  final String? location; // Business Address
  final bool
  isPremiumEnabled; // Master switch for AR, Voice, Loyalty, Proximity
  final String? themeName;
  final String? secondaryColor;
  final String? backgroundColor;
  final String? fontFamily;
  final double? borderRadius;
  final bool? darkModeEnabled;

  Tenant({
    required this.id,
    required this.name,
    required this.logo,
    required this.color,
    required this.domain,
    required this.isActive,
    required this.plan,
    this.currencyCode = 'NPR',
    this.currencySymbol = 'Rs.',
    this.country = 'Nepal',
    this.state = 'Bagmati Province',
    this.expiry,
    this.startDate,
    this.subscriptionStatus,
    this.trialStart,
    this.trialEnd,
    this.subscriptionStart,
    this.subscriptionEnd,
    this.storage,
    this.latitude,
    this.longitude,
    this.googleMapsLink,
    this.instagramLink,
    this.facebookLink,
    this.tiktokLink,
    this.contactEmail,
    this.contactPhone,
    this.location,
    required this.isPremiumEnabled,
    this.themeName,
    this.secondaryColor,
    this.backgroundColor,
    this.fontFamily,
    this.borderRadius,
    this.darkModeEnabled,
  });

  factory Tenant.fromMap(Map<String, dynamic> map) {
    return Tenant(
      id: (map['tenant_id']?.toString() ?? '').trim(),
      name: map['restaurant_name'] ?? map['name'] ?? 'Unknown',
      logo: map['logo_url'] ?? map['logo'] ?? '',
      color: map['primary_color'] ?? map['color'] ?? '#FF5C00',
      domain: map['domain'] ?? map['custom_domain'] ?? '',
      isActive: (map['is_active'] == 1 || map['is_active'] == true),
      plan: map['plan'] ?? 'Basic',
      currencyCode: map['currency_code'] ?? map['currency'] ?? 'NPR',
      currencySymbol: map['currency_symbol'] ?? 'Rs.',
      country: map['country'] ?? 'Nepal',
      state: map['state'] ?? map['province'] ?? 'Bagmati Province',
      expiry: map['subscription_end'] ?? map['expiry_date'] ?? map['expiry'],
      startDate:
          map['subscription_start'] ?? map['start_date'] ?? map['created_at'],
      subscriptionStatus:
          map['subscription_status'] ??
          (map['plan'] == '3 Days Free Trial' ? 'Trial' : 'Active'),
      trialStart: map['trial_start'],
      trialEnd: map['trial_end'],
      subscriptionStart: map['subscription_start'],
      subscriptionEnd:
          map['subscription_end'] ?? map['expiry_date'] ?? map['expiry'],
      storage: map['storage_used'] ?? map['storage'] ?? '0.0 GB',
      latitude: double.tryParse(map['latitude']?.toString() ?? ''),
      longitude: double.tryParse(map['longitude']?.toString() ?? ''),
      googleMapsLink: map['google_maps_link'],
      instagramLink: map['instagram_link'],
      facebookLink: map['facebook_link'],
      tiktokLink: map['tiktok_link'],
      contactEmail: map['contact_email'] ?? map['primary_email'],
      contactPhone: map['contact_phone'] ?? map['phone'],
      location: map['location'] ?? map['address'],
      isPremiumEnabled:
          (map['is_premium_enabled'] == 1 || map['is_premium_enabled'] == true),
      themeName: map['theme_name'],
      secondaryColor: map['secondary_color'],
      backgroundColor: map['background_color'],
      fontFamily: map['font_family'],
      borderRadius: (map['border_radius'] as num?)?.toDouble(),
      darkModeEnabled:
          (map['dark_mode_enabled'] == 1 || map['dark_mode_enabled'] == true),
    );
  }

  int get daysRemaining {
    final now = DateTime.now();
    DateTime? expDate;
    final expStr = subscriptionEnd ?? expiry;
    if (expStr != null && expStr.isNotEmpty) {
      try {
        expDate = DateTime.parse(expStr);
      } catch (_) {}
    }
    if (expDate == null) {
      return -1; // Inactive / No subscription approved yet
    }
    return expDate.difference(now).inDays;
  }

  bool get isSubscriptionExpiringOrExpired {
    return daysRemaining <= 3;
  }

  bool get isExpired {
    final expStr = subscriptionEnd ?? expiry;
    if (expStr == null || expStr.isEmpty) {
      return true;
    }
    return daysRemaining < 0;
  }

  bool get isSubscriptionActive {
    final status = subscriptionStatus?.toLowerCase() ?? '';
    if (status == 'pending' || status == 'inactive' || status == 'unapproved') {
      return false;
    }
    return isActive && !isExpired;
  }
}

class Staff {
  final int id;
  final String name;
  final String role;
  final String tenantId;

  Staff({
    required this.id,
    required this.name,
    required this.role,
    required this.tenantId,
  });
}

class TenantService extends ChangeNotifier {
  static final TenantService _instance = TenantService._internal();
  factory TenantService() => _instance;
  TenantService._internal();

  final ValueNotifier<Tenant?> currentTenant = ValueNotifier<Tenant?>(null);
  final ValueNotifier<Staff?> currentStaff = ValueNotifier<Staff?>(null);
  final ValueNotifier<bool> isLoading = ValueNotifier<bool>(true);
  final ValueNotifier<List<Map<String, dynamic>>> products = ValueNotifier([]);
  final ValueNotifier<List<Map<String, dynamic>>> categories = ValueNotifier(
    [],
  );
  String? _menuTenantId;

  Future<void> initialize(
    String domain, {
    bool showLoading = true,
    String? tenantId,
  }) async {
    if (showLoading) isLoading.value = true;

    // Auto-map primary domain or localhost to startups_main
    final requestedTenantId = tenantId?.trim();
    String domainToFetch =
        requestedTenantId != null && requestedTenantId.isNotEmpty
        ? requestedTenantId
        : domain;
    if ((requestedTenantId == null || requestedTenantId.isEmpty) &&
        (domain == "localhost" ||
            domain == "127.0.0.1" ||
            domain == "startupsgo.tech" ||
            domain.isEmpty)) {
      domainToFetch = "startups_main"; // Match main restaurant tenant_id in DB
    }

    debugPrint("TENANT: Loading data for $domainToFetch...");
    Map<String, dynamic>? data = await ApiService.initTenant(domainToFetch);
    if (data != null &&
        requestedTenantId != null &&
        requestedTenantId.isNotEmpty &&
        (data['tenant_id']?.toString() ?? '').trim() != requestedTenantId) {
      data = null;
    }

    if (data != null) {
      final parsedTenant = Tenant.fromMap(data);
      if (currentTenant.value?.id != parsedTenant.id) {
        products.value = [];
        categories.value = [];
        _menuTenantId = null;
      }
      currentTenant.value = parsedTenant;
      CurrencyService().applyTenantCurrency(
        parsedTenant.currencyCode,
        parsedTenant.currencySymbol,
      );

      debugPrint(
        "TENANT: Loaded ${currentTenant.value!.name} (ID: ${currentTenant.value!.id})",
      );

      // Fetch theme settings from backend
      debugPrint(
        "TENANT: Fetching theme from backend for ${parsedTenant.id}...",
      );
      final themeData = await ApiService.fetchTheme(parsedTenant.id);
      if (currentTenant.value?.id != parsedTenant.id) return;
      if (themeData != null) {
        debugPrint(
          "TENANT: Theme data received - ${themeData['theme_name']}, color: ${themeData['primary_color']}",
        );
        final updatedTenant = Tenant(
          id: parsedTenant.id,
          name: parsedTenant.name,
          logo: parsedTenant.logo,
          color: themeData['primary_color'] ?? parsedTenant.color,
          domain: parsedTenant.domain,
          isActive: parsedTenant.isActive,
          plan: parsedTenant.plan,
          currencyCode: parsedTenant.currencyCode,
          currencySymbol: parsedTenant.currencySymbol,
          country: parsedTenant.country,
          state: parsedTenant.state,
          expiry: parsedTenant.expiry,
          startDate: parsedTenant.startDate,
          subscriptionStatus: parsedTenant.subscriptionStatus,
          trialStart: parsedTenant.trialStart,
          trialEnd: parsedTenant.trialEnd,
          subscriptionStart: parsedTenant.subscriptionStart,
          subscriptionEnd: parsedTenant.subscriptionEnd,
          storage: parsedTenant.storage,
          latitude: parsedTenant.latitude,
          longitude: parsedTenant.longitude,
          googleMapsLink: parsedTenant.googleMapsLink,
          instagramLink: parsedTenant.instagramLink,
          facebookLink: parsedTenant.facebookLink,
          tiktokLink: parsedTenant.tiktokLink,
          isPremiumEnabled: parsedTenant.isPremiumEnabled,
          themeName: themeData['theme_name'],
          secondaryColor: themeData['secondary_color'],
          backgroundColor: themeData['background_color'],
          fontFamily: themeData['font_family'],
          borderRadius: (themeData['border_radius'] as num?)?.toDouble(),
          darkModeEnabled: themeData['dark_mode_enabled'],
        );
        currentTenant.value = updatedTenant;
        debugPrint("TENANT: Theme applied successfully!");
      } else {
        debugPrint(
          "TENANT: Theme data is NULL - using default colors from tenant data",
        );
        debugPrint("TENANT: Current color from DB: ${parsedTenant.color}");
      }

      await fetchMenuData(currentTenant.value!.id);
    } else {
      if (requestedTenantId != null && requestedTenantId.isNotEmpty) {
        currentTenant.value = null;
        products.value = [];
        categories.value = [];
        _menuTenantId = null;
        if (showLoading) isLoading.value = false;
        notifyListeners();
        throw StateError(
          'This QR code does not match an active restaurant. Please scan a valid restaurant QR code.',
        );
      }
      debugPrint(
        "TENANT: ERROR - Could not resolve restaurant for domain '$domain'.",
      );
      currentTenant.value = null;
      products.value = [];
      categories.value = [];
      _menuTenantId = null;
      if (showLoading) isLoading.value = false;
      notifyListeners();
      throw StateError(
        'Could not identify this restaurant. Check the restaurant domain or try again.',
      );
    }
    if (showLoading) isLoading.value = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>> login(String email, String pin) async {
    final tenant = currentTenant.value;
    if (tenant == null || tenant.id.trim().isEmpty) {
      return {
        "success": false,
        "message":
            "Restaurant could not be identified. Reload this restaurant site and try again.",
      };
    }

    final result = await ApiService.staffLogin(
      tenantId: tenant.id,
      email: email,
      pin: pin,
    );

    if (result['success'] == true) {
      final userData = result['user'] as Map<String, dynamic>;
      if ((userData['tenant_id']?.toString() ?? '').trim() != tenant.id) {
        await ApiService.staffLogout();
        return {
          "success": false,
          "message": "This staff account belongs to a different restaurant.",
        };
      }
      currentStaff.value = Staff(
        id: int.parse(userData['id'].toString()),
        name: userData['name'],
        role: userData['role'],
        tenantId: userData['tenant_id'],
      );
      notifyListeners();
      return {"success": true};
    }
    return {"success": false, "message": result['message']};
  }

  void logout() {
    unawaited(ApiService.staffLogout());
    if (currentStaff.value != null && currentTenant.value != null) {
      ApiService.goOffline(
        tenantId: currentTenant.value!.id,
        userId: currentStaff.value!.id.toString(),
      );
    }
    currentStaff.value = null;
    notifyListeners();
  }

  void devModeBypass(String role) {
    if (currentTenant.value == null) {
      currentTenant.value = Tenant(
        id: "startups_main",
        name: "Dev Mode Restaurant",
        logo: "",
        color: "#FF5C00",
        domain: "startupsgo.tech",
        isActive: true,
        plan: "Premium",
        isPremiumEnabled: true,
      );
      fetchMenuData("startups_main");
    }
    currentStaff.value = Staff(
      id: 999,
      name: "Dev Mode User",
      role: role,
      tenantId: currentTenant.value?.id ?? "startups_main",
    );
    notifyListeners();
  }

  Future<void> fetchMenuData(String tenantId) async {
    final requestedTenant = tenantId.trim();
    if (requestedTenant.isEmpty || currentTenant.value?.id != requestedTenant) {
      debugPrint(
        "TENANT: Skipping menu load for an unknown or mismatched restaurant.",
      );
      return;
    }

    if (_menuTenantId != requestedTenant) {
      products.value = [];
      categories.value = [];
      _menuTenantId = requestedTenant;
    }

    debugPrint("TENANT: Attempting to fetch menu for -> $tenantId");
    final menuData = await ApiService.fetchMenu(requestedTenant);
    if (currentTenant.value?.id != requestedTenant) return;

    if (menuData != null) {
      products.value = List<Map<String, dynamic>>.from(menuData['products']);
      categories.value = List<Map<String, dynamic>>.from(
        menuData['categories'],
      );
      debugPrint(
        "TENANT: SUCCESS! Found ${categories.value.length} categories and ${products.value.length} products.",
      );
    } else {
      debugPrint(
        "TENANT: ERROR! get_menu.php returned NULL. Check if the file exists in saas_api folder.",
      );
    }
  }

  bool isAccessBlocked() {
    return currentTenant.value != null && !currentTenant.value!.isActive;
  }
}
