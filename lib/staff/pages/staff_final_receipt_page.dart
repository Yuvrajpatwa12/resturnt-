import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';
import '../../services/tenant_service.dart';

class StaffFinalReceiptPage extends StatefulWidget {
  final int tableId;
  const StaffFinalReceiptPage({super.key, required this.tableId});

  @override
  State<StaffFinalReceiptPage> createState() => _StaffFinalReceiptPageState();
}

class _StaffFinalReceiptPageState extends State<StaffFinalReceiptPage> {
  bool _isSending = false;
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _bill;
  double _billY = 0;
  double _billOpacity = 1.0;

  @override
  void initState() {
    super.initState();
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
    final matchingTables = tables?.where(
      (table) =>
          table['table_number']?.toString() == widget.tableId.toString(),
    );
    final table = matchingTables == null || matchingTables.isEmpty
        ? null
        : matchingTables.first;
    final databaseTableId = int.tryParse(table?['id']?.toString() ?? '');
    final bill = databaseTableId == null
        ? null
        : await ApiService.fetchSessionBill(tableId: databaseTableId);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _bill = bill;
      _error = bill == null ? 'Could not load this bill from the server.' : null;
    });
  }

  Future<void> _sendBill() async {
    final sessionId = int.tryParse(_bill?['session_id']?.toString() ?? '');
    if (sessionId == null || _bill == null) return;
    setState(() => _isSending = true);
    final result = await ApiService.updateSessionStatus(
      sessionId: sessionId,
      status: 'ReadyForBilling',
    );
    if (!mounted) return;
    if (result['success'] != true) {
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']?.toString() ?? 'Could not send this bill.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    HapticFeedback.heavyImpact();
    setState(() {
      _billY = -500;
      _billOpacity = 0.0;
    });

    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      Navigator.pop(context); // Close receipt
      Navigator.pop(context); // Return to tables
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Table sent to billing."),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final orderItems = (_bill?['items'] as List?) ?? const [];
    final unbilledItems = (_bill?['unbilled_items'] as List?) ?? const [];

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text("Digital Receipt", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        leading: IconButton(icon: const Icon(Icons.close, color: Colors.black87), onPressed: () => Navigator.pop(context)),
      ),
      body: Stack(
        children: [
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    OutlinedButton(onPressed: _loadBill, child: const Text('RETRY')),
                  ],
                ),
              ),
            )
          else
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeInBack,
                  transform: Matrix4.translationValues(0, _billY, 0),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 500),
                    opacity: _billOpacity,
                    child: Container(
                      padding: const EdgeInsets.all(30),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20)],
                      ),
                      child: Column(
                        children: [
                          const Text("ChiyaBreak Downtown", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                          const Text("88 Sunrise Avenue, Kathmandu", style: TextStyle(fontSize: 11, color: Colors.grey)),
                          const Text("CONTACT NO: 9812345678", style: TextStyle(fontSize: 11, color: Colors.grey)),
                          const Divider(height: 40),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildMetaItem("Date", "20/08/2026"),
                              _buildMetaItem("Time", "14:45"),
                              _buildMetaItem("Table", widget.tableId.toString()),
                            ],
                          ),
                          const Divider(height: 40),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildMetaItem("RECEIPT NO", "INV-2026-9042"),
                              _buildMetaItem("CUSTOMER", "Guest User"),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildMetaItem("PAYMENT", "Mobile Pay"),
                            ],
                          ),
                          const Divider(height: 40),
                          
                          // Itemized List
                          ...orderItems.map((rawItem) {
                            final item = Map<String, dynamic>.from(rawItem as Map);
                            final quantity = int.tryParse(item['quantity']?.toString() ?? '') ?? 0;
                            return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("$quantity x ${item['product_name'] ?? 'Item'}", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                Text("NPR ${item['line_total'] ?? '0.00'}", style: const TextStyle(fontSize: 13)),
                              ],
                            ),
                          );
                          }),
                          if (unbilledItems.isNotEmpty) ...[
                            const Divider(height: 32),
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text('NOT YET BILLABLE', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                            ),
                            ...unbilledItems.map((rawItem) {
                              final item = Map<String, dynamic>.from(rawItem as Map);
                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text('${item['quantity']} x ${item['product_name']}'),
                                subtitle: Text(item['status']?.toString() ?? 'Pending'),
                                trailing: const Text('NPR 0.00'),
                              );
                            }),
                          ],
                          
                          const Divider(height: 40),
                          _buildSummaryItem("SUBTOTAL", "NPR ${_bill?['subtotal'] ?? '0.00'}"),
                          _buildSummaryItem("SERVICE CHARGE", "NPR ${_bill?['service_charge'] ?? '0.00'}"),
                          _buildSummaryItem("TAX", "NPR ${_bill?['tax'] ?? '0.00'}"),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("TOTAL", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                              Text("NPR ${_bill?['grand_total'] ?? '0.00'}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFFFF5C00))),
                            ],
                          ),
                          const SizedBox(height: 40),
                          const Text("THANK YOU. VISIT AGAIN.", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
          
          // Floating Send Button
          Positioned(
            bottom: 40,
            left: 30,
            right: 30,
            child: ElevatedButton.icon(
              onPressed: _isSending || orderItems.isEmpty ? null : _sendBill,
              icon: const Icon(Icons.send_rounded, size: 20),
              label: Text(_isSending ? "SENDING..." : "SEND TO BILLING"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5C00),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                elevation: 10,
                shadowColor: const Color(0xFFFF5C00).withValues(alpha: 0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
