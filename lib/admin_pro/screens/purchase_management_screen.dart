import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/tenant_service.dart';
import '../../cart_manager.dart';
import '../admin_theme.dart';

class PurchaseManagementScreen extends StatefulWidget {
  final String mode;
  const PurchaseManagementScreen({super.key, required this.mode});

  @override
  State<PurchaseManagementScreen> createState() => _PurchaseManagementScreenState();
}

class _PurchaseManagementScreenState extends State<PurchaseManagementScreen> {
  // Form Controllers
  final _ingredientController = TextEditingController();
  final _supplierController = TextEditingController();
  final _quantityController = TextEditingController();
  final _unitController = TextEditingController(text: "kg");
  final _priceController = TextEditingController();
  final _paidAmountController = TextEditingController(text: "0");
  
  // Return Module State
  final _returnNoteController = TextEditingController();
  DateTime _selectedReturnDate = DateTime.now();
  List<Map<String, dynamic>> _returns = [];

  // Invoice Portal State
  String _searchQuery = "";
  String _selectedRange = "All"; // Today, 7D, 15D, 30D, 3M, 1Y, All
  String _selectedSupplierFilter = "All";

  // Procurement State
  List<Map<String, dynamic>> _purchases = [];
  List<Map<String, dynamic>> get _suppliers => ShopManager.instance.allSuppliers.value;
  bool _isLoading = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  @override
  void dispose() {
    _ingredientController.dispose();
    _supplierController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    _priceController.dispose();
    _returnNoteController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PurchaseManagementScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.mode != oldWidget.mode) {
      _refreshData();
    }
  }

  void _refreshData() {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return;

    if (widget.mode == "Purchase Item" || widget.mode == "Add Purchase") {
      _loadPurchases();
      ShopManager.instance.syncProcurementData(tenant.id);
    } else if (widget.mode == "Purchase Return" || widget.mode == "Return Invoice") {
      _loadReturns();
    }
  }

  // Remove _loadSuppliers method as it is handled by central sync

  Future<void> _loadReturns() async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return;

    setState(() => _isLoading = true);
    final data = await ApiService.fetchReturns(tenant.id);
    if (mounted) {
      if (data != null) setState(() => _returns = data);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPurchases() async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return;

    setState(() => _isLoading = true);
    final data = await ApiService.fetchPurchases(tenant.id);
    if (mounted) {
      if (data != null) setState(() => _purchases = data);
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.mode == "Add Purchase") _buildAddPurchaseForm()
          else if (widget.mode == "Purchase Return") _buildPurchaseReturnView()
          else if (widget.mode == "Return Invoice") _buildReturnInvoicePortal()
          else _buildPurchaseListView(),
        ],
      ),
    );
  }

  // ==========================================
  // 1. PROCUREMENT (PURCHASE ITEM) VIEW
  // ==========================================
  Widget _buildPurchaseListView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("${widget.mode}s", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            IconButton(onPressed: _loadPurchases, icon: const Icon(Icons.refresh, color: AdminTheme.royalBlue)),
          ],
        ),
        const SizedBox(height: 16),
        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else if (_purchases.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  const Text("No purchase records found."),
                  const SizedBox(height: 10),
                  Text(
                    "Debugging Tenant ID: ${TenantService().currentTenant.value?.id ?? 'Not Found'}",
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            ),
          )
        else
          ..._purchases.map((p) => _buildPurchaseTicket(p)),
      ],
    );
  }

  Widget _buildPurchaseTicket(Map<String, dynamic> p) {
    final String name = p['ingredient_name'] ?? 'Unknown Item';
    final String supplier = p['supplier_name'] ?? 'N/A';
    final String qty = p['quantity']?.toString() ?? '0';
    final String unit = p['unit'] ?? 'kg';
    final String price = p['total_price']?.toString() ?? '0';
    final String date = p['purchase_date'] ?? '';
    final String image = _getIngredientImage(name);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      height: 140,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Stack(
        children: [
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.network(
                    image,
                    width: 110,
                    height: 110,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => Container(
                      width: 110, height: 110, 
                      color: Colors.grey[100],
                      child: const Icon(Icons.inventory_2_outlined, color: Colors.grey),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 16, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF1E293B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text("Supplier: $supplier", style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
                      Text("Date: $date", style: const TextStyle(fontSize: 9, color: Colors.grey)),
                      const Spacer(),
                      Text("NPR $price", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF2563EB))),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(30)),
              child: Text("Qty : $qty $unit", style: const TextStyle(color: Color(0xFF16A34A), fontSize: 10, fontWeight: FontWeight.w700)),
            ),
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: InkWell(
              onTap: () => _showPurchaseActions(p),
              child: Container(
                width: 36, height: 36,
                decoration: const BoxDecoration(color: Color(0xFF2D3282), shape: BoxShape.circle),
                child: const Icon(Icons.more_horiz_rounded, color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 2. PURCHASE RETURN VIEW
  // ==========================================
  Widget _buildPurchaseReturnView() {
    final filteredReturns = _returns.where((r) {
      try {
        final date = DateTime.parse(r['return_date']);
        return date.year == _selectedReturnDate.year && date.month == _selectedReturnDate.month && date.day == _selectedReturnDate.day;
      } catch (e) { return false; }
    }).toList();

    double totalRefundToday = 0;
    for (var r in filteredReturns) {
      totalRefundToday += double.tryParse(r['return_amount'].toString()) ?? 0;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Return Records", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            IconButton(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedReturnDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 1)),
                );
                if (picked != null) setState(() => _selectedReturnDate = picked);
              },
              icon: const Icon(Icons.calendar_today_rounded, color: AdminTheme.royalBlue),
            ),
          ],
        ),
        InkWell(
          onTap: () => _showReturnInvoiceModal(filteredReturns, _selectedReturnDate),
          borderRadius: BorderRadius.circular(24),
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF2D3282), Color(0xFF1E293B)]),
              borderRadius: BorderRadius.circular(24),
              boxShadow: AdminTheme.softShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Refund Invoice: ${_selectedReturnDate.day}/${_selectedReturnDate.month}/${_selectedReturnDate.year}", style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                    const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 12),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Total Refund", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                    Text("NPR ${totalRefundToday.toStringAsFixed(2)}", style: const TextStyle(color: Color(0xFF4ADE80), fontSize: 22, fontWeight: FontWeight.w900)),
                  ],
                ),
                const SizedBox(height: 12),
                const Text("TAP TO VIEW MASTER INVOICE", style: TextStyle(color: Colors.white30, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
              ],
            ),
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _showAddReturnForm,
            icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
            label: const Text("RECORD NEW RETURN"),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEA580C), padding: const EdgeInsets.symmetric(vertical: 14)),
          ),
        ),
        const SizedBox(height: 24),
        if (_isLoading) const Center(child: CircularProgressIndicator())
        else if (filteredReturns.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(40), child: Text("No returns for this date.")))
        else ...filteredReturns.map((r) => _buildReturnTicket(r, filteredReturns)),
      ],
    );
  }

  Widget _buildReturnTicket(Map<String, dynamic> r, List<Map<String, dynamic>> allDailyItems) {
    final String name = r['ingredient_name'] ?? 'Unknown Item';
    final String supplier = r['supplier_name'] ?? 'N/A';
    final String qty = r['quantity']?.toString() ?? '0';
    final String unit = r['unit'] ?? 'kg';
    final String amount = r['return_amount']?.toString() ?? '0';
    final String reason = r['reason'] ?? 'No reason provided';
    final String image = _getIngredientImage(name);

    return InkWell(
      onTap: () => _showReturnInvoiceModal(allDailyItems, _selectedReturnDate),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        height: 150,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: Stack(
          children: [
            Row(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.network(image, width: 110, height: 110, fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(width: 110, height: 110, color: Colors.grey[100], child: const Icon(Icons.inventory_2_outlined))),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 16, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF1E293B)))),
                            const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey),
                          ],
                        ),
                        Text("Supplier: $supplier", style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text("Note: $reason", style: const TextStyle(fontSize: 10, color: Colors.redAccent, fontStyle: FontStyle.italic), maxLines: 2, overflow: TextOverflow.ellipsis),
                        const Spacer(),
                        Text("Refund: NPR $amount", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFFEA580C))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              top: 16, right: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(30)),
                child: Text("Return : $qty $unit", style: const TextStyle(color: Color(0xFFEF4444), fontSize: 10, fontWeight: FontWeight.w700)),
              ),
            ),
            Positioned(
              bottom: 12, right: 12,
              child: IconButton(
                onPressed: () => _deleteReturn(r['id'].toString()),
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                padding: EdgeInsets.zero, constraints: const BoxConstraints(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 3. RETURN INVOICE PORTAL
  // ==========================================
  Widget _buildReturnInvoicePortal() {
    final groupedInvoices = _getGroupedInvoices();

    // Summary Analytics Calculations
    double totalRefund = 0;
    int totalItemsCount = 0;
    for (var group in groupedInvoices.values) {
      for (var item in group) {
        totalRefund += double.tryParse(item['return_amount']?.toString() ?? '0') ?? 0;
        totalItemsCount++;
      }
    }

    final List<String> supplierNames = ["All", ..._suppliers.map((s) => s['name']?.toString() ?? '').where((n) => n.isNotEmpty)];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Invoice Explorer", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AdminTheme.darkNavy)),
                Text("Manage and search through procurement refund statements.", style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            IconButton(
              onPressed: _refreshData,
              icon: const Icon(Icons.sync_rounded, color: AdminTheme.royalBlue),
              tooltip: "Sync Return Statements",
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Summary Analytics Stat Cards
        Row(
          children: [
            Expanded(child: _buildPortalStatCard("TOTAL REFUND CREDIT", "NPR ${totalRefund.toStringAsFixed(0)}", Icons.account_balance_wallet_rounded, const Color(0xFF16A34A))),
            const SizedBox(width: 12),
            Expanded(child: _buildPortalStatCard("STATEMENTS", "${groupedInvoices.length} Statements", Icons.receipt_long_rounded, AdminTheme.royalBlue)),
            const SizedBox(width: 12),
            Expanded(child: _buildPortalStatCard("RETURNED ITEMS", "$totalItemsCount Items", Icons.inventory_2_rounded, Colors.purple)),
          ],
        ),
        const SizedBox(height: 24),

        // Search + Supplier Dropdown Filter
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 5))],
                ),
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: "Search Invoice, Item, Reason or Supplier...",
                    hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                    prefixIcon: const Icon(Icons.search_rounded, color: AdminTheme.royalBlue),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 5))],
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: supplierNames.contains(_selectedSupplierFilter) ? _selectedSupplierFilter : "All",
                  icon: const Icon(Icons.filter_list_rounded, color: AdminTheme.royalBlue, size: 20),
                  items: supplierNames.map((sName) {
                    return DropdownMenuItem<String>(
                      value: sName,
                      child: Text(
                        sName == "All" ? "All Suppliers" : sName,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AdminTheme.darkNavy),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedSupplierFilter = val);
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Date Range Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ["Today", "7D", "15D", "30D", "3M", "1Y", "All"].map((range) {
              bool isSel = _selectedRange == range;
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: ChoiceChip(
                  label: Text(range, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  selected: isSel,
                  onSelected: (v) => setState(() => _selectedRange = range),
                  selectedColor: AdminTheme.royalBlue,
                  labelStyle: TextStyle(color: isSel ? Colors.white : Colors.black87),
                  backgroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide.none),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 28),

        if (_isLoading)
          const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
        else if (groupedInvoices.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)],
            ),
            child: const Column(
              children: [
                Icon(Icons.assignment_return_outlined, size: 48, color: Colors.grey),
                SizedBox(height: 12),
                Text("No statement history found.", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                SizedBox(height: 4),
                Text("Try adjusting date range, supplier filter or search term.", style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          )
        else
          ...groupedInvoices.entries.map((e) => _buildMasterInvoiceCard(e.key, e.value)),
      ],
    );
  }

  Widget _buildPortalStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 0.5)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Map<String, List<Map<String, dynamic>>> _getGroupedInvoices() {
    final Map<String, List<Map<String, dynamic>>> groups = {};
    final now = DateTime.now();

    for (var r in _returns) {
      DateTime? date;
      try { date = DateTime.parse(r['return_date']); } catch (_) {}
      if (date == null) continue;

      bool inRange = true;
      final diff = now.difference(date).inDays;
      if (_selectedRange == "Today" && (date.year != now.year || date.month != now.month || date.day != now.day)) inRange = false;
      if (_selectedRange == "7D" && diff > 7) inRange = false;
      if (_selectedRange == "15D" && diff > 15) inRange = false;
      if (_selectedRange == "30D" && diff > 30) inRange = false;
      if (_selectedRange == "3M" && diff > 90) inRange = false;
      if (_selectedRange == "1Y" && diff > 365) inRange = false;

      if (!inRange) continue;

      if (_selectedSupplierFilter != "All") {
        final supp = r['supplier_name']?.toString().toLowerCase().trim() ?? "";
        if (supp != _selectedSupplierFilter.toLowerCase().trim()) continue;
      }

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final name = r['ingredient_name']?.toString().toLowerCase() ?? "";
        final supplier = r['supplier_name']?.toString().toLowerCase() ?? "";
        final reason = r['reason']?.toString().toLowerCase() ?? "";
        final id = "STMT-${date.year}${date.month}${date.day}".toLowerCase();
        if (!name.contains(q) && !supplier.contains(q) && !reason.contains(q) && !id.contains(q)) continue;
      }

      final key = "${date.year}-${date.month}-${date.day}";
      if (!groups.containsKey(key)) groups[key] = [];
      groups[key]!.add(r);
    }
    return groups;
  }

  Widget _buildMasterInvoiceCard(String dateKey, List<Map<String, dynamic>> items) {
    double total = 0;
    for (var i in items) { total += double.tryParse(i['return_amount'].toString()) ?? 0; }

    final dateParts = dateKey.split('-');
    final displayDate = "${dateParts[2]}/${dateParts[1]}/${dateParts[0]}";
    final statementId = "STMT-${dateParts[0]}${dateParts[1].padLeft(2, '0')}${dateParts[2].padLeft(2, '0')}";

    // Item titles & suppliers
    final List<String> itemTitles = items.map((i) => i['ingredient_name']?.toString() ?? 'Item').where((n) => n.isNotEmpty).toSet().toList();
    final String cardMainTitle = itemTitles.isEmpty 
        ? statementId 
        : (itemTitles.length == 1 
            ? itemTitles.first 
            : (itemTitles.length <= 2 ? itemTitles.join(", ") : "${itemTitles.first} + ${itemTitles.length - 1} more"));

    final Set<String> suppliers = items.map((i) => i['supplier_name']?.toString() ?? 'Supplier').where((s) => s.isNotEmpty).toSet();
    final String suppText = suppliers.length == 1 ? suppliers.first : "${suppliers.length} Suppliers";

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 20, offset: const Offset(0, 10))],
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showReturnInvoiceModal(items, DateTime.parse(dateKey)),
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(16)),
                      child: const Icon(Icons.receipt_rounded, color: AdminTheme.royalBlue),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cardMainTitle,
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AdminTheme.darkNavy),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(statementId, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 6),
                              Text("• $displayDate", style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: AdminTheme.royalBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                                child: Text(suppText, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AdminTheme.royalBlue)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text("REFUND", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
                        Text("NPR ${total.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF16A34A))),
                      ],
                    ),
                  ],
                ),
                const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Divider(height: 1, color: Color(0xFFF1F5F9))),
                Row(
                  children: [
                    const Icon(Icons.layers_outlined, size: 14, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text("${items.length} Returned Items", style: const TextStyle(fontSize: 12, color: AdminTheme.darkNavy, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    const Text("VIEW DETAILS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AdminTheme.royalBlue, letterSpacing: 0.5)),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: AdminTheme.royalBlue),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 4. ADD PROCUREMENT FORM
  // ==========================================
  Widget _buildAddPurchaseForm() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text("New Procurement", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
      const SizedBox(height: 24),
      _buildTextField("Ingredient Name", _ingredientController, hint: "e.g. Milk, Tea Leaves"),
      const SizedBox(height: 16),
      
      // Supplier Dropdown
      const Text("Supplier Name", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
      const SizedBox(height: 8),
      ValueListenableBuilder<List<Map<String, dynamic>>>(
        valueListenable: ShopManager.instance.allSuppliers,
        builder: (context, suppliers, _) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white, 
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: suppliers.isEmpty ? Colors.red.withValues(alpha: 0.3) : Colors.transparent),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _supplierController.text.isEmpty ? null : _supplierController.text,
                hint: Text(suppliers.isEmpty ? "PLEASE ADD A SUPPLIER FIRST" : "Select Supplier Partner", 
                     style: TextStyle(fontSize: 13, color: suppliers.isEmpty ? Colors.red : Colors.grey)),
                isExpanded: true,
                items: suppliers.map((s) => DropdownMenuItem(
                      value: s['name'].toString(),
                      child: Text(s['name']),
                    )).toList(),
                onChanged: suppliers.isEmpty ? null : (val) => setState(() => _supplierController.text = val!),
              ),
            ),
          );
        }
      ),
      ValueListenableBuilder<List<Map<String, dynamic>>>(
        valueListenable: ShopManager.instance.allSuppliers,
        builder: (context, suppliers, _) {
          if (suppliers.isNotEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text("Go to 'Supplier Manage' to register your vendors first.", 
                  style: TextStyle(fontSize: 10, color: Colors.red[700], fontWeight: FontWeight.bold)),
          );
        }
      ),
      const SizedBox(height: 16),

      Row(children: [
        Expanded(child: _buildTextField("Quantity", _quantityController, hint: "10")),
        const SizedBox(width: 16),
        Expanded(child: _buildTextField("Unit", _unitController, hint: "kg/L")),
      ]),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: _buildTextField("Total Price (NPR)", _priceController, hint: "5000")),
        const SizedBox(width: 16),
        Expanded(child: _buildTextField("Amount Paid (NPR)", _paidAmountController, hint: "0")),
      ]),
      const SizedBox(height: 32),
      if (_isSubmitting) const Center(child: CircularProgressIndicator())
      else ElevatedButton(onPressed: _submitPurchase, style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 54)), child: const Text("SUBMIT PURCHASE TO DATABASE")),
    ]);
  }

  Future<void> _submitPurchase() async {
    if (_supplierController.text.isEmpty) { 
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a supplier partner!"), backgroundColor: Colors.orange)); 
      return; 
    }
    if (_ingredientController.text.isEmpty || _quantityController.text.isEmpty || _priceController.text.isEmpty) { 
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Fill all required fields!"), backgroundColor: Colors.orange)); 
      return; 
    }
    
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: Tenant data not loaded!"), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final result = await ApiService.addPurchase({
        'tenant_id': tenant.id,
        'ingredient_name': _ingredientController.text,
        'supplier_name': _supplierController.text,
        'quantity': _quantityController.text,
        'unit': _unitController.text,
        'total_price': _priceController.text,
        'paid_amount': _paidAmountController.text, // Added this
      });
      if (result['success'] == true) { 
        _ingredientController.clear(); 
        _quantityController.clear(); 
        _priceController.clear(); 
        // SYNC CENTRAL STATE
        ShopManager.instance.syncProcurementData(tenant.id);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Purchase recorded!"), backgroundColor: Colors.green)); 
      }
      else { final String msg = result['message']?.toString() ?? "Failed to save."; if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red)); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  // ==========================================
  // 5. HELPERS & MODALS
  // ==========================================
  String _getIngredientImage(String name) {
    final n = name.toLowerCase();
    if (n.contains('milk')) return 'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=500&auto=format&fit=crop';
    if (n.contains('tea')) return 'https://images.unsplash.com/photo-1594631252845-29fc458639a8?w=500&auto=format&fit=crop';
    if (n.contains('sugar')) return 'https://images.unsplash.com/photo-1581441363689-1f3c3c414635?w=500&auto=format&fit=crop';
    if (n.contains('meat') || n.contains('chicken')) return 'https://images.unsplash.com/photo-1604503468506-a8da13d82791?w=500&auto=format&fit=crop';
    if (n.contains('veg') || n.contains('onion')) return 'https://images.unsplash.com/photo-1540333673334-9707b1d17546?w=500&auto=format&fit=crop';
    if (n.contains('flour')) return 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=500&auto=format&fit=crop';
    if (n.contains('oil')) return 'https://images.unsplash.com/photo-1474979266404-7eaacfbca3c5?w=500&auto=format&fit=crop';
    if (n.contains('egg')) return 'https://images.unsplash.com/photo-1569288052389-dac9b01c9c05?w=500&auto=format&fit=crop';
    if (n.contains('coffee')) return 'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=500&auto=format&fit=crop';
    return 'https://images.unsplash.com/photo-1586717791821-3f44a563cc4c?w=500&auto=format&fit=crop';
  }

  void _showReturnInvoiceModal(List<Map<String, dynamic>> items, DateTime selectedDate) {
    if (items.isEmpty) return;
    final String dateStr = "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}";
    final String transId = "STMT-${selectedDate.year}${selectedDate.month.toString().padLeft(2, '0')}${selectedDate.day.toString().padLeft(2, '0')}";
    final tenant = TenantService().currentTenant.value;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalContext, setModalState) {
          double grandTotal = 0;
          for (var item in items) {
            grandTotal += double.tryParse(item['return_amount']?.toString() ?? '0') ?? 0;
          }

          return Container(
            height: MediaQuery.of(context).size.height * 0.88,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
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
                        // Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("PROCUREMENT REFUND STATEMENT", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AdminTheme.royalBlue, letterSpacing: 2)),
                                Text("DAILY STATEMENT", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AdminTheme.darkNavy)),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: AdminTheme.royalBlue.withValues(alpha: 0.1), shape: BoxShape.circle),
                              child: const Icon(Icons.summarize_rounded, color: AdminTheme.royalBlue, size: 28),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),

                        // Statement Info Grid
                        Row(
                          children: [
                            Expanded(child: _buildInvoiceInfoCol("ISSUED TO (TENANT)", tenant?.name ?? "ChiyaBreak Partner", subtitle: tenant?.domain ?? "saas.platform")),
                            Expanded(child: _buildInvoiceInfoCol("STATEMENT DATE", dateStr, subtitle: "Full Day Cycle")),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(child: _buildInvoiceInfoCol("REFERENCE ID", transId, subtitle: "Digital Log Active")),
                            Expanded(child: _buildInvoiceInfoCol("TOTAL ITEMS", "${items.length} Returns", subtitle: "Verified Records")),
                          ],
                        ),
                        const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9))),

                        // Item Table Header
                        const Text("CONSOLIDATED RETURN LIST", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
                        const SizedBox(height: 16),

                        // Item List Container
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            children: [
                              _buildEnhancedInvoiceItemRow("Item / Supplier", "Qty & Reason", "Amount", "Action", isHeader: true),
                              const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
                              if (items.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(20),
                                  child: Center(child: Text("All items removed from statement.", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
                                )
                              else
                                ...items.map((item) {
                                  final rId = item['id']?.toString() ?? '';
                                  final title = item['ingredient_name'] ?? 'Item';
                                  final supplier = item['supplier_name'] ?? 'General Supplier';
                                  final qty = "${item['quantity']} ${item['unit']}";
                                  final reason = item['reason']?.toString() ?? 'Damaged/Defective';
                                  final amount = "NPR ${item['return_amount']}";

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12.0),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AdminTheme.darkNavy)),
                                              Text(supplier, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          flex: 3,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(qty, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AdminTheme.darkNavy)),
                                              const SizedBox(height: 2),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.redAccent.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(reason, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(amount, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)), textAlign: TextAlign.right),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                          tooltip: "Remove from statement",
                                          onPressed: () async {
                                            if (rId.isNotEmpty) {
                                              await _deleteReturn(rId);
                                              setModalState(() {
                                                items.removeWhere((i) => i['id']?.toString() == rId);
                                              });
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, thickness: 2, color: Colors.white)),
                              _buildEnhancedInvoiceItemRow("Grand Total", "", "NPR ${grandTotal.toStringAsFixed(2)}", "", isHeader: true),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Total Credit & Authorized Stamp
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("TOTAL REFUND CREDIT", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                                Text("NPR ${grandTotal.toStringAsFixed(2)}", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF16A34A))),
                              ],
                            ),
                            Transform.rotate(
                              angle: -0.1,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(border: Border.all(color: const Color(0xFF16A34A), width: 3), borderRadius: BorderRadius.circular(8)),
                                child: const Column(
                                  children: [
                                    Text("CREDIT", style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w900, fontSize: 16)),
                                    Text("AUTHORIZED", style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w900, fontSize: 10)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),

                        // Print Master Invoice Button
                        Center(
                          child: Column(
                            children: [
                              const Icon(Icons.verified_rounded, size: 60, color: Color(0xFFE2E8F0)),
                              const SizedBox(height: 8),
                              const Text("END OF DAILY STATEMENT", style: TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1)),
                              const SizedBox(height: 30),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _showPrintableInvoiceDialog(items, selectedDate, grandTotal);
                                  },
                                  icon: const Icon(Icons.print_rounded, size: 18),
                                  label: const Text("PRINT MASTER INVOICE"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AdminTheme.darkNavy,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showPrintableInvoiceDialog(List<Map<String, dynamic>> items, DateTime selectedDate, double grandTotal) {
    final String dateStr = "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}";
    final String transId = "STMT-${selectedDate.year}${selectedDate.month.toString().padLeft(2, '0')}${selectedDate.day.toString().padLeft(2, '0')}";
    final tenant = TenantService().currentTenant.value;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          width: 550,
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tenant?.name.toUpperCase() ?? "CHIYABREAK PARTNER", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AdminTheme.darkNavy)),
                      Text(tenant?.domain ?? "saas.platform", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFF16A34A).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Text("OFFICIAL REFUND STATEMENT", style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w900, fontSize: 10)),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Summary
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("STATEMENT ID: $transId", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AdminTheme.darkNavy)),
                  Text("DATE: $dateStr", style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),

              // Printable Table
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
                child: Column(
                  children: [
                    _buildInvoiceItemRow("Item / Supplier", "Qty", "Refund", isHeader: true),
                    const Divider(height: 12),
                    ...items.map((i) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: _buildInvoiceItemRow(
                        "${i['ingredient_name']} (${i['supplier_name'] ?? 'Supplier'})",
                        "${i['quantity']} ${i['unit']}",
                        "NPR ${i['return_amount']}",
                      ),
                    )),
                    const Divider(height: 12),
                    _buildInvoiceItemRow("GRAND TOTAL REFUND", "", "NPR ${grandTotal.toStringAsFixed(2)}", isHeader: true),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Stamp & Timestamp
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("ISSUED BY: CHIYABREAK SAAS SYSTEM", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
                      Text("TIME: ${DateTime.now().toString().substring(11, 16)}", style: const TextStyle(fontSize: 9, color: Colors.grey)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(border: Border.all(color: const Color(0xFF16A34A), width: 2), borderRadius: BorderRadius.circular(6)),
                    child: const Text("CREDIT AUTHORIZED", style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w900, fontSize: 10)),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Statement link copied to clipboard!"), backgroundColor: AdminTheme.royalBlue),
                        );
                      },
                      icon: const Icon(Icons.share_rounded, size: 16),
                      label: const Text("SHARE"),
                      style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Master Return Invoice sent to printer! 🖨️"), backgroundColor: Color(0xFF16A34A)),
                        );
                      },
                      icon: const Icon(Icons.print_rounded, size: 16),
                      label: const Text("PRINT INVOICE"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdminTheme.darkNavy,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedInvoiceItemRow(String c1, String c2, String c3, String c4, {bool isHeader = false}) {
    final style = TextStyle(fontSize: isHeader ? 11 : 13, fontWeight: isHeader ? FontWeight.w900 : FontWeight.w600, color: isHeader ? Colors.grey : AdminTheme.darkNavy);
    return Row(children: [
      Expanded(flex: 3, child: Text(c1, style: style)),
      Expanded(flex: 3, child: Text(c2, style: style)),
      Expanded(flex: 2, child: Text(c3, style: style, textAlign: TextAlign.right)),
      if (isHeader) const SizedBox(width: 48),
    ]);
  }

  Widget _buildInvoiceInfoCol(String label, String value, {required String subtitle}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AdminTheme.darkNavy)),
      Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.grey)),
    ]);
  }

  Widget _buildInvoiceItemRow(String c1, String c2, String c3, {bool isHeader = false}) {
    final style = TextStyle(fontSize: isHeader ? 11 : 13, fontWeight: isHeader ? FontWeight.w900 : FontWeight.w600, color: isHeader ? Colors.grey : AdminTheme.darkNavy);
    return Row(children: [
      Expanded(flex: 3, child: Text(c1, style: style)),
      Expanded(flex: 2, child: Text(c2, style: style, textAlign: TextAlign.center)),
      Expanded(flex: 2, child: Text(c3, style: style, textAlign: TextAlign.right)),
    ]);
  }

  void _showPurchaseActions(Map<String, dynamic> p) {
    showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 12),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 24),
        ListTile(leading: const Icon(Icons.edit_outlined, color: Colors.blue), title: const Text("Edit Record"), onTap: () => Navigator.pop(ctx)),
        ListTile(leading: const Icon(Icons.delete_outline, color: Colors.red), title: const Text("Delete Purchase"), onTap: () { Navigator.pop(ctx); _deletePurchase(p['id'].toString()); }),
        const SizedBox(height: 24),
      ]),
    );
  }

  Future<void> _deletePurchase(String id) async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return;
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text("Delete Record?"), content: const Text("This will permanently remove this purchase record."), actions: [
      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCEL")),
      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("DELETE", style: TextStyle(color: Colors.red))),
    ]));
    if (confirm == true) {
      final res = await ApiService.deletePurchase(tenant.id, id);
      if (res['success'] == true) { 
        _loadPurchases(); 
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Record deleted."))); 
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Delete Failed: ${res['message']}"), backgroundColor: Colors.red));
      }
    }
  }

  Widget _buildTextField(String label, TextEditingController controller, {String? hint}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
      const SizedBox(height: 8),
      TextField(controller: controller, decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(fontSize: 13), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
    ]);
  }

  void _showAddReturnForm() {
    _ingredientController.clear(); _supplierController.clear(); _quantityController.clear(); _priceController.clear(); _returnNoteController.clear();
    showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (ctx) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom), child: SingleChildScrollView(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("Record Purchase Return", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 24),
        _buildTextField("Ingredient Name", _ingredientController, hint: "e.g. Spoiled Milk"),
        const SizedBox(height: 16),
        _buildTextField("Supplier", _supplierController, hint: "e.g. Dairy Fresh"),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _buildTextField("Qty", _quantityController, hint: "5")),
          const SizedBox(width: 16),
          Expanded(child: _buildTextField("Unit", _unitController, hint: "kg")),
        ]),
        const SizedBox(height: 16),
        _buildTextField("Return Amount (Refund)", _priceController, hint: "2500"),
        const SizedBox(height: 16),
        _buildTextField("Return Reason", _returnNoteController, hint: "e.g. Quality Issue"),
        const SizedBox(height: 32),
        ElevatedButton(onPressed: _submitReturn, style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 54), backgroundColor: const Color(0xFFEA580C)), child: const Text("SAVE RETURN TO DATABASE")),
        const SizedBox(height: 20),
      ]))),
    );
  }

  Future<void> _submitReturn() async {
    if (_ingredientController.text.isEmpty || _priceController.text.isEmpty) return;
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return;
    final result = await ApiService.addReturn({'tenant_id': tenant.id, 'ingredient_name': _ingredientController.text, 'supplier_name': _supplierController.text, 'quantity': _quantityController.text, 'unit': _unitController.text, 'return_amount': _priceController.text, 'reason': _returnNoteController.text});
    if (result['success'] == true) { 
      if (!mounted) return;
      Navigator.pop(context); 
      _loadReturns(); 
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Return recorded!"), backgroundColor: Colors.green)); 
    }
  }

  Future<void> _deleteReturn(String id) async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return;
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text("Delete Record?"), actions: [
      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCEL")),
      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("DELETE", style: TextStyle(color: Colors.red))),
    ]));
    if (confirm == true) {
      final res = await ApiService.deleteReturn(tenant.id, id);
      if (res['success'] == true) {
        _loadReturns(); 
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Delete Failed: ${res['message']}"), backgroundColor: Colors.red));
      }
    }
  }
}
