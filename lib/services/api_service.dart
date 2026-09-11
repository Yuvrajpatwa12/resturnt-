import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class ApiService {
  // --- 1. CONFIGURATION ---
  static const String baseUrl = "https://startupsgo.tech/saas_api"; 

  static Future<Map<String, dynamic>?> initTenant(String domain) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/init_tenant.php?domain=$domain"));
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

  static Future<Map<String, dynamic>?> fetchMenu(String tenantId) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/get_menu.php?tenant_id=$tenantId"));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          return {"categories": data['categories'], "products": data['products']};
        }
      }
      return null;
    } catch (e) { return null; }
  }

  // --- SUPER ADMIN METHODS ---

  static Future<List<Map<String, dynamic>>?> fetchTenants() async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/get_tenants.php"));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') return List<Map<String, dynamic>>.from(data['data']);
      }
      return null;
    } catch (e) { return null; }
  }

  static Future<bool> registerTenant(Map<String, dynamic> tenantData) async {
    try {
      final response = await http.post(Uri.parse("$baseUrl/register_tenant.php"), headers: {"Content-Type": "application/json"}, body: json.encode(tenantData));
      return json.decode(response.body)['status'] == 'success';
    } catch (e) { return false; }
  }

  static Future<Map<String, dynamic>> updateCredentials({required String tenantId, required String email, required String pin}) async {
    try {
      final response = await http.post(Uri.parse("$baseUrl/update_tenant_credentials.php"), headers: {"Content-Type": "application/json"}, body: json.encode({"tenant_id": tenantId, "email": email, "pin": pin}));
      return json.decode(response.body);
    } catch (e) { return {"success": false, "message": "Connection failed"}; }
  }

  static Future<Map<String, dynamic>> updateTenantLocation({
    required String tenantId, 
    required double latitude, 
    required double longitude
  }) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/update_tenant_location.php"), 
        headers: {"Content-Type": "application/json"}, 
        body: json.encode({
          "tenant_id": tenantId, 
          "latitude": latitude, 
          "longitude": longitude
        })
      );
      return json.decode(response.body);
    } catch (e) { return {"success": false, "message": "Connection failed"}; }
  }

  static Future<bool> deleteTenant(String tenantId) async {
    try {
      final response = await http.post(Uri.parse("$baseUrl/delete_tenant.php"), headers: {"Content-Type": "application/json"}, body: json.encode({"tenant_id": tenantId}));
      return json.decode(response.body)['status'] == 'success';
    } catch (e) { return false; }
  }

  static Future<Map<String, dynamic>> addProduct(Map<String, dynamic> productData) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/add_product.php"), 
        headers: {"Content-Type": "application/json"}, 
        body: json.encode(productData)
      );
      final result = json.decode(response.body);
      if (result['status'] == 'success') {
        return {"success": true};
      } else {
        return {"success": false, "message": result['message'] ?? "Unknown Error"};
      }
    } catch (e) { 
      return {"success": false, "message": "Connection error: $e"}; 
    }
  }

  static Future<Map<String, dynamic>> updateProduct(Map<String, dynamic> productData) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/update_product.php"), 
        headers: {"Content-Type": "application/json"}, 
        body: json.encode(productData)
      );
      final result = json.decode(response.body);
      if (result['status'] == 'success') {
        return {"success": true};
      } else {
        return {"success": false, "message": result['message'] ?? "Unknown Error"};
      }
    } catch (e) { 
      return {"success": false, "message": "Connection error: $e"}; 
    }
  }

  static Future<bool> deleteProduct(String tenantId, String productId) async {
    try {
      final response = await http.post(Uri.parse("$baseUrl/delete_product.php"), headers: {"Content-Type": "application/json"}, body: json.encode({"tenant_id": tenantId, "product_id": productId}));
      return json.decode(response.body)['status'] == 'success';
    } catch (e) { return false; }
  }

  static Future<bool> addCategory(String tenantId, String title, int rank, {String icon = 'restaurant_menu'}) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/add_category.php"), 
        headers: {"Content-Type": "application/json"}, 
        body: json.encode({
          "tenant_id": tenantId, 
          "title": title, 
          "rank": rank,
          "icon": icon,
        })
      );
      return json.decode(response.body)['status'] == 'success';
    } catch (e) { return false; }
  }

  static Future<Map<String, dynamic>> updateCategory({
    required String tenantId, 
    required String categoryId, 
    required String title, 
    required int rank,
    required String icon,
  }) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/update_category.php"), 
        headers: {"Content-Type": "application/json"}, 
        body: json.encode({
          "tenant_id": tenantId, 
          "category_id": categoryId,
          "title": title, 
          "rank": rank,
          "icon": icon,
        })
      );
      final data = json.decode(response.body);
      return {"success": data['status'] == 'success', "message": data['message']};
    } catch (e) { return {"success": false, "message": "Connection error"}; }
  }

  static Future<Map<String, dynamic>> deleteCategory(String tenantId, String categoryId) async {
    try {
      final response = await http.post(Uri.parse("$baseUrl/delete_category.php"), headers: {"Content-Type": "application/json"}, body: json.encode({"tenant_id": tenantId, "category_id": categoryId}));
      final data = json.decode(response.body);
      return {"success": data['status'] == 'success', "message": data['message']};
    } catch (e) { return {"success": false, "message": "Error"}; }
  }

  static Future<List<Map<String, dynamic>>?> fetchPurchases(String tenantId) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/get_purchases.php?tenant_id=$tenantId"));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') return List<Map<String, dynamic>>.from(data['data']);
      }
      return null;
    } catch (e) { return null; }
  }

  static Future<Map<String, dynamic>> addPurchase(Map<String, dynamic> purchaseData) async {
    try {
      final response = await http.post(Uri.parse("$baseUrl/add_purchase.php"), headers: {"Content-Type": "application/json"}, body: json.encode(purchaseData));
      final data = json.decode(response.body);
      return {"success": data['status'] == 'success', "message": data['message']};
    } catch (e) { return {"success": false, "message": "Error"}; }
  }

  static Future<Map<String, dynamic>> deletePurchase(String tenantId, String purchaseId) async {
    try {
      final response = await http.post(Uri.parse("$baseUrl/delete_purchase.php"), headers: {"Content-Type": "application/json"}, body: json.encode({"tenant_id": tenantId, "purchase_id": purchaseId}));
      final data = json.decode(response.body);
      return {"success": data['status'] == 'success', "message": data['message']};
    } catch (e) { return {"success": false, "message": "Error"}; }
  }

  // --- PURCHASE RETURN METHODS ---

  static Future<Map<String, dynamic>> addReturn(Map<String, dynamic> returnData) async {
    try {
      final response = await http.post(Uri.parse("$baseUrl/add_return.php"), headers: {"Content-Type": "application/json"}, body: json.encode(returnData));
      final data = json.decode(response.body);
      return {"success": data['status'] == 'success', "message": data['message']};
    } catch (e) { return {"success": false}; }
  }

  static Future<List<Map<String, dynamic>>?> fetchReturns(String tenantId) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/get_returns.php?tenant_id=$tenantId"));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') return List<Map<String, dynamic>>.from(data['data']);
      }
      return null;
    } catch (e) { return null; }
  }

  static Future<Map<String, dynamic>> deleteReturn(String tenantId, String returnId) async {
    try {
      final response = await http.post(Uri.parse("$baseUrl/delete_return.php"), headers: {"Content-Type": "application/json"}, body: json.encode({"tenant_id": tenantId, "return_id": returnId}));
      final data = json.decode(response.body);
      return {"success": data['status'] == 'success'};
    } catch (e) { return {"success": false}; }
  }

  // --- SUPPLIER MANAGEMENT METHODS ---

  static Future<List<Map<String, dynamic>>?> fetchSuppliers(String tenantId) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/get_suppliers.php?tenant_id=$tenantId"));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') return List<Map<String, dynamic>>.from(data['data']);
      }
      return null;
    } catch (e) { return null; }
  }

  static Future<Map<String, dynamic>> addSupplier(Map<String, dynamic> supplierData) async {
    try {
      final response = await http.post(Uri.parse("$baseUrl/add_supplier.php"), headers: {"Content-Type": "application/json"}, body: json.encode(supplierData));
      final data = json.decode(response.body);
      return {"success": data['status'] == 'success', "message": data['message']};
    } catch (e) { return {"success": false}; }
  }

  static Future<Map<String, dynamic>> updateSupplier(Map<String, dynamic> supplierData) async {
    try {
      final response = await http.post(Uri.parse("$baseUrl/update_supplier.php"), headers: {"Content-Type": "application/json"}, body: json.encode(supplierData));
      final data = json.decode(response.body);
      return {"success": data['status'] == 'success'};
    } catch (e) { return {"success": false}; }
  }

  static Future<Map<String, dynamic>> deleteSupplier(String tenantId, String supplierId) async {
    try {
      final response = await http.post(Uri.parse("$baseUrl/delete_supplier.php"), headers: {"Content-Type": "application/json"}, body: json.encode({"tenant_id": tenantId, "id": supplierId}));
      final data = json.decode(response.body);
      return {"success": data['status'] == 'success'};
    } catch (e) { return {"success": false}; }
  }

  static Future<List<Map<String, dynamic>>?> fetchAllOrders(String tenantId) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/get_all_orders.php?tenant_id=$tenantId"));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') return List<Map<String, dynamic>>.from(data['data']);
      }
      return null;
    } catch (e) { return null; }
  }

  static Future<Map<String, dynamic>> deleteOrder(String tenantId, String orderId) async {
    try {
      final response = await http.post(Uri.parse("$baseUrl/delete_order.php"), headers: {"Content-Type": "application/json"}, body: json.encode({"tenant_id": tenantId, "order_id": orderId}));
      final data = json.decode(response.body);
      return {"success": data['status'] == 'success'};
    } catch (e) { return {"success": false}; }
  }

  static Future<Map<String, dynamic>> staffLogin({required String domain, required String email, required String pin}) async {
    try {
      final response = await http.post(Uri.parse("$baseUrl/staff_login.php"), headers: {"Content-Type": "application/json"}, body: json.encode({"domain": domain, "email": email, "pin": pin}));
      final data = json.decode(response.body);
      return {"success": data['status'] == 'success', "user": data['user'], "message": data['message']};
    } catch (e) { return {"success": false, "message": "Network error"}; }
  }

  // --- SUPER ADMIN DASHBOARD METHODS ---

  static Future<Map<String, dynamic>?> fetchAdminStats() async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/admin_get_stats.php"));
      if (response.statusCode == 200) return json.decode(response.body)['data'];
      return null;
    } catch (e) { return null; }
  }

  static Future<List<Map<String, dynamic>>?> fetchResourceUsage() async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/admin_get_resources.php"));
      if (response.statusCode == 200) return List<Map<String, dynamic>>.from(json.decode(response.body)['data']);
      return null;
    } catch (e) { return null; }
  }

  static Future<List<Map<String, dynamic>>?> fetchSupportTickets() async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/admin_get_tickets.php"));
      if (response.statusCode == 200) return List<Map<String, dynamic>>.from(json.decode(response.body)['data']);
      return null;
    } catch (e) { return null; }
  }

  static Future<List<Map<String, dynamic>>?> fetchTenantStaff(String tenantId) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/get_tenant_staff.php?tenant_id=$tenantId"));
      if (response.statusCode == 200) return List<Map<String, dynamic>>.from(json.decode(response.body)['data']);
      return null;
    } catch (e) { return null; }
  }

  // --- RESTAURANT ADMIN SUPPORT METHODS ---

  static Future<bool> createSupportTicket(Map<String, dynamic> ticketData) async {
    try {
      final response = await http.post(Uri.parse("$baseUrl/create_ticket.php"), headers: {"Content-Type": "application/json"}, body: json.encode(ticketData));
      return json.decode(response.body)['status'] == 'success';
    } catch (e) { return false; }
  }

  static Future<List<Map<String, dynamic>>?> fetchMyTickets(String tenantId) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/get_my_tickets.php?tenant_id=$tenantId"));
      if (response.statusCode == 200) return List<Map<String, dynamic>>.from(json.decode(response.body)['data']);
      return null;
    } catch (e) { return null; }
  }

  static Future<bool> sendTicketReply({required int ticketId, required String message, String senderType = 'Admin'}) async {
    try {
      final response = await http.post(Uri.parse("$baseUrl/send_ticket_reply.php"), headers: {"Content-Type": "application/json"}, body: json.encode({"ticket_id": ticketId, "message": message, "sender_type": senderType}));
      return json.decode(response.body)['status'] == 'success';
    } catch (e) { return false; }
  }

  static Future<List<Map<String, dynamic>>?> fetchTicketHistory(int ticketId) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/get_ticket_history.php?ticket_id=$ticketId"));
      if (response.statusCode == 200) return List<Map<String, dynamic>>.from(json.decode(response.body)['data']);
      return null;
    } catch (e) { return null; }
  }

  static Future<String?> uploadProfilePicture(Uint8List bytes, String fileName) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse("$baseUrl/upload_profile.php"));
      request.files.add(http.MultipartFile.fromBytes('profile_pic', bytes, filename: fileName));
      final response = await request.send();
      if (response.statusCode == 200) {
        final resStr = await response.stream.bytesToString();
        final data = json.decode(resStr);
        if (data['status'] == 'success') return data['url'];
      }
      return null;
    } catch (e) { return null; }
  }

  // --- HRM / STAFF METHODS ---

  static Future<bool> addStaff(Map<String, dynamic> staffData) async {
    try {
      final response = await http.post(Uri.parse("$baseUrl/add_staff.php"), headers: {"Content-Type": "application/json"}, body: json.encode(staffData));
      return json.decode(response.body)['status'] == 'success';
    } catch (e) { return false; }
  }

  static Future<List<Map<String, dynamic>>?> fetchStaff(String tenantId) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/get_staff.php?tenant_id=$tenantId"));
      if (response.statusCode == 200) return List<Map<String, dynamic>>.from(json.decode(response.body)['data']);
      return null;
    } catch (e) { return null; }
  }

  static Future<bool> updateStaff(Map<String, dynamic> staffData) async {
    try {
      final response = await http.post(Uri.parse("$baseUrl/update_staff.php"), headers: {"Content-Type": "application/json"}, body: json.encode(staffData));
      return json.decode(response.body)['status'] == 'success';
    } catch (e) { return false; }
  }

  static Future<bool> deleteStaff(int userId) async {
    try {
      final response = await http.post(Uri.parse("$baseUrl/delete_staff.php"), headers: {"Content-Type": "application/json"}, body: json.encode({"user_id": userId}));
      return json.decode(response.body)['status'] == 'success';
    } catch (e) { return false; }
  }

  static Future<bool> markAttendance(List<Map<String, dynamic>> attendanceData) async {
    try {
      final response = await http.post(Uri.parse("$baseUrl/mark_attendance.php"), headers: {"Content-Type": "application/json"}, body: json.encode({"attendance": attendanceData}));
      return json.decode(response.body)['status'] == 'success';
    } catch (e) { return false; }
  }

  static Future<bool> markSingleAttendance(Map<String, dynamic> record) async {
    return markAttendance([record]);
  }

  static Future<List<Map<String, dynamic>>?> fetchAttendance(String tenantId, String date) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/get_attendance.php?tenant_id=$tenantId&date=$date"));
      if (response.statusCode == 200) return List<Map<String, dynamic>>.from(json.decode(response.body)['data']);
      return null;
    } catch (e) { return null; }
  }

  static Future<List<Map<String, dynamic>>?> fetchAttendanceReport(String tenantId, String start, String end) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/get_attendance_report.php?tenant_id=$tenantId&start=$start&end=$end"));
      if (response.statusCode == 200) return List<Map<String, dynamic>>.from(json.decode(response.body)['data']);
      return null;
    } catch (e) { return null; }
  }

  static Future<Map<String, dynamic>?> fetchAttendanceAnalytics(String tenantId, String range) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/get_attendance_analytics.php?tenant_id=$tenantId&range=$range"));
      if (response.statusCode == 200) return json.decode(response.body);
      return null;
    } catch (e) { return null; }
  }

  static Future<Map<String, dynamic>?> fetchEmployeeStats(int userId, String month) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/get_employee_stats.php?user_id=$userId&month=$month"));
      if (response.statusCode == 200) return json.decode(response.body);
      return null;
    } catch (e) { return null; }
  }

  // --- ORDERS & TABLES ---

  static Future<Map<String, dynamic>?> placeTableOrder(Map<String, dynamic> orderData) async {
    try {
      final response = await http.post(Uri.parse("$baseUrl/place_order.php"), headers: {"Content-Type": "application/json"}, body: json.encode(orderData));
      return json.decode(response.body);
    } catch (e) { return {"status": "error", "message": "Connection error"}; }
  }

  static Future<Map<String, dynamic>> updateOrderStatus(int orderId, String status) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/update_order_status.php"), 
        headers: {"Content-Type": "application/json"}, 
        body: json.encode({"order_id": orderId, "new_status": status})
      );
      
      final result = json.decode(response.body);
      if (result['status'] == 'success') {
        return {"success": true};
      } else {
        return {"success": false, "message": result['message'] ?? "Server error"};
      }
    } catch (e) { 
      return {"success": false, "message": "Connection error: $e"}; 
    }
  }

  static Future<String?> fetchOrderStatus(int orderId) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/get_order_status.php?order_id=$orderId"));
      if (response.statusCode == 200) return json.decode(response.body)['order_status'];
      return null;
    } catch (e) { return null; }
  }

  static Future<Map<String, dynamic>> waiterApproveOrder(int orderId, int waiterId) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/waiter_approve_order.php"), 
        headers: {"Content-Type": "application/json"}, 
        body: json.encode({"order_id": orderId, "waiter_id": waiterId})
      );
      
      final result = json.decode(response.body);
      if (result['status'] == 'success') {
        return {"success": true};
      } else {
        return {"success": false, "message": result['message'] ?? "Server error"};
      }
    } catch (e) { 
      return {"success": false, "message": "Connection error: $e"}; 
    }
  }

  static Future<Map<String, dynamic>> waiterAcceptDelivery(int orderId, int waiterId) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/waiter_accept_delivery.php"), 
        headers: {"Content-Type": "application/json"}, 
        body: json.encode({"order_id": orderId, "waiter_id": waiterId})
      );
      
      final result = json.decode(response.body);
      if (result['status'] == 'success') {
        return {"success": true};
      } else {
        return {"success": false, "message": result['message'] ?? "Server error"};
      }
    } catch (e) { 
      return {"success": false, "message": "Connection error: $e"}; 
    }
  }

  static Future<List<Map<String, dynamic>>?> fetchActiveOrders(String tenantId) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/get_active_orders.php?tenant_id=$tenantId"));
      if (response.statusCode == 200) return List<Map<String, dynamic>>.from(json.decode(response.body)['data']);
      return null;
    } catch (e) { return null; }
  }

  static Future<List<Map<String, dynamic>>?> fetchPendingOrders(String tenantId) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/get_pending_orders.php?tenant_id=$tenantId"));
      if (response.statusCode == 200) return List<Map<String, dynamic>>.from(json.decode(response.body)['data']);
      return null;
    } catch (e) { return null; }
  }

  static Future<List<Map<String, dynamic>>?> fetchOrderHistory(String tenantId) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/get_order_history.php?tenant_id=$tenantId"));
      if (response.statusCode == 200) return List<Map<String, dynamic>>.from(json.decode(response.body)['data']);
      return null;
    } catch (e) { return null; }
  }

  static Future<int> checkOrderChange(String tenantId) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/check_order_sync.php?tenant_id=$tenantId"));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') return (data['last_mod'] as int);
      }
      return 0;
    } catch (e) { return 0; }
  }

  static Future<bool> addTable(String tenantId, int tableNumber) async {
    try {
      final response = await http.post(Uri.parse("$baseUrl/add_table.php"), headers: {"Content-Type": "application/json"}, body: json.encode({"tenant_id": tenantId, "table_number": tableNumber}));
      return json.decode(response.body)['status'] == 'success';
    } catch (e) { return false; }
  }

  static Future<List<Map<String, dynamic>>?> fetchTables(String tenantId) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/get_tables.php?tenant_id=$tenantId"));
      if (response.statusCode == 200) return List<Map<String, dynamic>>.from(json.decode(response.body)['data']);
      return null;
    } catch (e) { return null; }
  }

  static Future<bool> deleteTable(int tableId) async {
    try {
      final response = await http.post(Uri.parse("$baseUrl/delete_table.php"), headers: {"Content-Type": "application/json"}, body: json.encode({"table_id": tableId}));
      return json.decode(response.body)['status'] == 'success';
    } catch (e) { return false; }
  }

  // --- STOCK & INVENTORY ---

  static Future<List<Map<String, dynamic>>?> fetchStockReports(String tenantId) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/get_stock_reports.php?tenant_id=$tenantId"));
      if (response.statusCode == 200) return List<Map<String, dynamic>>.from(json.decode(response.body)['data']);
      return null;
    } catch (e) { return null; }
  }

  static Future<Map<String, dynamic>> reportStockOut(Map<String, dynamic> reportData) async {
    try {
      final response = await http.post(Uri.parse("$baseUrl/report_stock_out.php"), headers: {"Content-Type": "application/json"}, body: json.encode(reportData));
      return json.decode(response.body);
    } catch (e) { return {"success": false}; }
  }

  static Future<int> fetchUnseenStockAlertCount(String tenantId) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/get_unseen_alert_count.php?tenant_id=$tenantId"));
      if (response.statusCode == 200) return json.decode(response.body)['count'] ?? 0;
      return 0;
    } catch (e) { return 0; }
  }

  static Future<void> markStockAlertsAsSeen(String tenantId) async {
    try {
      await http.post(Uri.parse("$baseUrl/mark_alerts_seen.php"), headers: {"Content-Type": "application/json"}, body: json.encode({"tenant_id": tenantId}));
    } catch (e) {}
  }

  static Future<Map<String, dynamic>> updateStockReportStatus(int reportId, String status) async {
    try {
      final response = await http.post(Uri.parse("$baseUrl/update_stock_report.php"), headers: {"Content-Type": "application/json"}, body: json.encode({"report_id": reportId, "status": status}));
      return json.decode(response.body);
    } catch (e) { return {"success": false}; }
  }

  // --- EXPENSE MANAGEMENT V3 ---

  static Future<Map<String, dynamic>?> fetchExpenseDashboard(String tenantId, String range) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/get_expense_dashboard.php?tenant_id=$tenantId&range=$range"));
      if (response.statusCode == 200) return json.decode(response.body);
      return null;
    } catch (e) { return null; }
  }

  static Future<bool> saveAdvancedExpense(Map<String, dynamic> data) async {
    try {
      final response = await http.post(Uri.parse("$baseUrl/add_expense_v3.php"), headers: {"Content-Type": "application/json"}, body: json.encode(data));
      return json.decode(response.body)['status'] == 'success';
    } catch (e) { return false; }
  }

  static Future<List<Map<String, dynamic>>?> fetchExpenseList(String tenantId) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/get_expenses.php?tenant_id=$tenantId"));
      if (response.statusCode == 200) return List<Map<String, dynamic>>.from(json.decode(response.body)['data']);
      return null;
    } catch (e) { return null; }
  }

  static Future<bool> deleteExpenseV3(int id) async {
    try {
      final response = await http.post(Uri.parse("$baseUrl/delete_expense_v3.php"), headers: {"Content-Type": "application/json"}, body: json.encode({"id": id}));
      return json.decode(response.body)['status'] == 'success';
    } catch (e) { return false; }
  }

  static Future<List<Map<String, dynamic>>?> fetchVendors(String tenantId) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/get_vendors.php?tenant_id=$tenantId"));
      if (response.statusCode == 200) return List<Map<String, dynamic>>.from(json.decode(response.body)['data']);
      return null;
    } catch (e) { return null; }
  }

  static Future<bool> addVendor(Map<String, dynamic> data) async {
    try {
      final response = await http.post(Uri.parse("$baseUrl/add_vendor.php"), headers: {"Content-Type": "application/json"}, body: json.encode(data));
      return json.decode(response.body)['status'] == 'success';
    } catch (e) { return false; }
  }

  static Future<List<Map<String, dynamic>>?> fetchRecurringExpenses(String tenantId) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/get_recurring.php?tenant_id=$tenantId"));
      if (response.statusCode == 200) return List<Map<String, dynamic>>.from(json.decode(response.body)['data']);
      return null;
    } catch (e) { return null; }
  }

  static Future<bool> saveRecurringExpense(Map<String, dynamic> data) async {
    try {
      final response = await http.post(Uri.parse("$baseUrl/add_recurring.php"), headers: {"Content-Type": "application/json"}, body: json.encode(data));
      return json.decode(response.body)['status'] == 'success';
    } catch (e) { return false; }
  }

  static Future<String?> uploadReceipt(Uint8List bytes, String fileName) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse("$baseUrl/upload_receipt.php"));
      request.files.add(http.MultipartFile.fromBytes('receipt', bytes, filename: fileName));
      final response = await request.send();
      if (response.statusCode == 200) {
        final resStr = await response.stream.bytesToString();
        final data = json.decode(resStr);
        if (data['status'] == 'success') return data['url'];
      }
      return null;
    } catch (e) { return null; }
  }

  static Future<String?> uploadProductImage(Uint8List bytes, String fileName) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse("$baseUrl/upload_product_image.php"));
      request.files.add(http.MultipartFile.fromBytes('product_image', bytes, filename: fileName));
      final response = await request.send();
      if (response.statusCode == 200) {
        final resStr = await response.stream.bytesToString();
        final data = json.decode(resStr);
        if (data['status'] == 'success') return data['url'];
      }
      return null;
    } catch (e) { return null; }
  }

  // --- LOYALTY & REWARDS SYSTEM ---

  static Future<Map<String, dynamic>?> fetchLoyaltySettings(String tenantId) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/loyalty_api.php?action=get_settings&tenant_id=$tenantId"));
      if (response.statusCode == 200) return json.decode(response.body)['data'];
      return null;
    } catch (e) { return null; }
  }

  static Future<Map<String, dynamic>> updateLoyaltySettings(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/loyalty_api.php?action=update_settings"),
        headers: {"Content-Type": "application/json"},
        body: json.encode(data),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode != 200) {
        return {"status": "error", "message": "Server Error ${response.statusCode}: ${response.body.isNotEmpty ? response.body : 'Empty response'}"};
      }

      try {
        return json.decode(response.body);
      } catch (e) {
        return {"status": "error", "message": "Invalid Server Response: ${response.body}"};
      }
    } catch (e) { 
      return {"status": "error", "message": "Network Failure: ${e.toString()}"}; 
    }
  }

  static Future<List<Map<String, dynamic>>?> fetchRewards(String tenantId) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/loyalty_api.php?action=get_rewards&tenant_id=$tenantId"));
      if (response.statusCode == 200) return List<Map<String, dynamic>>.from(json.decode(response.body)['data']);
      return null;
    } catch (e) { return null; }
  }

  static Future<bool> addReward(Map<String, dynamic> data) async {
    try {
      final response = await http.post(Uri.parse("$baseUrl/loyalty_api.php?action=add_reward"), headers: {"Content-Type": "application/json"}, body: json.encode(data));
      return json.decode(response.body)['status'] == 'success';
    } catch (e) { return false; }
  }

  static Future<bool> deleteReward(int id) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/loyalty_api.php?action=delete_reward&id=$id"));
      return json.decode(response.body)['status'] == 'success';
    } catch (e) { return false; }
  }

  static Future<List<Map<String, dynamic>>?> fetchMysteryBoxConfig(String tenantId) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/loyalty_api.php?action=get_mystery_box&tenant_id=$tenantId"));
      if (response.statusCode == 200) return List<Map<String, dynamic>>.from(json.decode(response.body)['data']);
      return null;
    } catch (e) { return null; }
  }

  static Future<bool> saveMysteryBoxConfig(String tenantId, List<Map<String, dynamic>> items) async {
    try {
      final response = await http.post(Uri.parse("$baseUrl/loyalty_api.php?action=save_mystery_box"), headers: {"Content-Type": "application/json"}, body: json.encode({"tenant_id": tenantId, "items": items}));
      return json.decode(response.body)['status'] == 'success';
    } catch (e) { return false; }
  }



  static Future<bool> addMysteryPrize(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/loyalty_api.php?action=add_mystery_prize"),
        headers: {"Content-Type": "application/json"},
        body: json.encode(data),
      );
      return json.decode(response.body)['status'] == 'success';
    } catch (e) { return false; }
  }

  static Future<bool> deleteMysteryPrize(int id) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/loyalty_api.php?action=delete_mystery_prize&id=$id"));
      return json.decode(response.body)['status'] == 'success';
    } catch (e) { return false; }
  }

  static Future<bool> updateClaimStatus(int id, String status) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/loyalty_api.php?action=update_claim_status&id=$id&status=$status"));
      return json.decode(response.body)['status'] == 'success';
    } catch (e) { return false; }
  }

  static Future<int> fetchUserPoints(String userId) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/loyalty_api.php?action=get_points&user_id=$userId"));
      if (response.statusCode == 200) return json.decode(response.body)['points'] ?? 0;
      return 0;
    } catch (e) { return 0; }
  }

  static Future<Map<String, dynamic>> addPoints(String tenantId, String userId, {double orderAmount = 0, int points = 0, int incrementStamps = 1}) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/loyalty_api.php?action=add_points"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "tenant_id": tenantId,
          "user_id": userId,
          "order_amount": orderAmount,
          "points": points > 0 ? points : null, // If explicit points given, use them
          "increment_stamps": incrementStamps,
        }),
      );
      return json.decode(response.body);
    } catch (e) { return {"status": "error", "message": "Failed to sync points"}; }
  }

  static Future<Map<String, dynamic>> claimReward(String tenantId, String userId, int rewardId) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/loyalty_api.php?action=claim_reward"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "tenant_id": tenantId,
          "user_id": userId,
          "reward_id": rewardId,
        }),
      );
      return json.decode(response.body);
    } catch (e) { return {"status": "error", "message": "Connection failed"}; }
  }

  static Future<Map<String, dynamic>?> openMysteryBox(String tenantId, String userId) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/loyalty_api.php?action=open_mystery_box&tenant_id=$tenantId&user_id=$userId"));
      if (response.statusCode == 200) return json.decode(response.body);
      return null;
    } catch (e) { return null; }
  }

  static Future<List<Map<String, dynamic>>?> fetchClaimHistory(String tenantId, [String? userId]) async {
    try {
      final url = userId != null 
          ? "$baseUrl/loyalty_api.php?action=get_all_claims&tenant_id=$tenantId&user_id=$userId"
          : "$baseUrl/loyalty_api.php?action=get_all_claims&tenant_id=$tenantId";
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') return List<Map<String, dynamic>>.from(data['data']);
      }
      return null;
    } catch (e) { return null; }
  }

  static Future<Map<String, dynamic>> redeemClaimCode(String tenantId, String code) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/loyalty_api.php?action=redeem_claim&tenant_id=$tenantId"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"claim_code": code}),
      );
      return json.decode(response.body);
    } catch (e) { return {"status": "error", "message": "Connection error"}; }
  }

  // --- MARKETING OFFERS ---

  static Future<List<Map<String, dynamic>>?> fetchOffers(String tenantId) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/offers_api.php?action=get_offers&tenant_id=$tenantId"));
      if (response.statusCode == 200) return List<Map<String, dynamic>>.from(json.decode(response.body)['data']);
      return null;
    } catch (e) { return null; }
  }

  static Future<bool> addOffer(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/offers_api.php?action=add_offer"),
        headers: {"Content-Type": "application/json"},
        body: json.encode(data),
      );
      return json.decode(response.body)['status'] == 'success';
    } catch (e) { return false; }
  }

  static Future<bool> deleteOffer(int id) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/offers_api.php?action=delete_offer&id=$id"));
      return json.decode(response.body)['status'] == 'success';
    } catch (e) { return false; }
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
      final response = await http.post(
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
    } catch (e) { return false; }
  }

  static Future<List<Map<String, dynamic>>?> fetchActiveGuests(String tenantId, String myId) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/nearby_api.php?action=get_active_users&tenant_id=$tenantId&user_id=$myId"));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') return List<Map<String, dynamic>>.from(data['data']);
      }
      return null;
    } catch (e) { return null; }
  }

  static Future<Map<String, dynamic>?> fetchUserOrders(String tenantId, String userId) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/get_user_orders.php?tenant_id=$tenantId&user_id=$userId"));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') return data;
      }
      return null;
    } catch (e) { return null; }
  }

  static Future<Map<String, dynamic>> toggleFollow({required String tenantId, required String myId, required String targetId}) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/nearby_api.php?action=toggle_follow"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"tenant_id": tenantId, "user_id": myId, "target_id": targetId}),
      );
      final data = json.decode(response.body);
      return {
        "success": data['status'] == 'success',
        "is_following": data['following'] ?? false,
      };
    } catch (e) { return {"success": false, "is_following": false}; }
  }

  static Future<Map<String, dynamic>?> fetchSocialStats(String tenantId, String userId) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/nearby_api.php?action=get_social_stats&tenant_id=$tenantId&user_id=$userId"));
      if (response.statusCode == 200) return json.decode(response.body);
      return null;
    } catch (e) { return null; }
  }

  static Future<bool> sendWave({required String tenantId, required String myId, required String targetId}) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/nearby_api.php?action=send_wave"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"tenant_id": tenantId, "sender_id": myId, "receiver_id": targetId}),
      );
      return json.decode(response.body)['status'] == 'success';
    } catch (e) { return false; }
  }

  static Future<List<Map<String, dynamic>>?> fetchWaves(String tenantId, String userId) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/nearby_api.php?action=get_waves&tenant_id=$tenantId&user_id=$userId"));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') return List<Map<String, dynamic>>.from(data['data']);
      }
      return null;
    } catch (e) { return null; }
  }

  // --- CUSTOMER AUTH & IDENTITY ---

  static Future<Map<String, dynamic>?> syncCustomerProfile({required String tenantId, required String email, String? name}) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/auth_customer_api.php?action=sync_profile&tenant_id=$tenantId"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"email": email, "name": name}),
      );
      return json.decode(response.body);
    } catch (e) { return null; }
  }

  static Future<bool> saveCustomerPin({required String tenantId, required String email, required String pin}) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/auth_customer_api.php?action=save_pin&tenant_id=$tenantId"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"email": email, "pin": pin}),
      );
      return json.decode(response.body)['status'] == 'success';
    } catch (e) { return false; }
  }

  static Future<Map<String, dynamic>> verifyCustomerPin({required String tenantId, required String email, required String pin}) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/auth_customer_api.php?action=verify_pin&tenant_id=$tenantId"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"email": email, "pin": pin}),
      );
      return json.decode(response.body);
    } catch (e) { return {"status": "error", "message": "Connection error"}; }
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
      final response = await http.post(
        Uri.parse("$baseUrl/onboarding_api.php?tenant_id=$tenantId"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "tenant_id": tenantId, // Added missing tenant_id
          "user_id": userId,
          "name": name,
          "gender": gender,
          "is_anonymous": isAnonymous,
        }),
      );
      return json.decode(response.body)['status'] == 'success';
    } catch (e) { return false; }
  }

  static Future<List<Map<String, dynamic>>?> fetchSocialList({
    required String action, // get_following, get_requests, get_friends
    required String tenantId,
    required String userId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/social_api_v2.php?action=$action&tenant_id=$tenantId&user_id=$userId"),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') return List<Map<String, dynamic>>.from(data['data']);
      }
      return null;
    } catch (e) { return null; }
  }

  static Future<Map<String, dynamic>?> fetchNotifications(String tenantId, String userId) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/notifications_api.php?action=get_notifications&tenant_id=$tenantId&user_id=$userId"),
      );
      if (response.statusCode == 200) return json.decode(response.body);
      return null;
    } catch (e) { return null; }
  }

  static Future<bool> markNotificationsRead(String tenantId, String userId) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/notifications_api.php?action=mark_as_read&tenant_id=$tenantId&user_id=$userId"),
      );
      return json.decode(response.body)['status'] == 'success';
    } catch (e) { return false; }
  }

  static Future<bool> updateFcmToken({required String tenantId, required String userId, required String token}) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/auth_customer_api.php?action=update_fcm&tenant_id=$tenantId"),
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
      final response = await http.get(
        Uri.parse("$baseUrl/get_public_profile.php?tenant_id=$tenantId&target_id=$targetId&my_id=$myId"),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') return data['data'];
      }
      return null;
    } catch (e) { return null; }
  }

  // --- MUSIC & JUKEBOX SYSTEM ---

  static Future<Map<String, dynamic>?> fetchMusicStatus(String tenantId, {String? userId}) async {
    try {
      final url = Uri.parse("$baseUrl/music_api.php?action=get_status&tenant_id=$tenantId&user_id=${userId ?? ''}");
      final response = await http.get(url);
      if (response.statusCode == 200) return json.decode(response.body);
      return null;
    } catch (e) { return null; }
  }

  static Future<Map<String, dynamic>> voteSong({required String tenantId, required String userId, required int songId}) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/music_api.php?action=vote&tenant_id=$tenantId"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"song_id": songId, "user_id": userId}),
      );
      return json.decode(response.body);
    } catch (e) { return {"status": "error", "message": "Connection error"}; }
  }

  static Future<Map<String, dynamic>> requestMusic(Map<String, dynamic> data) async {
    try {
      final url = Uri.parse("$baseUrl/music_api.php?action=request&tenant_id=${data['tenant_id']}");
      final body = {...data, "action": "request"};

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode(body),
      ).timeout(const Duration(seconds: 15));

      final result = json.decode(response.body);
      if (result['status'] == 'success') {
        return {"success": true};
      } else {
        return {"success": false, "message": result['message'] ?? "Unknown Error"};
      }
    } catch (e) { 
      return {"success": false, "message": "Connection Error: $e"}; 
    }
  }

  // Admin Music Controls
  static Future<bool> adminSetNowPlaying(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/music_api.php?action=set_playing&tenant_id=${data['tenant_id']}"),
        headers: {"Content-Type": "application/json"},
        body: json.encode(data),
      );
      return json.decode(response.body)['status'] == 'success';
    } catch (e) { return false; }
  }

  static Future<bool> adminDeleteQueue(String tenantId, int songId) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/music_api.php?action=delete_queue&tenant_id=$tenantId"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"song_id": songId}),
      );
      return json.decode(response.body)['status'] == 'success';
    } catch (e) { return false; }
  }

  static Future<bool> adminCreateMusicPoll(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/music_api.php?action=create_poll&tenant_id=${data['tenant_id']}"),
        headers: {"Content-Type": "application/json"},
        body: json.encode(data),
      );
      return json.decode(response.body)['status'] == 'success';
    } catch (e) { return false; }
  }

  // --- PRIVACY SETTINGS ---

  static Future<bool> updatePrivacySettings({
    required String tenantId,
    required String userId,
    required bool isPublic,
    required bool allowWaves,
  }) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/auth_customer_api.php?action=update_privacy&tenant_id=$tenantId"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "user_id": userId,
          "is_public": isPublic ? 1 : 0,
          "allow_waves": allowWaves ? 1 : 0,
        }),
      );
      return json.decode(response.body)['status'] == 'success';
    } catch (e) { return false; }
  }
}
