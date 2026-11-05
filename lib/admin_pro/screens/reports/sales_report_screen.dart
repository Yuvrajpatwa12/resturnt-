import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../services/api_service.dart';
import '../../admin_theme.dart';

class SalesReportScreen extends StatefulWidget {
  const SalesReportScreen({super.key});

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  bool _isLoading = true;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  List<Map<String, dynamic>> _sales = [];
  Map<String, dynamic> _reportSummary = {};
  Map<String, dynamic> _reconciliation = {};
  DateTime? _fromDate;
  DateTime? _toDate;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _dateString(DateTime date) =>
      "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

  Future<void> _loadData({DateTimeRange? range}) async {
    final today = DateTime.now();
    final now = DateTime(today.year, today.month, today.day);
    final from = range?.start ?? _fromDate ?? DateTime(now.year, now.month, 1);
    final to = range?.end ?? _toDate ?? now;
    setState(() => _isLoading = true);
    final report = await ApiService.fetchFinancialReport(
      from: _dateString(from),
      to: _dateString(to),
    );
    if (mounted) {
      setState(() {
        _fromDate = from;
        _toDate = to;
        _sales = report['transactions'] is List
            ? List<Map<String, dynamic>>.from(report['transactions'])
            : [];
        _reportSummary = report['summary'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(report['summary'])
            : {};
        _reconciliation = report['reconciliation'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(report['reconciliation'])
            : {};
        _error = report['success'] == true
            ? null
            : (report['message'] ?? "Could not load financial report.")
                  .toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDateRange() async {
    final current = DateTime.now();
    final now = DateTime(current.year, current.month, current.day);
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: DateTimeRange(
        start: _fromDate ?? DateTime(now.year, now.month, 1),
        end: _toDate ?? now,
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

    final filtered = _sales.where((s) {
      final q = _searchQuery.toLowerCase();
      final id = (s['id'] ?? s['order_id'] ?? '').toString().toLowerCase();
      final cust = (s['customer'] ?? s['customer_name'] ?? s['user_id'] ?? '')
          .toString()
          .toLowerCase();
      final method = (s['method'] ?? s['payment_method'] ?? '')
          .toString()
          .toLowerCase();
      return id.contains(q) || cust.contains(q) || method.contains(q);
    }).toList();

    double totalRevenue = filtered.fold(
      0.0,
      (sum, s) =>
          sum +
          (double.tryParse(
                s['amount']?.toString() ??
                    s['total_amount']?.toString() ??
                    s['total_price']?.toString() ??
                    '0',
              ) ??
              0.0),
    );
    int totalPaymentRows = filtered
        .where((row) => row['type'] == 'payment')
        .length;
    double avgPayment = totalPaymentRows > 0
        ? totalRevenue / totalPaymentRows
        : 0;
    double grossProfit = totalRevenue * 0.65; // Estimated 65% gross margin

    // Calculate Payment Method Breakdown
    double cashRev = 0;
    double digitalRev = 0;
    double cardRev = 0;
    for (var s in filtered) {
      double amt =
          double.tryParse(
            s['amount']?.toString() ??
                s['total_amount']?.toString() ??
                s['total_price']?.toString() ??
                '0',
          ) ??
          0.0;
      String m = (s['method'] ?? s['payment_method'] ?? 'Cash')
          .toString()
          .toLowerCase();
      if (m.contains('qr') ||
          m.contains('fonepay') ||
          m.contains('esewa') ||
          m.contains('khalti')) {
        digitalRev += amt;
      } else if (m.contains('card') || m.contains('pos')) {
        cardRev += amt;
      } else {
        cashRev += amt;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Sales Report",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Comprehensive revenue analytics, sales trends, gross profit, and payment method distribution.",
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
            _reportErrorBanner(_error!),
            const SizedBox(height: 20),
          ],
          if (_reconciliation['warning'] == true) ...[
            _buildReconciliationBanner(),
            const SizedBox(height: 20),
          ] else if (_reconciliation.isNotEmpty) ...[
            _buildReconciliationBanner(),
            const SizedBox(height: 20),
          ],

          // METRICS WITH MICRO SPARKLINES
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildSparklineCard(
                "Total Sales Revenue",
                "NPR ${totalRevenue.toStringAsFixed(0)}",
                "+14.2% ↑",
                Icons.monetization_on_rounded,
                const Color(0xFF2563EB),
              ),
              _buildSparklineCard(
                "Gross Profit (Est.)",
                "NPR ${grossProfit.toStringAsFixed(0)}",
                "+18.5% ↑",
                Icons.trending_up_rounded,
                const Color(0xFF10B981),
              ),
              _buildSparklineCard(
                "Payment Rows",
                "$totalPaymentRows",
                "LEDGER",
                Icons.shopping_cart_rounded,
                const Color(0xFF8B5CF6),
              ),
              _buildSparklineCard(
                "Avg Net Payment",
                "NPR ${avgPayment.toStringAsFixed(0)}",
                "LEDGER",
                Icons.analytics_rounded,
                const Color(0xFFF59E0B),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // SALES TREND GRADIENT AREA LINE CHART & DONUT PIE CHART
          Wrap(
            spacing: 20,
            runSpacing: 20,
            children: [
              // GRADIENT AREA LINE CHART
              Container(
                width: MediaQuery.sizeOf(context).width < 700
                    ? MediaQuery.sizeOf(context).width - 48
                    : 600,
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "DAILY REVENUE TREND & AREA INSIGHTS",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6B7280),
                            letterSpacing: 0.5,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF2563EB,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            "LIVE DATA",
                            style: TextStyle(
                              color: Color(0xFF2563EB),
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 200,
                      child: LineChart(
                        LineChartData(
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            getDrawingHorizontalLine: (val) => FlLine(
                              color: const Color(0xFFF1F5F9),
                              strokeWidth: 1,
                            ),
                          ),
                          titlesData: const FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            topTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: filtered.isEmpty
                                  ? const [FlSpot(1, 0), FlSpot(2, 0)]
                                  : filtered.asMap().entries.map((e) {
                                      double amt =
                                          double.tryParse(
                                            e.value['amount']?.toString() ??
                                                e.value['total_amount']
                                                    ?.toString() ??
                                                e.value['total_price']
                                                    ?.toString() ??
                                                '0',
                                          ) ??
                                          0.0;
                                      return FlSpot(e.key.toDouble() + 1, amt);
                                    }).toList(),
                              isCurved: true,
                              color: const Color(0xFF2563EB),
                              barWidth: 4,
                              isStrokeCapRound: true,
                              dotData: const FlDotData(show: true),
                              belowBarData: BarAreaData(
                                show: true,
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(
                                      0xFF2563EB,
                                    ).withValues(alpha: 0.35),
                                    const Color(
                                      0xFF2563EB,
                                    ).withValues(alpha: 0.02),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // PAYMENT METHOD DONUT CHART (IMAGE 1 STYLE)
              Container(
                width: MediaQuery.sizeOf(context).width < 700
                    ? MediaQuery.sizeOf(context).width - 48
                    : 320,
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
                      "PAYMENT METHOD DISTRIBUTION",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6B7280),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 180,
                      child: totalRevenue <= 0
                          ? const Center(
                              child: Text(
                                "No transactions yet",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            )
                          : PieChart(
                              PieChartData(
                                sectionsSpace: 4,
                                centerSpaceRadius: 40,
                                sections: [
                                  PieChartSectionData(
                                    color: const Color(0xFF10B981),
                                    value: cashRev > 0 ? cashRev : 1,
                                    title:
                                        "${(cashRev / (totalRevenue > 0 ? totalRevenue : 1) * 100).toInt()}%",
                                    radius: 45,
                                    titleStyle: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      fontSize: 11,
                                    ),
                                  ),
                                  PieChartSectionData(
                                    color: const Color(0xFF2563EB),
                                    value: digitalRev > 0 ? digitalRev : 1,
                                    title:
                                        "${(digitalRev / (totalRevenue > 0 ? totalRevenue : 1) * 100).toInt()}%",
                                    radius: 45,
                                    titleStyle: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      fontSize: 11,
                                    ),
                                  ),
                                  PieChartSectionData(
                                    color: const Color(0xFFF59E0B),
                                    value: cardRev > 0 ? cardRev : 1,
                                    title:
                                        "${(cardRev / (totalRevenue > 0 ? totalRevenue : 1) * 100).toInt()}%",
                                    radius: 45,
                                    titleStyle: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildLegendItem("Cash", const Color(0xFF10B981)),
                        _buildLegendItem("Digital QR", const Color(0xFF2563EB)),
                        _buildLegendItem("Card POS", const Color(0xFFF59E0B)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // SEARCH BAR & SALES TABLE
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
                SizedBox(
                  height: 44,
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (val) =>
                        setState(() => _searchQuery = val.trim()),
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: Color(0xFF9CA3AF),
                        size: 20,
                      ),
                      hintText:
                          "Search order ID, customer name, or payment method...",
                      hintStyle: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 13,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                filtered.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(
                          child: Text(
                            "No sales transactions found in database.",
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    : SingleChildScrollView(
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
                                  "ORDER ID",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  "CUSTOMER / TABLE",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              ),
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
                                  "PAYMENT METHOD",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  "TOTAL AMOUNT",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              ),
                            ],
                            rows: filtered.map((s) {
                              double amt =
                                  double.tryParse(
                                    s['amount']?.toString() ??
                                        s['total_amount']?.toString() ??
                                        s['total_price']?.toString() ??
                                        '0',
                                  ) ??
                                  0;
                              final isRefund = s['type'] == 'refund';
                              String ordId = isRefund
                                  ? "REF-${s['id'] ?? ''}"
                                  : "PAY-${s['id'] ?? ''}";
                              String cust =
                                  s['customer'] ??
                                  s['customer_name'] ??
                                  s['user_id'] ??
                                  'Guest';
                              String method =
                                  "${isRefund ? 'Refund · ' : ''}${s['method'] ?? s['payment_method'] ?? 'Cash'}";
                              String timeStr =
                                  s['time'] ?? s['created_at'] ?? '12:00 PM';

                              return DataRow(
                                cells: [
                                  DataCell(
                                    Text(
                                      ordId.toString(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Color(0xFF2563EB),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      "$cust (${s['table'] ?? s['table_number'] ?? 'Dine-In'})",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Color(0xFF1F2937),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      timeStr,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
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
                                        color: const Color(
                                          0xFF10B981,
                                        ).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        method,
                                        style: const TextStyle(
                                          color: Color(0xFF047857),
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
                                        color: isRefund
                                            ? Colors.red
                                            : Colors.green,
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

  Widget _buildReconciliationBanner() {
    final warning = _reconciliation['warning'] == true;
    final placed = _reconciliation['orders_placed_count'] ?? 0;
    final paid = _reconciliation['paid_orders_count'] ?? 0;
    final open = _reconciliation['open_session_orders_count'] ?? 0;
    final countVariance = _reconciliation['count_variance'] ?? 0;
    final subtotalVariance = _reconciliation['subtotal_variance'] ?? '0.00';
    final paymentMethods = _reportSummary['payment_methods'] is List
        ? (_reportSummary['payment_methods'] as List)
              .whereType<Map>()
              .map(
                (method) =>
                    "${method['method']}: NPR ${method['net_amount'] ?? '0.00'}",
              )
              .join(' · ')
        : 'No payment methods recorded';
    final warningReason = (_reconciliation['warning_reason'] ?? '').toString();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: warning ? const Color(0xFFFFF7ED) : const Color(0xFFF0FDF4),
        border: Border.all(
          color: warning ? const Color(0xFFF97316) : const Color(0xFF22C55E),
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            warning ? Icons.warning_amber_rounded : Icons.verified_outlined,
            color: warning ? const Color(0xFFEA580C) : const Color(0xFF16A34A),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  warning
                      ? (warningReason.isNotEmpty
                            ? warningReason
                            : "Reconciliation discrepancy detected")
                      : "Reconciliation balances",
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: warning
                        ? const Color(0xFF9A3412)
                        : const Color(0xFF166534),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Orders placed: $placed · Paid orders: $paid · Orders in open/ready sessions: $open · Ready-for-Billing sessions: ${_reportSummary['ready_for_billing_sessions'] ?? 0} · Count variance: $countVariance · Subtotal variance: NPR $subtotalVariance. Payments: ${_reportSummary['payments_recorded_count'] ?? 0} rows / NPR ${_reportSummary['payments_net_total'] ?? '0.00'} net; refunds: ${_reportSummary['refunds_issued_count'] ?? 0} / NPR ${_reportSummary['refunds_total'] ?? '0.00'}. By method: $paymentMethods.",
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Check excludes voided orders and compares stored order subtotals by order date; payments include tax/service, shown net of refunds separately.",
                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _reportErrorBanner(String message) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFFEF2F2),
      border: Border.all(color: const Color(0xFFFCA5A5)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(message, style: const TextStyle(color: Color(0xFFB91C1C))),
  );

  Widget _buildSparklineCard(
    String title,
    String value,
    String badge,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    color: Colors.green.shade800,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        CircleAvatar(radius: 5, backgroundColor: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Color(0xFF475569),
          ),
        ),
      ],
    );
  }
}
