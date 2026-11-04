import 'package:flutter/material.dart';
import '../../cart_manager.dart';
import '../../services/api_service.dart';
import '../../services/tenant_service.dart';
import '../theme.dart';

class BillSettlementScreen extends StatefulWidget {
  final String tableId;
  const BillSettlementScreen({super.key, required this.tableId});

  @override
  State<BillSettlementScreen> createState() => _BillSettlementScreenState();
}

class _BillSettlementScreenState extends State<BillSettlementScreen> {
  late final int _tableNumber;
  int? _tableId;
  Map<String, dynamic>? _bill;
  bool _isLoading = true;
  bool _isSendingToBilling = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tableNumber = ShopManager.parseTableId(widget.tableId);
    _loadBill();
  }

  Future<void> _loadBill() async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Restaurant session is unavailable.';
        });
      }
      return;
    }

    final tables = await ApiService.fetchTables(tenant.id);
    final matchingTables = tables?.where((entry) {
      return entry['table_number']?.toString() == _tableNumber.toString();
    });
    final table = matchingTables == null || matchingTables.isEmpty
        ? null
        : matchingTables.first;
    if (table == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'This table could not be found on the server.';
        });
      }
      return;
    }

    final tableId = int.tryParse(table['id']?.toString() ?? '');
    if (tableId == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'The server returned an invalid table ID.';
        });
      }
      return;
    }
    final bill = await ApiService.fetchSessionBill(tableId: tableId);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _tableId = tableId;
      _bill = bill;
      _error = bill == null
          ? 'Could not load this table’s bill from the server.'
          : null;
    });
  }

  Future<void> _sendToBilling() async {
    if (_isSendingToBilling || _tableId == null || _bill == null) return;
    setState(() => _isSendingToBilling = true);
    final sessionId = int.tryParse(_bill!['session_id']?.toString() ?? '');
    final result = await ApiService.updateSessionStatus(
      sessionId: sessionId,
      tableId: sessionId == null ? _tableId : null,
      status: 'ReadyForBilling',
    );
    if (!mounted) return;
    setState(() => _isSendingToBilling = false);
    if (result['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message']?.toString() ??
                'Could not send this table to billing.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Table sent to billing.'),
        backgroundColor: WaiterProTheme.emeraldGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = (_bill?['items'] as List?) ?? const [];
    final unbilledItems = (_bill?['unbilled_items'] as List?) ?? const [];
    final isSettled =
        (_bill?['session_status']?.toString().toLowerCase() == 'settled');
    return Scaffold(
      appBar: AppBar(title: Text('Bill: ${widget.tableId}')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _loadBill,
                      child: const Text('RETRY'),
                    ),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Itemized Summary',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  if (items.isEmpty)
                    const Text('No served items are currently ready to bill.')
                  else
                    ...items.map((rawItem) {
                      final item = Map<String, dynamic>.from(rawItem as Map);
                      final quantity =
                          int.tryParse(item['quantity']?.toString() ?? '') ?? 0;
                      final lineTotal =
                          double.tryParse(
                            item['line_total']?.toString() ?? '',
                          ) ??
                          0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '$quantity x ${item['product_name'] ?? 'Item'}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Text(
                              'NPR ${lineTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  if (unbilledItems.isNotEmpty) ...[
                    const Divider(height: 32),
                    const Text(
                      'NOT YET BILLABLE',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...unbilledItems.map((rawItem) {
                      final item = Map<String, dynamic>.from(rawItem as Map);
                      final quantity =
                          int.tryParse(item['quantity']?.toString() ?? '') ?? 0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '$quantity x ${item['product_name'] ?? 'Item'}'
                                ' (${item['status'] ?? 'Pending'})',
                                style: const TextStyle(color: Colors.black54),
                              ),
                            ),
                            const Text(
                              'NPR 0.00',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                  const Divider(height: 32),
                  _summaryRow('Subtotal', _bill!['subtotal']),
                  _summaryRow(
                    'Service Charge (${_bill!['rates']?['service_charge']}%)',
                    _bill!['service_charge'],
                  ),
                  _summaryRow(
                    'Tax (${_bill!['rates']?['vat_percentage']}%)',
                    _bill!['tax'],
                  ),
                  const SizedBox(height: 8),
                  _summaryRow(
                    'GRAND TOTAL',
                    _bill!['grand_total'],
                    isTotal: true,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed:
                          _isSendingToBilling || isSettled || items.isEmpty
                          ? null
                          : _sendToBilling,
                      icon: _isSendingToBilling
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_to_mobile_rounded),
                      label: Text(
                        _isSendingToBilling
                            ? 'SENDING...'
                            : isSettled
                            ? 'SETTLED'
                            : 'SEND TO BILLING',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: WaiterProTheme.emeraldGreen,
                        minimumSize: const Size(0, 54),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _summaryRow(String label, dynamic rawValue, {bool isTotal = false}) {
    final amount = double.tryParse(rawValue?.toString() ?? '') ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.w900 : FontWeight.w500,
            ),
          ),
          Text(
            'NPR ${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.w900 : FontWeight.bold,
              color: isTotal ? WaiterProTheme.royalBlue : null,
            ),
          ),
        ],
      ),
    );
  }
}
