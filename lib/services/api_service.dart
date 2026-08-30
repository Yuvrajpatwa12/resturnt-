import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class ApiService {
  // --- 1. CONFIGURATION ---
  // Using 'saas_api' to avoid conflict with existing folders on your Hostinger
  static const String baseUrl = "https://startupsgo.tech/saas_api"; 

  static Future<Map<String, dynamic>?> initTenant(String domain) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/init_tenant.php?domain=$domain"));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          return data['data'];
        }
      }
      return null;
    } catch (e) {
      debugPrint("API Error (initTenant): $e");
      return null;
    }
  }

  static Future<Map<String, dynamic>?> fetchMenu(String tenantId) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/get_menu.php?tenant_id=$tenantId"));
      
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
      debugPrint("API Error (fetchMenu): $e");
      return null;
    }
  }

  // --- SUPER ADMIN METHODS ---

  static Future<List<Map<String, dynamic>>?> fetchTenants() async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/get_tenants.php"));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
      return null;
    } catch (e) {
      debugPrint("API Error (fetchTenants): $e");
      return null;
    }
  }

  static Future<bool> registerTenant(Map<String, dynamic> tenantData) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/register_tenant.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode(tenantData),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['status'] == 'success';
      }
      return false;
    } catch (e) {
      debugPrint("API Error (registerTenant): $e");
      return false;
    }
  }

  static Future<Map<String, dynamic>> updateCredentials({
    required String tenantId,
    required String email,
    required String pin,
  }) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/update_tenant_credentials.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "tenant_id": tenantId,
          "email": email,
          "pin": pin,
        }),
      );
      
      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        return {"success": true, "message": data['message'] ?? "Updated!"};
      } else {
        return {"success": false, "message": data['message'] ?? "Server Error ${response.statusCode}"};
      }
    } catch (e) {
      debugPrint("API Error (updateCredentials): $e");
      return {"success": false, "message": "Connection failed: $e"};
    }
  }

  static Future<bool> deleteTenant(String tenantId) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/delete_tenant.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"tenant_id": tenantId}),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['status'] == 'success';
      }
      return false;
    } catch (e) {
      debugPrint("API Error (deleteTenant): $e");
      return false;
    }
  }

  static Future<bool> addProduct(Map<String, dynamic> productData) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/add_product.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode(productData),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['status'] == 'success';
      }
      return false;
    } catch (e) {
      debugPrint("API Error (addProduct): $e");
      return false;
    }
  }

  static Future<bool> deleteProduct(String tenantId, String productId) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/delete_product.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"tenant_id": tenantId, "product_id": productId}),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['status'] == 'success';
      }
      return false;
    } catch (e) {
      debugPrint("API Error (deleteProduct): $e");
      return false;
    }
  }

  static Future<bool> addCategory(String tenantId, String title, int rank) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/add_category.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"tenant_id": tenantId, "title": title, "rank": rank}),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['status'] == 'success';
      }
      return false;
    } catch (e) {
      debugPrint("API Error (addCategory): $e");
      return false;
    }
  }

  static Future<Map<String, dynamic>> deleteCategory(String tenantId, String categoryId) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/delete_category.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"tenant_id": tenantId, "category_id": categoryId}),
      );
      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        return {"success": true};
      }
      return {"success": false, "message": data['message'] ?? "Server Error"};
    } catch (e) {
      debugPrint("API Error (deleteCategory): $e");
      return {"success": false, "message": e.toString()};
    }
  }

  static Future<List<Map<String, dynamic>>?> fetchPurchases(String tenantId) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/get_purchases.php?tenant_id=$tenantId"));
      
      // Debug: Print raw response
      debugPrint("FETCH PURCHASES RAW: ${response.body}");

      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          if (data['status'] == 'success') {
            return List<Map<String, dynamic>>.from(data['data']);
          }
        } catch (e) {
          debugPrint("JSON PARSE ERROR in fetchPurchases: ${response.body}");
        }
      }
      return null;
    } catch (e) {
      debugPrint("API Error (fetchPurchases): $e");
      return null;
    }
  }

  static Future<Map<String, dynamic>> addPurchase(Map<String, dynamic> purchaseData) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/add_purchase.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode(purchaseData),
      );

      // Debug: Print raw response to console
      debugPrint("RAW RESPONSE: ${response.body}");

      if (response.body.isEmpty) {
        return {"success": false, "message": "Server returned an empty response."};
      }

      try {
        final data = json.decode(response.body);
        if (response.statusCode == 200 && data['status'] == 'success') {
          return {"success": true};
        }
        return {"success": false, "message": data['message'] ?? "Server Error ${response.statusCode}"};
      } catch (jsonError) {
        // If JSON parsing fails, show the raw body to the user
        return {"success": false, "message": "Invalid Server Response"};
      }
    } catch (e) {
      debugPrint("API Error (addPurchase): $e");
      return {"success": false, "message": "Connection Error: $e"};
    }
  }

  static Future<Map<String, dynamic>> deletePurchase(String tenantId, String purchaseId) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/delete_purchase.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"tenant_id": tenantId, "purchase_id": purchaseId}),
      );
      
      debugPrint("DELETE PURCHASE RAW: ${response.body}");
      
      if (response.body.isEmpty) return {"success": false, "message": "Empty response"};
      
      try {
        final data = json.decode(response.body);
        if (response.statusCode == 200 && data['status'] == 'success') {
          return {"success": true};
        }
        return {"success": false, "message": data['message'] ?? "Server Error"};
      } catch (e) {
        return {"success": false, "message": "Invalid Response: ${response.body}"};
      }
    } catch (e) {
      debugPrint("API Error (deletePurchase): $e");
      return {"success": false, "message": "Connection Error: $e"};
    }
  }

  // --- PURCHASE RETURN METHODS ---

  static Future<Map<String, dynamic>> addReturn(Map<String, dynamic> returnData) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/add_return.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode(returnData),
      );
      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        return {"success": true};
      }
      return {"success": false, "message": data['message'] ?? "Server Error"};
    } catch (e) {
      return {"success": false, "message": e.toString()};
    }
  }

  static Future<List<Map<String, dynamic>>?> fetchReturns(String tenantId) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/get_returns.php?tenant_id=$tenantId"));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
      return null;
    } catch (e) {
      debugPrint("API Error (fetchReturns): $e");
      return null;
    }
  }

  static Future<Map<String, dynamic>> deleteReturn(String tenantId, String returnId) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/delete_return.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"tenant_id": tenantId, "return_id": returnId}),
      );
      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        return {"success": true};
      }
      return {"success": false, "message": data['message'] ?? "Server Error"};
    } catch (e) {
      return {"success": false, "message": e.toString()};
    }
  }

  // --- SUPPLIER MANAGEMENT METHODS ---

  static Future<List<Map<String, dynamic>>?> fetchSuppliers(String tenantId) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/get_suppliers.php?tenant_id=$tenantId"));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
      return null;
    } catch (e) {
      debugPrint("API Error (fetchSuppliers): $e");
      return null;
    }
  }

  static Future<Map<String, dynamic>> addSupplier(Map<String, dynamic> supplierData) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/add_supplier.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode(supplierData),
      );

      debugPrint("ADD SUPPLIER RAW: ${response.body}");

      if (response.body.isEmpty) return {"success": false, "message": "Empty response from server."};

      try {
        final data = json.decode(response.body);
        if (response.statusCode == 200 && data['status'] == 'success') {
          return {"success": true};
        }
        return {"success": false, "message": data['message'] ?? "Server Error"};
      } catch (e) {
        // If JSON fails, show exactly what the server sent
        return {"success": false, "message": "Server sent invalid data: ${response.body}"};
      }
    } catch (e) {
      return {"success": false, "message": "Connection Error: $e"};
    }
  }

  static Future<Map<String, dynamic>> updateSupplier(Map<String, dynamic> supplierData) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/update_supplier.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode(supplierData),
      );
      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        return {"success": true};
      }
      return {"success": false, "message": data['message'] ?? "Server Error"};
    } catch (e) {
      debugPrint("API Error (updateSupplier): $e");
      return {"success": false, "message": e.toString()};
    }
  }

  static Future<Map<String, dynamic>> deleteSupplier(String tenantId, String supplierId) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/delete_supplier.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"tenant_id": tenantId, "id": supplierId}),
      );
      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        return {"success": true};
      }
      return {"success": false, "message": data['message'] ?? "Server Error"};
    } catch (e) {
      return {"success": false, "message": e.toString()};
    }
  }

  static Future<List<Map<String, dynamic>>?> fetchAllOrders(String tenantId) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/get_all_orders.php?tenant_id=$tenantId"));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
      return null;
    } catch (e) {
      debugPrint("API Error (fetchAllOrders): $e");
      return null;
    }
  }

  static Future<Map<String, dynamic>> deleteOrder(String tenantId, String orderId) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/delete_order.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"tenant_id": tenantId, "order_id": orderId}),
      );
      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        return {"success": true};
      }
      return {"success": false, "message": data['message'] ?? "Server Error"};
    } catch (e) {
      debugPrint("API Error (deleteOrder): $e");
      return {"success": false, "message": e.toString()};
    }
  }

  static Future<Map<String, dynamic>> staffLogin({
    required String domain,
    required String email,
    required String pin,
  }) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/staff_login.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "domain": domain,
          "email": email,
          "pin": pin,
        }),
      );
      
      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        return {"success": true, "user": data['user']};
      } else {
        return {"success": false, "message": data['message'] ?? "Invalid credentials."};
      }
    } catch (e) {
      debugPrint("API Error (staffLogin): $e");
      return {"success": false, "message": "Network error: $e"};
    }
  }

  // --- SUPER ADMIN DASHBOARD METHODS ---

  static Future<Map<String, dynamic>?> fetchAdminStats() async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/admin_get_stats.php"));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') return data['data'];
      }
      return null;
    } catch (e) {
      debugPrint("API Error (fetchAdminStats): $e");
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>?> fetchResourceUsage() async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/admin_get_resources.php"));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') return List<Map<String, dynamic>>.from(data['data']);
      }
      return null;
    } catch (e) {
      debugPrint("API Error (fetchResourceUsage): $e");
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>?> fetchSupportTickets() async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/admin_get_tickets.php"));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') return List<Map<String, dynamic>>.from(data['data']);
      }
      return null;
    } catch (e) {
      debugPrint("API Error (fetchSupportTickets): $e");
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>?> fetchTenantStaff(String tenantId) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/get_tenant_staff.php?tenant_id=$tenantId"));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') return List<Map<String, dynamic>>.from(data['data']);
      }
      return null;
    } catch (e) {
      debugPrint("API Error (fetchTenantStaff): $e");
      return null;
    }
  }

  // --- RESTAURANT ADMIN SUPPORT METHODS ---

  static Future<bool> createSupportTicket(Map<String, dynamic> ticketData) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/create_ticket.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode(ticketData),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['status'] == 'success';
      }
      return false;
    } catch (e) {
      debugPrint("API Error (createSupportTicket): $e");
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>?> fetchMyTickets(String tenantId) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/get_my_tickets.php?tenant_id=$tenantId"));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') return List<Map<String, dynamic>>.from(data['data']);
      }
      return null;
    } catch (e) {
      debugPrint("API Error (fetchMyTickets): $e");
      return null;
    }
  }

  static Future<bool> sendTicketReply({required int ticketId, required String message, String senderType = 'Admin'}) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/send_ticket_reply.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"ticket_id": ticketId, "message": message, "sender_type": senderType}),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['status'] == 'success';
      }
      return false;
    } catch (e) {
      debugPrint("API Error (sendTicketReply): $e");
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>?> fetchTicketHistory(int ticketId) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/get_ticket_history.php?ticket_id=$ticketId"));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') return List<Map<String, dynamic>>.from(data['data']);
      }
      return null;
    } catch (e) {
      debugPrint("API Error (fetchTicketHistory): $e");
      return null;
    }
  }

  static Future<String?> uploadProfilePicture(Uint8List bytes, String fileName) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse("$baseUrl/upload_profile.php"));
      request.files.add(http.MultipartFile.fromBytes(
        'profile_pic',
        bytes,
        filename: fileName,
      ));

      final response = await request.send();
      if (response.statusCode == 200) {
        final resStr = await response.stream.bytesToString();
        final data = json.decode(resStr);
        if (data['status'] == 'success') {
          return data['url'];
        }
      }
      return null;
    } catch (e) {
      debugPrint("API ERROR (uploadProfilePicture): $e");
      return null;
    }
  }

  // --- HRM / STAFF METHODS ---

  static Future<bool> addStaff(Map<String, dynamic> staffData) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/add_staff.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode(staffData),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['status'] == 'success';
      }
      return false;
    } catch (e) {
      debugPrint("API Error (addStaff): $e");
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>?> fetchStaff(String tenantId) async {
    try {
      // Forcefully adding a unique timestamp to every request
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final url = "$baseUrl/get_staff.php?tenant_id=$tenantId&nocache=$timestamp";
      
      debugPrint("API CALL -> $url"); // Print this to verify in console
      
      final response = await http.get(Uri.parse(url));
      debugPrint("API RESPONSE -> ${response.body}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
      return null;
    } catch (e) {
      debugPrint("API ERROR -> $e");
      return null;
    }
  }

  static Future<bool> deleteStaff(int userId) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/delete_staff.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"user_id": userId}),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['status'] == 'success';
      }
      return false;
    } catch (e) {
      debugPrint("API Error (deleteStaff): $e");
      return false;
    }
  }

  static Future<Map<String, dynamic>?> placeTableOrder(Map<String, dynamic> orderData) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/place_order.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode(orderData),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        return {
          "status": "error",
          "message": "HTTP ${response.statusCode}: ${response.body.isNotEmpty ? response.body : 'Internal Server Error'}"
        };
      }
    } catch (e) {
      debugPrint("API CRASH (placeTableOrder): $e");
      return {
        "status": "error",
        "message": "Connection Crash: $e"
      };
    }
  }

  static Future<bool> updateOrderStatus(int orderId, String status) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/update_order_status.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"order_id": orderId, "new_status": status}),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['status'] == 'success';
      }
      return false;
    } catch (e) {
      debugPrint("API Error (updateOrderStatus): $e");
      return false;
    }
  }

  static Future<bool> waiterApproveOrder(int orderId, int waiterId) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/waiter_approve_order.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"order_id": orderId, "waiter_id": waiterId}),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['status'] == 'success';
      }
      return false;
    } catch (e) {
      debugPrint("API Error (waiterApproveOrder): $e");
      return false;
    }
  }

  static Future<bool> waiterAcceptDelivery(int orderId, int waiterId) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/waiter_accept_delivery.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"order_id": orderId, "waiter_id": waiterId}),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['status'] == 'success';
      }
      return false;
    } catch (e) {
      debugPrint("API Error (waiterAcceptDelivery): $e");
      return false;
    }
  }

  static Future<String?> fetchOrderStatus(int orderId) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/get_order_status.php?order_id=$orderId"));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') return data['order_status'];
      }
      return null;
    } catch (e) {
      debugPrint("API Error (fetchOrderStatus): $e");
      return null;
    }
  }

  static Future<bool> updateStaff(Map<String, dynamic> staffData) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/update_staff.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode(staffData),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['status'] == 'success';
      }
      return false;
    } catch (e) {
      debugPrint("API Error (updateStaff): $e");
      return false;
    }
  }

  // --- TABLE MANAGEMENT METHODS ---

  static Future<bool> addTable(String tenantId, int tableNumber) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/add_table.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"tenant_id": tenantId, "table_number": tableNumber}),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['status'] == 'success';
      }
      return false;
    } catch (e) {
      debugPrint("API Error (addTable): $e");
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>?> fetchTables(String tenantId) async {
    try {
      debugPrint("API: Fetching tables for $tenantId...");
      final response = await http.get(Uri.parse("$baseUrl/get_tables.php?tenant_id=$tenantId"));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          final List<Map<String, dynamic>> tables = List<Map<String, dynamic>>.from(data['data']);
          debugPrint("API SUCCESS: Found ${tables.length} tables.");
          return tables;
        }
      }
      debugPrint("API FAILED: Status code ${response.statusCode}");
      return null;
    } catch (e) {
      debugPrint("API CRASH (fetchTables): $e");
      return null;
    }
  }

  static Future<bool> deleteTable(int tableId) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/delete_table.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"table_id": tableId}),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['status'] == 'success';
      }
      return false;
    } catch (e) {
      debugPrint("API Error (deleteTable): $e");
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>?> fetchActiveOrders(String tenantId) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/get_active_orders.php?tenant_id=$tenantId"));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') return List<Map<String, dynamic>>.from(data['data']);
      }
      return null;
    } catch (e) {
      debugPrint("API Error (fetchActiveOrders): $e");
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>?> fetchPendingOrders(String tenantId) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/get_pending_orders.php?tenant_id=$tenantId"));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') return List<Map<String, dynamic>>.from(data['data']);
      }
      return null;
    } catch (e) {
      debugPrint("API Error (fetchPendingOrders): $e");
      return null;
    }
  }

  // --- STOCK REPORTING METHODS ---

  static Future<Map<String, dynamic>> reportStockOut(Map<String, dynamic> reportData) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/report_stock_out.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode(reportData),
      );
      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        return {"success": true};
      }
      return {"success": false, "message": data['message'] ?? "Server Error"};
    } catch (e) {
      return {"success": false, "message": e.toString()};
    }
  }

  static Future<List<Map<String, dynamic>>?> fetchStockReports(String tenantId) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/get_stock_reports.php?tenant_id=$tenantId"));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') return List<Map<String, dynamic>>.from(data['data']);
      }
      return null;
    } catch (e) {
      debugPrint("API Error (fetchStockReports): $e");
      return null;
    }
  }

  static Future<int> fetchUnseenStockAlertCount(String tenantId) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/get_unseen_alert_count.php?tenant_id=$tenantId"));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') return (data['count'] as int);
      }
      return 0;
    } catch (e) {
      debugPrint("API Error (fetchUnseenStockAlertCount): $e");
      return 0;
    }
  }

  static Future<void> markStockAlertsAsSeen(String tenantId) async {
    try {
      await http.post(
        Uri.parse("$baseUrl/mark_alerts_seen.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"tenant_id": tenantId}),
      );
    } catch (e) {
      debugPrint("API Error (markStockAlertsAsSeen): $e");
    }
  }

  static Future<Map<String, dynamic>> updateStockReportStatus(int reportId, String status) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/update_stock_report.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"report_id": reportId, "status": status}),
      );
      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        return {"success": true};
      }
      return {"success": false, "message": data['message'] ?? "Server Error"};
    } catch (e) {
      return {"success": false, "message": e.toString()};
    }
  }

  // Add more API methods here (fetchProducts, login, etc.)
}
