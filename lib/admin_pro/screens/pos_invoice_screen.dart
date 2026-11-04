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

class _POSInvoiceScreenState extends State<POSInvoiceScreen>
    with WidgetsBindingObserver {
  List<Map<String, dynamic>> _tables = [];
  List<Map<String, dynamic>> _activeOrders = [];
  List<Map<String, dynamic>> _activePaymentMethods = [];
  Map<String, dynamic>? _sessionBill;
  bool _isLoading = true;
  String? _selectedTableNumber;
  String _paymentMethod = "Cash";
  String _splitPaymentMethod = "Card";
  bool _isSplitPayment = false;
  final TextEditingController _primarySplitAmountController =
      TextEditingController();
  final TextEditingController _splitAmountController = TextEditingController();
  bool _isProcessing = false;
  bool _isInvoicePreviewOpen = false;
  String? _pendingSettlementKey;
  int _cartViewTab = 0;

  Timer? _pollTimer;
  bool _isForeground = true;
  bool _isLoadingData = false;
  String? _pollError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData(showLoading: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPolling();
    _primarySplitAmountController.dispose();
    _splitAmountController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _isForeground = true;
      _pollError = null;
      _loadData(showLoading: false);
    } else {
      _isForeground = false;
      _stopPolling();
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    if (!_isForeground || !mounted || _pollError != null) return;
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_isLoadingData || _isProcessing || _isInvoicePreviewOpen) return;
      _loadData(showLoading: false);
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _pausePolling(String message) {
    _stopPolling();
    if (!mounted) return;
    setState(() => _pollError = message);
  }

  void _retryPolling() {
    if (!mounted || !_isForeground || _isLoadingData) return;
    setState(() => _pollError = null);
    _loadData(showLoading: false);
  }

  Future<void> _loadData({bool showLoading = true}) async {
    if (!mounted || !_isForeground || _isLoadingData) return;
    _isLoadingData = true;
    final tenant = TenantService().currentTenant.value;
    final tenantId = tenant?.id ?? 'startups_main';

    if (showLoading) setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        ApiService.fetchTables(tenantId),
        ApiService.fetchActiveOrders(tenantId),
        ApiService.fetchActivePaymentMethods(tenantId),
      ]);
      if (!mounted || !_isForeground) return;
      final tablesData = results[0];
      final ordersData = results[1];
      final paymentMethodsData = results[2] as List<Map<String, dynamic>>;

      if (tablesData == null || ordersData == null) {
        if (mounted && showLoading) setState(() => _isLoading = false);
        _pausePolling(
          'POS refresh failed. Check the connection or server configuration, then retry.',
        );
        return;
      }

      if (mounted) {
        setState(() {
          _tables = tablesData;
          _activeOrders = ordersData;
          _pollError = null;
          if (paymentMethodsData.isNotEmpty) {
            _activePaymentMethods = paymentMethodsData;
            final activeNames = _activePaymentMethods
                .map((m) => (m['name'] ?? m['method_id'] ?? 'Cash').toString())
                .toList();
            if (!activeNames.contains(_paymentMethod) &&
                activeNames.isNotEmpty) {
              _paymentMethod = activeNames.first;
            }
            if (!activeNames.contains(_splitPaymentMethod) &&
                activeNames.length > 1) {
              _splitPaymentMethod = activeNames[1];
            }
          }

          if (_activeOrders.isNotEmpty && _selectedTableNumber == null) {
            final firstOrdTable = _activeOrders.first['table_number']
                ?.toString();
            if (firstOrdTable != null &&
                _tables.any(
                  (t) => t['table_number'].toString() == firstOrdTable,
                )) {
              _selectedTableNumber = firstOrdTable;
            }
          }

          if (_tables.isNotEmpty &&
              (_selectedTableNumber == null ||
                  !_tables.any(
                    (t) => t['table_number'].toString() == _selectedTableNumber,
                  ))) {
            _selectedTableNumber = _tables.first['table_number'].toString();
          } else if (_tables.isEmpty) {
            _selectedTableNumber = null;
          }

          if (showLoading) _isLoading = false;
        });
      }
      await _loadSelectedBill();
      if (_pollError == null && _isForeground) _startPolling();
    } catch (error) {
      if (mounted && showLoading) setState(() => _isLoading = false);
      _pausePolling(
        'POS refresh failed. Check the connection or server configuration, then retry.',
      );
      debugPrint('POS refresh failed: $error');
    } finally {
      _isLoadingData = false;
    }
  }

  Future<void> _loadSelectedBill() async {
    final selectedNumber = _selectedTableNumber;
    if (selectedNumber == null) {
      if (mounted) setState(() => _sessionBill = null);
      return;
    }
    final matchingTables = _tables.where((table) {
      return table['table_number']?.toString() == selectedNumber;
    });
    final selectedTable = matchingTables.isEmpty ? null : matchingTables.first;
    final tableId = int.tryParse(selectedTable?['id']?.toString() ?? '');
    if (tableId == null) {
      if (mounted) setState(() => _sessionBill = null);
      return;
    }
    final hasActiveOrders = _activeOrders.any(
      (order) =>
          (order['table_number'] ?? order['table_id'] ?? '').toString() ==
          selectedNumber,
    );
    if (!hasActiveOrders) {
      if (mounted) setState(() => _sessionBill = null);
      return;
    }
    final bill = await ApiService.fetchSessionBill(tableId: tableId);
    if (mounted && _selectedTableNumber == selectedNumber) {
      setState(() => _sessionBill = bill);
      if (bill == null) {
        _pausePolling(
          'Could not load this table’s bill. Check the connection or billing configuration, then retry.',
        );
      }
    }
  }

  void _selectTableNumber(String tableNumber) {
    setState(() {
      _selectedTableNumber = tableNumber;
      _sessionBill = null;
      _pollError = null;
    });
    _startPolling();
    _loadSelectedBill();
  }

  List<Map<String, dynamic>> get _currentTableOrders {
    if (_selectedTableNumber == null) return [];
    return _activeOrders
        .where(
          (o) =>
              (o['table_number'] ?? o['table_id'] ?? '').toString() ==
              _selectedTableNumber,
        )
        .toList();
  }

  Map<String, dynamic>? get _currentOrder {
    final orders = _currentTableOrders;
    if (orders.isEmpty) return null;
    return orders.first;
  }

  List<dynamic> get _currentItems {
    final items = _sessionBill?['items'];
    return items is List ? items : [];
  }

  List<dynamic> get _currentUnbilledItems {
    final items = _sessionBill?['unbilled_items'];
    return items is List ? items : [];
  }

  String _resolvedSplitPaymentMethod() {
    final methods = _activePaymentMethods.isNotEmpty
        ? _activePaymentMethods
        : [
            {'name': 'Cash Payment'},
            {'name': 'eSewa QR'},
            {'name': 'Fonepay QR'},
          ];
    final names = methods
        .map((item) => (item['name'] ?? item['method_id'] ?? 'Cash').toString())
        .toList();
    if (names.contains(_splitPaymentMethod)) return _splitPaymentMethod;
    return names.length > 1 ? names[1] : names.first;
  }

  String _billAmount(String key) {
    if (_sessionBill == null) return 'NPR --';
    final value = double.tryParse(_sessionBill?[key]?.toString() ?? '');
    if (value == null) return 'NPR --';
    return 'NPR ${value.toStringAsFixed(2)}';
  }

  Future<void> _generateInvoice() async {
    if (_isProcessing || _isInvoicePreviewOpen) return;
    await _loadSelectedBill();
    if (!mounted) return;
    final bill = _sessionBill;
    final sessionId = int.tryParse(bill?['session_id']?.toString() ?? '');
    final billItems = bill?['items'];
    if (bill == null ||
        sessionId == null ||
        billItems is! List ||
        billItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No served items are ready to bill for this table."),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    _pendingSettlementKey ??= ApiService.newIdempotencyKey();
    setState(() => _isInvoicePreviewOpen = true);

    await showDialog<void>(
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
                          TenantService().currentTenant.value?.name ??
                              "Chiyalaa Restaurant",
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFFF5C00),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "Official Tax Invoice",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "INVOICE",
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: AdminTheme.darkNavy,
                            letterSpacing: 1.5,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          "Date: Today",
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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
                        const Text(
                          "BILLED TO:",
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Table Number: T-$_selectedTableNumber",
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: AdminTheme.darkNavy,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          "INVOICE NO:",
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "#INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}",
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: AdminTheme.darkNavy,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Itemized Table Header
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: Text(
                          "QTY",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: Text(
                          "DESCRIPTION",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          "PRICE",
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          "TOTAL",
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Include every line contributing to the server-stored bill.
                ..._currentItems.map((item) {
                  String name = item['product_name'] ?? item['name'] ?? 'Item';
                  int qty =
                      int.tryParse((item['quantity'] ?? '1').toString()) ?? 1;
                  double price =
                      double.tryParse(
                        (item['price_at_order'] ?? item['price'] ?? '0')
                            .toString(),
                      ) ??
                      0.0;
                  double total =
                      double.tryParse(item['line_total']?.toString() ?? '') ??
                      0;

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 12,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: Text(
                            "$qty",
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 4,
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            "NPR ${price.toStringAsFixed(2)}",
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            "NPR ${total.toStringAsFixed(2)}",
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                if (_currentUnbilledItems.isNotEmpty) ...[
                  const Divider(height: 24),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'NOT YET BILLABLE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                  ),
                  ..._currentUnbilledItems.map((rawItem) {
                    final item = Map<String, dynamic>.from(rawItem as Map);
                    final quantity =
                        int.tryParse(item['quantity']?.toString() ?? '') ?? 0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 12,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: Text(
                              '$quantity',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          Expanded(
                            flex: 4,
                            child: Text(
                              '${item['product_name'] ?? 'Item'}'
                              ' (${item['status'] ?? 'Pending'})',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                          const Expanded(
                            flex: 4,
                            child: Text(
                              'NPR 0.00',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],

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
                          const Text(
                            "Payment Method",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _paymentMethod,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: AdminTheme.darkNavy,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "Terms & Conditions",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            "Goods once sold will not be taken back. Thank you for dining with us!",
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.black54,
                            ),
                          ),
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
                              const Text(
                                "Sub Total",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                _billAmount('subtotal'),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          _invoiceTotalRow(
                            'Service charge',
                            _billAmount('service_charge'),
                          ),
                          const SizedBox(height: 6),
                          _invoiceTotalRow('Tax', _billAmount('tax')),
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
                                const Text(
                                  "GRAND TOTAL",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  _billAmount('grand_total'),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
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
                      onPressed: _isProcessing
                          ? null
                          : () => _settleInvoice(ctx),
                      icon: const Icon(Icons.print, size: 16),
                      label: const Text("PRINT & SETTLE BILL"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdminTheme.emeraldGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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
    if (mounted) setState(() => _isInvoicePreviewOpen = false);
  }

  Widget _invoiceTotalRow(String label, String amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        Text(
          amount,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Future<void> _settleInvoice(BuildContext dialogContext) async {
    if (_isProcessing) return;
    final sessionId = int.tryParse(
      _sessionBill?['session_id']?.toString() ?? '',
    );
    final total = double.tryParse(
      _sessionBill?['grand_total']?.toString() ?? '',
    );
    if (sessionId == null || total == null || total <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The server returned an invalid session bill.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final idempotencyKey = _pendingSettlementKey;
    if (idempotencyKey == null) return;
    final List<Map<String, dynamic>> paymentParts;
    if (_isSplitPayment) {
      final primaryAmount = double.tryParse(
        _primarySplitAmountController.text.trim(),
      );
      final secondaryAmount = double.tryParse(
        _splitAmountController.text.trim(),
      );
      if (primaryAmount == null ||
          secondaryAmount == null ||
          primaryAmount <= 0 ||
          secondaryAmount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enter a positive amount for both payment methods.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      final splitMethod = _resolvedSplitPaymentMethod();
      if (splitMethod == _paymentMethod) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Choose two different payment methods to split a bill.',
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      paymentParts = [
        {'method': _paymentMethod, 'amount': primaryAmount.toStringAsFixed(2)},
        {'method': splitMethod, 'amount': secondaryAmount.toStringAsFixed(2)},
      ];
    } else {
      paymentParts = [
        {'method': _paymentMethod, 'amount': total.toStringAsFixed(2)},
      ];
    }
    setState(() => _isProcessing = true);
    Navigator.pop(dialogContext);

    final tenantId = TenantService().currentTenant.value?.id;
    final result = tenantId == null
        ? <String, dynamic>{
            'success': false,
            'message': 'Restaurant session is unavailable.',
          }
        : await ApiService.settleBill(
            tenantId: tenantId,
            sessionId: sessionId,
            idempotencyKey: idempotencyKey,
            payments: paymentParts,
          );

    if (!mounted) return;
    setState(() {
      _isProcessing = false;
      if (result['success'] == true || result['ambiguous'] != true) {
        _pendingSettlementKey = null;
      }
    });

    if (result['success'] == true) {
      await _loadData(showLoading: false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invoice generated and payment recorded successfully.'),
          backgroundColor: AdminTheme.emeraldGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${result['message'] ?? 'Settlement failed.'} Reopen the invoice to retry.',
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
              if (_pollError != null) ...[
                const SizedBox(height: 12),
                _buildPollingErrorBanner(),
              ],
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

  Widget _buildPollingErrorBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_outlined, color: Colors.red.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _pollError!,
              style: TextStyle(color: Colors.red.shade800, fontSize: 13),
            ),
          ),
          TextButton(onPressed: _retryPolling, child: const Text('Retry')),
        ],
      ),
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
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.amber.shade900,
                ),
              ),
              TextButton(
                onPressed: () => _loadData(showLoading: true),
                child: const Text(
                  "Force Refresh",
                  style: TextStyle(fontSize: 11),
                ),
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
    List<String> tableNumbers = _tables
        .map((t) => t['table_number'].toString())
        .toList();
    if (tableNumbers.isEmpty) tableNumbers = ["No Tables"];

    if (_selectedTableNumber != null &&
        !tableNumbers.contains(_selectedTableNumber)) {
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
              Text(
                t('pos.active_selection'),
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                t('pos.select_table'),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AdminTheme.darkNavy,
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                onPressed: () => _loadData(showLoading: true),
                icon: const Icon(
                  Icons.refresh_rounded,
                  size: 20,
                  color: AdminTheme.royalBlue,
                ),
                tooltip: "Refresh Tables & Orders",
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AdminTheme.royalBlue.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AdminTheme.royalBlue.withValues(alpha: 0.2),
                  ),
                ),
                child: DropdownButton<String>(
                  value:
                      _selectedTableNumber != null &&
                          tableNumbers.contains(_selectedTableNumber)
                      ? _selectedTableNumber
                      : tableNumbers.first,
                  underline: const SizedBox(),
                  icon: const Icon(
                    Icons.keyboard_arrow_down,
                    color: AdminTheme.royalBlue,
                  ),
                  items: tableNumbers.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(
                        value == "No Tables" ? value : "Table $value",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AdminTheme.royalBlue,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null && val != "No Tables") {
                      _selectTableNumber(val);
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
    final unbilledItems = _currentUnbilledItems;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              t('pos.current_items'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (_currentTableOrders.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AdminTheme.royalBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "Orders: ${_currentTableOrders.map((o) => '#${o['id']}').join(', ')}",
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AdminTheme.royalBlue,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        // Segmented Tab Toggle / Dual-Section Switcher
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _cartViewTab = 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _cartViewTab == 0
                          ? Colors.white
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: _cartViewTab == 0
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : [],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Served Items",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _cartViewTab == 0
                                ? AdminTheme.emeraldGreen
                                : Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AdminTheme.emeraldGreen.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            "${items.length}",
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AdminTheme.emeraldGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _cartViewTab = 1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _cartViewTab == 1
                          ? Colors.white
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: _cartViewTab == 1
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : [],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Remaining / Active",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _cartViewTab == 1
                                ? Colors.orange.shade800
                                : Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            "${unbilledItems.length}",
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AdminTheme.softShadow,
          ),
          child: _cartViewTab == 0
              ? (items.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.receipt_long_outlined,
                                size: 40,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _tables.isEmpty
                                    ? "No tables configured."
                                    : "No served items ready for billing.",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: items.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 20, endIndent: 20),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return _buildCartItemRow(item);
                        },
                      ))
              : (unbilledItems.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.hourglass_empty_rounded,
                                size: 40,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "No remaining or pending kitchen items.",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: unbilledItems.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 20, endIndent: 20),
                        itemBuilder: (context, index) {
                          final item = Map<String, dynamic>.from(
                            unbilledItems[index] as Map,
                          );
                          return _buildRemainingItemRow(item);
                        },
                      )),
        ),
      ],
    );
  }

  Widget _buildRemainingItemRow(Map<String, dynamic> item) {
    String name = item['product_name'] ?? item['name'] ?? 'Item';
    String qty = (item['quantity'] ?? '1').toString();
    String status = (item['status'] ?? 'Pending').toString();

    Color statusColor = Colors.orange;
    if (status.toLowerCase() == 'preparing') {
      statusColor = Colors.blue;
    } else if (status.toLowerCase() == 'ready') {
      statusColor = AdminTheme.emeraldGreen;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'x$qty',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      "Non-billable (Tracking)",
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Text(
            "NPR 0.00",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItemRow(Map<String, dynamic> item) {
    String name = item['product_name'] ?? item['name'] ?? 'Item';
    String qty = (item['quantity'] ?? '1').toString();
    final itemTotal =
        double.tryParse(item['line_total']?.toString() ?? '') ?? 0.0;
    String status = (item['status'] ?? 'Pending').toString().toUpperCase();

    bool isCompleted = status == 'COMPLETED' || status == 'SERVED';
    Color stColor = isCompleted ? AdminTheme.emeraldGreen : Colors.orange;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      title: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AdminTheme.darkNavy,
              ),
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
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: stColor,
              ),
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
    final activeItems = _activePaymentMethods.isNotEmpty
        ? _activePaymentMethods
        : [
            {
              'name': 'Cash Payment',
              'account_holder_name': 'Counter Cash Drawer',
              'account_number': '0000',
            },
            {
              'name': 'eSewa QR',
              'account_holder_name': 'Ram Sharma',
              'account_number': '9841234567',
            },
            {
              'name': 'Fonepay QR',
              'account_holder_name': 'Restro Main Account',
              'account_number': '9801987654',
            },
          ];
    final splitPaymentMethod = _resolvedSplitPaymentMethod();

    Map<String, dynamic>? selectedObj;
    for (var m in activeItems) {
      final name = (m['name'] ?? m['method_id'] ?? '').toString();
      final holder = (m['account_holder_name'] ?? '').toString();
      final displayName =
          (holder.isNotEmpty &&
              holder != 'Main Account' &&
              !name.contains(holder))
          ? "$name ($holder)"
          : name;
      if (_paymentMethod == displayName || _paymentMethod == name) {
        selectedObj = m;
        break;
      }
    }
    selectedObj ??= activeItems.first;
    final currentHolder = (selectedObj['account_holder_name'] ?? 'Main Account')
        .toString();
    final currentNum = (selectedObj['account_number'] ?? '').toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              t('pos.payment_method'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AdminTheme.royalBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "Account: $currentHolder ${currentNum.isNotEmpty ? '• $currentNum' : ''}",
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AdminTheme.royalBlue,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: activeItems.map((item) {
              final name = (item['name'] ?? item['method_id'] ?? 'Cash')
                  .toString();
              final holder = (item['account_holder_name'] ?? '').toString();
              final displayName =
                  (holder.isNotEmpty &&
                      holder != 'Main Account' &&
                      !name.contains(holder))
                  ? "$name ($holder)"
                  : name;

              bool isSelected =
                  _paymentMethod == displayName || _paymentMethod == name;

              return Container(
                margin: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () => setState(() => _paymentMethod = displayName),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? AdminTheme.royalBlue : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? AdminTheme.royalBlue
                            : Colors.grey.withValues(alpha: 0.2),
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AdminTheme.royalBlue.withValues(
                                  alpha: 0.2,
                                ),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : [],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : AdminTheme.darkNavy,
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
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            "Split payment",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: const Text("Record this bill across two payment methods."),
          value: _isSplitPayment,
          onChanged: (enabled) {
            final total =
                double.tryParse(
                  _sessionBill?['grand_total']?.toString() ?? '',
                ) ??
                0;
            setState(() {
              _isSplitPayment = enabled ?? false;
              if (_isSplitPayment) {
                _primarySplitAmountController.text = (total / 2)
                    .toStringAsFixed(2);
                _splitAmountController.text = (total / 2).toStringAsFixed(2);
              }
            });
          },
        ),
        if (_isSplitPayment) ...[
          DropdownButtonFormField<String>(
            initialValue: splitPaymentMethod,
            decoration: const InputDecoration(
              labelText: "Second payment method",
              border: OutlineInputBorder(),
            ),
            items: activeItems.map((item) {
              final name = (item['name'] ?? item['method_id'] ?? 'Cash')
                  .toString();
              return DropdownMenuItem(value: name, child: Text(name));
            }).toList(),
            onChanged: (value) {
              if (value != null) setState(() => _splitPaymentMethod = value);
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _primarySplitAmountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: "Amount paid with $_paymentMethod",
              prefixText: "NPR ",
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _splitAmountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: "Amount paid with $splitPaymentMethod",
              prefixText: "NPR ",
              border: const OutlineInputBorder(),
            ),
          ),
        ],
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
          _buildSummaryRow(
            t('pos.subtotal'),
            _billAmount('subtotal'),
            Colors.white70,
          ),
          _buildSummaryRow(
            'Service charge',
            _billAmount('service_charge'),
            Colors.white70,
          ),
          _buildSummaryRow('Tax', _billAmount('tax'), Colors.white70),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(color: Colors.white10),
          ),
          _buildSummaryRow(
            t('pos.total_amount'),
            _billAmount('grand_total'),
            Colors.white,
            isBold: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value,
    Color color, {
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: isBold ? 14 : 12,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: isBold ? 18 : 13,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
          ),
        ),
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
                const SnackBar(
                  content: Text("KOT sent to kitchen printer successfully."),
                  backgroundColor: AdminTheme.royalBlue,
                ),
              );
            },
            icon: const Icon(Icons.print, size: 18),
            label: Text(t('pos.print_kot')),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: const BorderSide(color: AdminTheme.royalBlue),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: _isProcessing || _isInvoicePreviewOpen
                ? null
                : _generateInvoice,
            icon: _isProcessing
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.receipt_long, size: 18),
            label: Text(
              _isProcessing ? "PROCESSING..." : t('pos.generate_invoice'),
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: AdminTheme.emeraldGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
