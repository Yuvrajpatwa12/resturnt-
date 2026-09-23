import 'package:flutter/material.dart';
import '../../services/tenant_service.dart';
import '../../cart_manager.dart';
import '../admin_theme.dart';
import 'package:intl/intl.dart';

class PurchaseReportScreen extends StatefulWidget {
  const PurchaseReportScreen({super.key});

  @override
  State<PurchaseReportScreen> createState() => _PurchaseReportScreenState();
}

class _PurchaseReportScreenState extends State<PurchaseReportScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final tenant = TenantService().currentTenant.value;
    setState(() => _isLoading = true);

    if (tenant == null) {
      // In offline/demo mode, we just wait a bit and show demo data
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    try {
      await ShopManager.instance.syncProcurementData(tenant.id);
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  final List<Map<String, dynamic>> _demoPurchases = [
    {
      'ingredient_name': 'Premium Basmati Rice',
      'supplier_name': 'Annapurna Veggies',
      'quantity': 100,
      'unit_name': 'kg',
      'purchase_date': '2026-09-10',
      'total_amount': 12500.0,
      'type': 'Raw'
    },
    {
      'ingredient_name': 'Fresh Chicken Breast',
      'supplier_name': 'Everest Meat Center',
      'quantity': 45,
      'unit_name': 'kg',
      'purchase_date': '2026-09-12',
      'total_amount': 22000.0,
      'type': 'Raw'
    },
    {
      'ingredient_name': 'Dairy Milk (Full Cream)',
      'supplier_name': 'City Dairy Hub',
      'quantity': 60,
      'unit_name': 'ltr',
      'purchase_date': '2026-09-14',
      'total_amount': 8400.0,
      'type': 'Raw'
    },
    {
      'ingredient_name': 'Chef Special Masala',
      'supplier_name': 'Bhojon Masala',
      'quantity': 10,
      'unit_name': 'pkt',
      'purchase_date': '2026-09-15',
      'total_amount': 5600.0,
      'type': 'Raw'
    },
    {
      'ingredient_name': 'Cooking Oil (Sunflower)',
      'supplier_name': 'Patan Oil Mill',
      'quantity': 40,
      'unit_name': 'ltr',
      'purchase_date': '2026-09-16',
      'total_amount': 9200.0,
      'type': 'Raw'
    },
  ];

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: ShopManager.instance.allPurchases,
      builder: (context, realPurchases, _) {
        final purchases = realPurchases.isEmpty ? _demoPurchases : realPurchases;

        double totalPurchase = purchases.fold(
            0,
            (sum, p) =>
                sum +
                (double.tryParse(p['total_amount']?.toString() ??
                        p['total_price']?.toString() ??
                        '0') ??
                    0));
        double totalTax = totalPurchase * 0.13;
        double netCost = totalPurchase - totalTax;

        return LayoutBuilder(builder: (context, constraints) {
          bool isMobile = constraints.maxWidth < 900;
          bool isVerySmall = constraints.maxWidth < 600;

          return SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(isVerySmall),
                const SizedBox(height: 24),
                _buildFilterBar(isVerySmall),
                const SizedBox(height: 24),
                // Top Stats Cards
                _buildResponsiveStats(
                    isMobile, isVerySmall, totalPurchase, netCost, totalTax),
                const SizedBox(height: 24),
                // Charts & Sections
                _buildResponsiveCharts(
                    isMobile, isVerySmall, purchases, totalPurchase),
                const SizedBox(height: 24),
                // Detailed Logs Table
                _buildPurchaseLogsTable(purchases),
              ],
            ),
          );
        });
      },
    );
  }

  Widget _buildResponsiveStats(
      bool isMobile, bool isVerySmall, double total, double net, double tax) {
    int crossAxisCount = isVerySmall ? 1 : (isMobile ? 2 : 3);
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: isVerySmall ? 2.5 : 1.8,
      children: [
        _buildStatCard(
            "TOTAL PURCHASE", "NPR ${NumberFormat('#,###').format(total)}", "+2.5K", true),
        _buildStatCard(
            "NET COST", "NPR ${NumberFormat('#,###').format(net)}", "+1.4K", false),
        _buildStatCard("TOTAL TAX (13%)", "NPR ${NumberFormat('#,###').format(tax)}",
            "-3.2K", false,
            isNegative: true),
      ],
    );
  }

  Widget _buildResponsiveCharts(bool isMobile, bool isVerySmall,
      List<Map<String, dynamic>> purchases, double total) {
    return LayoutBuilder(builder: (context, box) {
      if (box.maxWidth < 1100) {
        return Column(
          children: [
            _buildCategoryDistributionCard(purchases),
            const SizedBox(height: 24),
            _buildExpenseTrendCard(),
            const SizedBox(height: 24),
            _buildImportCard(),
            const SizedBox(height: 24),
            _buildPurchaseVsTargetCard(total),
            const SizedBox(height: 24),
            _buildVendorLocationCard(),
          ],
        );
      }
      return Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: _buildCategoryDistributionCard(purchases)),
              const SizedBox(width: 24),
              Expanded(flex: 4, child: _buildExpenseTrendCard()),
              const SizedBox(width: 24),
              Expanded(flex: 3, child: _buildImportCard()),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 7, child: _buildPurchaseVsTargetCard(total)),
              const SizedBox(width: 24),
              Expanded(flex: 3, child: _buildVendorLocationCard()),
            ],
          ),
        ],
      );
    });
  }

  Widget _buildHeader(bool isVerySmall) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
                child: Text(isVerySmall ? "Admin 👋" : "Good Morning, Admin 👋",
                    style: TextStyle(
                        fontSize: isVerySmall ? 20 : 24,
                        fontWeight: FontWeight.w900,
                        color: AdminTheme.darkNavy))),
            if (!isVerySmall) ...[
              _buildIconButton(Icons.search),
              const SizedBox(width: 12),
              _buildIconButton(Icons.notifications_none),
              const SizedBox(width: 12),
              _buildIconButton(Icons.fullscreen),
            ],
          ],
        ),
        const Text("Welcome to Procurement Analysis Dashboard",
            style: TextStyle(
                color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildIconButton(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: AdminTheme.softShadow),
      child: Icon(icon, size: 20, color: Colors.grey[600]),
    );
  }

  Widget _buildFilterBar(bool isVerySmall) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _buildDropdownFilter(Icons.calendar_today, "Last 6 Month"),
        _buildDropdownFilter(Icons.storefront, "Select Vendor Location"),
        ElevatedButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006D77),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8))),
          child: const Text("Customize",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildDropdownFilter(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 12),
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AdminTheme.darkNavy)),
          const SizedBox(width: 24),
          const Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String val, String change, bool isMain,
      {bool isNegative = false}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AdminTheme.softShadow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                  child: Text(val,
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AdminTheme.darkNavy),
                      overflow: TextOverflow.ellipsis)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: (isNegative ? Colors.red : Colors.green)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4)),
                child: Text(change,
                    style: TextStyle(
                        color: isNegative ? Colors.red : Colors.green,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: 0.7,
              backgroundColor: Colors.grey.shade100,
              color: isNegative ? Colors.red : const Color(0xFF83C5BE),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryDistributionCard(List<Map<String, dynamic>> purchases) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: AdminTheme.softShadow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("PRODUCT PURCHASE BY TYPE",
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: AdminTheme.darkNavy)),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, box) {
            bool isSmall = box.maxWidth < 400;
            return Column(
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      _buildDot(const Color(0xFF006D77)),
                      const SizedBox(width: 4),
                      const Text("Raw", style: TextStyle(fontSize: 10))
                    ]),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      _buildDot(const Color(0xFF83C5BE)),
                      const SizedBox(width: 4),
                      const Text("Semi", style: TextStyle(fontSize: 10))
                    ]),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      _buildDot(const Color(0xFFEDF6F9)),
                      const SizedBox(width: 4),
                      const Text("Fixed", style: TextStyle(fontSize: 10))
                    ]),
                  ],
                ),
                const SizedBox(height: 32),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildCircleChart(const Color(0xFF006D77), "229", isSmall ? 70 : 90),
                      const SizedBox(width: 12),
                      _buildCircleChart(const Color(0xFF83C5BE), "1,283", isSmall ? 90 : 110),
                      const SizedBox(width: 12),
                      _buildCircleChart(const Color(0xFFEDF6F9), "622", isSmall ? 65 : 80),
                    ],
                  ),
                )
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDot(Color c) =>
      Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle));

  Widget _buildCircleChart(Color c, String val, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(val,
          style: TextStyle(
              color: c == const Color(0xFFEDF6F9) ? AdminTheme.darkNavy : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16)),
    );
  }

  Widget _buildExpenseTrendCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: AdminTheme.softShadow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("PROFIT AND LOSS TREND",
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: AdminTheme.darkNavy)),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildDot(const Color(0xFF006D77)),
              const SizedBox(width: 4),
              const Text("Income", style: TextStyle(fontSize: 10)),
              const SizedBox(width: 12),
              _buildDot(const Color(0xFF83C5BE)),
              const SizedBox(width: 4),
              const Text("Expense", style: TextStyle(fontSize: 10)),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildBar(40, 60),
              _buildBar(30, 80),
              _buildBar(70, 40),
              _buildBar(20, 90),
              _buildBar(50, 70),
              _buildBar(80, 50),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ["Jan", "Feb", "Mar", "Apr", "May", "Jun"]
                .map((m) => Text(m, style: const TextStyle(fontSize: 10, color: Colors.grey)))
                .toList(),
          )
        ],
      ),
    );
  }

  Widget _buildBar(double h1, double h2) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
            width: 8,
            height: h1,
            decoration: const BoxDecoration(
                color: Color(0xFF006D77),
                borderRadius: BorderRadius.vertical(top: Radius.circular(2)))),
        const SizedBox(width: 2),
        Container(
            width: 8,
            height: h2,
            decoration: const BoxDecoration(
                color: Color(0xFF83C5BE),
                borderRadius: BorderRadius.vertical(top: Radius.circular(2)))),
      ],
    );
  }

  Widget _buildImportCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: const Color(0xFFF1F8F9), borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Scan receipts effortlessly, anywhere or import from excel",
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: AdminTheme.darkNavy)),
          const SizedBox(height: 12),
          const Text(
              "Automatic expense tracking with Enelys's mobile app and web upload.",
              style: TextStyle(color: Colors.grey, fontSize: 11)),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
                backgroundColor: AdminTheme.darkNavy,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            child: const Text("Get Started",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Widget _buildPurchaseVsTargetCard(double actual) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: AdminTheme.softShadow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("SALES VS. TARGET OVER TIME",
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: AdminTheme.darkNavy)),
          const SizedBox(height: 24),
          Wrap(
            spacing: 32,
            runSpacing: 16,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("NPR ${NumberFormat('#,###').format(actual)}",
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AdminTheme.darkNavy)),
                const Text("TOTAL SALES",
                    style: TextStyle(
                        color: Colors.grey,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ]),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text("NPR 20,000.00",
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AdminTheme.darkNavy)),
                const Text("TOTAL TARGET",
                    style: TextStyle(
                        color: Colors.grey,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ]),
            ],
          ),
          const SizedBox(height: 40),
          SizedBox(
            height: 200,
            width: double.infinity,
            child: CustomPaint(
              painter: _LineChartPainter(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ["Jan", "Feb", "Mar", "Apr", "May", "Jun"]
                .map((m) => Text(m, style: const TextStyle(fontSize: 10, color: Colors.grey)))
                .toList(),
          )
        ],
      ),
    );
  }

  Widget _buildVendorLocationCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: AdminTheme.softShadow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("SALES BY STORE LOCATION",
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: AdminTheme.darkNavy)),
          const SizedBox(height: 24),
          const Text("NPR 37,829.21",
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: AdminTheme.darkNavy)),
          const SizedBox(height: 32),
          _buildLocationBar("Downtown", 0.7, "\$17.0M"),
          _buildLocationBar("Commercial", 0.4, "\$7.1M"),
          _buildLocationBar("Airport", 0.6, "\$13.0M"),
        ],
      ),
    );
  }

  Widget _buildLocationBar(String label, double val, String amount) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
              Text(amount,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AdminTheme.darkNavy)),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
              value: val,
              backgroundColor: Colors.grey.shade100,
              color: const Color(0xFF006D77),
              minHeight: 30,
              borderRadius: BorderRadius.circular(4)),
        ],
      ),
    );
  }

  Widget _buildPurchaseLogsTable(List<Map<String, dynamic>> purchases) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: AdminTheme.softShadow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("RECENT PURCHASE TRANSACTIONS",
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AdminTheme.darkNavy)),
          const SizedBox(height: 24),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(2),
              1: FlexColumnWidth(2),
              2: FlexColumnWidth(1),
              3: FlexColumnWidth(1.5),
              4: FlexColumnWidth(1.5),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(color: Colors.grey.shade50),
                children: const [
                  Padding(
                      padding: EdgeInsets.all(12),
                      child: Text("ITEM NAME",
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey))),
                  Padding(
                      padding: EdgeInsets.all(12),
                      child: Text("VENDOR",
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey))),
                  Padding(
                      padding: EdgeInsets.all(12),
                      child: Text("QTY",
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey))),
                  Padding(
                      padding: EdgeInsets.all(12),
                      child: Text("DATE",
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey))),
                  Padding(
                      padding: EdgeInsets.all(12),
                      child: Text("AMOUNT",
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey))),
                ],
              ),
              ...purchases.map((p) => TableRow(
                    children: [
                      Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(p['ingredient_name'] ?? 'N/A',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13))),
                      Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(p['supplier_name'] ?? 'Direct',
                              style: const TextStyle(fontSize: 12))),
                      Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text("${p['quantity']} ${p['unit_name'] ?? 'kg'}",
                              style: const TextStyle(fontSize: 12))),
                      Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(p['purchase_date'] ?? 'N/A',
                              style: const TextStyle(fontSize: 12))),
                      Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text("NPR ${p['total_amount']}",
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: AdminTheme.royalBlue,
                                  fontSize: 13))),
                    ],
                  )),
            ],
          ),
        ],
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..color = const Color(0xFF006D77)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final paint2 = Paint()
      ..color = const Color(0xFF83C5BE)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path1 = Path();
    path1.moveTo(0, size.height * 0.8);
    path1.quadraticBezierTo(
        size.width * 0.2, size.height * 0.4, size.width * 0.4, size.height * 0.6);
    path1.quadraticBezierTo(
        size.width * 0.6, size.height * 0.9, size.width * 0.8, size.height * 0.5);
    path1.lineTo(size.width, size.height * 0.7);

    final path2 = Path();
    path2.moveTo(0, size.height * 0.6);
    path2.lineTo(size.width * 0.3, size.height * 0.5);
    path2.lineTo(size.width * 0.7, size.height * 0.4);
    path2.lineTo(size.width, size.height * 0.2);

    canvas.drawPath(path1, paint1);
    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
