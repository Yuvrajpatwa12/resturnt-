import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/language_service.dart';
import '../../services/tenant_service.dart';
import '../admin_theme.dart';

class POSInvoiceScreen extends StatefulWidget {
  const POSInvoiceScreen({super.key});

  @override
  State<POSInvoiceScreen> createState() => _POSInvoiceScreenState();
}

class _POSInvoiceScreenState extends State<POSInvoiceScreen> {
  List<Map<String, dynamic>> _tables = [];
  List<Map<String, dynamic>> _activeOrders = [];
  List<Map<String, dynamic>> _activePaymentMethods = [];
  bool _isLoading = true;
  String? _selectedTableNumber;
  String _paymentMethod = "Cash";
  bool _isProcessing = false;

  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadData(showLoading: true);
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _loadData(showLoading: false);
    });
  }

  Future<void> _loadData({bool showLoading = true}) async {
    final tenant = TenantService().currentTenant.value;
    final tenantId = tenant?.id ?? 'startups_main';

    if (showLoading) setState(() => _isLoading = true);

    final tablesData = await ApiService.fetchTables(tenantId);
    final ordersData = await ApiService.fetchActiveOrders(tenantId);
    final paymentMethodsData = await ApiService.fetchActivePaymentMethods(tenantId);

    debugPrint("POS DEBUG: Loaded ${tablesData?.length ?? 0} tables and ${ordersData?.length ?? 0} active orders.");
    if (ordersData != null) {
      for (var o in ordersData) {
        debugPrint("POS DEBUG Order: ID=${o['id']}, table_number=${o['table_number']}, table_id=${o['table_id']}, status=${o['status']}");
      }
    }

    if (mounted) {
      setState(() {
        _tables = tablesData ?? [];
        _activeOrders = ordersData ?? [];
        if (paymentMethodsData.isNotEmpty) {
          _activePaymentMethods = paymentMethodsData;
          final activeNames = _activePaymentMethods.map((m) => (m['name'] ?? m['method_id'] ?? 'Cash').toString()).toList();
          if (!activeNames.contains(_paymentMethod) && activeNames.isNotEmpty) {
            _paymentMethod = activeNames.first;
          }
        }

        if (_activeOrders.isNotEmpty && _selectedTableNumber == null) {
          final firstOrdTable = _activeOrders.first['table_number']?.toString();
          if (firstOrdTable != null && _tables.any((t) => t['table_number'].toString() == firstOrdTable)) {
            _selectedTableNumber = firstOrdTable;
          }
        }

        if (_tables.isNotEmpty &&
            (_selectedTableNumber == null ||
                !_tables.any((t) => t['table_number'].toString() == _selectedTableNumber))) {
          _selectedTableNumber = _tables.first['table_number'].toString();
        } else if (_tables.isEmpty) {
          _selectedTableNumber = null;
        }

        if (showLoading) _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _currentTableOrders {
    if (_selectedTableNumber == null) return [];
    return _activeOrders.where(
      (o) => (o['table_number'] ?? o['table_id'] ?? '').toString() == _selectedTableNumber,
    ).toList();
  }

  Map<String, dynamic>? get _currentOrder {
    final orders = _currentTableOrders;
    if (orders.isEmpty) return null;
    return orders.first;
  }

  List<dynamic> get _currentItems {
    final orders = _currentTableOrders;
    if (orders.isEmpty) return [];
    List<dynamic> allItems = [];
    for (var ord in orders) {
      final items = ord['items'] ?? ord['order_items'] ?? [];
      for (var itm in items) {
        allItems.add(itm);
      }
    }
    return allItems;
  }

  bool _isItemConfirmed(Map<String, dynamic> item) {
    final st = (item['status'] ?? 'pending').toString().trim().toLowerCase();
    return st == 'completed' || st == 'ready' || st == 'approved';
  }

  double get _subtotal {
    double total = 0.0;
    for (var item in _currentItems) {
      if (!_isItemConfirmed(item)) continue;
      double price = double.tryParse((item['price_at_order'] ?? item['price'] ?? '0').toString()) ?? 0.0;
      int qty = int.tryParse((item['quantity'] ?? '1').toString()) ?? 1;
      total += price * qty;
    }
    return total;
  }

  Future<void> _generateInvoice() async {
    final orders = _currentTableOrders;
    if (orders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No active orders found for this table to invoice."),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 550, maxHeight: 750),
          padding: const EdgeInsets.all(32),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          TenantService().currentTenant.value?.name ?? "Chiyalaa Restaurant",
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFFFF5C00)),
                        ),
                        const SizedBox(height: 4),
                        const Text("Official Tax Invoice", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text("INVOICE", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AdminTheme.darkNavy, letterSpacing: 1.5)),
                        SizedBox(height: 2),
                        Text("Date: Today", style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(thickness: 1.5),
                const SizedBox(height: 16),

                // Table & Invoice Info
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("BILLED TO:", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text("Table Number: T-$_selectedTableNumber", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AdminTheme.darkNavy)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text("INVOICE NO:", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text("#INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AdminTheme.darkNavy)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Itemized Table Header
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                  child: const Row(
                    children: [
                      Expanded(flex: 1, child: Text("QTY", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey))),
                      Expanded(flex: 4, child: Text("DESCRIPTION", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey))),
                      Expanded(flex: 2, child: Text("PRICE", textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey))),
                      Expanded(flex: 2, child: Text("TOTAL", textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey))),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Items list (only confirmed/completed items)
                ..._currentItems.where((item) => _isItemConfirmed(item)).map((item) {
                  String name = item['product_name'] ?? item['name'] ?? 'Item';
                  int qty = int.tryParse((item['quantity'] ?? '1').toString()) ?? 1;
                  double price = double.tryParse((item['price_at_order'] ?? item['price'] ?? '0').toString()) ?? 0.0;
                  double total = price * qty;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    child: Row(
                      children: [
                        Expanded(flex: 1, child: Text("$qty", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
                        Expanded(flex: 4, child: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                        Expanded(flex: 2, child: Text("NPR ${price.toStringAsFixed(0)}", textAlign: TextAlign.right, style: const TextStyle(fontSize: 13))),
                        Expanded(flex: 2, child: Text("NPR ${total.toStringAsFixed(0)}", textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 16),
                const Divider(thickness: 1.5),
                const SizedBox(height: 16),

                // Payment Method & Summary
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Payment Method", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text(_paymentMethod, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AdminTheme.darkNavy)),
                          const SizedBox(height: 16),
                          const Text("Terms & Conditions", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 2),
                          const Text("Goods once sold will not be taken back. Thank you for dining with us!", style: TextStyle(fontSize: 10, color: Colors.black54)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    SizedBox(
                      width: 200,
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Sub Total", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                              Text("NPR ${_subtotal.toStringAsFixed(0)}", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF5C00),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("GRAND TOTAL", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white)),
                                Text("NPR ${_subtotal.toStringAsFixed(0)}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("CLOSE"),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        setState(() => _isProcessing = true);
                        for (var order in orders) {
                          final orderId = int.tryParse(order['id'].toString()) ?? 0;
                          if (orderId > 0) {
                            await ApiService.updateOrderStatus(orderId, 'Completed', paymentMethod: _paymentMethod);
                          }
                        }
                        setState(() => _isProcessing = false);

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Invoice generated and all table orders completed successfully!"),
                              backgroundColor: AdminTheme.emeraldGreen,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                        _loadData(showLoading: false);
                      },
                      icon: const Icon(Icons.print, size: 16),
                      label: const Text("PRINT & COMPLETE ORDER"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdminTheme.emeraldGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LanguageService().currentLanguageCode,
      builder: (context, _, __) {
        if (_isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: AdminTheme.royalBlue),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTableSelectionHeader(),
              const SizedBox(height: 16),
              _buildDebugBanner(),
              const SizedBox(height: 16),
              _buildLiveCartPreview(),
              const SizedBox(height: 24),
              _buildPaymentSelection(),
              const SizedBox(height: 32),
              _buildInvoiceSummary(),
              const SizedBox(height: 40),
              _buildActionButtons(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDebugBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "🐛 DEBUG INFO: Loaded Orders (${_activeOrders.length})",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.amber.shade900),
              ),
              TextButton(
                onPressed: () => _loadData(showLoading: true),
                child: const Text("Force Refresh", style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "Selected Table: $_selectedTableNumber | Active Order Found: ${_currentOrder != null ? 'YES (ID: ${_currentOrder!['id']})' : 'NO'}",
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
          if (_activeOrders.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              "All Orders Table Numbers: ${_activeOrders.map((o) => "T#${o['table_number'] ?? o['table_id']} (Ord#${o['id']})").join(', ')}",
              style: const TextStyle(fontSize: 10, color: Colors.black54),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTableSelectionHeader() {
    List<String> tableNumbers = _tables.map((t) => t['table_number'].toString()).toList();
    if (tableNumbers.isEmpty) tableNumbers = ["No Tables"];

    if (_selectedTableNumber != null && !tableNumbers.contains(_selectedTableNumber)) {
      _selectedTableNumber = tableNumbers.first;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AdminTheme.softShadow,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t('pos.active_selection'),
                  style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(t('pos.select_table'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AdminTheme.darkNavy)),
            ],
          ),
          Row(
            children: [
              IconButton(
                onPressed: () => _loadData(showLoading: true),
                icon: const Icon(Icons.refresh_rounded, size: 20, color: AdminTheme.royalBlue),
                tooltip: "Refresh Tables & Orders",
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AdminTheme.royalBlue.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AdminTheme.royalBlue.withValues(alpha: 0.2)),
                ),
                child: DropdownButton<String>(
                  value: _selectedTableNumber != null && tableNumbers.contains(_selectedTableNumber)
                      ? _selectedTableNumber
                      : tableNumbers.first,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.keyboard_arrow_down, color: AdminTheme.royalBlue),
                  items: tableNumbers.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(
                        value == "No Tables" ? value : "Table $value",
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.royalBlue),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null && val != "No Tables") {
                      setState(() => _selectedTableNumber = val);
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLiveCartPreview() {
    final items = _currentItems;
    int completedCount = items.where((i) => _isItemConfirmed(i)).length;
    int pendingCount = items.length - completedCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(t('pos.current_items'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                if (items.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AdminTheme.emeraldGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "$completedCount Completed",
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AdminTheme.emeraldGreen),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "$pendingCount Pending",
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange),
                    ),
                  ),
                ],
              ],
            ),
            if (_currentTableOrders.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AdminTheme.royalBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "Orders: ${_currentTableOrders.map((o) => '#${o['id']}').join(', ')}",
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AdminTheme.royalBlue),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AdminTheme.softShadow,
          ),
          child: items.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 40, color: Colors.grey.shade300),
                        const SizedBox(height: 8),
                        Text(
                          _tables.isEmpty ? "No tables configured." : "No active orders for Table $_selectedTableNumber.",
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 20, endIndent: 20),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _buildCartItemRow(item);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCartItemRow(Map<String, dynamic> item) {
    String name = item['product_name'] ?? item['name'] ?? 'Item';
    String qty = (item['quantity'] ?? '1').toString();
    double price = double.tryParse((item['price_at_order'] ?? item['price'] ?? '0').toString()) ?? 0.0;
    double itemTotal = price * (int.tryParse(qty) ?? 1);
    String status = (item['status'] ?? 'Pending').toString().toUpperCase();

    bool isCompleted = status == 'COMPLETED' || status == 'READY' || status == 'APPROVED';
    Color stColor = isCompleted ? AdminTheme.emeraldGreen : Colors.orange;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      title: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AdminTheme.darkNavy),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: stColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: stColor.withValues(alpha: 0.3)),
            ),
            child: Text(
              status,
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: stColor),
            ),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          "${t('form.quantity')}: $qty ${isCompleted ? '• Included in bill' : '• Pending (Not billed)'}",
          style: TextStyle(
            fontSize: 11,
            color: isCompleted ? Colors.grey : Colors.orange.shade800,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      trailing: Text(
        "NPR ${itemTotal.toStringAsFixed(0)}",
        style: TextStyle(
          fontWeight: FontWeight.w900,
          color: isCompleted ? AdminTheme.darkNavy : Colors.grey,
        ),
      ),
    );
  }

  Widget _buildPaymentSelection() {
    final activeItems = _activePaymentMethods.isNotEmpty ? _activePaymentMethods : [
      {'name': 'Cash Payment', 'account_holder_name': 'Counter Cash Drawer', 'account_number': '0000'},
      {'name': 'eSewa QR', 'account_holder_name': 'Ram Sharma', 'account_number': '9841234567'},
      {'name': 'Fonepay QR', 'account_holder_name': 'Restro Main Account', 'account_number': '9801987654'},
    ];

    Map<String, dynamic>? selectedObj;
    for (var m in activeItems) {
      final name = (m['name'] ?? m['method_id'] ?? '').toString();
      final holder = (m['account_holder_name'] ?? '').toString();
      final displayName = (holder.isNotEmpty && holder != 'Main Account' && !name.contains(holder)) ? "$name ($holder)" : name;
      if (_paymentMethod == displayName || _paymentMethod == name) {
        selectedObj = m;
        break;
      }
    }
    selectedObj ??= activeItems.first;
    final currentHolder = (selectedObj['account_holder_name'] ?? 'Main Account').toString();
    final currentNum = (selectedObj['account_number'] ?? '').toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(t('pos.payment_method'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AdminTheme.royalBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "Account: $currentHolder ${currentNum.isNotEmpty ? '• $currentNum' : ''}",
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AdminTheme.royalBlue),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: activeItems.map((item) {
              final name = (item['name'] ?? item['method_id'] ?? 'Cash').toString();
              final holder = (item['account_holder_name'] ?? '').toString();
              final displayName = (holder.isNotEmpty && holder != 'Main Account' && !name.contains(holder))
                  ? "$name ($holder)"
                  : name;

              bool isSelected = _paymentMethod == displayName || _paymentMethod == name;

              return Container(
                margin: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () => setState(() => _paymentMethod = displayName),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected ? AdminTheme.royalBlue : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isSelected ? AdminTheme.royalBlue : Colors.grey.withValues(alpha: 0.2)),
                      boxShadow: isSelected ? [BoxShadow(color: AdminTheme.royalBlue.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 4))] : [],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: TextStyle(
                            color: isSelected ? Colors.white : AdminTheme.darkNavy,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        if (holder.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            "Credit to: $holder",
                            style: TextStyle(
                              color: isSelected ? Colors.white70 : Colors.grey,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildInvoiceSummary() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AdminTheme.darkNavy,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          _buildSummaryRow(t('pos.subtotal'), "NPR ${_subtotal.toStringAsFixed(0)}", Colors.white70),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(color: Colors.white10),
          ),
          _buildSummaryRow(t('pos.total_amount'), "NPR ${_subtotal.toStringAsFixed(0)}", Colors.white, isBold: true),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, Color color, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: color, fontSize: isBold ? 14 : 12, fontWeight: isBold ? FontWeight.w900 : FontWeight.bold)),
        Text(value, style: TextStyle(color: color, fontSize: isBold ? 18 : 13, fontWeight: isBold ? FontWeight.w900 : FontWeight.bold)),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("KOT sent to kitchen printer successfully."), backgroundColor: AdminTheme.royalBlue),
              );
            },
            icon: const Icon(Icons.print, size: 18),
            label: Text(t('pos.print_kot')),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: const BorderSide(color: AdminTheme.royalBlue),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: _isProcessing ? null : _generateInvoice,
            icon: _isProcessing
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.receipt_long, size: 18),
            label: Text(_isProcessing ? "PROCESSING..." : t('pos.generate_invoice')),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: AdminTheme.emeraldGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
          ),
        ),
      ],
    );
  }
}
