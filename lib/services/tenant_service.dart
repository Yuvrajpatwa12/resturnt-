import 'package:flutter/material.dart';
import 'api_service.dart';

class Tenant {
  final String id;
  final String name;
  final String logo;
  final String color;
  final String domain; // Added domain field
  final bool isActive;
  final String plan;
  final String? expiry;
  final String? startDate;
  final String? storage;
  final double? latitude;  // Added
  final double? longitude; // Added

  Tenant({
    required this.id,
    required this.name,
    required this.logo,
    required this.color,
    required this.domain,
    required this.isActive,
    required this.plan,
    this.expiry,
    this.startDate,
    this.storage,
    this.latitude,
    this.longitude,
  });

  factory Tenant.fromMap(Map<String, dynamic> map) {
    return Tenant(
      id: (map['tenant_id']?.toString() ?? '').trim(),
      name: map['restaurant_name'] ?? map['name'] ?? 'Unknown',
      logo: map['logo_url'] ?? map['logo'] ?? '',
      color: map['primary_color'] ?? map['color'] ?? '#FF5C00',
      domain: map['domain'] ?? map['custom_domain'] ?? '', // Corrected mapping key
      isActive: (map['is_active'] == 1 || map['is_active'] == true),
      plan: map['plan'] ?? 'Basic',
      expiry: map['expiry_date'] ?? map['expiry'],
      startDate: map['start_date'] ?? map['created_at'],
      storage: map['storage_used'] ?? map['storage'] ?? '0.0 GB',
      latitude: double.tryParse(map['latitude']?.toString() ?? ''),
      longitude: double.tryParse(map['longitude']?.toString() ?? ''),
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

  Future<void> initialize(String domain) async {
    isLoading.value = true;
    
    // DEBUG BYPASS FOR LOCALHOST TESTING
    String domainToFetch = domain;
    if (domain == "localhost" || domain == "127.0.0.1") {
      domainToFetch = "startupsgo.tech"; // Use your live domain data for testing
    }

    debugPrint("TENANT: Loading data for $domainToFetch...");
    final data = await ApiService.initTenant(domainToFetch);
    
    if (data != null) {
      currentTenant.value = Tenant.fromMap(data);
      debugPrint("TENANT: Loaded ${currentTenant.value!.name} (ID: ${currentTenant.value!.id})");
      // Fetch Menu instantly for this tenant
      await fetchMenuData(currentTenant.value!.id);
    } else {
      debugPrint("TENANT: ERROR - Domain '$domainToFetch' not found in database.");
    }
    isLoading.value = false;
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
      notifyListeners();
      return {"success": true};
    }
    return {"success": false, "message": result['message']};
  }

  void logout() {
    currentStaff.value = null;
    notifyListeners();
  }

  void devModeBypass(String role) {
    currentStaff.value = Staff(
      id: 999,
      name: "Dev Mode User",
      role: role,
      tenantId: currentTenant.value?.id ?? "startupsgo_tech",
    );
    notifyListeners();
  }

  Future<void> fetchMenuData(String tenantId) async {
    final menuData = await ApiService.fetchMenu(tenantId);
    if (menuData != null) {
      products.value = List<Map<String, dynamic>>.from(menuData['products']);
      categories.value = List<Map<String, dynamic>>.from(menuData['categories']);
    }
  }

  bool isAccessBlocked() {
    return currentTenant.value != null && !currentTenant.value!.isActive;
  }
}
