import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/tenant_service.dart';
import '../../cart_manager.dart';
import '../admin_theme.dart';
import 'dart:math' as math;

class SupplierManagementScreen extends StatefulWidget {
  final String mode;
  const SupplierManagementScreen({super.key, required this.mode});

  @override
  State<SupplierManagementScreen> createState() => _SupplierManagementScreenState();
}

class _SupplierManagementScreenState extends State<SupplierManagementScreen> {
  bool _isLoading = false;

  // Search/Filter state
  String _historySearchQuery = "";

  // Dynamic getters for centralized state
  List<Map<String, dynamic>> get _suppliers => ShopManager.instance.allSuppliers.value;
  List<Map<String, dynamic>> get _purchases => ShopManager.instance.allPurchases.value;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return;
    setState(() => _isLoading = true);
    await ShopManager.instance.syncProcurementData(tenant.id);
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: ShopManager.instance.allSuppliers,
      builder: (context, suppliers, _) {
        return ValueListenableBuilder<List<Map<String, dynamic>>>(
          valueListenable: ShopManager.instance.allPurchases,
          builder: (context, purchases, _) {
            // Check if we are in Ledger Mode
            if (widget.mode == "Supplier Ledger") {
              return _buildLedgerListView();
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildSummaryCards(),
                  const SizedBox(height: 32),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildCategoryAnalytics()),
                      const SizedBox(width: 24),
                      Expanded(child: _buildTrendAnalytics()),
                    ],
                  ),
                  const SizedBox(height: 32),
                  _buildBudgetOverview(),
                  const SizedBox(height: 32),
                  _buildRecentTransactions(),
                ],
              ),
            );
          }
        );
      }
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Supplier Command Center", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AdminTheme.darkNavy)),
            Text("Manage your vendors and their individual supply containers.", style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        ElevatedButton.icon(
          onPressed: _showAddSupplierModal,
          icon: const Icon(Icons.add_business_rounded, size: 18),
          label: const Text("NEW SUPPLIER"),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF5C00)),
        ),
      ],
    );
  }

  double get _totalExpenses {
    return _purchases.fold(0, (sum, p) => sum + (double.tryParse(p['total_price'].toString()) ?? 0));
  }

  double get _totalOutstanding {
    return _purchases.fold(0, (sum, p) {
      double total = double.tryParse(p['total_price'].toString()) ?? 0;
      double paid = double.tryParse(p['paid_amount']?.toString() ?? '0') ?? 0;
      return sum + (total - paid);
    });
  }

  Map<String, double> get _categoryDistribution {
    Map<String, double> dist = {"Dairy": 0, "Vegetables": 0, "Meat": 0, "General": 0};
    double total = _totalExpenses;
    if (total == 0) return {"Dairy": 0.25, "Vegetables": 0.25, "Meat": 0.25, "General": 0.25};

    for (var p in _purchases) {
      String name = (p['ingredientnameCtrl'] ?? "").toString().toLowerCase();
      double price = double.tryParse(p['total_price'].toString()) ?? 0;
      if (name.contains("milk") || name.contains("cheese")) {
        dist["Dairy"] = dist["Dairy"]! + price;
      } else if (name.contains("meat") || name.contains("chicken")) {
        dist["Meat"] = dist["Meat"]! + price;
      } else if (name.contains("veg") || name.contains("onion")) {
        dist["Vegetables"] = dist["Vegetables"]! + price;
      } else {
        dist["General"] = dist["General"]! + price;
      }
    }

    dist.forEach((key, value) { dist[key] = value / total; });
    return dist;
  }

  Widget _buildSummaryCards() {
    return Row(
      children: [
        _buildStatCard("Total Purchases", "NPR ${_totalExpenses.toStringAsFixed(0)}", const Color(0xFF6366F1), Icons.receipt_long),
        const SizedBox(width: 16),
        _buildStatCard("Active Vendors", "${_suppliers.length}", const Color(0xFF10B981), Icons.storefront_rounded),
        const SizedBox(width: 16),
        _buildStatCard("Net Outstanding", "NPR ${_totalOutstanding.toStringAsFixed(0)}", const Color(0xFFF59E0B), Icons.pending_actions_rounded),
        const SizedBox(width: 16),
        _buildStatCard("Supply Orders", "${_purchases.length}", const Color(0xFF3B82F6), Icons.inventory_2_rounded),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 5))],
          border: Border.all(color: color.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AdminTheme.darkNavy)),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryAnalytics() {
    return Container(
      height: 300, padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32), boxShadow: AdminTheme.softShadow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Spending by Category", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 24),
          Expanded(
            child: Row(
              children: [
                SizedBox(width: 110, height: 110, child: CustomPaint(painter: RingChartPainter(dist: _categoryDistribution))),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLegendItem("Dairy", const Color(0xFF6366F1), "${(_categoryDistribution['Dairy']! * 100).toStringAsFixed(0)}%"),
                      _buildLegendItem("Vegetables", const Color(0xFF10B981), "${(_categoryDistribution['Vegetables']! * 100).toStringAsFixed(0)}%"),
                      _buildLegendItem("Meat", const Color(0xFFF59E0B), "${(_categoryDistribution['Meat']! * 100).toStringAsFixed(0)}%"),
                      _buildLegendItem("Other", const Color(0xFF3B82F6), "${(_categoryDistribution['General']! * 100).toStringAsFixed(0)}%"),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendAnalytics() {
    return Container(
      height: 300, padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32), boxShadow: AdminTheme.softShadow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Monthly Spend Trend", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 24),
          Expanded(child: CustomPaint(size: Size.infinite, painter: TrendLinePainter())),
        ],
      ),
    );
  }

  Widget _buildBudgetOverview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Supplier Specific Containers", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const Text("Tap to manage individual product lists for each vendor.", style: TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 16),
        if (_suppliers.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(40), child: Text("No suppliers registered.")))
        else SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _suppliers.map((s) {
              double limit = double.tryParse(s['budget_limit']?.toString() ?? '10000') ?? 10000;
              double spent = _purchases.where((p) => p['supplier_name'] == s['name']).fold(0, (sum, p) => sum + (double.tryParse(p['total_price'].toString()) ?? 0));
              double progress = (spent / limit).clamp(0.0, 1.0);
              return _buildSupplierContainerCard(s, spent, limit, progress);
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSupplierContainerCard(Map<String, dynamic> s, double spent, double limit, double progress) {
    return Container(
      width: 240, margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: AdminTheme.softShadow, border: Border.all(color: const Color(0xFFF1F5F9))),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showSupplierPortal(s),
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AdminTheme.royalBlue.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.inventory_rounded, color: AdminTheme.royalBlue, size: 20)),
                    IconButton(onPressed: () => _deleteSupplier(s['id'].toString()), icon: const Icon(Icons.delete_outline, color: Colors.red, size: 16), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                  ],
                ),
                const SizedBox(height: 16),
                Text(s['name'] ?? 'Vendor', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AdminTheme.darkNavy), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text("Spent: NPR ${spent.toStringAsFixed(0)}", style: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 20),
                ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: progress, minHeight: 6, backgroundColor: Colors.grey[100], color: AdminTheme.royalBlue)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("${(progress * 100).toInt()}% Used", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const Text("OPEN PORTAL", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AdminTheme.royalBlue, letterSpacing: 0.5)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentTransactions() {
    final filtered = _purchases.where((p) {
      if (_historySearchQuery.isEmpty) return true;
      final q = _historySearchQuery.toLowerCase();
      return (p['supplier_name']?.toString().toLowerCase().contains(q) ?? false) || (p['ingredientnameCtrl']?.toString().toLowerCase().contains(q) ?? false);
    }).toList();

    return Container(
      width: double.infinity, padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32), boxShadow: AdminTheme.softShadow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Global Audit Log", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              Container(width: 200, height: 40, decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)), child: TextField(onChanged: (v) => setState(() => _historySearchQuery = v), decoration: const InputDecoration(hintText: "Search logs...", prefixIcon: Icon(Icons.search, size: 16), border: InputBorder.none, contentPadding: EdgeInsets.zero))),
            ],
          ),
          const SizedBox(height: 24),
          if (filtered.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("No records match your search.")))
          else ...filtered.take(10).map((p) => _buildLogMinimalRow(p)),
        ],
      ),
    );
  }

  Widget _buildLogMinimalRow(Map<String, dynamic> p) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(p['supplier_name'] ?? 'Vendor', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
          Expanded(flex: 2, child: Text(p['ingredientnameCtrl'] ?? 'Item', style: const TextStyle(fontSize: 12, color: Colors.grey))),
          Text("NPR ${p['total_price']}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AdminTheme.darkNavy)),
        ],
      ),
    );
  }

  // ==========================================
  // LEDGER MODE VIEWS
  // ==========================================
  Widget _buildLedgerListView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Financial Supplier Ledger", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AdminTheme.darkNavy)),
          const Text("Detailed audit trail and lifetime spending per vendor.", style: TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 32),
          if (_suppliers.isEmpty) 
            const Center(child: Padding(padding: EdgeInsets.all(40), child: Text("No vendors registered.")))
          else 
            ..._suppliers.map((s) => _buildLedgerSummaryCard(s)),
        ],
      ),
    );
  }

  Widget _buildLedgerSummaryCard(Map<String, dynamic> s) {
    final name = s['name'] ?? 'Vendor';
    final vendorPurchases = _purchases.where((p) => p['supplier_name'] == name).toList();
    double totalSpent = vendorPurchases.fold(0, (sum, p) => sum + (double.tryParse(p['total_price'].toString()) ?? 0));
    double totalPaid = vendorPurchases.fold(0, (sum, p) => sum + (double.tryParse(p['paid_amount']?.toString() ?? '0') ?? 0));
    double balance = totalSpent - totalPaid;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFF1F5F9))),
      child: ListTile(
        contentPadding: const EdgeInsets.all(20),
        leading: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AdminTheme.royalBlue.withValues(alpha: 0.05), shape: BoxShape.circle), child: const Icon(Icons.account_balance_wallet_outlined, color: AdminTheme.royalBlue)),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        subtitle: Row(
          children: [
            Text("Purchases: NPR ${totalSpent.toStringAsFixed(0)}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            const SizedBox(width: 12),
            Text("Balance: NPR ${balance.toStringAsFixed(0)}", style: TextStyle(fontSize: 11, color: balance > 0 ? Colors.red : Colors.green, fontWeight: FontWeight.bold)),
          ],
        ),
        trailing: TextButton(
          onPressed: () => _showFullLedgerReport(s, vendorPurchases, totalSpent, totalPaid),
          child: const Text("FULL LEDGER", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
        ),
      ),
    );
  }

  void _showFullLedgerReport(Map<String, dynamic> s, List<Map<String, dynamic>> history, double total, double paid) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text("OFFICIAL LEDGER", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AdminTheme.royalBlue, letterSpacing: 2)),
                          Text(s['name'] ?? 'Vendor', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                        ]),
                        const Icon(Icons.verified_user_rounded, color: AdminTheme.royalBlue, size: 32),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Row(children: [
                      Expanded(child: _buildInvoiceInfoCol("TOTAL BILLINGS", "NPR ${total.toStringAsFixed(2)}")),
                      Expanded(child: _buildInvoiceInfoCol("TOTAL SETTLED", "NPR ${paid.toStringAsFixed(2)}")),
                    ]),
                    const SizedBox(height: 24),
                    _buildInvoiceInfoCol("CURRENT OUTSTANDING", "NPR ${(total - paid).toStringAsFixed(2)}", subtitle: "As of ${DateTime.now().toString().split(' ')[0]}"),
                    
                    const Padding(padding: EdgeInsets.symmetric(vertical: 32), child: Divider()),
                    const Text("TRANSACTION HISTORY", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
                    const SizedBox(height: 16),
                    
                    if (history.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(40), child: Text("No transactions recorded.")))
                    else ...history.map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(p['ingredientnameCtrl'] ?? 'Item', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text(p['purchase_date']?.toString().split(' ')[0] ?? 'Date', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          ]),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text("NPR ${p['total_price']}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                            Text(p['total_price'] == p['paid_amount'] ? "Fully Paid" : "Partial", style: TextStyle(fontSize: 9, color: p['total_price'] == p['paid_amount'] ? Colors.green : Colors.orange, fontWeight: FontWeight.bold)),
                          ]),
                        ],
                      ),
                    )),

                    const SizedBox(height: 40),
                    const Divider(),
                    const SizedBox(height: 24),
                    
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Preparing PDF Report... Please wait."), backgroundColor: AdminTheme.royalBlue));
                          Future.delayed(const Duration(seconds: 2), () {
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ledger Report Downloaded Successfully!"), backgroundColor: Colors.green));
                          });
                        },
                        icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                        label: const Text("DOWNLOAD PDF REPORT"),
                        style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.darkNavy),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text("CLOSE LEDGER"))),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSupplierPortal(Map<String, dynamic> s) {
    final String vendorName = s['name'] ?? 'Vendor';
    final double limit = double.tryParse(s['budget_limit']?.toString() ?? '10000') ?? 10000;
    
    final itemTitle = TextEditingController();
    final itemQty = TextEditingController();
    final itemPrice = TextEditingController();
    bool isAdding = false;

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final items = _purchases.where((p) => p['supplier_name'] == vendorName).toList();
          double total = items.fold(0, (sum, p) => sum + (double.tryParse(p['total_price'].toString()) ?? 0));

          return Container(
            height: MediaQuery.of(context).size.height * 0.9,
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Text("SPECIFIC CONTAINER", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AdminTheme.royalBlue, letterSpacing: 2)),
                              Text(vendorName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                            ]),
                            FloatingActionButton.small(
                              onPressed: () => setModalState(() => isAdding = !isAdding),
                              backgroundColor: AdminTheme.royalBlue,
                              child: Icon(isAdding ? Icons.close : Icons.add, color: Colors.white),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(children: [
                          _buildInvoiceInfoCol("TOTAL PURCHASED", "NPR ${total.toStringAsFixed(0)}"),
                          const SizedBox(width: 32),
                          _buildInvoiceInfoCol("REMAINING LIMIT", "NPR ${(limit - total).toStringAsFixed(0)}"),
                        ]),
                        const SizedBox(height: 32),
                        
                        if (isAdding) ...[
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(24), border: Border.all(color: AdminTheme.royalBlue.withValues(alpha: 0.1))),
                            child: Column(children: [
                              _buildTextFieldInside("Item Name", itemTitle, hint: "e.g. Fresh Milk 5L"),
                              const SizedBox(height: 12),
                              Row(children: [
                                Expanded(child: _buildTextFieldInside("Quantity", itemQty, hint: "5")),
                                const SizedBox(width: 12),
                                Expanded(child: _buildTextFieldInside("Price (NPR)", itemPrice, hint: "1200")),
                              ]),
                              const SizedBox(height: 20),
                              ElevatedButton(
                                onPressed: isAdding ? () async {
                                  if (itemTitle.text.trim().isEmpty) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text("Enter product name")));
                                    return;
                                  }

                                  final tenant = TenantService().currentTenant.value;
                                  if (tenant == null) return;

                                  setModalState(() => isAdding = false); // Show loading or close form

                                  final res = await ApiService.addPurchase({
                                    'tenant_id': tenant.id,
                                    'supplier_name': vendorName,
                                    'ingredientnameCtrl': itemTitle.text.trim(),
                                    'quantity': itemQty.text.trim(),
                                    'total_price': itemPrice.text.trim(),
                                    'unit': 'units',
                                    'paid_amount': itemPrice.text.trim(),
                                  });

                                  if (res['success'] == true) {
                                    itemTitle.clear(); itemQty.clear(); itemPrice.clear();
                                    await _loadData();
                                    setModalState(() {}); // Refresh list
                                    if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text("Added Successfully!"), backgroundColor: Colors.green));
                                  } else {
                                    if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text("Error: ${res['message']}"), backgroundColor: Colors.red));
                                  }
                                } : null,
                                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: const Color(0xFFFF5C00)),
                                child: const Text("ADD TO THIS VENDOR"),
                              ),
                            ]),
                          ),
                          const SizedBox(height: 32),
                        ],

                        const Text("INTERNAL ITEM LOG", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
                        const SizedBox(height: 16),
                        if (items.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(40), child: Text("No items recorded for this vendor.")))
                        else ...items.map((item) => _buildPortalItemCard(item, () async {
                          final res = await ApiService.deletePurchase(TenantService().currentTenant.value!.id, item['id'].toString());
                          if (res['success'] == true) {
                            await _loadData();
                            setModalState(() {});
                            if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text("Record Deleted"), backgroundColor: Colors.red));
                          } else {
                            if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text("Delete Failed: ${res['message']}"), backgroundColor: Colors.red));
                          }
                        })),
                        const SizedBox(height: 40),
                        SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text("CLOSE CONTAINER"))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      ),
    );
  }

  Widget _buildPortalItemCard(Map<String, dynamic> item, VoidCallback onDelete) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFF1F5F9))),
      child: Row(children: [
        const Icon(Icons.shopping_bag_outlined, color: AdminTheme.royalBlue, size: 20),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item['ingredientnameCtrl'] ?? 'Item', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          Text("${item['quantity']} units • ${item['purchase_date']?.toString().split(' ')[0]}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ])),
        Text("NPR ${item['total_price']}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AdminTheme.royalBlue)),
        const SizedBox(width: 8),
        IconButton(onPressed: () => _confirmDeleteItem(onDelete), icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
      ]),
    );
  }

  void _confirmDeleteItem(VoidCallback onDelete) async {
    final res = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text("Delete Record?"), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("NO")), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("YES"))]));
    if (res == true) onDelete();
  }

  void _showAddSupplierModal() {
    final nameCtrl = TextEditingController();
    final limitCtrl = TextEditingController(text: "10000");

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          bool isSaving = false;

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("New Supplier Container", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 24),
                  _buildTextFieldInside("Supplier Name", nameCtrl, hint: "e.g. Dairy Fresh"),
                  const SizedBox(height: 16),
                  _buildTextFieldInside("Credit Limit (NPR)", limitCtrl),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSaving ? null : () async {
                        if (nameCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text("Please enter supplier name")));
                          return;
                        }

                        final tenant = TenantService().currentTenant.value;
                        if (tenant == null) {
                          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text("Error: No tenant identified. Please refresh.")));
                          return;
                        }

                        setModalState(() => isSaving = true);
                        
                        final res = await ApiService.addSupplier({
                          'tenant_id': tenant.id,
                          'name': nameCtrl.text.trim(),
                          'budget_limit': limitCtrl.text.trim(),
                          'category': 'General'
                        });

                        if (res['success'] == true) {
                          if (context.mounted) {
                            Navigator.pop(ctx);
                            _loadData();
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Supplier Created!"), backgroundColor: Colors.green));
                          }
                        } else {
                          setModalState(() => isSaving = false);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text("FAILED: ${res['message']}"), backgroundColor: Colors.red));
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 54)),
                      child: isSaving 
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text("CREATE CONTAINER"),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _deleteSupplier(String id) async {
    final res = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text("Remove Vendor?"), content: const Text("This will delete the entire container and its products."), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("NO")), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("YES"))]));
    if (res == true) { 
      final result = await ApiService.deleteSupplier(TenantService().currentTenant.value!.id, id); 
      if (result['success'] == true) {
        _loadData(); 
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Delete Failed: ${result['message']}"), backgroundColor: Colors.red));
      }
    }
  }

  Widget _buildTextFieldInside(String label, TextEditingController controller, {String? hint}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
      const SizedBox(height: 8),
      TextField(controller: controller, decoration: InputDecoration(hintText: hint, filled: true, fillColor: const Color(0xFFF8FAFC), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
    ]);
  }

  Widget _buildInvoiceInfoCol(String label, String value, {String subtitle = ""}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AdminTheme.darkNavy)),
      if (subtitle.isNotEmpty) Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.grey)),
    ]);
  }

  Widget _buildLegendItem(String label, Color color, String percent) {
    return Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 12), Expanded(child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AdminTheme.darkNavy))), Text(percent, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold))]));
  }
}

// --- PAINTERS ---
class SparklinePainter extends CustomPainter {
  final Color color; SparklinePainter({required this.color});
  @override void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2.0..strokeCap = StrokeCap.round;
    final path = Path(); path.moveTo(0, size.height * 0.8); path.lineTo(size.width * 0.2, size.height * 0.5); path.lineTo(size.width, 0); canvas.drawPath(path, paint);
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class RingChartPainter extends CustomPainter {
  final Map<String, double> dist; RingChartPainter({required this.dist});
  @override void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2); final radius = size.width / 2; final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = 15.0..strokeCap = StrokeCap.round;
    double startAngle = -math.pi / 2;
    final colors = [const Color(0xFF6366F1), const Color(0xFF10B981), const Color(0xFFF59E0B), const Color(0xFF3B82F6)];
    final keys = ["Dairy", "Vegetables", "Meat", "General"];
    for (int i = 0; i < 4; i++) {
      paint.color = colors[i]; double sweep = 2 * math.pi * (dist[keys[i]] ?? 0.25);
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweep, false, paint);
      startAngle += sweep;
    }
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class TrendLinePainter extends CustomPainter {
  @override void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF6366F1)..style = PaintingStyle.stroke..strokeWidth = 3.0..strokeCap = StrokeCap.round;
    final path = Path(); path.moveTo(0, size.height * 0.9); path.lineTo(size.width * 0.5, size.height * 0.4); path.lineTo(size.width, size.height * 0.2);
    canvas.drawPath(path, paint);
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
