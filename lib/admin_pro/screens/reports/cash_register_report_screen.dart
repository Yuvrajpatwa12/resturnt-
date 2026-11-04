import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import '../../admin_theme.dart';

class CashRegisterReportScreen extends StatefulWidget {
  const CashRegisterReportScreen({super.key});

  @override
  State<CashRegisterReportScreen> createState() =>
      _CashRegisterReportScreenState();
}

class _CashRegisterReportScreenState extends State<CashRegisterReportScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _registerLogs = [];
  double _openingCash = 5000.0;
  double _cashIn = 0.0;
  double _cashOut = 0.0;
  DateTime? _fromDate;
  DateTime? _toDate;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String _dateString(DateTime date) =>
      "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

  Future<void> _loadData({DateTimeRange? range}) async {
    final current = DateTime.now();
    final today = DateTime(current.year, current.month, current.day);
    final from =
        range?.start ?? _fromDate ?? DateTime(today.year, today.month, 1);
    final to = range?.end ?? _toDate ?? today;
    setState(() => _isLoading = true);
    final report = await ApiService.fetchFinancialReport(
      from: _dateString(from),
      to: _dateString(to),
    );

    if (mounted) {
      _fromDate = from;
      _toDate = to;
      _error = report['success'] == true
          ? null
          : (report['message'] ?? "Could not load financial report.")
                .toString();
      _cashIn = 0;
      _cashOut = 0;
      _registerLogs = [
        {
          'time': 'Opening',
          'action': 'Opening Drawer Float',
          'amount': _openingCash,
          'user': 'Cashier',
          'type': 'Credit',
        },
      ];
      final transactions = report['transactions'];
      if (transactions is List) {
        for (final entry in transactions) {
          if (entry is! Map) continue;
          final transaction = Map<String, dynamic>.from(entry);
          final method = (transaction['method'] ?? '').toString().toLowerCase();
          if (!method.contains('cash')) continue;
          final amount =
              double.tryParse(transaction['amount']?.toString() ?? '0') ?? 0;
          final isRefund = transaction['type'] == 'refund' || amount < 0;
          if (isRefund) {
            _cashOut += amount.abs();
          } else {
            _cashIn += amount;
          }
          _registerLogs.add({
            'time': transaction['created_at'] ?? '',
            'action': isRefund
                ? 'Refund ${transaction['id']} · Cash'
                : 'Payment ${transaction['id']} · Cash',
            'amount': amount.abs(),
            'user': 'Staff #${transaction['staff_id'] ?? ''}',
            'type': isRefund ? 'Debit' : 'Credit',
          });
        }
      }
      _registerLogs.add({
        'time': 'Closing',
        'action': 'Current Drawer Balance',
        'amount': _openingCash + _cashIn - _cashOut,
        'user': 'Cashier',
        'type': 'Balance',
      });
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDateRange() async {
    final current = DateTime.now();
    final today = DateTime(current.year, current.month, current.day);
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: today,
      initialDateRange: DateTimeRange(
        start: _fromDate ?? DateTime(today.year, today.month, 1),
        end: _toDate ?? today,
      ),
    );
    if (selected != null) {
      await _loadData(range: selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return const Padding(
        padding: EdgeInsets.all(60),
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFF2563EB)),
        ),
      );

    double endingCash = _openingCash + _cashIn - _cashOut;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Cash Register Report",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Opening drawer cash, payments collected, refunds issued, and closing audit log.",
                    style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                  ),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _selectDateRange,
                    icon: const Icon(Icons.date_range, size: 18),
                    label: Text(
                      "${_dateString(_fromDate ?? DateTime.now())} – ${_dateString(_toDate ?? DateTime.now())}",
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _loadData,
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: Color(0xFF2563EB),
                      size: 24,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_error != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                border: Border.all(color: const Color(0xFFFCA5A5)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _error!,
                style: const TextStyle(color: Color(0xFFB91C1C)),
              ),
            ),
            const SizedBox(height: 20),
          ],

          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildMetricCard(
                "Opening Float",
                "NPR ${_openingCash.toStringAsFixed(0)}",
                Icons.lock_clock_rounded,
                const Color(0xFF2563EB),
              ),
              _buildMetricCard(
                "Cash In (Sales)",
                "NPR ${_cashIn.toStringAsFixed(0)}",
                Icons.add_circle_rounded,
                const Color(0xFF10B981),
              ),
              _buildMetricCard(
                "Cash Out (Refunds)",
                "NPR ${_cashOut.toStringAsFixed(0)}",
                Icons.remove_circle_rounded,
                const Color(0xFFEF4444),
              ),
              _buildMetricCard(
                "Drawer Ending Balance",
                "NPR ${endingCash.toStringAsFixed(0)}",
                Icons.point_of_sale_rounded,
                const Color(0xFFF59E0B),
              ),
            ],
          ),
          const SizedBox(height: 28),

          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: AdminTheme.softShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "CASH REGISTER AUDIT LOG",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6B7280),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 20),

                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 800),
                    child: DataTable(
                      headingRowHeight: 48,
                      dataRowMaxHeight: 60,
                      horizontalMargin: 12,
                      columnSpacing: 24,
                      columns: const [
                        DataColumn(
                          label: Text(
                            "TIME",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            "TRANSACTION / ACTION",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            "REGISTER OPERATOR",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            "TYPE",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            "AMOUNT",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ),
                      ],
                      rows: _registerLogs.map((l) {
                        double amt =
                            (double.tryParse(l['amount']?.toString() ?? '0') ??
                            0.0);
                        bool isDebit = l['type'] == 'Debit';
                        bool isBalance = l['type'] == 'Balance';

                        Color color = isBalance
                            ? const Color(0xFF2563EB)
                            : (isDebit ? Colors.redAccent : Colors.green);

                        return DataRow(
                          cells: [
                            DataCell(
                              Text(
                                l['time'].toString(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                l['action'].toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                l['user'].toString(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF4B5563),
                                ),
                              ),
                            ),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  l['type'].toString(),
                                  style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                "NPR ${amt.abs().toStringAsFixed(2)}",
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                  color: color,
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: AdminTheme.softShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
