import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'tenant_service.dart';

class ApiService {
  // --- 1. CONFIGURATION ---
  static const String baseUrl = "https://startupsgo.tech/saas_api";
  static const Duration _timeout = Duration(seconds: 15);
  static String? _staffSessionCookie;
  static String? _staffApiToken;
  static bool _staffApiTokenLoaded = false;
  static const Set<String> _staffProtectedEndpoints = {
    'financial_report.php',
    'get_tables.php',
    'get_all_orders.php',
    'get_billing_settings.php',
    'get_session_bill.php',
    'payment_methods_api.php',
    'refund_payment.php',
    'reopen_session.php',
    'save_billing_settings.php',
    'settle_bill.php',
    'staff_logout.php',
    'stock_reports_api.php',
    'theme_api.php',
    'add_table.php',
    'update_order_status.php',
    'waiter_assistance_api.php',
    'waiter_ready_api.php',
    'update_session_status.php',
    'update_tenant_settings.php',
    'void_order.php',
  };

  static String newIdempotencyKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(24, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  // --- HELPER METHODS FOR STABILITY ---
  static Future<Map<String, String>> _withStaffAuth(
    Uri uri,
    Map<String, String>? headers,
  ) async {
    final requestHeaders = <String, String>{...?headers};
    if (!_staffApiTokenLoaded) {
      final prefs = await SharedPreferences.getInstance();
      _staffApiToken = prefs.getString('staff_api_token');
      _staffApiTokenLoaded = true;
    }
    if (uri.pathSegments.isNotEmpty &&
        _staffProtectedEndpoints.contains(uri.pathSegments.last) &&
        _staffApiToken != null &&
        _staffApiToken!.isNotEmpty &&
        !requestHeaders.containsKey('Authorization')) {
      requestHeaders['Authorization'] = 'Bearer ${_staffApiToken!}';
    }
    if (!kIsWeb && _staffSessionCookie != null) {
      requestHeaders['Cookie'] = _staffSessionCookie!;
    }
    return requestHeaders;
  }

  static void _captureStaffSessionCookie(http.Response response) {
    if (kIsWeb) return;
    final setCookie = response.headers['set-cookie'];
    if (setCookie == null || setCookie.isEmpty) return;
    final cookiePair = setCookie.split(';').first.trim();
    if (RegExp(r'^[A-Za-z0-9_-]+=[^;]+$').hasMatch(cookiePair)) {
      _staffSessionCookie = cookiePair;
    }
  }

  static Future<http.Response> _get(
    Uri uri, {
    Map<String, String>? headers,
  }) async {
    final requestHeaders = await _withStaffAuth(uri, headers);
    return await http
        .get(uri, headers: requestHeaders)
        .timeout(
          _timeout,
          onTimeout: () {
            throw TimeoutException(
              "Server is taking too long to respond. Please check your connection.",
            );
          },
        );
  }

  static Future<http.Response> _post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final requestHeaders = await _withStaffAuth(uri, headers);
    return await http
        .post(uri, headers: requestHeaders, body: body)
        .timeout(
          _timeout,
          onTimeout: () {
            throw TimeoutException(
              "Server is taking too long to respond. Please check your connection.",
            );
          },
        );
  }

  static Future<Map<String, String>> _customerSessionHeaders(
    String tenantId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final tokenKey = 'customer_${Uri.encodeComponent(tenantId)}_session_token';
    final token = prefs.getString(tokenKey) ?? '';
    return {
      'Content-Type': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>?> initTenant(String domain) async {
    try {
      final response = await _get(
        Uri.parse(
          "$baseUrl/init_tenant.php",
        ).replace(queryParameters: {'domain': domain}),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') return data['data'];
      }
      return null;
    } catch (e) {
      debugPrint("API Error (initTenant): $e");
      return null;
    }
  }

  static Future<bool> updateTenantCurrency(
    String tenantId,
    String currencyCode,
    String currencySymbol,
  ) async {
    try {
      final currentDomain = Uri.base.host;
      final response = await _post(
        Uri.parse(
          "$baseUrl/init_tenant.php?action=update_currency&t=${DateTime.now().millisecondsSinceEpoch}",
        ),
        body: json.encode({
          'tenant_id': tenantId,
          'domain': currentDomain,
          'currency_code': currencyCode,
          'currency_symbol': currencySymbol,
        }),
        headers: {'Content-Type': 'application/json'},
      );
      debugPrint(
        "API updateTenantCurrency response (${response.statusCode}): ${response.body}",
      );
      if (response.statusCode == 200) {
        final res = json.decode(response.body);
        return res['status'] == 'success' || res['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint("API Error (updateTenantCurrency): $e");
      return false;
    }
  }

  static Future<Map<String, dynamic>> updateTenantLocation(
    String tenantId, {
    String? country,
    String? state,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final currentDomain = Uri.base.host;
      final response = await _post(
        Uri.parse(
          "$baseUrl/init_tenant.php?action=update_location&t=${DateTime.now().millisecondsSinceEpoch}",
        ),
        body: json.encode({
          'tenant_id': tenantId,
          'domain': currentDomain,
          if (country != null) 'country': country,
          if (state != null) 'state': state,
          if (latitude != null) 'latitude': latitude,
          if (longitude != null) 'longitude': longitude,
        }),
        headers: {'Content-Type': 'application/json'},
      );
      debugPrint(
        "API updateTenantLocation response (${response.statusCode}): ${response.body}",
      );
      if (response.statusCode == 200) {
        final res = json.decode(response.body);
        return {
          "success": res['status'] == 'success' || res['success'] == true,
          "message": res['message'] ?? 'Location updated successfully',
        };
      }
      return {
        "success": false,
        "message": "Server error (${response.statusCode})",
      };
    } catch (e) {
      debugPrint("API Error (updateTenantLocation): $e");
      return {"success": false, "message": e.toString()};
    }
  }

  static Future<Map<String, dynamic>> updateTenantProfile({
    required String tenantId,
    required String restaurantName,
    required String contactEmail,
    required String contactPhone,
    required String location,
  }) async {
    try {
      final response = await _post(
        Uri.parse(
          "$baseUrl/init_tenant.php?action=update_profile&t=${DateTime.now().millisecondsSinceEpoch}",
        ),
        body: json.encode({
          'tenant_id': tenantId,
          'restaurant_name': restaurantName,
          'contact_email': contactEmail,
          'contact_phone': contactPhone,
          'location': location,
        }),
        headers: {'Content-Type': 'application/json'},
      );
      debugPrint(
        "API updateTenantProfile response (${response.statusCode}): ${response.body}",
      );
      if (response.statusCode == 200) {
        final res = json.decode(response.body);
        return {
          "success": res['status'] == 'success' || res['success'] == true,
          "message": res['message'] ?? 'Profile updated successfully!',
          "profile": res['profile'],
        };
      }
      return {
        "success": false,
        "message": "Server error (${response.statusCode})",
      };
    } catch (e) {
      debugPrint("API Error (updateTenantProfile): $e");
      return {"success": false, "message": e.toString()};
    }
  }

  static Future<Map<String, dynamic>> superAdminUpdateTenant({
    required String tenantId,
    required String restaurantName,
    required String domain,
    required String customDomain,
    required String contactEmail,
    required String contactPhone,
    required String location,
    required String color,
    required String fontFamily,
    required String logoUrl,
    required double vatPercentage,
    required double serviceChargePercentage,
  }) async {
    try {
      final response = await _post(
        Uri.parse(
          "$baseUrl/super_admin_update_tenant.php?t=${DateTime.now().millisecondsSinceEpoch}",
        ),
        body: json.encode({
          'tenant_id': tenantId,
          'restaurant_name': restaurantName,
          'domain': domain,
          'custom_domain': customDomain,
          'contact_email': contactEmail,
          'contact_phone': contactPhone,
          'location': location,
          'color': color,
          'font_family': fontFamily,
          'logo_url': logoUrl,
          'vat_percentage': vatPercentage,
          'service_charge_percentage': serviceChargePercentage,
        }),
        headers: {'Content-Type': 'application/json'},
      );
      debugPrint(
        "API superAdminUpdateTenant response (${response.statusCode}): ${response.body}",
      );
      if (response.statusCode == 200) {
        final res = json.decode(response.body);
        return {
          "success": res['status'] == 'success' || res['success'] == true,
          "message":
              res['message'] ?? 'Restaurant profile updated successfully!',
          "tenant": res['tenant'],
        };
      }
      return {
        "success": false,
        "message": "Server error (${response.statusCode})",
      };
    } catch (e) {
      debugPrint("API Error (superAdminUpdateTenant): $e");
      return {"success": false, "message": e.toString()};
    }
  }

  static Future<Map<String, dynamic>> superAdminToggleTenantStatus({
    required String tenantId,
    required bool isActive,
  }) async {
    try {
      final response = await _post(
        Uri.parse(
          "$baseUrl/super_admin_toggle_tenant_status.php?t=${DateTime.now().millisecondsSinceEpoch}",
        ),
        body: json.encode({
          'tenant_id': tenantId,
          'is_active': isActive ? 1 : 0,
        }),
        headers: {'Content-Type': 'application/json'},
      );
      debugPrint(
        "API superAdminToggleTenantStatus response (${response.statusCode}): ${response.body}",
      );
      if (response.statusCode == 200) {
        final res = json.decode(response.body);
        return {
          "success": res['status'] == 'success' || res['success'] == true,
          "message": res['message'] ?? 'Status updated successfully!',
          "is_active": res['is_active'],
        };
      }
      return {
        "success": false,
        "message": "Server error (${response.statusCode})",
      };
    } catch (e) {
      debugPrint("API Error (superAdminToggleTenantStatus): $e");
      return {"success": false, "message": e.toString()};
    }
  }

  static Future<Map<String, dynamic>?> fetchMenu(String tenantId) async {
    try {
      // Add timestamp to bypass server/browser cache
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final response = await _get(
        Uri.parse("$baseUrl/get_menu.php?tenant_id=$tenantId&t=$timestamp"),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          return {
            "categories": data['categories'],
            "products": data['products'],
          };
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // --- SUPER ADMIN METHODS ---

  static Future<List<Map<String, dynamic>>?> fetchTenants() async {
    try {
      final token = await getSuperAdminToken();
      final headers = <String, String>{};
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = '******';
      }
      final response = await _get(
        Uri.parse(
          "$baseUrl/get_tenants.php?t=${DateTime.now().millisecondsSinceEpoch}",
        ),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> registerTenant(Map<String, dynamic> tenantData) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/register_tenant.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode(tenantData),
      );
      return json.decode(response.body)['status'] == 'success';
    } catch (e) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> updateCredentials({
    required String tenantId,
    required String email,
    required String pin,
  }) async {
    try {
      final token = await getSuperAdminToken();
      final headers = <String, String>{"Content-Type": "application/json"};
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = '******';
      }
      final response = await _post(
        Uri.parse("$baseUrl/update_tenant_credentials.php"),
        headers: headers,
        body: json.encode({"tenant_id": tenantId, "email": email, "pin": pin}),
      );
      return json.decode(response.body);
    } catch (e) {
      return {"success": false, "message": "Connection failed"};
    }
  }

  static Future<Map<String, dynamic>> updateTenantPremiumStatus({
    required String tenantId,
    required bool isEnabled,
  }) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/update_premium_status.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "tenant_id": tenantId,
          "is_premium_enabled": isEnabled ? 1 : 0,
        }),
      );
      return json.decode(response.body);
    } catch (e) {
      return {"success": false, "message": "Connection failed"};
    }
  }

  static Future<bool> deleteTenant(String tenantId) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/delete_tenant.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"tenant_id": tenantId}),
      );
      return json.decode(response.body)['status'] == 'success';
    } catch (e) {
      return false;
    }
  }

  // --- REAL-TIME SUBSCRIPTION & SUPER ADMIN AUTH METHODS ---
  static String? _superAdminToken;

  static final List<Map<String, dynamic>> _defaultPackages = [
    {
      'id': 1,
      'name': '3 Days Free Trial',
      'duration_days': 3,
      'price': '0.00',
      'perks': 'Full Feature Access • Auto Activated • No Credit Card',
      'is_active': 1,
    },
    {
      'id': 2,
      'name': 'Monthly Starter',
      'duration_days': 28,
      'price': '799.00',
      'perks': 'Standard Features • 1 Store • POS Billing',
      'is_active': 1,
    },
    {
      'id': 3,
      'name': '3 Months Pro',
      'duration_days': 84,
      'price': '2396.52',
      'perks': 'Priority Support • Advanced Analytics • Staff & Inventory',
      'is_active': 1,
    },
    {
      'id': 4,
      'name': '6 Months Enterprise',
      'duration_days': 168,
      'price': '4793.04',
      'perks': 'Unlimited Access • Multi-Store Ready • Premium Modules',
      'is_active': 1,
    },
  ];

  static Future<void> _ensureLocalPackagesLoaded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('saved_subscription_packages_list');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> decoded = json.decode(jsonStr);
        if (decoded.isNotEmpty) {
          _defaultPackages.clear();
          _defaultPackages.addAll(
            decoded.map((x) => Map<String, dynamic>.from(x)),
          );
        }
      }
    } catch (e) {
      debugPrint("Error loading local subscription packages: $e");
    }
  }

  static Future<void> _persistLocalPackages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'saved_subscription_packages_list',
        json.encode(_defaultPackages),
      );
    } catch (e) {
      debugPrint("Error persisting local subscription packages: $e");
    }
  }

  static final List<Map<String, dynamic>> _localSubscriptionRequests = [];

  static Future<void> _ensureLocalSubscriptionRequestsLoaded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('saved_subscription_requests_list');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> decoded = json.decode(jsonStr);
        _localSubscriptionRequests.clear();
        _localSubscriptionRequests.addAll(
          decoded.map((x) => Map<String, dynamic>.from(x)),
        );
      }
    } catch (e) {
      debugPrint("Error loading local subscription requests: $e");
    }
  }

  static Future<void> _persistLocalSubscriptionRequests() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'saved_subscription_requests_list',
        json.encode(_localSubscriptionRequests),
      );
    } catch (e) {
      debugPrint("Error persisting local subscription requests: $e");
    }
  }

  static void setSuperAdminToken(String? token) {
    _superAdminToken = token;
    if (token != null && token.isNotEmpty) {
      SharedPreferences.getInstance().then(
        (prefs) => prefs.setString('super_admin_session_token', token),
      );
    } else {
      SharedPreferences.getInstance().then(
        (prefs) => prefs.remove('super_admin_session_token'),
      );
    }
  }

  static Future<String?> getSuperAdminToken() async {
    if (_superAdminToken != null && _superAdminToken!.isNotEmpty)
      return _superAdminToken;
    final prefs = await SharedPreferences.getInstance();
    _superAdminToken = prefs.getString('super_admin_session_token');
    return _superAdminToken;
  }

  static Future<Map<String, dynamic>> superAdminLogin(
    String email,
    String pin,
  ) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/super_admin_api.php?action=login"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"email": email, "pin": pin}),
      );
      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        final token = data['token']?.toString();
        if (token != null && token.isNotEmpty) {
          setSuperAdminToken(token);
          return {
            "success": true,
            "message": data['message'] ?? 'Logged in',
            "admin": data['admin'],
          };
        }
        setSuperAdminToken(null);
        return {
          "success": false,
          "message": "The authentication server did not issue a session.",
        };
      }
      setSuperAdminToken(null);
      return {
        "success": false,
        "message": data is Map
            ? (data['message'] ?? "Invalid email or PIN.")
            : "The server returned an invalid login response.",
      };
    } catch (e) {
      setSuperAdminToken(null);
      debugPrint("Super Admin login request failed: $e");
      return {
        "success": false,
        "message":
            "Could not reach the authentication server. Check your connection and try again.",
      };
    }
  }

  static Future<Map<String, dynamic>?> fetchSuperAdminProfile() async {
    try {
      final token = await getSuperAdminToken();
      final headers = <String, String>{};
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
      final response = await _get(
        Uri.parse("$baseUrl/super_admin_api.php?action=get_profile"),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          return data['profile'];
        }
      }
    } catch (e) {
      debugPrint("Error fetching admin profile: $e");
    }
    return null;
  }

  static Future<Map<String, dynamic>> updateSuperAdminProfile({
    required String email,
    required String name,
    String? newPassword,
  }) async {
    try {
      final token = await getSuperAdminToken();
      final headers = <String, String>{"Content-Type": "application/json"};
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
      final body = <String, dynamic>{'email': email, 'name': name};
      if (newPassword != null && newPassword.isNotEmpty) {
        body['new_password'] = newPassword;
      }
      final response = await _post(
        Uri.parse("$baseUrl/super_admin_api.php?action=update_profile"),
        headers: headers,
        body: json.encode(body),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          "success": data['status'] == 'success',
          "message": data['message'] ?? 'Profile updated successfully!',
        };
      }
    } catch (e) {
      debugPrint("Error updating admin profile: $e");
    }

    return {
      "success": false,
      "message": "Could not save the Super Admin profile to the server.",
    };
  }

  static Future<List<Map<String, dynamic>>> fetchSubscriptionPackages({
    String tenantId = '',
  }) async {
    try {
      final query = tenantId.isNotEmpty ? "&tenant_id=$tenantId" : "";
      final response = await _get(
        Uri.parse("$baseUrl/subscription_api.php?action=get_packages$query"),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
    } catch (e) {
      debugPrint("Error fetching packages from server: $e");
    }
    return _defaultPackages;
  }

  static Future<Map<String, dynamic>> cancelSubscriptionRequest(
    String tenantId,
    int requestId,
  ) async {
    await _ensureLocalSubscriptionRequestsLoaded();

    // Remove locally first so local mock requests or synced requests clear immediately
    _localSubscriptionRequests.removeWhere(
      (r) => int.tryParse(r['id'].toString()) == requestId,
    );
    await _persistLocalSubscriptionRequests();

    try {
      final response = await _post(
        Uri.parse("$baseUrl/subscription_api.php?action=cancel_request"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"tenant_id": tenantId, "request_id": requestId}),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          "success": true,
          "message":
              data['message'] ?? 'Subscription request cancelled successfully.',
        };
      }
    } catch (e) {
      debugPrint("Error cancelling request on server: $e");
    }

    return {
      "success": true,
      "message": "Subscription request cancelled successfully.",
    };
  }

  static Future<Map<String, dynamic>> requestSubscriptionPackage(
    String tenantId,
    int packageId,
  ) async {
    final String tId = tenantId.trim();
    if (tId.isEmpty || packageId <= 0) {
      return {
        "success": false,
        "message": "A valid tenant and subscription package are required.",
      };
    }
    try {
      final response = await _post(
        Uri.parse("$baseUrl/subscription_api.php?action=request_package"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"tenant_id": tId, "package_id": packageId}),
      );
      final decoded = json.decode(response.body);
      if (response.statusCode == 200 &&
          decoded is Map &&
          decoded['status'] == 'success') {
        return {
          "success": true,
          "message": decoded['message'] ?? 'Subscription request submitted.',
          "request_id": decoded['request_id'],
        };
      }

      final message = decoded is Map ? decoded['message']?.toString() : null;
      return {
        "success": false,
        "message": message?.isNotEmpty == true
            ? message!
            : "Request failed (HTTP ${response.statusCode}).",
      };
    } catch (e) {
      debugPrint("Subscription request failed: $e");
      return {
        "success": false,
        "message": "Could not submit the request to the server: $e",
      };
    }
  }

  static Future<List<Map<String, dynamic>>> fetchMySubscriptionRequests(
    String tenantId,
  ) async {
    final tId = tenantId.trim();
    if (tId.isEmpty) {
      throw StateError(
        "Tenant ID is missing; subscription requests cannot load.",
      );
    }

    final response = await _get(
      Uri.parse(
        "$baseUrl/subscription_api.php?action=get_my_requests&tenant_id=${Uri.encodeQueryComponent(tId)}",
      ),
    );
    final decoded = json.decode(response.body);
    if (response.statusCode != 200 ||
        decoded is! Map ||
        decoded['status'] != 'success' ||
        decoded['data'] is! List) {
      final message = decoded is Map ? decoded['message']?.toString() : null;
      throw StateError(
        message?.isNotEmpty == true
            ? message!
            : "Could not load subscription requests (HTTP ${response.statusCode}).",
      );
    }

    return List<Map<String, dynamic>>.from(decoded['data']);
  }

  static Future<List<Map<String, dynamic>>>
  fetchPendingSubscriptionRequests() async {
    List<Map<String, dynamic>> serverReqs = [];

    try {
      final token = await getSuperAdminToken();
      if (token == null || token.isEmpty) {
        throw StateError("Super Admin session expired. Please sign in again.");
      }
      final headers = <String, String>{};
      if (token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await _get(
        Uri.parse("$baseUrl/subscription_api.php?action=get_pending_requests"),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' &&
            data['data'] != null &&
            data['data'] is List) {
          serverReqs = List<Map<String, dynamic>>.from(data['data']);
        } else {
          throw StateError(
            data is Map
                ? (data['message']?.toString() ??
                      "Could not load pending subscription requests.")
                : "The server returned an invalid pending-requests response.",
          );
        }
      } else {
        throw StateError(
          "Could not load pending requests (HTTP ${response.statusCode}).",
        );
      }
    } catch (e) {
      debugPrint("Error fetching pending requests from server: $e");
      rethrow;
    }

    return serverReqs;
  }

  static Future<Map<String, dynamic>> approveSubscriptionRequest(
    int requestId,
  ) async {
    try {
      final token = await getSuperAdminToken();
      final headers = <String, String>{"Content-Type": "application/json"};
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await _post(
        Uri.parse("$baseUrl/subscription_api.php?action=approve_request"),
        headers: headers,
        body: json.encode({"request_id": requestId}),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          return {
            "success": true,
            "message": data['message'] ?? 'Subscription approved!',
          };
        }
        return {
          "success": false,
          "message":
              data['message'] ?? 'The server could not approve this request.',
        };
      }
      return {
        "success": false,
        "message": "Approval failed (HTTP ${response.statusCode}).",
      };
    } catch (e) {
      debugPrint("Subscription approval failed: $e");
      return {
        "success": false,
        "message": "Could not approve the request on the server: $e",
      };
    }
  }

  static Future<Map<String, dynamic>> rejectSubscriptionRequest(
    int requestId, {
    String? note,
  }) async {
    try {
      final token = await getSuperAdminToken();
      final headers = <String, String>{"Content-Type": "application/json"};
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await _post(
        Uri.parse("$baseUrl/subscription_api.php?action=reject_request"),
        headers: headers,
        body: json.encode({"request_id": requestId, "rejection_note": note}),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          return {
            "success": true,
            "message": data['message'] ?? 'Subscription rejected',
          };
        }
        return {
          "success": false,
          "message":
              data['message'] ?? 'The server could not reject this request.',
        };
      }
      return {
        "success": false,
        "message": "Rejection failed (HTTP ${response.statusCode}).",
      };
    } catch (e) {
      debugPrint("Subscription rejection failed: $e");
      return {
        "success": false,
        "message": "Could not reject the request on the server: $e",
      };
    }
  }

  static Future<Map<String, dynamic>> saveSubscriptionPackage(
    Map<String, dynamic> packageData,
  ) async {
    // 1. Update in-memory and local SharedPreferences first (offline/demo support)
    await _ensureLocalPackagesLoaded();
    final pkgId = int.tryParse(packageData['id']?.toString() ?? '0');
    final name = (packageData['name'] ?? packageData['title'] ?? 'Package')
        .toString();
    final durationDays =
        int.tryParse(packageData['duration_days']?.toString() ?? '30') ?? 30;
    final price = (packageData['price'] ?? '0.00').toString();
    final perks = (packageData['perks'] ?? '').toString();

    if (pkgId != null && pkgId > 0) {
      final idx = _defaultPackages.indexWhere(
        (p) => int.tryParse(p['id'].toString()) == pkgId,
      );
      if (idx >= 0) {
        _defaultPackages[idx] = {
          'id': pkgId,
          'name': name,
          'duration_days': durationDays,
          'price': price,
          'perks': perks,
          'is_active': 1,
        };
      }
    } else {
      final newId = _defaultPackages.length + 1;
      _defaultPackages.add({
        'id': newId,
        'name': name,
        'duration_days': durationDays,
        'price': price,
        'perks': perks,
        'is_active': 1,
      });
    }
    await _persistLocalPackages();

    // 2. Attempt sync with server
    try {
      final token = await getSuperAdminToken();
      final headers = <String, String>{"Content-Type": "application/json"};
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await _post(
        Uri.parse("$baseUrl/subscription_api.php?action=save_package"),
        headers: headers,
        body: json.encode(packageData),
      );

      // Check for valid JSON response from server
      if (response.statusCode == 200 && response.body.trim().isNotEmpty) {
        try {
          final data = json.decode(response.body);
          if (data is Map<String, dynamic> && data['status'] == 'success') {
            return {
              "success": true,
              "message": data['message'] ?? 'Package updated successfully!',
            };
          }
        } catch (_) {
          // If server returns HTML error or non-JSON string, fallback gracefully to local update
        }
      }
    } catch (e) {
      debugPrint("Server save_package notice: $e");
    }

    // Return success since local update completed smoothly
    return {"success": true, "message": "Package updated successfully!"};
  }

  static Future<Map<String, dynamic>> addProduct(
    Map<String, dynamic> productData,
  ) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/add_product.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode(productData),
      );

      try {
        final result = json.decode(response.body);
        if (result['status'] == 'success') {
          return {"success": true};
        } else {
          return {
            "success": false,
            "message": result['message'] ?? "Unknown Error",
          };
        }
      } catch (e) {
        // If server sends non-JSON error (like PHP Crash)
        return {
          "success": false,
          "message":
              "Server Crash: ${response.body.substring(0, response.body.length > 100 ? 100 : response.body.length)}",
        };
      }
    } catch (e) {
      return {"success": false, "message": "Connection error: $e"};
    }
  }

  static Future<Map<String, dynamic>> updateProduct(
    Map<String, dynamic> productData,
  ) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/update_product.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode(productData),
      );
      final result = json.decode(response.body);
      if (result['status'] == 'success') {
        return {"success": true};
      } else {
        return {
          "success": false,
          "message": result['message'] ?? "Unknown Error",
        };
      }
    } catch (e) {
      return {"success": false, "message": "Connection error: $e"};
    }
  }

  static Future<bool> deleteProduct(String tenantId, String productId) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/delete_product.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"tenant_id": tenantId, "product_id": productId}),
      );
      return json.decode(response.body)['status'] == 'success';
    } catch (e) {
      return false;
    }
  }

  // --- THEME MANAGEMENT METHODS ---

  static Future<Map<String, dynamic>?> fetchTheme(String tenantId) async {
    try {
      final tId = tenantId.isNotEmpty ? tenantId : 'startups_main';
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final response = await _get(
        Uri.parse(
          "$baseUrl/theme_api.php?action=get_theme&tenant_id=$tId&t=$timestamp",
        ),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          return data['theme'];
        }
      }
      return null;
    } catch (e) {
      debugPrint("API Error (fetchTheme): $e");
      return null;
    }
  }

  static Future<Map<String, dynamic>> updateTheme({
    required String tenantId,
    required String primaryColor,
    required String themeName,
    String? secondaryColor,
    String? backgroundColor,
    String? fontFamily,
    double? borderRadius,
    bool? darkModeEnabled,
  }) async {
    try {
      final tId = tenantId.isNotEmpty ? tenantId : 'startups_main';
      final response = await _post(
        Uri.parse("$baseUrl/theme_api.php?action=update_theme"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          'tenant_id': tId,
          'primary_color': primaryColor,
          'theme_name': themeName,
          'secondary_color': secondaryColor ?? '#002D62',
          'background_color': backgroundColor ?? '#F8FAFC',
          'font_family': fontFamily ?? 'Inter',
          'border_radius': borderRadius ?? 16.0,
          'dark_mode_enabled': darkModeEnabled ?? false,
        }),
      );
      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        return {
          "success": true,
          "message": data['message'] ?? 'Theme updated successfully',
          "theme": data['theme'],
        };
      }
      return {
        "success": false,
        "message": data['message'] ?? 'Failed to update theme',
      };
    } catch (e) {
      debugPrint("API Error (updateTheme): $e");
      return {"success": false, "message": "Connection error: $e"};
    }
  }

  static Future<List<Map<String, dynamic>>?> listAllThemes() async {
    try {
      final token = await getSuperAdminToken();
      final headers = <String, String>{};
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
      final response = await _get(
        Uri.parse("$baseUrl/theme_api.php?action=list_themes"),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          return List<Map<String, dynamic>>.from(data['themes']);
        }
      }
      return null;
    } catch (e) {
      debugPrint("API Error (listAllThemes): $e");
      return null;
    }
  }

  static Future<bool> toggleAvailability(
    String tenantId,
    String productId,
    int isAvailable,
  ) async {
    try {
      final tId = tenantId.isNotEmpty ? tenantId : 'startups_main';
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Try GET query request first (bypasses CORS preflight on localhost)
      final getRes = await _get(
        Uri.parse(
          "$baseUrl/toggle_availability.php?tenant_id=$tId&product_id=$productId&is_available=$isAvailable&t=$timestamp",
        ),
      );
      if (getRes.statusCode == 200) {
        final data = json.decode(getRes.body);
        if (data['status'] == 'success') return true;
      }

      // Fallback POST request
      final response = await _post(
        Uri.parse("$baseUrl/toggle_availability.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "tenant_id": tId,
          "product_id": productId,
          "is_available": isAvailable,
        }),
      );
      final res = json.decode(response.body);
      return res['status'] == 'success';
    } catch (e) {
      debugPrint("toggleAvailability Error: $e");
      return false;
    }
  }

  static Future<bool> addCategory(
    String tenantId,
    String title,
    int rank, {
    String icon = 'restaurant_menu',
  }) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/add_category.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "tenant_id": tenantId,
          "title": title,
          "rank": rank,
          "icon": icon,
        }),
      );
      return json.decode(response.body)['status'] == 'success';
    } catch (e) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> updateCategory({
    required String tenantId,
    required String categoryId,
    required String title,
    required int rank,
    required String icon,
  }) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/update_category.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "tenant_id": tenantId,
          "category_id": categoryId,
          "title": title,
          "rank": rank,
          "icon": icon,
        }),
      );
      final data = json.decode(response.body);
      return {
        "success": data['status'] == 'success',
        "message": data['message'],
      };
    } catch (e) {
      return {"success": false, "message": "Connection error"};
    }
  }

  static Future<Map<String, dynamic>> deleteCategory(
    String tenantId,
    String categoryId,
  ) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/delete_category.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"tenant_id": tenantId, "category_id": categoryId}),
      );
      final data = json.decode(response.body);
      return {
        "success": data['status'] == 'success',
        "message": data['message'],
      };
    } catch (e) {
      return {"success": false, "message": "Error"};
    }
  }

  static Future<List<Map<String, dynamic>>?> fetchPurchases(
    String tenantId,
  ) async {
    try {
      final response = await _get(
        Uri.parse("$baseUrl/get_purchases.php?tenant_id=$tenantId"),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success')
          return List<Map<String, dynamic>>.from(data['data']);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>> addPurchase(
    Map<String, dynamic> purchaseData,
  ) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/add_purchase.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode(purchaseData),
      );
      final data = json.decode(response.body);
      return {
        "success": data['status'] == 'success',
        "message": data['message'],
      };
    } catch (e) {
      return {"success": false, "message": "Error"};
    }
  }

  static Future<Map<String, dynamic>> deletePurchase(
    String tenantId,
    String purchaseId,
  ) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/delete_purchase.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"tenant_id": tenantId, "purchase_id": purchaseId}),
      );
      final data = json.decode(response.body);
      return {
        "success": data['status'] == 'success',
        "message": data['message'],
      };
    } catch (e) {
      return {"success": false, "message": "Error"};
    }
  }

  // --- PURCHASE RETURN METHODS ---

  static Future<Map<String, dynamic>> addReturn(
    Map<String, dynamic> returnData,
  ) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/add_return.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode(returnData),
      );
      final data = json.decode(response.body);
      return {
        "success": data['status'] == 'success',
        "message": data['message'] ?? 'Recorded',
      };
    } catch (e) {
      return {"success": false, "message": "Connection Error: $e"};
    }
  }

  static Future<List<Map<String, dynamic>>?> fetchReturns(
    String tenantId,
  ) async {
    try {
      final tId = tenantId.isNotEmpty ? tenantId : 'startups_main';
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final response = await _get(
        Uri.parse("$baseUrl/get_returns.php?tenant_id=$tId&t=$timestamp"),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success')
          return List<Map<String, dynamic>>.from(data['data']);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>> deleteReturn(
    String tenantId,
    String returnId,
  ) async {
    try {
      final tId = tenantId.isNotEmpty ? tenantId : 'startups_main';
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // GET query string request bypasses CORS preflight on localhost
      final getRes = await _get(
        Uri.parse(
          "$baseUrl/delete_return.php?tenant_id=$tId&return_id=$returnId&t=$timestamp",
        ),
      );
      if (getRes.statusCode == 200) {
        final data = json.decode(getRes.body);
        if (data['status'] == 'success')
          return {"success": true, "message": "Return deleted"};
      }

      // Fallback POST
      final response = await _post(
        Uri.parse("$baseUrl/delete_return.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"tenant_id": tId, "return_id": returnId}),
      );
      final data = json.decode(response.body);
      return {
        "success": data['status'] == 'success',
        "message": data['message'] ?? 'Deleted',
      };
    } catch (e) {
      return {"success": false, "message": "Connection Error: $e"};
    }
  }

  // --- SUPPLIER MANAGEMENT METHODS ---

  static Future<List<Map<String, dynamic>>?> fetchSuppliers(
    String tenantId,
  ) async {
    try {
      final response = await _get(
        Uri.parse("$baseUrl/get_suppliers.php?tenant_id=$tenantId"),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success')
          return List<Map<String, dynamic>>.from(data['data']);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>> addSupplier(
    Map<String, dynamic> supplierData,
  ) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/add_supplier.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode(supplierData),
      );
      final data = json.decode(response.body);
      return {
        "success": data['status'] == 'success',
        "message": data['message'],
      };
    } catch (e) {
      return {"success": false};
    }
  }

  static Future<Map<String, dynamic>> updateSupplier(
    Map<String, dynamic> supplierData,
  ) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/update_supplier.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode(supplierData),
      );
      final data = json.decode(response.body);
      return {"success": data['status'] == 'success'};
    } catch (e) {
      return {"success": false};
    }
  }

  static Future<Map<String, dynamic>> deleteSupplier(
    String tenantId,
    String supplierId,
  ) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/delete_supplier.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"tenant_id": tenantId, "id": supplierId}),
      );
      final data = json.decode(response.body);
      return {"success": data['status'] == 'success'};
    } catch (e) {
      return {"success": false};
    }
  }

  static Future<List<Map<String, dynamic>>?> fetchAllOrders(
    String tenantId,
  ) async {
    try {
      final response = await _get(
        Uri.parse("$baseUrl/get_all_orders.php?tenant_id=$tenantId"),
      );
      final data = json.decode(response.body);
      if (response.statusCode == 200 &&
          data is Map<String, dynamic> &&
          data['status'] == 'success' &&
          data['data'] is List) {
        return List<Map<String, dynamic>>.from(data['data']);
      }
      debugPrint('Server order lookup failed: ${response.body}');
      return null;
    } on FormatException catch (e) {
      debugPrint('Invalid or empty response fetching all orders: $e');
      return null;
    } catch (e) {
      debugPrint("Error fetching all orders: $e");
      return null;
    }
  }

  static Future<Map<String, dynamic>> voidOrder(
    String orderId,
    String reason,
  ) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/void_order.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"order_id": orderId, "reason": reason}),
      );
      final decoded = json.decode(response.body);
      if (decoded is Map<String, dynamic>) {
        return {
          "success":
              response.statusCode == 200 && decoded['status'] == 'success',
          "message": decoded['message'] ?? "Could not void this order.",
        };
      }
      return {
        "success": false,
        "message": "The server returned an invalid response.",
      };
    } catch (e) {
      return {"success": false, "message": "Network error: $e"};
    }
  }

  static Future<Map<String, dynamic>> fetchFinancialReport({
    required String from,
    required String to,
  }) async {
    try {
      final uri = Uri.parse(
        "$baseUrl/financial_report.php",
      ).replace(queryParameters: {"from": from, "to": to});
      final response = await _get(uri);
      final decoded = json.decode(response.body);
      if (decoded is Map<String, dynamic>) {
        return {
          "success":
              response.statusCode == 200 && decoded['status'] == 'success',
          ...decoded,
        };
      }
      return {
        "success": false,
        "message": "The server returned an invalid response.",
      };
    } catch (e) {
      return {"success": false, "message": "Network error: $e"};
    }
  }

  static Future<Map<String, dynamic>> staffLogin({
    required String tenantId,
    required String email,
    required String pin,
  }) async {
    try {
      _staffSessionCookie = null;
      _staffApiToken = null;
      _staffApiTokenLoaded = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('staff_api_token');
      final response = await _post(
        Uri.parse("$baseUrl/staff_login.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"tenant_id": tenantId, "email": email, "pin": pin}),
      );
      _captureStaffSessionCookie(response);
      final decoded = json.decode(response.body);
      if (decoded is! Map<String, dynamic>) {
        _staffSessionCookie = null;
        return {
          "success": false,
          "message": "The server returned an invalid login response.",
        };
      }
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          decoded['status'] != 'success' ||
          decoded['user'] is! Map ||
          decoded['token'] is! String ||
          (decoded['token'] as String).isEmpty) {
        _staffSessionCookie = null;
        return {
          "success": false,
          "message": decoded['message'] ?? "Staff login failed.",
        };
      }
      _staffApiToken = decoded['token'] as String;
      await prefs.setString('staff_api_token', _staffApiToken!);
      if (!kIsWeb && _staffSessionCookie == null) {
        await prefs.remove('staff_api_token');
        _staffApiToken = null;
        return {
          "success": false,
          "message": "The server did not establish a staff session.",
        };
      }
      return {
        "success": true,
        "user": decoded['user'],
        "message": decoded['message'],
      };
    } catch (e) {
      _staffSessionCookie = null;
      _staffApiToken = null;
      _staffApiTokenLoaded = true;
      return {"success": false, "message": "Network error"};
    }
  }

  static Future<void> staffLogout() async {
    try {
      await _post(
        Uri.parse("$baseUrl/staff_logout.php"),
        headers: {"Content-Type": "application/json"},
        body: "{}",
      );
    } catch (e) {
      debugPrint("API Error (staffLogout): $e");
    } finally {
      _staffSessionCookie = null;
      _staffApiToken = null;
      _staffApiTokenLoaded = true;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('staff_api_token');
      } catch (e) {
        debugPrint("Could not clear staff API token: $e");
      }
    }
  }

  // --- SUPER ADMIN DASHBOARD METHODS ---

  static Future<Map<String, dynamic>?> fetchAdminStats() async {
    try {
      final response = await _get(Uri.parse("$baseUrl/admin_get_stats.php"));
      if (response.statusCode == 200) return json.decode(response.body)['data'];
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>?> fetchResourceUsage() async {
    try {
      final response = await _get(
        Uri.parse("$baseUrl/admin_get_resources.php"),
      );
      if (response.statusCode == 200)
        return List<Map<String, dynamic>>.from(
          json.decode(response.body)['data'],
        );
      return null;
    } catch (e) {
      return null;
    }
  }

  // --- SUPPORT TICKET STATE & PERSISTENT FALLBACK ---
  static final List<Map<String, dynamic>> _localSupportTickets = [];
  static final Map<String, List<Map<String, dynamic>>> _localTicketReplies = {};

  static Future<void> _ensureLocalTicketsLoaded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ticketsJson = prefs.getString('saved_support_tickets');
      if (ticketsJson != null && ticketsJson.isNotEmpty) {
        final List<dynamic> decoded = json.decode(ticketsJson);
        if (decoded.isNotEmpty) {
          _localSupportTickets.clear();
          // Filter out legacy demo tickets (101, 102)
          _localSupportTickets.addAll(
            decoded
                .map((x) => Map<String, dynamic>.from(x))
                .where(
                  (t) =>
                      t['id'].toString() != '101' &&
                      t['id'].toString() != '102' &&
                      t['is_demo'] != true,
                ),
          );
        }
      }

      if (_localSupportTickets.isEmpty) {
        _seedSampleTicket();
      }

      final repliesJson = prefs.getString('saved_ticket_replies');
      if (repliesJson != null && repliesJson.isNotEmpty) {
        final Map<String, dynamic> decoded = json.decode(repliesJson);
        _localTicketReplies.clear();
        decoded.forEach((key, val) {
          if (key.isNotEmpty && val is List) {
            _localTicketReplies[key] = val
                .map((x) => Map<String, dynamic>.from(x))
                .toList();
          }
        });
      }
    } catch (e) {
      debugPrint("Error loading saved support tickets: $e");
      if (_localSupportTickets.isEmpty) _seedSampleTicket();
    }
  }

  static void _seedSampleTicket() {
    _localSupportTickets.clear();
    _localSupportTickets.add({
      'id': 201,
      'tenant_id': '1',
      'restaurant_name': 'Chiyalaa Cafe & Restaurant',
      'subject': '[POS & Billing] Receipt printer configuration assistance',
      'description':
          'Hello, we need assistance setting up our thermal receipt printer for direct billing.',
      'priority': 'Medium',
      'status': 'Open',
      'created_at': DateTime.now().toString().split('.')[0],
    });
    _persistLocalTickets();
  }

  static Future<void> _persistLocalTickets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'saved_support_tickets',
        json.encode(_localSupportTickets),
      );

      final Map<String, dynamic> repliesMap = {};
      _localTicketReplies.forEach((key, val) {
        repliesMap[key] = val;
      });
      await prefs.setString('saved_ticket_replies', json.encode(repliesMap));
    } catch (e) {
      debugPrint("Error persisting support tickets: $e");
    }
  }

  static Future<List<Map<String, dynamic>>?> fetchSupportTickets() async {
    await _ensureLocalTicketsLoaded();
    List<Map<String, dynamic>> serverTickets = [];
    try {
      final response = await _get(Uri.parse("$baseUrl/admin_get_tickets.php"));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['data'] != null && data['data'] is List) {
          serverTickets = List<Map<String, dynamic>>.from(data['data']);
        }
      }
    } catch (e) {
      debugPrint("Error fetching support tickets: $e");
    }

    // Merge server tickets and local memory tickets using normalized String IDs
    final Map<String, Map<String, dynamic>> mergedMap = {};
    for (var t in _localSupportTickets) {
      mergedMap[t['id'].toString()] = Map<String, dynamic>.from(t);
    }
    for (var t in serverTickets) {
      mergedMap[t['id'].toString()] = Map<String, dynamic>.from(t);
    }

    // Purge demo tickets if real user tickets exist
    final realTickets = mergedMap.values.where((t) {
      String tid = t['id'].toString();
      return tid != '101' && tid != '102' && t['is_demo'] != true;
    }).toList();

    final List<Map<String, dynamic>> listToReturn = realTickets.isNotEmpty
        ? realTickets
        : mergedMap.values.toList();

    listToReturn.sort((a, b) {
      int idA = int.tryParse(a['id'].toString()) ?? 0;
      int idB = int.tryParse(b['id'].toString()) ?? 0;
      return idB.compareTo(idA);
    });

    return listToReturn;
  }

  static Future<List<Map<String, dynamic>>?> fetchTenantStaff(
    String tenantId,
  ) async {
    try {
      final response = await _get(
        Uri.parse("$baseUrl/get_tenant_staff.php?tenant_id=$tenantId"),
      );
      if (response.statusCode == 200)
        return List<Map<String, dynamic>>.from(
          json.decode(response.body)['data'],
        );
      return null;
    } catch (e) {
      return null;
    }
  }

  // --- RESTAURANT ADMIN SUPPORT METHODS ---

  static Future<Map<String, dynamic>> createSupportTicket(
    Map<String, dynamic> ticketData,
  ) async {
    await _ensureLocalTicketsLoaded();

    // Purge initial demo tickets when a real user submits a ticket
    _localSupportTickets.removeWhere(
      (t) =>
          t['id'].toString() == '101' ||
          t['id'].toString() == '102' ||
          t['is_demo'] == true,
    );

    final tenantId = (ticketData['tenant_id'] ?? '1').toString();
    final newId = DateTime.now().millisecondsSinceEpoch % 100000;
    final localTicket = {
      'id': newId,
      'tenant_id': tenantId,
      'restaurant_name':
          TenantService().currentTenant.value?.name ?? 'Restaurant #$tenantId',
      'subject': ticketData['subject'] ?? 'Support Request',
      'description': ticketData['description'] ?? '',
      'priority': ticketData['priority'] ?? 'Medium',
      'status': 'Open',
      'created_at': DateTime.now().toString().split('.')[0],
    };
    _localSupportTickets.insert(0, localTicket);
    await _persistLocalTickets();

    try {
      final response = await _post(
        Uri.parse("$baseUrl/create_ticket.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode(ticketData),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          if (data['ticket_id'] != null) {
            localTicket['id'] = data['ticket_id'];
            await _persistLocalTickets();
          }
          return {
            "success": true,
            "message": data['message'] ?? 'Ticket created successfully',
          };
        }
      }
    } catch (e) {
      debugPrint("Server ticket creation notice: $e");
    }

    return {
      "success": true,
      "message": "Support request submitted successfully.",
    };
  }

  static Future<List<Map<String, dynamic>>?> fetchMyTickets(
    String tenantId,
  ) async {
    await _ensureLocalTicketsLoaded();
    List<Map<String, dynamic>> serverTickets = [];
    try {
      final response = await _get(
        Uri.parse("$baseUrl/get_my_tickets.php?tenant_id=$tenantId"),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['data'] != null && data['data'] is List) {
          serverTickets = List<Map<String, dynamic>>.from(data['data']);
        }
      }
    } catch (e) {
      debugPrint("Error fetching my tickets: $e");
    }

    final Map<String, Map<String, dynamic>> mergedMap = {};
    for (var t in _localSupportTickets.where(
      (x) => x['tenant_id'].toString() == tenantId.toString(),
    )) {
      mergedMap[t['id'].toString()] = Map<String, dynamic>.from(t);
    }
    for (var t in serverTickets) {
      mergedMap[t['id'].toString()] = Map<String, dynamic>.from(t);
    }

    final realTickets = mergedMap.values.where((t) {
      String tid = t['id'].toString();
      return tid != '101' && tid != '102' && t['is_demo'] != true;
    }).toList();

    final List<Map<String, dynamic>> res = realTickets.isNotEmpty
        ? realTickets
        : mergedMap.values.toList();

    res.sort((a, b) {
      int idA = int.tryParse(a['id'].toString()) ?? 0;
      int idB = int.tryParse(b['id'].toString()) ?? 0;
      return idB.compareTo(idA);
    });

    return res;
  }

  static Future<bool> sendTicketReply({
    required dynamic ticketId,
    required String message,
    String senderType = 'Admin',
  }) async {
    await _ensureLocalTicketsLoaded();
    final tidStr = ticketId.toString();

    try {
      final response = await _post(
        Uri.parse("$baseUrl/send_ticket_reply.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "ticket_id": tidStr,
          "message": message,
          "sender_type": senderType,
          "sender": senderType,
        }),
      );
      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        // Clear local cache for this ticket so fresh server history is loaded without duplicates
        _localTicketReplies.remove(tidStr);
        await _persistLocalTickets();
        return true;
      }
    } catch (e) {
      debugPrint("Error sending ticket reply to server: $e");
    }

    // Fallback: save locally only if server is unreachable
    _localTicketReplies.putIfAbsent(tidStr, () => []);
    _localTicketReplies[tidStr]!.add({
      'id': DateTime.now().millisecondsSinceEpoch,
      'ticket_id': tidStr,
      'sender_type': senderType,
      'sender': senderType,
      'message': message,
      'created_at': DateTime.now().toString().split('.')[0],
    });
    await _persistLocalTickets();
    return true;
  }

  static Future<List<Map<String, dynamic>>?> fetchTicketHistory(
    dynamic ticketId,
  ) async {
    await _ensureLocalTicketsLoaded();
    final tidStr = ticketId.toString();

    List<Map<String, dynamic>> serverReplies = [];
    try {
      final response = await _get(
        Uri.parse("$baseUrl/get_ticket_history.php?ticket_id=$tidStr"),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['data'] != null && data['data'] is List) {
          serverReplies = List<Map<String, dynamic>>.from(data['data']);
        }
      }
    } catch (e) {
      debugPrint("Error fetching ticket history: $e");
    }

    if (serverReplies.isNotEmpty) {
      // Server returned canonical database records; update local cache to avoid duplicate rendering
      _localTicketReplies[tidStr] = List<Map<String, dynamic>>.from(
        serverReplies,
      );
      await _persistLocalTickets();

      // Ensure each reply map has normalized sender fields
      for (var r in serverReplies) {
        r['sender_type'] ??= r['sender'];
        r['sender'] ??= r['sender_type'];
      }
      return serverReplies;
    }

    final List<Map<String, dynamic>> local = _localTicketReplies[tidStr] ?? [];
    return local;
  }

  static Future<bool> updateTicketStatus({
    required dynamic ticketId,
    required String status,
  }) async {
    await _ensureLocalTicketsLoaded();
    final tidStr = ticketId.toString();

    for (var t in _localSupportTickets) {
      if (t['id'].toString() == tidStr) {
        t['status'] = status;
      }
    }
    await _persistLocalTickets();

    try {
      final response = await _post(
        Uri.parse("$baseUrl/update_ticket_status.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"ticket_id": tidStr, "status": status}),
      );
      return json.decode(response.body)['status'] == 'success';
    } catch (e) {
      return true;
    }
  }

  static Future<String?> uploadProfilePicture(
    Uint8List bytes,
    String fileName,
  ) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse("$baseUrl/upload_profile.php"),
      );
      request.files.add(
        http.MultipartFile.fromBytes('profile_pic', bytes, filename: fileName),
      );
      final response = await request.send();
      if (response.statusCode == 200) {
        final resStr = await response.stream.bytesToString();
        final data = json.decode(resStr);
        if (data['status'] == 'success') return data['url'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // --- HRM / STAFF METHODS ---

  static Future<bool> addStaff(Map<String, dynamic> staffData) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/add_staff.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode(staffData),
      );
      return json.decode(response.body)['status'] == 'success';
    } catch (e) {
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>?> fetchStaff(String tenantId) async {
    try {
      final response = await _get(
        Uri.parse("$baseUrl/get_staff.php?tenant_id=$tenantId"),
      );
      if (response.statusCode == 200)
        return List<Map<String, dynamic>>.from(
          json.decode(response.body)['data'],
        );
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> updateStaff(Map<String, dynamic> staffData) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/update_staff.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode(staffData),
      );
      return json.decode(response.body)['status'] == 'success';
    } catch (e) {
      return false;
    }
  }

  static Future<bool> deleteStaff(int userId) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/delete_staff.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"user_id": userId}),
      );
      return json.decode(response.body)['status'] == 'success';
    } catch (e) {
      return false;
    }
  }

  // --- DEPARTMENT & DIVISION METHODS ---

  static Future<List<Map<String, dynamic>>?> fetchDepartments(
    String tenantId,
  ) async {
    try {
      final tid = (tenantId.isNotEmpty && tenantId != 'null')
          ? tenantId
          : 'startups_main';
      final response = await _get(
        Uri.parse(
          "$baseUrl/department_api.php?action=get_departments&tenant_id=$tid",
        ),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success')
          return List<Map<String, dynamic>>.from(data['data']);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> addDepartment(Map<String, dynamic> deptData) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/department_api.php?action=add_department"),
        headers: {"Content-Type": "application/json"},
        body: json.encode(deptData),
      );
      return json.decode(response.body)['status'] == 'success';
    } catch (e) {
      return false;
    }
  }

  static Future<bool> updateDepartment(Map<String, dynamic> deptData) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/department_api.php?action=update_department"),
        headers: {"Content-Type": "application/json"},
        body: json.encode(deptData),
      );
      return json.decode(response.body)['status'] == 'success';
    } catch (e) {
      return false;
    }
  }

  static Future<bool> deleteDepartment(int id) async {
    try {
      final response = await _get(
        Uri.parse(
          "$baseUrl/department_api.php?action=delete_department&id=$id",
        ),
      );
      return json.decode(response.body)['status'] == 'success';
    } catch (e) {
      return false;
    }
  }

  // --- SALARY & PAYROLL METHODS ---

  static Future<List<Map<String, dynamic>>?> fetchSalarySetups(
    String tenantId,
  ) async {
    try {
      final tid = (tenantId.isNotEmpty && tenantId != 'null')
          ? tenantId
          : 'startups_main';
      final response = await _get(
        Uri.parse(
          "$baseUrl/salary_api.php?action=get_salary_setups&tenant_id=$tid",
        ),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success')
          return List<Map<String, dynamic>>.from(data['data']);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> updateSalarySetup(Map<String, dynamic> salaryData) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/salary_api.php?action=update_salary_setup"),
        headers: {"Content-Type": "application/json"},
        body: json.encode(salaryData),
      );
      return json.decode(response.body)['status'] == 'success';
    } catch (e) {
      return false;
    }
  }

  static Future<bool> deleteSalarySetup(int userId, String tenantId) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/salary_api.php?action=delete_salary_setup"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"user_id": userId, "tenant_id": tenantId}),
      );
      return json.decode(response.body)['status'] == 'success';
    } catch (e) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> saveSalaryPayout(
    Map<String, dynamic> payoutData,
  ) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/salary_payout_api.php?action=save_salary_payout"),
        headers: {"Content-Type": "application/json"},
        body: json.encode(payoutData),
      );
      return json.decode(response.body);
    } catch (e) {
      return {"status": "error", "message": "Connection error"};
    }
  }

  static Future<List<Map<String, dynamic>>?> fetchSalaryPayoutHistory(
    String tenantId, {
    int? userId,
  }) async {
    try {
      final tid = (tenantId.isNotEmpty && tenantId != 'null')
          ? tenantId
          : 'startups_main';
      String payoutEndpoint =
          "$baseUrl/salary_payout_api.php?action=get_payout_history&tenant_id=$tid";
      if (userId != null && userId > 0) payoutEndpoint += "&user_id=$userId";

      final response = await _get(Uri.parse(payoutEndpoint));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success')
          return List<Map<String, dynamic>>.from(data['data']);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // --- PAYMENT METHODS MANAGEMENT APIs ---
  static final Map<String, List<Map<String, dynamic>>>
  _localPaymentMethodsByTenant = {};
  static final Set<String> _loadedLocalPaymentMethodTenants = {};

  static String _localPaymentMethodsKey(String tenantId) =>
      'saved_local_payment_methods_${Uri.encodeComponent(tenantId)}';

  static Future<List<Map<String, dynamic>>> _localPaymentMethodsForTenant(
    String tenantId,
  ) async {
    if (_loadedLocalPaymentMethodTenants.contains(tenantId)) {
      return _localPaymentMethodsByTenant[tenantId] ?? [];
    }

    final methods = <Map<String, dynamic>>[];
    try {
      final prefs = await SharedPreferences.getInstance();
      final scopedJson = prefs.getString(_localPaymentMethodsKey(tenantId));
      final jsonStr =
          scopedJson ?? prefs.getString('saved_local_payment_methods');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> decoded = json.decode(jsonStr);
        for (var d in decoded) {
          if (d is! Map) continue;
          final method = Map<String, dynamic>.from(d);
          if ((method['tenant_id'] ?? '').toString() != tenantId) continue;
          final mId = (d['method_id'] ?? d['id'] ?? '').toString();
          if (mId.isNotEmpty &&
              !methods.any(
                (existing) =>
                    (existing['method_id'] ?? existing['id']).toString() == mId,
              )) {
            methods.add(method);
          }
        }
        if (scopedJson == null && methods.isNotEmpty) {
          await prefs.setString(
            _localPaymentMethodsKey(tenantId),
            json.encode(methods),
          );
        }
      }
    } catch (e) {
      debugPrint(
        "Error loading local payment methods for tenant $tenantId: $e",
      );
    }
    _localPaymentMethodsByTenant[tenantId] = methods;
    _loadedLocalPaymentMethodTenants.add(tenantId);
    return methods;
  }

  static Future<void> _persistLocalPaymentMethods(String tenantId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _localPaymentMethodsKey(tenantId),
        json.encode(_localPaymentMethodsByTenant[tenantId] ?? []),
      );
    } catch (e) {
      debugPrint(
        "Error persisting local payment methods for tenant $tenantId: $e",
      );
    }
  }

  static Future<List<Map<String, dynamic>>> fetchPaymentMethods(
    String tenantId,
  ) async {
    final tid = (tenantId.isNotEmpty && tenantId != 'null')
        ? tenantId
        : 'startups_main';
    final localMethods = await _localPaymentMethodsForTenant(tid);
    List<Map<String, dynamic>> serverMethods = [];
    try {
      final response = await _get(
        Uri.parse(
          "$baseUrl/payment_methods_api.php?action=get_payment_methods&tenant_id=$tid",
        ),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' &&
            data['data'] != null &&
            data['data'] is List) {
          serverMethods = List<Map<String, dynamic>>.from(data['data']);
        }
      }
    } catch (e) {
      debugPrint("API Error fetching payment methods: $e");
    }

    final Map<String, Map<String, dynamic>> map = {};
    for (var m in serverMethods) {
      final methodTenant = (m['tenant_id'] ?? '').toString();
      if (methodTenant.isNotEmpty && methodTenant != tid) continue;
      final mId = (m['method_id'] ?? m['id'] ?? '').toString();
      if (mId.isNotEmpty) map[mId] = Map<String, dynamic>.from(m);
    }
    for (var m in localMethods) {
      final mId = (m['method_id'] ?? m['id'] ?? '').toString();
      if (mId.isNotEmpty) map[mId] = Map<String, dynamic>.from(m);
    }

    return map.values.toList();
  }

  static Future<List<Map<String, dynamic>>> fetchActivePaymentMethods(
    String tenantId,
  ) async {
    final all = await fetchPaymentMethods(tenantId);
    return all
        .where(
          (m) =>
              m['is_active'] == true ||
              m['is_active'] == 1 ||
              m['is_active'] == '1',
        )
        .toList();
  }

  static Future<bool> togglePaymentMethodStatus(
    String tenantId,
    String methodId,
    bool isActive,
  ) async {
    final tid = (tenantId.isNotEmpty && tenantId != 'null')
        ? tenantId
        : 'startups_main';
    final localMethods = await _localPaymentMethodsForTenant(tid);

    for (var m in localMethods) {
      if ((m['method_id'] ?? m['id']).toString() == methodId) {
        m['is_active'] = isActive ? 1 : 0;
      }
    }
    await _persistLocalPaymentMethods(tid);

    try {
      final response = await _post(
        Uri.parse(
          "$baseUrl/payment_methods_api.php?action=toggle_payment_method",
        ),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "tenant_id": tid,
          "method_id": methodId,
          "is_active": isActive,
        }),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['status'] == 'success';
      }
    } catch (e) {
      debugPrint("API Error toggling payment method: $e");
    }
    return false;
  }

  static Future<bool> savePaymentMethod(
    String tenantId,
    Map<String, dynamic> methodData,
  ) async {
    final tid = (tenantId.isNotEmpty && tenantId != 'null')
        ? tenantId
        : 'startups_main';
    final localMethods = await _localPaymentMethodsForTenant(tid);
    final payload = Map<String, dynamic>.from(methodData);
    payload['tenant_id'] = tid;

    final mId = (payload['method_id'] ?? payload['id'] ?? '').toString();
    final idx = localMethods.indexWhere(
      (m) => (m['method_id'] ?? m['id']).toString() == mId,
    );
    if (idx >= 0) {
      localMethods[idx] = payload;
    } else {
      localMethods.add(payload);
    }
    await _persistLocalPaymentMethods(tid);

    try {
      final response = await _post(
        Uri.parse(
          "$baseUrl/payment_methods_api.php?action=save_payment_method",
        ),
        headers: {"Content-Type": "application/json"},
        body: json.encode(payload),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint("savePaymentMethod response: ${response.body}");
        return data['status'] == 'success';
      }
    } catch (e) {
      debugPrint("API Error saving payment method: $e");
    }
    return false;
  }

  static Future<bool> deletePaymentMethod(
    String tenantId,
    String methodId,
  ) async {
    final tid = (tenantId.isNotEmpty && tenantId != 'null')
        ? tenantId
        : 'startups_main';
    final localMethods = await _localPaymentMethodsForTenant(tid);
    localMethods.removeWhere(
      (m) => (m['method_id'] ?? m['id']).toString() == methodId,
    );
    await _persistLocalPaymentMethods(tid);

    try {
      final response = await _post(
        Uri.parse(
          "$baseUrl/payment_methods_api.php?action=delete_payment_method",
        ),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"tenant_id": tid, "method_id": methodId}),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['status'] == 'success';
      }
    } catch (e) {
      debugPrint("API Error deleting payment method: $e");
    }
    return false;
  }

  static Future<List<Map<String, dynamic>>?> fetchDivisions(
    String tenantId,
  ) async {
    try {
      final response = await _get(
        Uri.parse(
          "$baseUrl/department_api.php?action=get_divisions&tenant_id=$tenantId",
        ),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success')
          return List<Map<String, dynamic>>.from(data['data']);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> addDivision(Map<String, dynamic> divData) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/department_api.php?action=add_division"),
        headers: {"Content-Type": "application/json"},
        body: json.encode(divData),
      );
      return json.decode(response.body)['status'] == 'success';
    } catch (e) {
      return false;
    }
  }

  static Future<bool> assignDivisionStaff(
    int divisionId,
    int staffCount,
    List<String> assignedStaff,
  ) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/department_api.php?action=assign_division_staff"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "id": divisionId,
          "staff_count": staffCount,
          "assigned_staff": assignedStaff,
        }),
      );
      return json.decode(response.body)['status'] == 'success';
    } catch (e) {
      return false;
    }
  }

  static Future<bool> updateDivision(Map<String, dynamic> divData) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/department_api.php?action=update_division"),
        headers: {"Content-Type": "application/json"},
        body: json.encode(divData),
      );
      return json.decode(response.body)['status'] == 'success';
    } catch (e) {
      return false;
    }
  }

  static Future<bool> deleteDivision(int id) async {
    try {
      final response = await _get(
        Uri.parse("$baseUrl/department_api.php?action=delete_division&id=$id"),
      );
      return json.decode(response.body)['status'] == 'success';
    } catch (e) {
      return false;
    }
  }

  static Future<bool> markAttendance(
    List<Map<String, dynamic>> attendanceData,
  ) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/mark_attendance.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"attendance": attendanceData}),
      );
      return json.decode(response.body)['status'] == 'success';
    } catch (e) {
      return false;
    }
  }

  static Future<bool> markSingleAttendance(Map<String, dynamic> record) async {
    return markAttendance([record]);
  }

  static Future<List<Map<String, dynamic>>?> fetchAttendance(
    String tenantId,
    String date,
  ) async {
    try {
      final response = await _get(
        Uri.parse("$baseUrl/get_attendance.php?tenant_id=$tenantId&date=$date"),
      );
      if (response.statusCode == 200)
        return List<Map<String, dynamic>>.from(
          json.decode(response.body)['data'],
        );
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>?> fetchAttendanceReport(
    String tenantId,
    String start,
    String end,
  ) async {
    try {
      final response = await _get(
        Uri.parse(
          "$baseUrl/get_attendance_report.php?tenant_id=$tenantId&start=$start&end=$end",
        ),
      );
      if (response.statusCode == 200)
        return List<Map<String, dynamic>>.from(
          json.decode(response.body)['data'],
        );
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> fetchAttendanceAnalytics(
    String tenantId,
    String range,
  ) async {
    try {
      final response = await _get(
        Uri.parse(
          "$baseUrl/get_attendance_analytics.php?tenant_id=$tenantId&range=$range",
        ),
      );
      if (response.statusCode == 200) return json.decode(response.body);
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> fetchEmployeeStats(
    int userId,
    String month,
  ) async {
    try {
      final response = await _get(
        Uri.parse(
          "$baseUrl/get_employee_stats.php?user_id=$userId&month=$month",
        ),
      );
      if (response.statusCode == 200) return json.decode(response.body);
      return null;
    } catch (e) {
      return null;
    }
  }

  static String _userOrdersCacheKey(String tenantId, String userId) {
    return 'user_orders_${Uri.encodeComponent(tenantId)}_${Uri.encodeComponent(userId)}';
  }

  static Future<List<Map<String, dynamic>>> getCachedUserOrders(
    String tenantId,
    String userId,
  ) async {
    if (tenantId.isEmpty || userId.isEmpty) return [];
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = prefs.getString(_userOrdersCacheKey(tenantId, userId));
      if (encoded == null || encoded.isEmpty) return [];
      final decoded = json.decode(encoded);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((order) => Map<String, dynamic>.from(order))
          .toList();
    } catch (e) {
      debugPrint("Could not load cached user orders: $e");
      return [];
    }
  }

  static Future<void> cacheUserOrders(
    String tenantId,
    String userId,
    List<Map<String, dynamic>> orders,
  ) async {
    if (tenantId.isEmpty || userId.isEmpty || orders.isEmpty) return;
    try {
      final existing = await getCachedUserOrders(tenantId, userId);
      final merged = <String, Map<String, dynamic>>{
        for (final order in existing)
          if (order['id'] != null) order['id'].toString(): order,
      };
      for (final order in orders) {
        final id = order['id']?.toString();
        if (id != null && id.isNotEmpty) merged[id] = order;
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _userOrdersCacheKey(tenantId, userId),
        json.encode(merged.values.toList()),
      );
    } catch (e) {
      debugPrint("Could not save cached user orders: $e");
    }
  }

  static Future<void> _cachePlacedOrder(
    Map<String, dynamic> orderData,
    int orderId,
    int? orderNumber,
  ) async {
    final tenantId = orderData['tenant_id']?.toString() ?? '';
    final userId = orderData['user_id']?.toString() ?? '';
    if (tenantId.isEmpty || userId.isEmpty) return;

    final rawItems = orderData['items'];
    final items = rawItems is List
        ? rawItems.whereType<Map>().map((item) {
            final normalized = Map<String, dynamic>.from(item);
            normalized['product_name'] ??=
                normalized['name']?.toString() ?? 'Food Item';
            return normalized;
          }).toList()
        : <Map<String, dynamic>>[];
    final snapshot = <String, dynamic>{
      'id': orderId,
      if (orderNumber != null) 'tenant_order_number': orderNumber,
      'tenant_id': tenantId,
      'user_id': userId,
      'customer_email': orderData['customer_email'] ?? '',
      'table_number': orderData['table_number'] ?? 1,
      'total_amount': orderData['total_amount'] ?? 0,
      'status': 'Pending',
      'created_at': DateTime.now().toIso8601String(),
      'items': items,
    };
    await cacheUserOrders(tenantId, userId, [snapshot]);

    final email = orderData['customer_email']?.toString() ?? '';
    if (email.isNotEmpty && email != userId) {
      await cacheUserOrders(tenantId, email, [snapshot]);
    }
  }

  static Future<Map<String, dynamic>?> placeTableOrder(
    Map<String, dynamic> orderData,
  ) async {
    try {
      final requestData = Map<String, dynamic>.from(orderData);
      requestData.putIfAbsent('idempotency_key', newIdempotencyKey);
      final response = await _post(
        Uri.parse("$baseUrl/place_order.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode(requestData),
      );

      final decoded = json.decode(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
          "Order request failed (HTTP ${response.statusCode}): ${response.body}",
        );
        if (decoded is Map<String, dynamic>) {
          return {
            ...decoded,
            'status': 'error',
            'http_status': response.statusCode,
            'message':
                decoded['message']?.toString() ??
                'The server rejected this order (HTTP ${response.statusCode}).',
          };
        }
        return {
          'status': 'error',
          'http_status': response.statusCode,
          'message':
              'The server rejected this order (HTTP ${response.statusCode}).',
        };
      }

      if (decoded is! Map<String, dynamic> || decoded['status'] != 'success') {
        debugPrint(
          "Order request was not confirmed by the server: ${response.body}",
        );
        return {
          'status': 'error',
          'message': decoded is Map<String, dynamic>
              ? decoded['message']?.toString() ??
                    'The server did not confirm this order.'
              : 'The server returned an invalid order response.',
        };
      }

      final orderId = int.tryParse(decoded['order_id']?.toString() ?? '');
      if (orderId == null || orderId <= 0) {
        debugPrint("Order response did not contain a valid database order ID.");
        return null;
      }

      if (decoded['total_amount'] != null) {
        requestData['total_amount'] = decoded['total_amount'];
      }
      if (decoded['items'] is List) {
        requestData['items'] = decoded['items'];
      }
      final orderNumber = int.tryParse(
        decoded['order_number']?.toString() ?? '',
      );
      await _cachePlacedOrder(requestData, orderId, orderNumber);
      return {...decoded, 'order_id': orderId};
    } catch (e) {
      debugPrint("Order request failed: $e");
      return null;
    }
  }

  static Future<Map<String, dynamic>> updateOrderStatus(
    int orderId,
    String status, {
    String? paymentMethod,
  }) async {
    try {
      final payload = <String, dynamic>{
        "order_id": orderId,
        "new_status": status,
      };
      if (paymentMethod != null && paymentMethod.isNotEmpty) {
        payload['payment_method'] = paymentMethod;
      }
      final response = await _post(
        Uri.parse("$baseUrl/update_order_status.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode(payload),
      );

      final decoded = json.decode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return {
          "success": false,
          "message": "The server returned an invalid status response.",
        };
      }
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          !(decoded['status'] == 'success' || decoded['success'] == true)) {
        return {
          "success": false,
          "message":
              decoded['message']?.toString() ??
              "The server could not update this order.",
        };
      }

      return {"success": true, "message": decoded['message']};
    } catch (e) {
      debugPrint("API Error (updateOrderStatus): $e");
      return {
        "success": false,
        "message":
            "Could not update the order. Check the connection and retry.",
      };
    }
  }

  static Future<Map<String, dynamic>?> fetchSessionBill({
    int? sessionId,
    int? tableId,
  }) async {
    if ((sessionId == null) == (tableId == null)) {
      return null;
    }
    try {
      final query = sessionId != null
          ? 'session_id=$sessionId'
          : 'table_id=$tableId';
      final response = await _get(
        Uri.parse('$baseUrl/get_session_bill.php?$query'),
      );
      final decoded = json.decode(response.body);
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          decoded is! Map<String, dynamic> ||
          decoded['status'] != 'success') {
        debugPrint('Session bill request failed: ${response.body}');
        return null;
      }
      return decoded;
    } on FormatException catch (e) {
      debugPrint('Invalid or empty response fetching session bill: $e');
      return null;
    } catch (e) {
      debugPrint('API Error (fetchSessionBill): $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>> updateSessionStatus({
    int? sessionId,
    int? tableId,
    required String status,
  }) async {
    if ((sessionId == null) == (tableId == null)) {
      return {
        'success': false,
        'message': 'Select one dining session or table.',
      };
    }
    try {
      final response = await _post(
        Uri.parse('$baseUrl/update_session_status.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          if (sessionId != null) 'session_id': sessionId,
          if (tableId != null) 'table_id': tableId,
          'status': status,
        }),
      );
      final decoded = json.decode(response.body);
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          decoded is! Map<String, dynamic> ||
          decoded['status'] != 'success') {
        return {
          'success': false,
          'message': decoded is Map<String, dynamic>
              ? decoded['message']?.toString() ??
                    'Could not update the session.'
              : 'The server returned an invalid session status response.',
        };
      }
      return {...decoded, 'success': true};
    } catch (e) {
      debugPrint('API Error (updateSessionStatus): $e');
      return {
        'success': false,
        'message':
            'Could not update the session. Check the connection and retry.',
      };
    }
  }

  static Future<Map<String, dynamic>> reopenSession({
    int? sessionId,
    int? tableId,
  }) async {
    if ((sessionId == null) == (tableId == null)) {
      return {
        'success': false,
        'message': 'Select one dining session or table.',
      };
    }
    try {
      final response = await _post(
        Uri.parse('$baseUrl/reopen_session.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          if (sessionId != null) 'session_id': sessionId,
          if (tableId != null) 'table_id': tableId,
        }),
      );
      final decoded = json.decode(response.body);
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          decoded is! Map<String, dynamic> ||
          decoded['status'] != 'success') {
        return {
          'success': false,
          'message': decoded is Map<String, dynamic>
              ? decoded['message']?.toString() ??
                    'Could not reopen the session.'
              : 'The server returned an invalid session response.',
        };
      }
      return {...decoded, 'success': true};
    } catch (e) {
      debugPrint('API Error (reopenSession): $e');
      return {
        'success': false,
        'message':
            'Could not reopen the session. Check the connection and retry.',
      };
    }
  }

  static Future<Map<String, dynamic>> getBillingSettings() async {
    try {
      final response = await _get(
        Uri.parse('$baseUrl/get_billing_settings.php'),
      );
      final decoded = json.decode(response.body);
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          decoded is! Map<String, dynamic> ||
          decoded['status'] != 'success') {
        return {
          'success': false,
          'message': decoded is Map<String, dynamic>
              ? decoded['message']?.toString() ??
                    'Could not load billing rates.'
              : 'The server returned invalid billing settings.',
        };
      }
      return {...decoded, 'success': true};
    } catch (e) {
      debugPrint('API Error (getBillingSettings): $e');
      return {'success': false, 'message': 'Could not load billing rates.'};
    }
  }

  static Future<Map<String, dynamic>> saveBillingSettings({
    required double vatPercentage,
    required double serviceCharge,
  }) async {
    try {
      // Try update_tenant_settings.php first, fallback to save_billing_settings.php
      http.Response response;
      try {
        response = await _post(
          Uri.parse('$baseUrl/update_tenant_settings.php'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'vat_percentage': vatPercentage,
            'service_charge': serviceCharge,
          }),
        );
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw Exception('Endpoint failed with status ${response.statusCode}');
        }
      } catch (_) {
        response = await _post(
          Uri.parse('$baseUrl/save_billing_settings.php'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'vat_percentage': vatPercentage,
            'service_charge': serviceCharge,
          }),
        );
      }
      final decoded = json.decode(response.body);
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          decoded is! Map<String, dynamic> ||
          decoded['status'] != 'success') {
        return {
          'success': false,
          'message': decoded is Map<String, dynamic>
              ? decoded['message']?.toString() ??
                    'Could not save billing rates.'
              : 'The server returned an invalid billing settings response.',
        };
      }
      return {...decoded, 'success': true};
    } catch (e) {
      debugPrint('API Error (saveBillingSettings): $e');
      return {'success': false, 'message': 'Could not save billing rates.'};
    }
  }

  static Future<Map<String, dynamic>> settleBill({
    required String tenantId,
    required String idempotencyKey,
    String? amount,
    String? method,
    List<Map<String, dynamic>>? payments,
    int? sessionId,
    List<int>? orderIds,
  }) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/settle_bill.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "tenant_id": tenantId,
          if (sessionId != null) "session_id": sessionId,
          if (orderIds != null) "order_ids": orderIds,
          if (payments != null)
            "payments": payments
          else ...{
            if (amount != null) "amount": amount,
            if (method != null) "method": method,
          },
          "idempotency_key": idempotencyKey,
        }),
      );
      final decoded = json.decode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return {
          "success": false,
          "ambiguous": true,
          "message": "The server returned an invalid settlement response.",
        };
      }
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          !(decoded['status'] == 'success' || decoded['success'] == true)) {
        return {
          ...decoded,
          "success": false,
          "message":
              decoded['message']?.toString() ??
              "The server could not settle this bill.",
        };
      }
      return {...decoded, "success": true};
    } catch (e) {
      debugPrint("API Error (settleBill): $e");
      return {
        "success": false,
        "ambiguous": true,
        "message":
            "Settlement could not be confirmed. Verify the bill status before retrying.",
      };
    }
  }

  static Future<String?> fetchOrderStatus(
    int orderId, {
    required String tenantId,
  }) async {
    try {
      final response = await _get(
        Uri.parse("$baseUrl/get_order_status.php").replace(
          queryParameters: {
            'order_id': orderId.toString(),
            'tenant_id': tenantId,
          },
        ),
      );
      if (response.statusCode == 200)
        return json.decode(response.body)['order_status'];
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>> waiterApproveOrder(
    int orderId,
    int waiterId,
  ) async {
    return updateOrderStatus(orderId, 'Approved');
  }

  static Future<Map<String, dynamic>> waiterAcceptDelivery(
    int orderId,
    int waiterId,
  ) async {
    return updateOrderStatus(orderId, 'OnWay');
  }

  static Future<List<Map<String, dynamic>>?> fetchActiveOrders(
    String tenantId,
  ) async {
    final allOrders = await fetchAllOrders(tenantId);
    if (allOrders == null) return null;
    return allOrders.where((o) {
      final st = (o['status'] ?? '').toString().toLowerCase();
      return st != 'cancelled' &&
          st != 'canceled' &&
          st != 'settled' &&
          st != 'voided';
    }).toList();
  }

  static Future<List<Map<String, dynamic>>?> fetchServerActiveOrders(
    String tenantId,
  ) async {
    try {
      final response = await _get(
        Uri.parse("$baseUrl/get_all_orders.php?tenant_id=$tenantId"),
      );
      final decoded = json.decode(response.body);
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          decoded is! Map<String, dynamic> ||
          decoded['status'] != 'success' ||
          decoded['data'] is! List) {
        return null;
      }
      return List<Map<String, dynamic>>.from(decoded['data']).where((order) {
        final status = (order['status'] ?? '').toString().toLowerCase();
        return status != 'cancelled' && status != 'settled';
      }).toList();
    } catch (e) {
      debugPrint("API Error (fetchServerActiveOrders): $e");
      return null;
    }
  }

  static Future<Map<String, dynamic>> uploadVoiceOrder({
    required String tenantId,
    required int tableNumber,
    required String customerName,
    required String transcript,
    List<int>? audioBytes,
    String? audioFileName,
  }) async {
    try {
      if (transcript.trimLeft().startsWith('ASSISTANCE:')) {
        final requestText = transcript.trim().replaceFirst(
          RegExp(r'^ASSISTANCE:\s*'),
          '',
        );
        final response = await _post(
          Uri.parse('$baseUrl/waiter_assistance_api.php?action=create'),
          headers: {"Content-Type": "application/json"},
          body: json.encode({
            "tenant_id": tenantId,
            "table_number": tableNumber,
            "customer_name": customerName,
            "request_text": requestText,
          }),
        );
        final result = json.decode(response.body);
        return result is Map<String, dynamic>
            ? result
            : {
                "status": "error",
                "message": "Invalid waiter assistance response",
              };
      }

      final Uri url = Uri.parse("$baseUrl/upload_voice_order.php");

      if (audioBytes != null && audioBytes.isNotEmpty) {
        var request = http.MultipartRequest('POST', url);
        request.fields['tenant_id'] = tenantId;
        request.fields['table_number'] = tableNumber.toString();
        request.fields['customer_name'] = customerName;
        request.fields['transcript'] = transcript;

        request.files.add(
          http.MultipartFile.fromBytes(
            'audio_file',
            audioBytes,
            filename: audioFileName ?? 'voice_order.m4a',
          ),
        );

        var streamedResponse = await request.send();
        var response = await http.Response.fromStream(streamedResponse);
        return json.decode(response.body);
      } else {
        final response = await _post(
          url,
          headers: {"Content-Type": "application/json"},
          body: json.encode({
            "tenant_id": tenantId,
            "table_number": tableNumber,
            "customer_name": customerName,
            "transcript": transcript,
          }),
        );
        return json.decode(response.body);
      }
    } catch (e) {
      return {"status": "error", "message": "Connection error: $e"};
    }
  }

  static Future<List<Map<String, dynamic>>?> fetchVoiceOrders(
    String tenantId,
  ) async {
    final orders = <Map<String, dynamic>>[];
    var succeeded = false;
    try {
      final response = await _get(
        Uri.parse("$baseUrl/get_voice_orders.php?tenant_id=$tenantId"),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic> && data['status'] == 'success') {
          orders.addAll(List<Map<String, dynamic>>.from(data['orders'] ?? []));
          succeeded = true;
        }
      }
    } catch (e) {
      debugPrint("API Error fetching voice orders: $e");
    }

    try {
      final response = await _get(
        Uri.parse(
          "$baseUrl/waiter_assistance_api.php?action=list&tenant_id=${Uri.encodeQueryComponent(tenantId)}",
        ),
      );
      final data = json.decode(response.body);
      if (response.statusCode == 200 &&
          data is Map<String, dynamic> &&
          data['status'] == 'success' &&
          data['orders'] is List) {
        orders.addAll(List<Map<String, dynamic>>.from(data['orders']));
        succeeded = true;
      } else {
        debugPrint(
          "Server could not load waiter assistance requests: ${response.body}",
        );
      }
    } catch (e) {
      debugPrint("API Error fetching waiter assistance requests: $e");
    }
    return succeeded ? orders : null;
  }

  static Future<Map<String, dynamic>> requestWaiterAssistance({
    required String tenantId,
    required int tableNumber,
    required String customerName,
    required String assistanceType,
    String? notes,
  }) async {
    final trimmedNotes = notes?.trim() ?? '';
    final String transcript =
        "ASSISTANCE: $assistanceType - ${trimmedNotes.isEmpty ? 'Immediate assistance requested' : trimmedNotes}";
    return uploadVoiceOrder(
      tenantId: tenantId,
      tableNumber: tableNumber,
      customerName: customerName,
      transcript: transcript,
    );
  }

  static Future<Map<String, dynamic>> updateVoiceOrderStatus(
    int voiceOrderId,
    String newStatus,
  ) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/update_voice_order_status.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "voice_order_id": voiceOrderId,
          "new_status": newStatus,
        }),
      );
      final result = json.decode(response.body);
      if (result['status'] == 'success') {
        return {"success": true};
      } else {
        return {
          "success": false,
          "message": result['message'] ?? "Unknown Error",
        };
      }
    } catch (e) {
      return {"success": false, "message": "Connection error: $e"};
    }
  }

  static Future<Map<String, dynamic>> completeWaiterAssistance(
    int requestId,
  ) async {
    try {
      final response = await _post(
        Uri.parse('$baseUrl/waiter_assistance_api.php?action=complete'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"request_id": requestId}),
      );
      final result = json.decode(response.body);
      if (result is Map<String, dynamic> &&
          response.statusCode >= 200 &&
          response.statusCode < 300 &&
          result['status'] == 'success') {
        return {"success": true};
      }
      return {
        "success": false,
        "message": result is Map<String, dynamic>
            ? result['message']?.toString() ??
                  "Could not complete the assistance request"
            : "Invalid waiter assistance response",
      };
    } catch (e) {
      debugPrint("API Error completing waiter assistance request: $e");
      return {
        "success": false,
        "message": "Could not complete the assistance request",
      };
    }
  }

  static Future<List<Map<String, dynamic>>?> fetchWaiterReadyTasks(
    String tenantId,
  ) async {
    try {
      final response = await _get(
        Uri.parse(
          '$baseUrl/waiter_ready_api.php?action=list&tenant_id=${Uri.encodeQueryComponent(tenantId)}',
        ),
      );
      final result = json.decode(response.body);
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          result is Map<String, dynamic> &&
          result['status'] == 'success' &&
          result['tasks'] is List) {
        return List<Map<String, dynamic>>.from(result['tasks']);
      }
      debugPrint('Could not load ready waiter tasks: ${response.body}');
      return null;
    } catch (e) {
      debugPrint('API Error loading ready waiter tasks: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>> notifyWaitersOrderReady(
    int orderId,
  ) async {
    return _waiterReadyTaskAction('notify', {'order_id': orderId});
  }

  static Future<Map<String, dynamic>> acceptWaiterReadyTask(int taskId) async {
    return _waiterReadyTaskAction('accept', {'task_id': taskId});
  }

  static Future<Map<String, dynamic>> completeWaiterReadyTask(
    int taskId,
  ) async {
    return _waiterReadyTaskAction('complete', {'task_id': taskId});
  }

  static Future<Map<String, dynamic>> _waiterReadyTaskAction(
    String action,
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await _post(
        Uri.parse('$baseUrl/waiter_ready_api.php?action=$action'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );
      final result = json.decode(response.body);
      if (result is Map<String, dynamic> &&
          response.statusCode >= 200 &&
          response.statusCode < 300 &&
          result['status'] == 'success') {
        return {'success': true, ...result};
      }
      return {
        'success': false,
        'message': result is Map<String, dynamic>
            ? result['message']?.toString() ??
                  'Could not process the waiter service task.'
            : 'Invalid waiter service task response.',
      };
    } catch (e) {
      debugPrint('API Error for waiter ready task ($action): $e');
      return {
        'success': false,
        'message':
            'Could not process the waiter service task. Check the connection and retry.',
      };
    }
  }

  static Future<Map<String, dynamic>> deleteVoiceOrder(int voiceOrderId) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/delete_voice_order.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"voice_order_id": voiceOrderId}),
      );
      final result = json.decode(response.body);
      if (result['status'] == 'success') {
        return {"success": true};
      } else {
        return {
          "success": false,
          "message": result['message'] ?? "Unknown Error",
        };
      }
    } catch (e) {
      return {"success": false, "message": "Connection error: $e"};
    }
  }

  static Future<List<Map<String, dynamic>>?> fetchPendingOrders(
    String tenantId,
  ) async {
    final orders = await fetchAllOrders(tenantId);
    if (orders == null) return null;
    return orders.where((order) {
      final status = (order['status'] ?? '').toString().toLowerCase();
      return status == 'pending' || status == 'awaiting approval';
    }).toList();
  }

  static Future<List<Map<String, dynamic>>?> fetchOrderHistory(
    String tenantId,
  ) async {
    final orders = await fetchAllOrders(tenantId);
    if (orders == null) return null;
    return orders.where((order) {
      final status = (order['status'] ?? '').toString().toLowerCase();
      return status == 'completed' ||
          status == 'served' ||
          status == 'onway' ||
          status == 'cancelled' ||
          status == 'canceled' ||
          status == 'settled' ||
          status == 'voided';
    }).toList();
  }

  static Future<Map<String, dynamic>?> fetchLatestOrder(
    String tenantId,
    String userId,
  ) async {
    try {
      final response = await _get(
        Uri.parse(
          "$baseUrl/get_user_orders.php?tenant_id=$tenantId&user_id=$userId",
        ),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' &&
            data['orders'] != null &&
            (data['orders'] as List).isNotEmpty) {
          return Map<String, dynamic>.from(data['orders'][0]);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>> addTable(
    String tenantId,
    int tableNumber,
  ) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/add_table.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"tenant_id": tenantId, "table_number": tableNumber}),
      );
      final decoded = json.decode(response.body);
      if (decoded is Map<String, dynamic> &&
          response.statusCode >= 200 &&
          response.statusCode < 300 &&
          decoded['status'] == 'success') {
        return {"success": true};
      }
      return {
        "success": false,
        "message": decoded is Map<String, dynamic>
            ? decoded['message']?.toString() ??
                  "The server could not add this table."
            : "The server returned an invalid response while adding the table.",
      };
    } catch (e) {
      debugPrint("Server add table request failed: $e");
      return {
        "success": false,
        "message": "Could not connect to the server to add this table.",
      };
    }
  }

  static Future<List<Map<String, dynamic>>?> fetchTables(
    String tenantId, {
    bool onlyActive = false,
  }) async {
    try {
      final response = await _get(
        Uri.parse(
          '$baseUrl/get_tables.php?tenant_id=${Uri.encodeQueryComponent(tenantId)}',
        ),
      );
      if (response.statusCode != 200) {
        debugPrint('Server table lookup failed: ${response.body}');
        return null;
      }
      final decoded = json.decode(response.body);
      if (decoded is! Map<String, dynamic> ||
          decoded['status'] != 'success' ||
          decoded['data'] is! List) {
        debugPrint('Server returned an invalid table list.');
        return null;
      }
      var resultTables = List<Map<String, dynamic>>.from(
        (decoded['data'] as List).map((table) {
          final item = Map<String, dynamic>.from(table as Map);
          item['status'] =
              item['lifecycle_status']?.toString() ??
              item['status']?.toString() ??
              'Available';
          return item;
        }),
      );
      if (onlyActive) {
        resultTables = resultTables.where((table) {
          final enabled = table['is_enabled'] ?? table['is_active'] ?? true;
          return enabled.toString() != '0' && enabled.toString() != 'false';
        }).toList();
      }
      return resultTables;
    } catch (e) {
      debugPrint("Error fetching tables from server: $e");
      return null;
    }
  }

  static Future<bool> deleteTable(dynamic tableId) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/delete_table.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"table_id": tableId}),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body)['status'] == 'success';
      }
    } catch (e) {
      debugPrint("Server delete table request failed: $e");
    }
    return false;
  }

  static Future<bool> updateTableStatus(dynamic tableId, bool isEnabled) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/update_table_status.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "table_id": tableId,
          "is_enabled": isEnabled ? 1 : 0,
        }),
      );
      if (response.statusCode == 200) {
        return true;
      }
    } catch (e) {
      debugPrint("Server update table status request failed: $e");
    }
    return false;
  }

  static Future<Map<String, dynamic>> fetchCustomersPaged(
    String tenantId, {
    int page = 1,
    int limit = 40,
  }) async {
    try {
      final response = await _get(
        Uri.parse(
          "$baseUrl/get_customers.php?tenant_id=$tenantId&page=$page&limit=$limit",
        ),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          return {
            'data': List<Map<String, dynamic>>.from(data['data']),
            'totalPages':
                int.tryParse(data['total_pages']?.toString() ?? '1') ?? 1,
            'totalCount':
                int.tryParse(data['total_count']?.toString() ?? '0') ?? 0,
          };
        }
      }
    } catch (e) {
      debugPrint("Error fetching paged customers from server: $e");
    }

    return {'data': <Map<String, dynamic>>[], 'totalPages': 1, 'totalCount': 0};
  }

  static Future<List<Map<String, dynamic>>?> fetchCustomers(
    String tenantId,
  ) async {
    final res = await fetchCustomersPaged(tenantId, page: 1, limit: 100);
    return res['data'] as List<Map<String, dynamic>>;
  }

  // --- STOCK & INVENTORY ---

  static Future<List<Map<String, dynamic>>?> fetchStockReports(
    String tenantId,
  ) async {
    try {
      final response = await _get(
        Uri.parse(
          "$baseUrl/stock_reports_api.php?action=list&tenant_id=$tenantId",
        ),
      );
      final data = json.decode(response.body);
      if (response.statusCode == 200 &&
          data is Map<String, dynamic> &&
          data['status'] == 'success' &&
          data['data'] is List) {
        return List<Map<String, dynamic>>.from(data['data']);
      }
      return null;
    } catch (e) {
      debugPrint("API Error fetching stock reports: $e");
      return null;
    }
  }

  static Future<Map<String, dynamic>> reportStockOut(
    Map<String, dynamic> reportData,
  ) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/stock_reports_api.php?action=create"),
        headers: {"Content-Type": "application/json"},
        body: json.encode(reportData),
      );
      final data = json.decode(response.body);
      return data is Map<String, dynamic>
          ? data
          : {"success": false, "message": "Invalid server response"};
    } catch (e) {
      return {"success": false, "message": "Could not send stock report: $e"};
    }
  }

  static Future<int> fetchUnseenStockAlertCount(String tenantId) async {
    try {
      final response = await _get(
        Uri.parse(
          "$baseUrl/stock_reports_api.php?action=unseen_count&tenant_id=$tenantId",
        ),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic>) {
          return int.tryParse(data['count']?.toString() ?? '') ?? 0;
        }
      }
      return 0;
    } catch (e) {
      debugPrint("API Error fetching unseen stock count: $e");
      return 0;
    }
  }

  static Future<void> markStockAlertsAsSeen(String tenantId) async {
    try {
      await _post(
        Uri.parse("$baseUrl/stock_reports_api.php?action=mark_seen"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"tenant_id": tenantId}),
      );
    } catch (e) {
      debugPrint("API Error marking stock alerts as seen: $e");
    }
  }

  static Future<Map<String, dynamic>> updateStockReportStatus(
    int reportId,
    String status,
  ) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/stock_reports_api.php?action=update_status"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"report_id": reportId, "status": status}),
      );
      final data = json.decode(response.body);
      return data is Map<String, dynamic>
          ? data
          : {"success": false, "message": "Invalid server response"};
    } catch (e) {
      return {"success": false, "message": "Could not update stock report: $e"};
    }
  }

  // --- EXPENSE MANAGEMENT V3 ---

  static Future<Map<String, dynamic>?> fetchExpenseDashboard(
    String tenantId,
    String range,
  ) async {
    try {
      final response = await _get(
        Uri.parse(
          "$baseUrl/get_expense_dashboard.php?tenant_id=$tenantId&range=$range",
        ),
      );
      if (response.statusCode == 200) return json.decode(response.body);
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> saveAdvancedExpense(Map<String, dynamic> data) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/add_expense_v3.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode(data),
      );
      return json.decode(response.body)['status'] == 'success';
    } catch (e) {
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>?> fetchExpenseList(
    String tenantId,
  ) async {
    try {
      final response = await _get(
        Uri.parse("$baseUrl/get_expenses.php?tenant_id=$tenantId"),
      );
      if (response.statusCode == 200)
        return List<Map<String, dynamic>>.from(
          json.decode(response.body)['data'],
        );
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> deleteExpenseV3(int id) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/delete_expense_v3.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"id": id}),
      );
      return json.decode(response.body)['status'] == 'success';
    } catch (e) {
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>?> fetchVendors(
    String tenantId,
  ) async {
    try {
      final response = await _get(
        Uri.parse("$baseUrl/get_vendors.php?tenant_id=$tenantId"),
      );
      if (response.statusCode == 200)
        return List<Map<String, dynamic>>.from(
          json.decode(response.body)['data'],
        );
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> addVendor(Map<String, dynamic> data) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/add_vendor.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode(data),
      );
      return json.decode(response.body)['status'] == 'success';
    } catch (e) {
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>?> fetchRecurringExpenses(
    String tenantId,
  ) async {
    try {
      final response = await _get(
        Uri.parse("$baseUrl/get_recurring.php?tenant_id=$tenantId"),
      );
      if (response.statusCode == 200)
        return List<Map<String, dynamic>>.from(
          json.decode(response.body)['data'],
        );
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> saveRecurringExpense(Map<String, dynamic> data) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/add_recurring.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode(data),
      );
      return json.decode(response.body)['status'] == 'success';
    } catch (e) {
      return false;
    }
  }

  static Future<bool> toggleRecurringExpense(int id, int isActive) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/toggle_recurring.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"id": id, "is_active": isActive}),
      );
      return json.decode(response.body)['status'] == 'success';
    } catch (e) {
      return false;
    }
  }

  static Future<String?> uploadReceipt(Uint8List bytes, String fileName) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse("$baseUrl/upload_receipt.php"),
      );
      request.files.add(
        http.MultipartFile.fromBytes('receipt', bytes, filename: fileName),
      );
      final response = await request.send();
      if (response.statusCode == 200) {
        final resStr = await response.stream.bytesToString();
        final data = json.decode(resStr);
        if (data['status'] == 'success') return data['url'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<String?> uploadProductImage(
    Uint8List bytes,
    String fileName,
  ) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse("$baseUrl/upload_product_image.php"),
      );
      request.files.add(
        http.MultipartFile.fromBytes(
          'product_image',
          bytes,
          filename: fileName,
        ),
      );
      final response = await request.send();
      if (response.statusCode == 200) {
        final resStr = await response.stream.bytesToString();
        final data = json.decode(resStr);
        if (data['status'] == 'success') return data['url'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<String?> upload3DModel(Uint8List bytes, String fileName) async {
    try {
      // Reusing a similar endpoint or specialized one
      final request = http.MultipartRequest(
        'POST',
        Uri.parse("$baseUrl/upload_3d_model.php"),
      );
      request.files.add(
        http.MultipartFile.fromBytes('model_file', bytes, filename: fileName),
      );
      final response = await request.send();
      if (response.statusCode == 200) {
        final resStr = await response.stream.bytesToString();
        final data = json.decode(resStr);
        if (data['status'] == 'success') return data['url'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // --- LOYALTY & REWARDS SYSTEM ---

  static Future<Map<String, dynamic>?> fetchLoyaltySettings(
    String tenantId,
  ) async {
    try {
      final response = await _get(
        Uri.parse(
          "$baseUrl/loyalty_api.php?action=get_settings&tenant_id=$tenantId",
        ),
      );
      if (response.statusCode == 200) return json.decode(response.body)['data'];
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>> updateLoyaltySettings(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/loyalty_api.php?action=update_settings"),
        headers: {"Content-Type": "application/json"},
        body: json.encode(data),
      );

      if (response.statusCode != 200) {
        return {
          "status": "error",
          "message": "Server Error ${response.statusCode}",
        };
      }

      return json.decode(response.body);
    } catch (e) {
      return {"status": "error", "message": "Connection Failure"};
    }
  }

  static Future<List<Map<String, dynamic>>?> fetchRewards(
    String tenantId,
  ) async {
    try {
      final response = await _get(
        Uri.parse(
          "$baseUrl/loyalty_api.php?action=get_rewards&tenant_id=$tenantId",
        ),
      );
      if (response.statusCode == 200)
        return List<Map<String, dynamic>>.from(
          json.decode(response.body)['data'],
        );
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> addReward(Map<String, dynamic> data) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/loyalty_api.php?action=add_reward"),
        headers: {"Content-Type": "application/json"},
        body: json.encode(data),
      );
      return json.decode(response.body)['status'] == 'success';
    } catch (e) {
      return false;
    }
  }

  static Future<bool> updateReward(Map<String, dynamic> data) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/loyalty_api.php?action=update_reward"),
        headers: {"Content-Type": "application/json"},
        body: json.encode(data),
      );
      return json.decode(response.body)['status'] == 'success';
    } catch (e) {
      return false;
    }
  }

  static Future<bool> deleteReward(int id) async {
    try {
      final response = await _get(
        Uri.parse("$baseUrl/loyalty_api.php?action=delete_reward&id=$id"),
      );
      return json.decode(response.body)['status'] == 'success';
    } catch (e) {
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>?> fetchMysteryBoxConfig(
    String tenantId,
  ) async {
    try {
      final response = await _get(
        Uri.parse(
          "$baseUrl/loyalty_api.php?action=get_mystery_box&tenant_id=$tenantId",
        ),
      );
      if (response.statusCode == 200)
        return List<Map<String, dynamic>>.from(
          json.decode(response.body)['data'],
        );
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> saveMysteryBoxConfig(
    String tenantId,
    List<Map<String, dynamic>> items,
  ) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/loyalty_api.php?action=save_mystery_box"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"tenant_id": tenantId, "items": items}),
      );
      return json.decode(response.body)['status'] == 'success';
    } catch (e) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> addMysteryPrize(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/loyalty_api.php?action=add_mystery_prize"),
        headers: {"Content-Type": "application/json"},
        body: json.encode(data),
      );
      final decoded = json.decode(response.body);
      if (decoded is Map<String, dynamic>) {
        return {
          "success": decoded['status'] == 'success',
          "message": decoded['message'] ?? 'Failed to save mystery prize',
        };
      }
      return {"success": false, "message": "Invalid server response"};
    } catch (e) {
      return {"success": false, "message": "Connection error: $e"};
    }
  }

  static Future<bool> deleteMysteryPrize(int id) async {
    try {
      final response = await _get(
        Uri.parse(
          "$baseUrl/loyalty_api.php?action=delete_mystery_prize&id=$id",
        ),
      );
      return json.decode(response.body)['status'] == 'success';
    } catch (e) {
      return false;
    }
  }

  static Future<bool> updateClaimStatus(int id, String status) async {
    try {
      final response = await _get(
        Uri.parse(
          "$baseUrl/loyalty_api.php?action=update_claim_status&id=$id&status=$status",
        ),
      );
      return json.decode(response.body)['status'] == 'success';
    } catch (e) {
      return false;
    }
  }

  static Future<int> fetchUserPoints(String userId) async {
    try {
      final response = await _get(
        Uri.parse("$baseUrl/loyalty_api.php?action=get_points&user_id=$userId"),
      );
      if (response.statusCode == 200)
        return json.decode(response.body)['points'] ?? 0;
      return 0;
    } catch (e) {
      return 0;
    }
  }

  static Future<Map<String, dynamic>> addPoints(
    String tenantId,
    String userId, {
    double orderAmount = 0,
    int points = 0,
    int incrementStamps = 1,
  }) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/loyalty_api.php?action=add_points"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "tenant_id": tenantId,
          "user_id": userId,
          "order_amount": orderAmount,
          "points": points > 0 ? points : null,
          "increment_stamps": incrementStamps,
        }),
      );
      return json.decode(response.body);
    } catch (e) {
      return {"status": "error", "message": "Failed to sync points"};
    }
  }

  static Future<Map<String, dynamic>> claimReward(
    String tenantId,
    String userId,
    int rewardId,
  ) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/loyalty_api.php?action=claim_reward"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "tenant_id": tenantId,
          "user_id": userId,
          "reward_id": rewardId,
        }),
      );
      return json.decode(response.body);
    } catch (e) {
      return {"status": "error", "message": "Connection failed"};
    }
  }

  static Future<Map<String, dynamic>?> openMysteryBox(
    String tenantId,
    String userId, [
    String? userName,
  ]) async {
    try {
      String url =
          "$baseUrl/loyalty_api.php?action=open_mystery_box&tenant_id=$tenantId&user_id=${Uri.encodeComponent(userId)}";
      if (userName != null && userName.isNotEmpty) {
        url += "&user_name=${Uri.encodeComponent(userName)}";
      }
      final response = await _get(Uri.parse(url));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {
        "status": "error",
        "message": "Server returned status code ${response.statusCode}",
      };
    } catch (e) {
      return {"status": "error", "message": "Connection error: $e"};
    }
  }

  static Future<List<Map<String, dynamic>>?> fetchClaimHistory(
    String tenantId, [
    String? userId,
    String? guestId,
  ]) async {
    try {
      String url =
          "$baseUrl/loyalty_api.php?action=get_claims&tenant_id=$tenantId";
      if (userId != null &&
          userId.isNotEmpty &&
          userId.toLowerCase() != 'guest') {
        url += "&user_id=${Uri.encodeComponent(userId)}";
      }
      if (guestId != null &&
          guestId.isNotEmpty &&
          guestId.toLowerCase() != 'guest') {
        url += "&guest_id=${Uri.encodeComponent(guestId)}";
      }
      final response = await _get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success')
          return List<Map<String, dynamic>>.from(data['data']);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>?> fetchAdminClaimHistory(
    String tenantId,
  ) async {
    try {
      final response = await _get(
        Uri.parse(
          "$baseUrl/loyalty_api.php?action=get_admin_claims&tenant_id=$tenantId",
        ),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success')
          return List<Map<String, dynamic>>.from(data['data']);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>> verifyClaimCode(
    String tenantId,
    String code,
  ) async {
    try {
      final response = await _get(
        Uri.parse(
          "$baseUrl/loyalty_api.php?action=verify_claim_code&tenant_id=$tenantId&claim_code=${Uri.encodeComponent(code)}",
        ),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {"status": "error", "message": "Server error"};
    } catch (e) {
      return {"status": "error", "message": "Connection error"};
    }
  }

  static Future<Map<String, dynamic>> redeemClaimCode(
    String tenantId,
    String code, {
    String status = 'redeemed',
  }) async {
    try {
      final response = await _post(
        Uri.parse(
          "$baseUrl/loyalty_api.php?action=redeem_claim&tenant_id=$tenantId",
        ),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"claim_code": code, "status": status}),
      );
      return json.decode(response.body);
    } catch (e) {
      return {"status": "error", "message": "Connection error"};
    }
  }

  // --- MARKETING OFFERS ---

  static Future<List<Map<String, dynamic>>?> fetchOffers(
    String tenantId,
  ) async {
    try {
      final response = await _get(
        Uri.parse(
          "$baseUrl/offers_api.php?action=get_offers&tenant_id=$tenantId",
        ),
      );
      if (response.statusCode == 200)
        return List<Map<String, dynamic>>.from(
          json.decode(response.body)['data'],
        );
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> addOffer(Map<String, dynamic> data) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/offers_api.php?action=add_offer"),
        headers: {"Content-Type": "application/json"},
        body: json.encode(data),
      );
      return json.decode(response.body)['status'] == 'success';
    } catch (e) {
      return false;
    }
  }

  static Future<bool> deleteOffer(int id) async {
    try {
      final response = await _get(
        Uri.parse("$baseUrl/offers_api.php?action=delete_offer&id=$id"),
      );
      return json.decode(response.body)['status'] == 'success';
    } catch (e) {
      return false;
    }
  }

  // --- NEARBY DISCOVERY ---

  static Future<bool> updatePresence({
    required String tenantId,
    required String userId,
    required int tableNumber,
    String? userName,
    String? userImage,
  }) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/nearby_api.php?action=check_in"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "tenant_id": tenantId,
          "user_id": userId,
          "table_number": tableNumber,
          "user_name": userName,
          "user_image": userImage,
        }),
      );
      return json.decode(response.body)['status'] == 'success';
    } catch (e) {
      return false;
    }
  }

  static Future<void> goOffline({
    required String tenantId,
    required String userId,
  }) async {
    try {
      await _post(
        Uri.parse(
          "$baseUrl/nearby_api.php?action=go_offline&tenant_id=$tenantId",
        ),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"user_id": userId}),
      );
    } catch (e) {
      debugPrint("Offline Sync Failed: $e");
    }
  }

  static Future<List<Map<String, dynamic>>?> fetchActiveGuests(
    String tenantId,
    String myId,
  ) async {
    try {
      final response = await _get(
        Uri.parse(
          "$baseUrl/nearby_api.php?action=get_active_users&tenant_id=$tenantId&user_id=$myId",
        ),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success')
          return List<Map<String, dynamic>>.from(data['data']);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> fetchUserOrders(
    String tenantId,
    String userId, {
    String? customerEmail,
    String? guestId,
    String? orderIds,
  }) async {
    try {
      final queryParams = <String, String>{
        "tenant_id": tenantId,
        "user_id": userId,
        "t": DateTime.now().millisecondsSinceEpoch.toString(),
      };
      if (customerEmail != null && customerEmail.trim().isNotEmpty) {
        queryParams["customer_email"] = customerEmail.trim();
      }
      if (guestId != null && guestId.trim().isNotEmpty) {
        queryParams["guest_id"] = guestId.trim();
      }
      if (orderIds != null && orderIds.trim().isNotEmpty) {
        queryParams["order_ids"] = orderIds.trim();
      }

      final response = await _get(
        Uri.parse(
          "$baseUrl/get_user_orders.php",
        ).replace(queryParameters: queryParams),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') return data;
        debugPrint("My Orders endpoint returned an unsuccessful response.");
      } else {
        debugPrint("My Orders request failed (HTTP ${response.statusCode}).");
      }
      return null;
    } catch (e) {
      debugPrint("My Orders request failed: $e");
      return null;
    }
  }

  static Future<Map<String, dynamic>> toggleFollow({
    required String tenantId,
    required String myId,
    required String targetId,
  }) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/nearby_api.php?action=toggle_follow"),
        headers: await _customerSessionHeaders(tenantId),
        body: json.encode({
          "tenant_id": tenantId,
          "user_id": myId,
          "target_id": targetId,
        }),
      );
      final decoded = json.decode(response.body);
      final data = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{};
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          data['status'] != 'success') {
        final message =
            data['message']?.toString() ?? 'HTTP ${response.statusCode}';
        debugPrint('Follow request failed: $message');
        return {
          "success": false,
          "is_following": false,
          "message": message,
        };
      }
      return {
        "success": true,
        "is_following": data['following'] ?? false,
      };
    } catch (e) {
      debugPrint('Follow request failed: $e');
      return {"success": false, "is_following": false, "message": e.toString()};
    }
  }

  static Future<Map<String, dynamic>?> fetchSocialStats(
    String tenantId,
    String userId,
  ) async {
    try {
      final response = await _get(
        Uri.parse(
          "$baseUrl/nearby_api.php?action=get_social_stats&tenant_id=$tenantId&user_id=$userId",
        ),
      );
      if (response.statusCode == 200) return json.decode(response.body);
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> sendWave({
    required String tenantId,
    required String myId,
    required String targetId,
  }) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/nearby_api.php?action=send_wave"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "tenant_id": tenantId,
          "sender_id": myId,
          "receiver_id": targetId,
        }),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
          "Wave request failed (HTTP ${response.statusCode}): ${response.body}",
        );
        return false;
      }

      final decoded = json.decode(response.body);
      if (decoded is! Map<String, dynamic> || decoded['status'] != 'success') {
        debugPrint("Wave request was rejected by the server: ${response.body}");
        return false;
      }
      return true;
    } catch (e, stackTrace) {
      debugPrint("Wave request failed: $e");
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>?> fetchWaves(
    String tenantId,
    String userId,
  ) async {
    try {
      final response = await _get(
        Uri.parse(
          "$baseUrl/nearby_api.php?action=get_waves&tenant_id=$tenantId&user_id=$userId",
        ),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success')
          return List<Map<String, dynamic>>.from(data['data']);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // --- CUSTOMER AUTH & IDENTITY ---

  static Future<Map<String, dynamic>?> syncCustomerProfile({
    required String tenantId,
    required String email,
    String? name,
  }) async {
    try {
      final response = await _post(
        Uri.parse(
          "$baseUrl/auth_customer_api.php?action=sync_profile&tenant_id=$tenantId",
        ),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"email": email, "name": name}),
      );
      return json.decode(response.body);
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>> saveCustomerPin({
    required String tenantId,
    required String email,
    required String pin,
  }) async {
    try {
      final response = await _post(
        Uri.parse(
          "$baseUrl/auth_customer_api.php?action=save_pin&tenant_id=$tenantId",
        ),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"email": email, "pin": pin}),
      );
      return Map<String, dynamic>.from(json.decode(response.body));
    } catch (e) {
      return {"status": "error", "message": "Connection error"};
    }
  }

  static Future<Map<String, dynamic>> verifyCustomerPin({
    required String tenantId,
    required String email,
    required String pin,
  }) async {
    try {
      final response = await _post(
        Uri.parse(
          "$baseUrl/auth_customer_api.php?action=verify_pin&tenant_id=$tenantId",
        ),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"email": email, "pin": pin}),
      );
      return json.decode(response.body);
    } catch (e) {
      return {"status": "error", "message": "Connection error"};
    }
  }

  // --- ONBOARDING & ADVANCED SOCIAL ---

  static Future<bool> submitOnboarding({
    required String tenantId,
    required String userId,
    required String name,
    required String gender,
    bool isAnonymous = false,
  }) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/onboarding_api.php?tenant_id=$tenantId"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "tenant_id": tenantId,
          "user_id": userId,
          "name": name,
          "gender": gender,
          "is_anonymous": isAnonymous,
        }),
      );
      return json.decode(response.body)['status'] == 'success';
    } catch (e) {
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>?> fetchSocialList({
    required String action,
    required String tenantId,
    required String userId,
  }) async {
    try {
      final response = await _get(
        Uri.parse(
          "$baseUrl/social_api_v2.php?action=$action&tenant_id=$tenantId&user_id=$userId",
        ),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success')
          return List<Map<String, dynamic>>.from(data['data']);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> fetchNotifications(
    String tenantId,
    String userId, {
    String? sessionToken,
  }) async {
    try {
      final headers = <String, String>{};
      if (sessionToken != null && sessionToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $sessionToken';
      }
      final response = await _get(
        Uri.parse(
          "$baseUrl/notifications_api.php?action=get_notifications&tenant_id=$tenantId&user_id=$userId",
        ),
        headers: headers,
      );
      if (response.statusCode == 200) return json.decode(response.body);
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> fetchEmailNotificationPreferences({
    required String tenantId,
    required String sessionToken,
  }) async {
    try {
      final response = await _get(
        Uri.parse(
          "$baseUrl/email_notifications_api.php?action=get_preferences&tenant_id=$tenantId",
        ),
        headers: {"Authorization": "Bearer $sessionToken"},
      );
      if (response.statusCode != 200) return null;
      final data = Map<String, dynamic>.from(json.decode(response.body));
      if (data['status'] != 'success') return null;
      return Map<String, dynamic>.from(data['preferences'] ?? {});
    } catch (e) {
      return null;
    }
  }

  static Future<bool> saveEmailNotificationPreferences({
    required String tenantId,
    required String sessionToken,
    required Map<String, bool> preferences,
  }) async {
    try {
      final response = await _post(
        Uri.parse(
          "$baseUrl/email_notifications_api.php?action=save_preferences&tenant_id=$tenantId",
        ),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $sessionToken",
        },
        body: json.encode(preferences),
      );
      return json.decode(response.body)['status'] == 'success';
    } catch (e) {
      return false;
    }
  }

  static Future<void> revokeCustomerSession({
    required String tenantId,
    required String sessionToken,
  }) async {
    try {
      await _post(
        Uri.parse(
          "$baseUrl/email_notifications_api.php?action=logout&tenant_id=$tenantId",
        ),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $sessionToken",
        },
        body: "{}",
      );
    } catch (e) {
      debugPrint("API Error (revokeCustomerSession): $e");
    }
  }

  static Future<bool> markNotificationsRead(
    String tenantId,
    String userId, {
    String? sessionToken,
  }) async {
    try {
      final headers = sessionToken == null || sessionToken.isEmpty
          ? null
          : {"Authorization": "Bearer $sessionToken"};
      final response = await _get(
        Uri.parse(
          "$baseUrl/notifications_api.php?action=mark_as_read&tenant_id=$tenantId&user_id=$userId",
        ),
        headers: headers,
      );
      return json.decode(response.body)['status'] == 'success';
    } catch (e) {
      return false;
    }
  }

  static Future<bool> acknowledgeNotification({
    required String tenantId,
    required String userId,
    required int notificationId,
    required String sessionToken,
  }) async {
    try {
      final response = await _post(
        Uri.parse(
          "$baseUrl/notifications_api.php?action=acknowledge&tenant_id=$tenantId&user_id=$userId",
        ),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $sessionToken",
        },
        body: json.encode({"notification_id": notificationId}),
      );
      return json.decode(response.body)['status'] == 'success';
    } catch (e) {
      return false;
    }
  }

  static Future<bool> sendTestOfferNotification(
    String tenantId,
    String userId,
  ) async {
    try {
      final response = await _get(
        Uri.parse(
          "$baseUrl/notifications_api.php?action=send_test_offer&tenant_id=$tenantId&user_id=$userId",
        ),
      );
      return json.decode(response.body)['status'] == 'success';
    } catch (e) {
      return false;
    }
  }

  static Future<bool> updateFcmToken({
    required String tenantId,
    required String userId,
    required String token,
  }) async {
    try {
      final response = await _post(
        Uri.parse(
          "$baseUrl/auth_customer_api.php?action=update_fcm&tenant_id=$tenantId",
        ),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"user_id": userId, "fcm_token": token}),
      );
      return json.decode(response.body)['status'] == 'success';
    } catch (e) {
      debugPrint("API Error (updateFcmToken): $e");
      return false;
    }
  }

  static Future<Map<String, dynamic>?> fetchPublicProfile({
    required String tenantId,
    required String targetId,
    required String myId,
  }) async {
    try {
      final response = await _get(
        Uri.parse(
          "$baseUrl/get_public_profile.php?tenant_id=$tenantId&target_id=$targetId&my_id=$myId",
        ),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') return data['data'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // --- MUSIC & JUKEBOX SYSTEM ---

  static Future<Map<String, dynamic>?> fetchMusicStatus(
    String tenantId, {
    String? userId,
  }) async {
    try {
      final tId = tenantId.trim();
      if (tId.isEmpty) return null;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final url = Uri.parse("$baseUrl/music_api.php").replace(
        queryParameters: {
          'action': 'get_status',
          'tenant_id': tId,
          'user_id': userId ?? '',
          't': timestamp.toString(),
        },
      );
      final response = await _get(url);
      if (response.statusCode == 200) return json.decode(response.body);
      return null;
    } catch (e) {
      debugPrint("fetchMusicStatus Error: $e");
      return null;
    }
  }

  static Future<Map<String, dynamic>> voteSong({
    required String tenantId,
    required String userId,
    required int songId,
  }) async {
    try {
      final tId = tenantId.trim();
      if (tId.isEmpty) {
        return {
          'status': 'error',
          'message': 'A restaurant is required to vote for a song.',
        };
      }
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Try GET first to bypass Chrome localhost CORS
      final url = Uri.parse("$baseUrl/music_api.php").replace(
        queryParameters: {
          'action': 'vote',
          'tenant_id': tId,
          'song_id': songId.toString(),
          'user_id': userId,
          't': timestamp.toString(),
        },
      );
      final response = await _get(url);
      if (response.statusCode == 200) return json.decode(response.body);

      // Fallback POST
      final postRes = await _post(
        Uri.parse(
          "$baseUrl/music_api.php",
        ).replace(queryParameters: {'action': 'vote', 'tenant_id': tId}),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "tenant_id": tId,
          "song_id": songId,
          "user_id": userId,
        }),
      );
      return json.decode(postRes.body);
    } catch (e) {
      debugPrint("voteSong Error: $e");
      return {"status": "error", "message": "Connection error"};
    }
  }

  static Future<Map<String, dynamic>> requestMusic(
    Map<String, dynamic> data,
  ) async {
    try {
      final tId = (data['tenant_id'] ?? '').toString().trim();
      if (tId.isEmpty) {
        return {
          'success': false,
          'message': 'A restaurant is required to request a song.',
        };
      }
      final title = Uri.encodeComponent((data['title'] ?? '').toString());
      final artist = Uri.encodeComponent(
        (data['artist'] ?? 'Requested').toString(),
      );
      final dedication = Uri.encodeComponent(
        (data['dedication'] ?? '').toString(),
      );
      final userId = Uri.encodeComponent((data['user_id'] ?? '').toString());
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final url = Uri.parse(
        "$baseUrl/music_api.php?action=request&tenant_id=$tId&title=$title&artist=$artist&dedication=$dedication&user_id=$userId&t=$timestamp",
      );
      final response = await _get(url);
      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['status'] == 'success') return {"success": true};
      }

      // Fallback POST
      final postRes = await _post(
        Uri.parse("$baseUrl/music_api.php?action=request&tenant_id=$tId"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({...data, "action": "request"}),
      );
      final result = json.decode(postRes.body);
      return {
        "success": result['status'] == 'success',
        "message": result['message'],
      };
    } catch (e) {
      debugPrint("requestMusic Error: $e");
      return {"success": false, "message": "Connection Error: $e"};
    }
  }

  // Admin Music Controls
  static Future<bool> adminSetNowPlaying(Map<String, dynamic> data) async {
    try {
      final tId = (data['tenant_id'] ?? '').toString().trim();
      if (tId.isEmpty) return false;
      final qId = data['queue_id'] ?? 0;
      final title = Uri.encodeComponent((data['title'] ?? '').toString());
      final artist = Uri.encodeComponent((data['artist'] ?? '').toString());
      final image = Uri.encodeComponent((data['image'] ?? '').toString());
      final dedication = Uri.encodeComponent(
        (data['dedication'] ?? '').toString(),
      );
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Direct GET url bypasses Chrome CORS preflight on localhost!
      final url = Uri.parse(
        "$baseUrl/music_api.php?action=set_playing&tenant_id=$tId&queue_id=$qId&title=$title&artist=$artist&image=$image&dedication=$dedication&t=$timestamp",
      );
      final response = await _get(url);
      if (response.statusCode == 200) {
        final res = json.decode(response.body);
        if (res['status'] == 'success') return true;
      }

      // Fallback POST
      final postRes = await _post(
        Uri.parse("$baseUrl/music_api.php?action=set_playing&tenant_id=$tId"),
        headers: {"Content-Type": "application/json"},
        body: json.encode(data),
      );
      return json.decode(postRes.body)['status'] == 'success';
    } catch (e) {
      debugPrint("adminSetNowPlaying Error: $e");
      return false;
    }
  }

  static Future<bool> adminDeleteQueue(String tenantId, int songId) async {
    try {
      final tId = tenantId.trim();
      if (tId.isEmpty) return false;
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Direct GET URL bypasses Chrome CORS preflight on localhost!
      final url = Uri.parse(
        "$baseUrl/music_api.php?action=delete_queue&tenant_id=$tId&song_id=$songId&t=$timestamp",
      );
      final response = await _get(url);
      if (response.statusCode == 200) {
        final res = json.decode(response.body);
        if (res['status'] == 'success') return true;
      }

      // Fallback POST request
      final postRes = await _post(
        Uri.parse(
          "$baseUrl/music_api.php?action=delete_queue&tenant_id=$tId&song_id=$songId",
        ),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"tenant_id": tId, "song_id": songId}),
      );
      if (postRes.statusCode == 200) {
        final resJson = json.decode(postRes.body);
        return resJson['status'] == 'success';
      }
      return false;
    } catch (e) {
      debugPrint("adminDeleteQueue Error: $e");
      return false;
    }
  }

  static Future<bool> adminCreateMusicPoll(Map<String, dynamic> data) async {
    try {
      final tenantId = (data['tenant_id'] ?? '').toString().trim();
      if (tenantId.isEmpty) return false;
      final response = await _post(
        Uri.parse(
          "$baseUrl/music_api.php?action=create_poll&tenant_id=${Uri.encodeQueryComponent(tenantId)}",
        ),
        headers: {"Content-Type": "application/json"},
        body: json.encode(data),
      );
      return json.decode(response.body)['status'] == 'success';
    } catch (e) {
      return false;
    }
  }

  // --- PRIVACY SETTINGS ---

  static Future<bool> updatePrivacySettings({
    required String tenantId,
    required String userId,
    required bool isPublic,
    required bool allowWaves,
  }) async {
    try {
      final response = await _post(
        Uri.parse(
          "$baseUrl/auth_customer_api.php?action=update_privacy&tenant_id=$tenantId",
        ),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "user_id": userId,
          "is_public": isPublic ? 1 : 0,
          "allow_waves": allowWaves ? 1 : 0,
        }),
      );
      return json.decode(response.body)['status'] == 'success';
    } catch (e) {
      return false;
    }
  }

  // --- CHAT SYSTEM METHODS ---

  static Future<List<Map<String, dynamic>>?> fetchConversations(
    String tenantId,
    String userId,
  ) async {
    try {
      final response = await _get(
        Uri.parse(
          "$baseUrl/chat_api.php?action=get_conversations&tenant_id=$tenantId&user_id=$userId",
        ),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success')
          return List<Map<String, dynamic>>.from(data['data']);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> syncMessages({
    required String tenantId,
    required String myId,
    required String friendId,
    required int lastId,
  }) async {
    try {
      final url =
          "$baseUrl/chat_api.php?action=sync&tenant_id=$tenantId&uid1=$myId&uid2=$friendId&last_id=$lastId";
      final response = await _get(Uri.parse(url));
      if (response.statusCode == 200) return json.decode(response.body);
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>> sendMessage({
    required String tenantId,
    required String senderId,
    required String receiverId,
    required String message,
    String type = 'text',
    int? replyToId, // Added support for replies
  }) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/chat_api.php?action=send&tenant_id=$tenantId"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "sender_id": senderId,
          "receiver_id": receiverId,
          "message": message,
          "type": type,
          "reply_to_id": replyToId, // Send to server
        }),
      );
      final data = json.decode(response.body) as Map<String, dynamic>;
      return {...data, 'success': data['status'] == 'success'};
    } catch (e) {
      return {
        'success': false,
        'message': 'Could not send message. Please try again.',
      };
    }
  }

  static Future<bool> deliverPendingChatMessages({
    required String tenantId,
    required String userId,
    required String otherUserId,
  }) async {
    try {
      final response = await _post(
        Uri.parse(
          "$baseUrl/chat_api.php?action=deliver_pending&tenant_id=$tenantId",
        ),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"user_id": userId, "other_user_id": otherUserId}),
      );
      final data = json.decode(response.body);
      return response.statusCode == 200 && data['status'] == 'success';
    } catch (e) {
      debugPrint("deliverPendingChatMessages Error: $e");
      return false;
    }
  }

  static Future<void> updateTypingStatus(
    String tenantId,
    String userId,
    String toId,
  ) async {
    try {
      await _post(
        Uri.parse("$baseUrl/chat_api.php?action=typing&tenant_id=$tenantId"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"user_id": userId, "typing_to": toId}),
      );
    } catch (e) {}
  }

  static Future<void> markMessagesRead(
    String tenantId,
    String myId,
    String fromId,
  ) async {
    try {
      await _get(
        Uri.parse(
          "$baseUrl/chat_api.php?action=mark_read&tenant_id=$tenantId&my_id=$myId&from_id=$fromId",
        ),
      );
    } catch (e) {}
  }

  static Future<bool> editMessage(
    String tenantId,
    String userId,
    int messageId,
    String newText,
  ) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/chat_api.php?action=edit&tenant_id=$tenantId"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "user_id": userId,
          "message_id": messageId,
          "message": newText,
        }),
      );
      return json.decode(response.body)['status'] == 'success';
    } catch (e) {
      return false;
    }
  }

  static Future<bool> deleteMessage(
    String tenantId,
    String userId,
    int messageId,
  ) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/chat_api.php?action=delete&tenant_id=$tenantId"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"user_id": userId, "message_id": messageId}),
      );
      return json.decode(response.body)['status'] == 'success';
    } catch (e) {
      return false;
    }
  }

  // --- COLLABORATIVE BILL SPLITTER METHODS (V3 - Real Backend) ---

  static Future<Map<String, dynamic>?> createSplitGroup({
    required String tenantId,
    required String userId,
    required int tableNumber,
  }) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/split_api.php?action=create&tenant_id=$tenantId"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"user_id": userId, "table_number": tableNumber}),
      );
      final data = json.decode(response.body);
      if (data['status'] == 'success') return data['data'];
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> joinSplitGroup({
    required String tenantId,
    required String userId,
    required String pin,
  }) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/split_api.php?action=join&tenant_id=$tenantId"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"user_id": userId, "pin": pin}),
      );
      final data = json.decode(response.body);
      if (data['status'] == 'success') return data['data'];
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getSplitGroupDetails({
    required String tenantId,
    required int sessionId,
    String? lastSyncTime,
  }) async {
    try {
      final url =
          "$baseUrl/split_api.php?action=get_details&tenant_id=$tenantId&session_id=$sessionId&last_sync=${lastSyncTime ?? ''}";
      final response = await _get(Uri.parse(url));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> lockSplitGroup(String tenantId, int sessionId) async {
    try {
      final response = await _get(
        Uri.parse(
          "$baseUrl/split_api.php?action=lock&tenant_id=$tenantId&session_id=$sessionId",
        ),
      );
      return json.decode(response.body)['status'] == 'success';
    } catch (e) {
      return false;
    }
  }

  static Future<bool> shareSplitDetails(
    int sessionId,
    String volunteerId,
  ) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/split_api.php?action=share_split"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "session_id": sessionId,
          "volunteer_id": volunteerId,
        }),
      );
      return json.decode(response.body)['status'] == 'success';
    } catch (e) {
      return false;
    }
  }

  static Future<String?> uploadGroupQR(
    int sessionId,
    Uint8List bytes,
    String fileName,
  ) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse("$baseUrl/split_api.php?action=upload_qr"),
      );
      request.fields['session_id'] = sessionId.toString();
      request.files.add(
        http.MultipartFile.fromBytes('qr_image', bytes, filename: fileName),
      );
      final response = await request.send();
      if (response.statusCode == 200) {
        final resStr = await response.stream.bytesToString();
        final data = json.decode(resStr);
        if (data['status'] == 'success') return data['url'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> deleteSplitGroupSession(
    String tenantId,
    int sessionId,
  ) async {
    try {
      final response = await _get(
        Uri.parse(
          "$baseUrl/split_api.php?action=delete_session&tenant_id=$tenantId&session_id=$sessionId",
        ),
      );
      return json.decode(response.body)['status'] == 'success';
    } catch (e) {
      return false;
    }
  }

  static Future<String?> submitGroupPayment(
    int sessionId,
    String userId,
    Uint8List bytes,
    String fileName,
  ) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse("$baseUrl/split_api.php?action=submit_payment"),
      );
      request.fields['session_id'] = sessionId.toString();
      request.fields['user_id'] = userId;
      request.files.add(
        http.MultipartFile.fromBytes('ss_image', bytes, filename: fileName),
      );
      final response = await request.send();
      if (response.statusCode == 200) {
        final resStr = await response.stream.bytesToString();
        final data = json.decode(resStr);
        if (data['status'] == 'success') return data['url'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // --- REVIEW SYSTEM V1 ---

  static Future<List<Map<String, dynamic>>?> fetchReviews(
    String tenantId, {
    String? targetUserId,
  }) async {
    try {
      final url = targetUserId != null
          ? "$baseUrl/review_api.php?action=get_reviews&tenant_id=$tenantId&target_user_id=$targetUserId"
          : "$baseUrl/review_api.php?action=get_reviews&tenant_id=$tenantId";
      final response = await _get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success')
          return List<Map<String, dynamic>>.from(data['data']);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>> submitReview(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/review_api.php?action=submit_review"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: json.encode(data),
      );

      debugPrint("API STATUS (submit_review): ${response.statusCode}");
      debugPrint("API RESPONSE (submit_review): ${response.body}");

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {
          "status": "error",
          "message": "Server returned status: ${response.statusCode}",
        };
      }
    } catch (e) {
      debugPrint("API EXCEPTION (submit_review): $e");
      return {"status": "error", "message": "Network error: $e"};
    }
  }

  static Future<bool> deleteReview(
    String tenantId,
    int reviewId,
    String userId,
  ) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/review_api.php?action=delete_review"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "tenant_id": tenantId,
          "review_id": reviewId,
          "user_id": userId,
        }),
      );
      return json.decode(response.body)['status'] == 'success';
    } catch (e) {
      return false;
    }
  }

  static Future<bool> toggleReviewLike(int reviewId, String userId) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/review_api.php?action=toggle_like"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"review_id": reviewId, "user_id": userId}),
      );
      return json.decode(response.body)['status'] == 'success';
    } catch (e) {
      return false;
    }
  }

  static Future<bool> updateGoogleMapsLink(String tenantId, String link) async {
    return updateSocialLinks(tenantId, {"google_maps_link": link});
  }

  static Future<bool> updateSocialLinks(
    String tenantId,
    Map<String, String> links,
  ) async {
    try {
      final payload = {"tenant_id": tenantId.trim(), ...links};
      debugPrint(
        "API REQUEST (update_social_links) to: $baseUrl/review_api.php?action=update_social_links",
      );
      debugPrint("API PAYLOAD: ${json.encode(payload)}");

      final response = await _post(
        Uri.parse("$baseUrl/review_api.php?action=update_social_links"),
        headers: {"Content-Type": "application/json"},
        body: json.encode(payload),
      );
      debugPrint("API RESPONSE STATUS: ${response.statusCode}");
      debugPrint("API RESPONSE BODY: ${response.body}");
      final data = json.decode(response.body);
      return data['status'] == 'success';
    } catch (e) {
      debugPrint("API EXCEPTION (update_social_links): $e");
      return false;
    }
  }

  static Future<bool> verifyReviewOnServer(int reviewId) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/review_api.php?action=verify_review"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"review_id": reviewId}),
      );
      return json.decode(response.body)['status'] == 'success';
    } catch (e) {
      return false;
    }
  }

  // --- UNITS & INGREDIENT INVENTORY (100% REAL DATABASE BACKEND) ---
  // --- UNITS & INGREDIENT INVENTORY (STRICT DATABASE BACKEND) ---
  static Future<List<Map<String, dynamic>>> fetchUnits(String tenantId) async {
    try {
      final response = await _get(
        Uri.parse("$baseUrl/units_api.php?action=fetch&tenant_id=$tenantId"),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
    } catch (e) {
      debugPrint("Error fetching units: $e");
    }
    return [];
  }

  static Future<bool> saveUnit(Map<String, dynamic> unit) async {
    try {
      final tenant = TenantService().currentTenant.value;
      final tenantId = tenant?.id ?? 'startups_main';
      final payload = {...unit, 'tenant_id': tenantId};
      final response = await _post(
        Uri.parse("$baseUrl/units_api.php?action=save"),
        headers: {"Content-Type": "application/json"},
        body: json.encode(payload),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['status'] == 'success';
      }
    } catch (e) {
      debugPrint("Error saving unit: $e");
    }
    return false;
  }

  static Future<bool> deleteUnit(dynamic id) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/units_api.php?action=delete"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"id": id}),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body)['status'] == 'success';
      }
    } catch (e) {
      debugPrint("Error deleting unit: $e");
    }
    return false;
  }

  static Future<List<Map<String, dynamic>>> fetchIngredients(
    String tenantId,
  ) async {
    try {
      final response = await _get(
        Uri.parse(
          "$baseUrl/ingredients_api.php?action=fetch&tenant_id=$tenantId",
        ),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
    } catch (e) {
      debugPrint("Error fetching ingredients: $e");
    }
    return [];
  }

  static Future<bool> saveIngredient(Map<String, dynamic> ingredient) async {
    try {
      final tenant = TenantService().currentTenant.value;
      final tenantId = tenant?.id ?? 'startups_main';
      double total =
          double.tryParse(ingredient['total_stock']?.toString() ?? '0') ?? 0;
      double consumed =
          double.tryParse(ingredient['consumed_today']?.toString() ?? '0') ?? 0;
      ingredient['remaining_stock'] = total - consumed;

      final payload = {...ingredient, 'tenant_id': tenantId};
      final response = await _post(
        Uri.parse("$baseUrl/ingredients_api.php?action=save"),
        headers: {"Content-Type": "application/json"},
        body: json.encode(payload),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['status'] == 'success';
      }
    } catch (e) {
      debugPrint("Error saving ingredient: $e");
    }
    return false;
  }

  static Future<bool> logIngredientConsumption(
    dynamic id,
    double consumedToday,
  ) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/ingredients_api.php?action=log_consumption"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"id": id, "consumed_today": consumedToday}),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['status'] == 'success';
      }
    } catch (e) {
      debugPrint("Error logging consumption: $e");
    }
    return false;
  }

  static Future<bool> deleteIngredient(dynamic id) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/ingredients_api.php?action=delete"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"id": id}),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body)['status'] == 'success';
      }
    } catch (e) {
      debugPrint("Error deleting ingredient: $e");
    }
    return false;
  }

  // --- MULTIPLAYER TAP WAR SQUAD SYSTEM ---

  static Future<Map<String, dynamic>?> createBattleground({
    required String tenantId,
    required int durationSeconds,
  }) async {
    try {
      final response = await _post(
        Uri.parse(
          "$baseUrl/game_squad_api.php?action=create_battleground&tenant_id=$tenantId",
        ),
        headers: await _customerSessionHeaders(tenantId),
        body: json.encode({'duration_seconds': durationSeconds}),
      );
      final decoded = json.decode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      debugPrint(
        "API Error (createBattleground): unexpected JSON response "
        "(HTTP ${response.statusCode}).",
      );
      return {
        'status': 'error',
        'message':
            'The server returned an unexpected response. Please try again.',
      };
    } on FormatException {
      debugPrint(
        "API Error (createBattleground): invalid JSON response "
        "(HTTP response body was empty or malformed).",
      );
      return {
        'status': 'error',
        'message':
            'The server returned an invalid response. Please try again later.',
      };
    } catch (e) {
      debugPrint("API Error (createBattleground): $e");
      return null;
    }
  }

  static Future<Map<String, dynamic>?> createSquad({
    required String tenantId,
    required String userId,
    required int tableId,
  }) async {
    try {
      final response = await _post(
        Uri.parse(
          "$baseUrl/game_squad_api.php?action=create_squad&tenant_id=$tenantId",
        ),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"user_id": userId, "table_id": tableId}),
      );
      return json.decode(response.body);
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> inviteToSquad({
    required String tenantId,
    required String userId,
    required int squadId,
    required String invitedUserId,
  }) async {
    try {
      final response = await _post(
        Uri.parse(
          "$baseUrl/game_squad_api.php?action=invite_to_squad&tenant_id=$tenantId",
        ),
        headers: await _customerSessionHeaders(tenantId),
        body: json.encode({
          "user_id": userId,
          "squad_id": squadId,
          "invited_user_id": invitedUserId,
        }),
      );
      return json.decode(response.body);
    } catch (e) {
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>?> getOpenBattlegrounds({
    required String tenantId,
  }) async {
    try {
      final response = await _get(
        Uri.parse(
          "$baseUrl/game_squad_api.php?action=get_open_battlegrounds&tenant_id=$tenantId",
        ),
        headers: await _customerSessionHeaders(tenantId),
      );
      final decoded = json.decode(response.body);
      if (response.statusCode != 200 || decoded['status'] != 'success') {
        debugPrint(
          "API Error (getOpenBattlegrounds): ${decoded['message'] ?? response.statusCode}",
        );
        return null;
      }
      return List<Map<String, dynamic>>.from(
        decoded['battlegrounds'] ?? const [],
      );
    } catch (e) {
      debugPrint("API Error (getOpenBattlegrounds): $e");
      return null;
    }
  }

  static Future<Map<String, dynamic>?> requestBattlegroundJoin({
    required String tenantId,
    required int squadId,
  }) async {
    try {
      final response = await _post(
        Uri.parse(
          "$baseUrl/game_squad_api.php?action=request_battleground_join&tenant_id=$tenantId",
        ),
        headers: await _customerSessionHeaders(tenantId),
        body: json.encode({'squad_id': squadId}),
      );
      return Map<String, dynamic>.from(json.decode(response.body));
    } catch (e) {
      debugPrint("API Error (requestBattlegroundJoin): $e");
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>?> getBattlegroundJoinRequests({
    required String tenantId,
    required int squadId,
  }) async {
    try {
      final response = await _get(
        Uri.parse(
          "$baseUrl/game_squad_api.php?action=get_battleground_join_requests&tenant_id=$tenantId&squad_id=$squadId",
        ),
        headers: await _customerSessionHeaders(tenantId),
      );
      final decoded = json.decode(response.body);
      if (response.statusCode != 200 || decoded['status'] != 'success') {
        debugPrint(
          "API Error (getBattlegroundJoinRequests): ${decoded['message'] ?? response.statusCode}",
        );
        return null;
      }
      return List<Map<String, dynamic>>.from(decoded['requests'] ?? const []);
    } catch (e) {
      debugPrint("API Error (getBattlegroundJoinRequests): $e");
      return null;
    }
  }

  static Future<Map<String, dynamic>?> respondToBattlegroundJoin({
    required String tenantId,
    required int squadId,
    required String requesterId,
    required bool accept,
  }) async {
    try {
      final response = await _post(
        Uri.parse(
          "$baseUrl/game_squad_api.php?action=respond_to_battleground_join&tenant_id=$tenantId",
        ),
        headers: await _customerSessionHeaders(tenantId),
        body: json.encode({
          'squad_id': squadId,
          'requester_id': requesterId,
          'accept': accept,
        }),
      );
      return Map<String, dynamic>.from(json.decode(response.body));
    } catch (e) {
      debugPrint("API Error (respondToBattlegroundJoin): $e");
      return null;
    }
  }

  static Future<Map<String, dynamic>?> respondToInvite({
    required String tenantId,
    required String userId,
    required int squadId,
    required bool accept,
  }) async {
    try {
      final response = await _post(
        Uri.parse(
          "$baseUrl/game_squad_api.php?action=respond_to_invite&tenant_id=$tenantId",
        ),
        headers: await _customerSessionHeaders(tenantId),
        body: json.encode({
          "user_id": userId,
          "squad_id": squadId,
          "accept": accept,
        }),
      );
      return json.decode(response.body);
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getSquadStatus({
    required String tenantId,
    required int squadId,
    required String userId,
  }) async {
    try {
      final response = await _get(
        Uri.parse(
          "$baseUrl/game_squad_api.php?action=get_squad_status&tenant_id=$tenantId&squad_id=$squadId&user_id=$userId",
        ),
      );
      final decoded = json.decode(response.body);
      if (decoded is Map<String, dynamic>) {
        if (response.statusCode != 200) {
          debugPrint(
            "API Error (getSquadStatus): HTTP ${response.statusCode}, "
            "${decoded['message'] ?? 'request failed'}",
          );
        }
        return decoded;
      }
      debugPrint(
        "API Error (getSquadStatus): unexpected response "
        "(HTTP ${response.statusCode}).",
      );
      return null;
    } catch (e) {
      debugPrint("API Error (getSquadStatus): $e");
      return null;
    }
  }

  static Future<Map<String, dynamic>?> startSquadGame({
    required String tenantId,
    required String userId,
    required int squadId,
  }) async {
    try {
      final response = await _post(
        Uri.parse(
          "$baseUrl/game_squad_api.php?action=start_squad_game&tenant_id=$tenantId",
        ),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"user_id": userId, "squad_id": squadId}),
      );
      return json.decode(response.body);
    } catch (e) {
      return null;
    }
  }

  static Future<bool> submitTapBatch({
    required String tenantId,
    required String userId,
    required int squadId,
    required int tapCountIncrement,
  }) async {
    try {
      final response = await _post(
        Uri.parse(
          "$baseUrl/game_squad_api.php?action=submit_tap_batch&tenant_id=$tenantId",
        ),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "user_id": userId,
          "squad_id": squadId,
          "tap_count_increment": tapCountIncrement,
        }),
      );
      return json.decode(response.body)['status'] == 'success';
    } catch (e) {
      return false;
    }
  }

  static Future<Map<String, dynamic>?> submitFinalScore({
    required String tenantId,
    required int squadId,
    required int tapCount,
    required String? reachedAtTimestamp,
  }) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/submit_final_score.php?tenant_id=$tenantId"),
        headers: await _customerSessionHeaders(tenantId),
        body: json.encode({
          'squad_id': squadId,
          'tap_count': tapCount,
          'reached_at_timestamp': reachedAtTimestamp,
        }),
      );
      return json.decode(response.body);
    } catch (e) {
      debugPrint("API Error (submitFinalScore): $e");
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getGameState({
    required String tenantId,
    required int squadId,
  }) async {
    try {
      final response = await _get(
        Uri.parse(
          "$baseUrl/game_squad_api.php?action=get_game_state&tenant_id=$tenantId&squad_id=$squadId",
        ),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getActiveSquad({
    required String tenantId,
    required String userId,
  }) async {
    try {
      final response = await _get(
        Uri.parse(
          "$baseUrl/game_squad_api.php?action=get_active_squad&tenant_id=$tenantId&user_id=$userId",
        ),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') return data['squad'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> spawnTestBot(String tenantId) async {
    try {
      final response = await _get(
        Uri.parse(
          "$baseUrl/nearby_api.php?action=spawn_test_bot&tenant_id=$tenantId",
        ),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body)['status'] == 'success';
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
