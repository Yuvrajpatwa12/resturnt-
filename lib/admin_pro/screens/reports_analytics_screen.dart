import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/tenant_service.dart';
import '../admin_theme.dart';

class ReportsAnalyticsScreen extends StatefulWidget {
  const ReportsAnalyticsScreen({super.key});

  @override
  State<ReportsAnalyticsScreen> createState() => _ReportsAnalyticsScreenState();
}

class _ReportsAnalyticsScreenState extends State<ReportsAnalyticsScreen> {
  Map<String, dynamic>? _report;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) {
      setState(() {
        _isLoading = false;
        _error = 'Restaurant session is unavailable.';
      });
      return;
    }

    final today = DateTime.now();
    final from = DateTime(
      today.year,
      today.month,
      1,
    ).toIso8601String().substring(0, 10);
    final to = today.toIso8601String().substring(0, 10);
    final result = await ApiService.fetchFinancialReport(from: from, to: to);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _report = result['success'] == true ? result : null;
      _error = result['success'] == true
          ? null
          : result['message']?.toString() ??
                'Could not load the financial report.';
    });
  }

  String _amount(dynamic value) {
    final parsed = double.tryParse(value?.toString() ?? '');
    return parsed == null ? 'NPR --' : 'NPR ${parsed.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final summary = _report?['summary'] is Map
        ? Map<String, dynamic>.from(_report!['summary'] as Map)
        : <String, dynamic>{};
    final reconciliation = _report?['reconciliation'] is Map
        ? Map<String, dynamic>.from(_report!['reconciliation'] as Map)
        : <String, dynamic>{};
    final transactions = _report?['transactions'] is List
        ? List<Map<String, dynamic>>.from(
            (_report!['transactions'] as List).map(
              (row) => Map<String, dynamic>.from(row as Map),
            ),
          )
        : <Map<String, dynamic>>[];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Financial Reports',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text(
            'Settled payments and refunds from the server ledger for this month.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            Center(
              child: Column(
                children: [
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _loadReport,
                    child: const Text('RETRY'),
                  ),
                ],
              ),
            )
          else ...[
            _buildRevenueSummaryCard(summary),
            const SizedBox(height: 20),
            if (reconciliation['warning'] == true)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Text(
                  reconciliation['warning_reason']?.toString() ??
                      'The server reported a reconciliation discrepancy.',
                  style: TextStyle(color: Colors.orange.shade900),
                ),
              ),
            const SizedBox(height: 24),
            const Text(
              'Payment & Refund Ledger',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (transactions.isEmpty)
              const Text(
                'No settled payment or refund transactions in this period.',
              )
            else
              ...transactions.map(_buildInvoiceTile),
          ],
        ],
      ),
    );
  }

  Widget _buildRevenueSummaryCard(Map<String, dynamic> summary) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AdminTheme.royalBlue, AdminTheme.darkNavy],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          _buildRevenueRow('Gross payments', summary['payments_gross_total']),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(color: Colors.white24),
          ),
          _buildRevenueRow('Refunds', summary['refunds_total']),
          const SizedBox(height: 8),
          _buildRevenueRow('Net payments', summary['payments_net_total']),
        ],
      ),
    );
  }

  Widget _buildRevenueRow(String label, dynamic amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          _amount(amount),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _buildInvoiceTile(Map<String, dynamic> transaction) {
    final isRefund = transaction['type']?.toString() == 'refund';
    final id = transaction['id']?.toString() ?? '--';
    final method = transaction['method']?.toString() ?? 'Payment';
    final createdAt = transaction['created_at']?.toString() ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${isRefund ? 'Refund' : 'Payment'} #$id · $method',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Text(
                createdAt,
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ],
          ),
          Text(
            _amount(transaction['amount']),
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: isRefund ? Colors.red : AdminTheme.royalBlue,
            ),
          ),
        ],
      ),
    );
  }
}
