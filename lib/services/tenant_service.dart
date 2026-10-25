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
  final String? storage;
  final double? latitude;  // Added
  final double? longitude; // Added
  final String? googleMapsLink; // Added
  final String? instagramLink;   // Added
  final String? facebookLink;    // Added
  final String? tiktokLink;      // Added
  final bool isPremiumEnabled; // Master switch for AR, Voice, Loyalty, Proximity

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
    this.storage,
    this.latitude,
    this.longitude,
    this.googleMapsLink,
    this.instagramLink,
    this.facebookLink,
    this.tiktokLink,
    required this.isPremiumEnabled,
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
      expiry: map['expiry_date'] ?? map['expiry'],
      startDate: map['start_date'] ?? map['created_at'],
      storage: map['storage_used'] ?? map['storage'] ?? '0.0 GB',
      latitude: double.tryParse(map['latitude']?.toString() ?? ''),
      longitude: double.tryParse(map['longitude']?.toString() ?? ''),
      googleMapsLink: map['google_maps_link'],
      instagramLink: map['instagram_link'],
      facebookLink: map['facebook_link'],
      tiktokLink: map['tiktok_link'],
      isPremiumEnabled: (map['is_premium_enabled'] == 1 || map['is_premium_enabled'] == true),
    );
  }
}

class Staff {
  final int id;
  final String name;
  final String role;
  final String tenantId;

  Staff({required this.id, required this.name, required this.role, required this.tenantId});
}

class TenantService extends ChangeNotifier {
  static final TenantService _instance = TenantService._internal();
  factory TenantService() => _instance;
  TenantService._internal();

  final ValueNotifier<Tenant?> currentTenant = ValueNotifier<Tenant?>(null);
  final ValueNotifier<Staff?> currentStaff = ValueNotifier<Staff?>(null);
  final ValueNotifier<bool> isLoading = ValueNotifier<bool>(true);
  final ValueNotifier<List<Map<String, dynamic>>> products = ValueNotifier([]);
  final ValueNotifier<List<Map<String, dynamic>>> categories = ValueNotifier([]);

  Future<void> initialize(String domain, {bool showLoading = true}) async {
    if (showLoading) isLoading.value = true;
    
    // Auto-map primary domain or localhost to startups_main
    String domainToFetch = domain;
    if (domain == "localhost" || domain == "127.0.0.1" || domain == "startupsgo.tech" || domain.isEmpty) {
      domainToFetch = "startups_main"; // Match main restaurant tenant_id in DB
    }

    debugPrint("TENANT: Loading data for $domainToFetch...");
    Map<String, dynamic>? data = await ApiService.initTenant(domainToFetch);
    
    // If not found, fallback to startups_main
    if (data == null && domainToFetch != "startups_main") {
      debugPrint("TENANT: Domain not found directly, falling back to startups_main...");
      data = await ApiService.initTenant("startups_main");
    }
    
    if (data != null) {
      final parsedTenant = Tenant.fromMap(data);
      currentTenant.value = parsedTenant;
      CurrencyService().applyTenantCurrency(parsedTenant.currencyCode, parsedTenant.currencySymbol);
      
      debugPrint("TENANT: Loaded ${currentTenant.value!.name} (ID: ${currentTenant.value!.id})");
      await fetchMenuData(currentTenant.value!.id);
    } else {
      debugPrint("TENANT: ERROR - Tenant data could not be fetched. Using Default Active Tenant.");
      currentTenant.value = Tenant(
        id: "startups_main",
        name: "ChiyaBreak Restaurant",
        logo: "",
        color: "#FF5C00",
        domain: "startupsgo.tech",
        isActive: true,
        plan: "Premium",
        isPremiumEnabled: true,
        googleMapsLink: "https://maps.google.com",
        instagramLink: "https://instagram.com",
        facebookLink: "https://facebook.com",
        tiktokLink: "https://tiktok.com",
      );
      await fetchMenuData("startups_main");
    }
    if (showLoading) isLoading.value = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>> login(String email, String pin) async {
    String domain = Uri.base.host == "127.0.0.1" ? "localhost" : Uri.base.host;
    
    if (domain == "localhost") domain = "startupsgo.tech"; // Force domain for localhost login

    final result = await ApiService.staffLogin(domain: domain, email: email, pin: pin);
    
    if (result['success'] == true) {
      final userData = result['user'];
      currentStaff.value = Staff(
        id: int.parse(userData['id'].toString()),
        name: userData['name'],
        role: userData['role'],
        tenantId: userData['tenant_id'],
      );
      if (currentTenant.value == null) {
        currentTenant.value = Tenant(
          id: userData['tenant_id']?.toString() ?? "startups_main",
          name: "Logged In Restaurant",
          logo: "",
          color: "#FF5C00",
          domain: "startupsgo.tech",
          isActive: true,
          plan: "Premium",
          isPremiumEnabled: true,
        );
        await fetchMenuData(currentTenant.value!.id);
      }
      notifyListeners();
      return {"success": true};
    }
    return {"success": false, "message": result['message']};
  }

  void logout() {
    if (currentStaff.value != null && currentTenant.value != null) {
      ApiService.goOffline(tenantId: currentTenant.value!.id, userId: currentStaff.value!.id.toString());
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
    debugPrint("TENANT: Attempting to fetch menu for -> $tenantId");
    final menuData = await ApiService.fetchMenu(tenantId);
    
    if (menuData != null) {
      products.value = List<Map<String, dynamic>>.from(menuData['products']);
      categories.value = List<Map<String, dynamic>>.from(menuData['categories']);
      debugPrint("TENANT: SUCCESS! Found ${categories.value.length} categories and ${products.value.length} products.");
    } else {
      debugPrint("TENANT: ERROR! get_menu.php returned NULL. Check if the file exists in saas_api folder.");
      // Auto-Retry with default ID if it failed
      if (tenantId != "startups_main") {
        debugPrint("TENANT: Retrying with startups_main...");
        fetchMenuData("startups_main");
      }
    }
  }

  bool isAccessBlocked() {
    return currentTenant.value != null && !currentTenant.value!.isActive;
  }
}
