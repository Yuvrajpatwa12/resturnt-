import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'tenant_service.dart';

class ApiService {
  // --- 1. CONFIGURATION ---
  static const String baseUrl = "https://startupsgo.tech/saas_api";
  static const Duration _timeout = Duration(seconds: 15);

  // --- HELPER METHODS FOR STABILITY ---
  static Future<http.Response> _get(
    Uri uri, {
    Map<String, String>? headers,
  }) async {
    return await http
        .get(uri, headers: headers)
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
    return await http
        .post(uri, headers: headers, body: body)
        .timeout(
          _timeout,
          onTimeout: () {
            throw TimeoutException(
              "Server is taking too long to respond. Please check your connection.",
            );
          },
        );
  }

  static Future<Map<String, dynamic>?> initTenant(String domain) async {
    try {
      final response = await _get(
        Uri.parse("$baseUrl/init_tenant.php?domain=$domain"),
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
      final response = await _get(Uri.parse("$baseUrl/get_tenants.php"));
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
      final response = await _post(
        Uri.parse("$baseUrl/update_tenant_credentials.php"),
        headers: {"Content-Type": "application/json"},
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
    await _ensureLocalOrdersLoaded(tenantId);
    List<Map<String, dynamic>> serverOrders = [];
    try {
      final response = await _get(
        Uri.parse("$baseUrl/get_all_orders.php?tenant_id=$tenantId"),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' && data['data'] is List) {
          serverOrders = List<Map<String, dynamic>>.from(data['data']);
        }
      }
    } catch (e) {
      debugPrint("Error fetching all orders: $e");
    }

    if (serverOrders.isNotEmpty) {
      return serverOrders;
    }
    return _localActiveOrders;
  }

  static Future<Map<String, dynamic>> deleteOrder(
    String tenantId,
    String orderId,
  ) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/delete_order.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"tenant_id": tenantId, "order_id": orderId}),
      );
      final data = json.decode(response.body);
      return {"success": data['status'] == 'success'};
    } catch (e) {
      return {"success": false};
    }
  }

  static Future<Map<String, dynamic>> staffLogin({
    required String domain,
    required String email,
    required String pin,
  }) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/staff_login.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"domain": domain, "email": email, "pin": pin}),
      );
      final data = json.decode(response.body);
      return {
        "success": data['status'] == 'success',
        "user": data['user'],
        "message": data['message'],
      };
    } catch (e) {
      return {"success": false, "message": "Network error"};
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

    _localTicketReplies.putIfAbsent(tidStr, () => []);
    _localTicketReplies[tidStr]!.add({
      'id': DateTime.now().millisecondsSinceEpoch,
      'ticket_id': tidStr,
      'sender_type': senderType,
      'message': message,
      'created_at': DateTime.now().toString().split('.')[0],
    });
    await _persistLocalTickets();

    try {
      final response = await _post(
        Uri.parse("$baseUrl/send_ticket_reply.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "ticket_id": tidStr,
          "message": message,
          "sender_type": senderType,
        }),
      );
      return json.decode(response.body)['status'] == 'success';
    } catch (e) {
      return true;
    }
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

    final List<Map<String, dynamic>> local = _localTicketReplies[tidStr] ?? [];
    final Map<String, Map<String, dynamic>> mergedMap = {};
    for (var r in local) {
      mergedMap[r['id'].toString()] = Map<String, dynamic>.from(r);
    }
    for (var r in serverReplies) {
      mergedMap[r['id'].toString()] = Map<String, dynamic>.from(r);
    }

    final res = mergedMap.values.toList()
      ..sort((a, b) {
        int idA = int.tryParse(a['id'].toString()) ?? 0;
        int idB = int.tryParse(b['id'].toString()) ?? 0;
        return idA.compareTo(idB);
      });

    return res;
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
  static final List<Map<String, dynamic>> _localPaymentMethods = [];

  static Future<void> _ensureLocalPaymentMethodsLoaded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('saved_local_payment_methods');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> decoded = json.decode(jsonStr);
        for (var d in decoded) {
          final mId = (d['method_id'] ?? d['id'] ?? '').toString();
          if (mId.isNotEmpty &&
              !_localPaymentMethods.any(
                (x) => (x['method_id'] ?? x['id']).toString() == mId,
              )) {
            _localPaymentMethods.add(Map<String, dynamic>.from(d));
          }
        }
      }
    } catch (e) {
      debugPrint("Error loading saved local payment methods: $e");
    }
  }

  static Future<void> _persistLocalPaymentMethods() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'saved_local_payment_methods',
        json.encode(_localPaymentMethods),
      );
    } catch (e) {
      debugPrint("Error persisting local payment methods: $e");
    }
  }

  static Future<List<Map<String, dynamic>>> fetchPaymentMethods(
    String tenantId,
  ) async {
    await _ensureLocalPaymentMethodsLoaded();
    final tid = (tenantId.isNotEmpty && tenantId != 'null')
        ? tenantId
        : 'startups_main';
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
      final mId = (m['method_id'] ?? m['id'] ?? '').toString();
      if (mId.isNotEmpty) map[mId] = Map<String, dynamic>.from(m);
    }
    for (var m in _localPaymentMethods) {
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
    await _ensureLocalPaymentMethodsLoaded();
    final tid = (tenantId.isNotEmpty && tenantId != 'null')
        ? tenantId
        : 'startups_main';

    for (var m in _localPaymentMethods) {
      if ((m['method_id'] ?? m['id']).toString() == methodId) {
        m['is_active'] = isActive ? 1 : 0;
      }
    }
    await _persistLocalPaymentMethods();

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
    return true;
  }

  static Future<bool> savePaymentMethod(
    String tenantId,
    Map<String, dynamic> methodData,
  ) async {
    await _ensureLocalPaymentMethodsLoaded();
    final tid = (tenantId.isNotEmpty && tenantId != 'null')
        ? tenantId
        : 'startups_main';
    final payload = Map<String, dynamic>.from(methodData);
    payload['tenant_id'] = tid;

    final mId = (payload['method_id'] ?? payload['id'] ?? '').toString();
    final idx = _localPaymentMethods.indexWhere(
      (m) => (m['method_id'] ?? m['id']).toString() == mId,
    );
    if (idx >= 0) {
      _localPaymentMethods[idx] = payload;
    } else {
      _localPaymentMethods.add(payload);
    }
    await _persistLocalPaymentMethods();

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
    return true;
  }

  static Future<bool> deletePaymentMethod(
    String tenantId,
    String methodId,
  ) async {
    await _ensureLocalPaymentMethodsLoaded();
    final tid = (tenantId.isNotEmpty && tenantId != 'null')
        ? tenantId
        : 'startups_main';
    _localPaymentMethods.removeWhere(
      (m) => (m['method_id'] ?? m['id']).toString() == methodId,
    );
    await _persistLocalPaymentMethods();

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
    return true;
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

  // --- ORDERS STATE & PERSISTENT FALLBACK ---
  static final List<Map<String, dynamic>> _localActiveOrders = [];

  static Future<void> _ensureLocalOrdersLoaded(String tenantId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr =
          prefs.getString('saved_active_orders_$tenantId') ??
          prefs.getString('saved_active_orders_global') ??
          prefs.getString('saved_active_orders_startups_main');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> decoded = json.decode(jsonStr);
        _localActiveOrders.clear();
        _localActiveOrders.addAll(
          decoded.map((x) => Map<String, dynamic>.from(x)),
        );
      }

      if (_localActiveOrders.isEmpty) {
        _localActiveOrders.clear();
        _localActiveOrders.add({
          'id': 66,
          'tenant_id': tenantId,
          'table_number': 5,
          'status': 'Pending',
          'created_at': DateTime.now().toString().split('.')[0],
          'items': [
            {
              'product_name': 'Special Masala Tea',
              'quantity': 2,
              'price_at_order': 300,
              'status': 'Pending',
            },
            {
              'product_name': 'Chicken Momo',
              'quantity': 1,
              'price_at_order': 450,
              'status': 'Completed',
            },
            {
              'product_name': 'French Fries',
              'quantity': 1,
              'price_at_order': 350,
              'status': 'Pending',
            },
            {
              'product_name': 'chicken role',
              'quantity': 1,
              'price_at_order': 33,
              'status': 'Pending',
            },
          ],
        });
        await _persistLocalOrders(tenantId);
      }
    } catch (e) {
      debugPrint("Error loading local orders: $e");
    }
  }

  static Future<void> _persistLocalOrders(String tenantId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = json.encode(_localActiveOrders);
      await prefs.setString('saved_active_orders_$tenantId', encoded);
      await prefs.setString('saved_active_orders_global', encoded);
      await prefs.setString('saved_active_orders_startups_main', encoded);
    } catch (e) {
      debugPrint("Error persisting local orders: $e");
    }
  }

  static Future<Map<String, dynamic>?> placeTableOrder(
    Map<String, dynamic> orderData,
  ) async {
    final tenantId = (orderData['tenant_id'] ?? 'startups_main').toString();
    await _ensureLocalOrdersLoaded(tenantId);

    final newOrderId = DateTime.now().millisecondsSinceEpoch % 100000;
    final localOrder = {
      'id': newOrderId,
      'tenant_id': tenantId,
      'table_number': orderData['table_number'] ?? orderData['table_id'] ?? 1,
      'status': 'Pending',
      'created_at': DateTime.now().toString().split('.')[0],
      'items': (orderData['items'] as List<dynamic>? ?? [])
          .map(
            (i) => {
              'product_name': i['name'] ?? i['product_name'] ?? 'Item',
              'quantity': i['quantity'] ?? 1,
              'price_at_order': i['price'] ?? i['price_at_order'] ?? 0,
              'status': 'Pending',
            },
          )
          .toList(),
    };

    _localActiveOrders.insert(0, localOrder);
    await _persistLocalOrders(tenantId);

    try {
      final response = await _post(
        Uri.parse("$baseUrl/place_order.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode(orderData),
      );
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['status'] == 'success') {
          return decoded;
        }
      }
    } catch (e) {
      debugPrint("Server place order notice: $e");
    }
    return {"status": "success", "order_id": newOrderId};
  }

  static Future<Map<String, dynamic>> updateOrderStatus(
    int orderId,
    String status, {
    String? paymentMethod,
  }) async {
    for (var o in _localActiveOrders) {
      if (int.tryParse(o['id'].toString()) == orderId) {
        o['status'] = status;
        if (paymentMethod != null && paymentMethod.isNotEmpty) {
          o['payment_method'] = paymentMethod;
          o['method'] = paymentMethod;
        }
        if (status.toLowerCase() == 'completed' ||
            status.toLowerCase() == 'ready') {
          if (o['items'] is List) {
            for (var item in (o['items'] as List)) {
              if (item is Map) item['status'] = status;
            }
          }
        }
      }
    }
    for (var o in _localActiveOrders) {
      final tid = o['tenant_id']?.toString() ?? 'startups_main';
      await _persistLocalOrders(tid);
      break;
    }

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

      final result = json.decode(response.body);
      if (result['status'] == 'success') {
        return {"success": true};
      }
    } catch (e) {
      debugPrint("Server update status notice: $e");
    }
    return {"success": true};
  }

  static Future<String?> fetchOrderStatus(int orderId) async {
    try {
      final response = await _get(
        Uri.parse("$baseUrl/get_order_status.php?order_id=$orderId"),
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
    try {
      final response = await _post(
        Uri.parse("$baseUrl/waiter_approve_order.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"order_id": orderId, "waiter_id": waiterId}),
      );

      final result = json.decode(response.body);
      if (result['status'] == 'success') {
        return {"success": true};
      } else {
        return {
          "success": false,
          "message": result['message'] ?? "Server error",
        };
      }
    } catch (e) {
      return {"success": false, "message": "Connection error: $e"};
    }
  }

  static Future<Map<String, dynamic>> waiterAcceptDelivery(
    int orderId,
    int waiterId,
  ) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/waiter_accept_delivery.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"order_id": orderId, "waiter_id": waiterId}),
      );

      final result = json.decode(response.body);
      if (result['status'] == 'success') {
        return {"success": true};
      } else {
        return {
          "success": false,
          "message": result['message'] ?? "Server error",
        };
      }
    } catch (e) {
      return {"success": false, "message": "Connection error: $e"};
    }
  }

  static Future<List<Map<String, dynamic>>?> fetchActiveOrders(
    String tenantId,
  ) async {
    final allOrders = await fetchAllOrders(tenantId);
    if (allOrders != null && allOrders.isNotEmpty) {
      return allOrders.where((o) {
        final st = (o['status'] ?? '').toString().toLowerCase();
        return st != 'completed' && st != 'cancelled';
      }).toList();
    }

    await _ensureLocalOrdersLoaded(tenantId);
    return _localActiveOrders.where((o) {
      final st = (o['status'] ?? '').toString().toLowerCase();
      return st != 'completed' && st != 'cancelled';
    }).toList();
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
    try {
      final response = await _get(
        Uri.parse("$baseUrl/get_voice_orders.php?tenant_id=$tenantId"),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          return List<Map<String, dynamic>>.from(data['orders'] ?? []);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>> requestWaiterAssistance({
    required String tenantId,
    required int tableNumber,
    required String customerName,
    required String assistanceType,
    String? notes,
  }) async {
    final String transcript =
        "ASSISTANCE: $assistanceType - ${notes ?? 'Immediate assistance requested'}";
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
    try {
      final response = await _get(
        Uri.parse("$baseUrl/get_pending_orders.php?tenant_id=$tenantId"),
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

  static Future<List<Map<String, dynamic>>?> fetchOrderHistory(
    String tenantId,
  ) async {
    try {
      final response = await _get(
        Uri.parse("$baseUrl/get_order_history.php?tenant_id=$tenantId"),
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

  static Future<int> checkOrderChange(String tenantId) async {
    try {
      final response = await _get(
        Uri.parse("$baseUrl/check_order_sync.php?tenant_id=$tenantId"),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') return (data['last_mod'] as int);
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  // --- TABLES STATE & PERSISTENT FALLBACK ---
  static final List<Map<String, dynamic>> _localTables = [];

  static Future<void> _ensureLocalTablesLoaded(String tenantId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr =
          prefs.getString('saved_tables_$tenantId') ??
          prefs.getString('saved_tables_global') ??
          prefs.getString('saved_tables_startups_main');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> decoded = json.decode(jsonStr);
        _localTables.clear();
        _localTables.addAll(decoded.map((x) => Map<String, dynamic>.from(x)));
      }

      if (_localTables.isEmpty) {
        _localTables.clear();
        final List<int> dbTableNumbers = [
          5,
          10,
          8,
          11,
          12,
          7,
          18,
          13,
          20,
          22,
          99,
          98,
          2,
          1,
          101,
          4,
          3,
        ];
        int idCounter = 15;
        for (var num in dbTableNumbers) {
          _localTables.add({
            'id': idCounter++,
            'tenant_id': tenantId,
            'table_number': num,
            'status': 'Available',
          });
        }
        await _persistLocalTables(tenantId);
      }
    } catch (e) {
      debugPrint("Error loading local tables: $e");
    }
  }

  static Future<void> _persistLocalTables(String tenantId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = json.encode(_localTables);
      await prefs.setString('saved_tables_$tenantId', encoded);
      await prefs.setString('saved_tables_global', encoded);
      await prefs.setString('saved_tables_startups_main', encoded);
    } catch (e) {
      debugPrint("Error persisting local tables: $e");
    }
  }

  static Future<bool> addTable(String tenantId, int tableNumber) async {
    await _ensureLocalTablesLoaded(tenantId);

    if (!_localTables.any(
      (t) => t['table_number'].toString() == tableNumber.toString(),
    )) {
      _localTables.add({
        'id': DateTime.now().millisecondsSinceEpoch % 100000,
        'tenant_id': tenantId,
        'table_number': tableNumber,
        'status': 'Available',
      });
      await _persistLocalTables(tenantId);
    }

    try {
      final response = await _post(
        Uri.parse("$baseUrl/add_table.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"tenant_id": tenantId, "table_number": tableNumber}),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body)['status'] == 'success';
      }
    } catch (e) {
      debugPrint("Server add table notice: $e");
    }
    return true;
  }

  static Future<List<Map<String, dynamic>>?> fetchTables(
    String tenantId, {
    bool onlyActive = false,
  }) async {
    await _ensureLocalTablesLoaded(tenantId);
    List<Map<String, dynamic>> serverTables = [];

    // Try fetching for current tenantId
    try {
      final response = await _get(
        Uri.parse("$baseUrl/get_tables.php?tenant_id=$tenantId"),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['data'] != null && data['data'] is List) {
          serverTables = List<Map<String, dynamic>>.from(data['data']);
        }
      }
    } catch (e) {
      debugPrint("Error fetching tables from server: $e");
    }

    // If empty, fallback to 'startups_main' (where database tables are stored)
    if (serverTables.isEmpty && tenantId != 'startups_main') {
      try {
        final response = await _get(
          Uri.parse("$baseUrl/get_tables.php?tenant_id=startups_main"),
        );
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['data'] != null && data['data'] is List) {
            serverTables = List<Map<String, dynamic>>.from(data['data']);
          }
        }
      } catch (e) {
        debugPrint("Error fetching tables for startups_main: $e");
      }
    }

    List<Map<String, dynamic>> resultTables = serverTables.isNotEmpty
        ? serverTables
        : _localTables;

    if (serverTables.isNotEmpty) {
      _localTables.clear();
      _localTables.addAll(serverTables);
      await _persistLocalTables(tenantId);
    }

    if (onlyActive) {
      resultTables = resultTables.where((t) {
        bool isEnabled = t['is_enabled'] ?? t['is_active'] ?? true;
        if (isEnabled.toString() == '0' || isEnabled.toString() == 'false')
          isEnabled = false;
        return isEnabled;
      }).toList();
    }

    return resultTables;
  }

  static Future<bool> deleteTable(dynamic tableId) async {
    final tidStr = tableId.toString();
    _localTables.removeWhere(
      (t) =>
          t['id'].toString() == tidStr ||
          t['table_number'].toString() == tidStr,
    );

    // Persist changes across local tables if tenantId is active
    for (var t in _localTables) {
      final tenantId = t['tenant_id']?.toString() ?? '1';
      await _persistLocalTables(tenantId);
      break;
    }

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
      debugPrint("Server delete table notice: $e");
    }
    return true;
  }

  static Future<bool> updateTableStatus(dynamic tableId, bool isEnabled) async {
    final tidStr = tableId.toString();
    for (var t in _localTables) {
      if (t['id'].toString() == tidStr ||
          t['table_number'].toString() == tidStr) {
        t['is_enabled'] = isEnabled;
        final tenantId = t['tenant_id']?.toString() ?? 'startups_main';
        await _persistLocalTables(tenantId);
        break;
      }
    }
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
      debugPrint("Server update table status notice: $e");
    }
    return true;
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
        Uri.parse("$baseUrl/get_stock_reports.php?tenant_id=$tenantId"),
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

  static Future<Map<String, dynamic>> reportStockOut(
    Map<String, dynamic> reportData,
  ) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/report_stock_out.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode(reportData),
      );
      return json.decode(response.body);
    } catch (e) {
      return {"success": false};
    }
  }

  static Future<int> fetchUnseenStockAlertCount(String tenantId) async {
    try {
      final response = await _get(
        Uri.parse("$baseUrl/get_unseen_alert_count.php?tenant_id=$tenantId"),
      );
      if (response.statusCode == 200)
        return json.decode(response.body)['count'] ?? 0;
      return 0;
    } catch (e) {
      return 0;
    }
  }

  static Future<void> markStockAlertsAsSeen(String tenantId) async {
    try {
      await _post(
        Uri.parse("$baseUrl/mark_alerts_seen.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"tenant_id": tenantId}),
      );
    } catch (e) {}
  }

  static Future<Map<String, dynamic>> updateStockReportStatus(
    int reportId,
    String status,
  ) async {
    try {
      final response = await _post(
        Uri.parse("$baseUrl/update_stock_report.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"report_id": reportId, "status": status}),
      );
      return json.decode(response.body);
    } catch (e) {
      return {"success": false};
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
        if (data['status'] == 'success') return data;
      }
      return null;
    } catch (e) {
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
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "tenant_id": tenantId,
          "user_id": myId,
          "target_id": targetId,
        }),
      );
      final data = json.decode(response.body);
      return {
        "success": data['status'] == 'success',
        "is_following": data['following'] ?? false,
      };
    } catch (e) {
      return {"success": false, "is_following": false};
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
      return json.decode(response.body)['status'] == 'success';
    } catch (e) {
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
    String userId,
    {String? sessionToken}
  ) async {
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
    String userId,
    {String? sessionToken}
  ) async {
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
      final tId = tenantId.isNotEmpty ? tenantId : 'startups_main';
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final url = Uri.parse(
        "$baseUrl/music_api.php?action=get_status&tenant_id=$tId&user_id=${userId ?? ''}&t=$timestamp",
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
      final tId = tenantId.isNotEmpty ? tenantId : 'startups_main';
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Try GET first to bypass Chrome localhost CORS
      final url = Uri.parse(
        "$baseUrl/music_api.php?action=vote&tenant_id=$tId&song_id=$songId&user_id=$userId&t=$timestamp",
      );
      final response = await _get(url);
      if (response.statusCode == 200) return json.decode(response.body);

      // Fallback POST
      final postRes = await _post(
        Uri.parse("$baseUrl/music_api.php?action=vote&tenant_id=$tId"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"song_id": songId, "user_id": userId}),
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
      final tId = (data['tenant_id'] ?? '').toString().isNotEmpty
          ? data['tenant_id'].toString()
          : 'startups_main';
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
      final tId = (data['tenant_id'] ?? '').toString().isNotEmpty
          ? data['tenant_id'].toString()
          : 'startups_main';
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
      final tId = tenantId.isNotEmpty ? tenantId : 'startups_main';
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
      final response = await _post(
        Uri.parse(
          "$baseUrl/music_api.php?action=create_poll&tenant_id=${data['tenant_id']}",
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
}
