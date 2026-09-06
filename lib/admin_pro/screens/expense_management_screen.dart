import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:math' as math;
import 'dart:typed_data';
import '../admin_theme.dart';
import '../../services/api_service.dart';
import '../../services/tenant_service.dart';

class ExpenseManagementScreen extends StatefulWidget {
  final String mode;
  const ExpenseManagementScreen({super.key, required this.mode});

  @override
  State<ExpenseManagementScreen> createState() => _ExpenseManagementScreenState();
}

class _ExpenseManagementScreenState extends State<ExpenseManagementScreen> {
  String _searchQuery = "";
  bool _isLoading = false;
  
  // Data State
  Map<String, dynamic>? _dashboardData;
  List<Map<String, dynamic>> _allExpenses = [];
  List<Map<String, dynamic>> _vendors = [];
  List<Map<String, dynamic>> _recurring = [];
  
  // Entry Form State
  String _amount = "0";
  String _selectedCategory = "COGS"; 
  String _selectedPaymentMode = "Cash";
  Map<String, dynamic>? _selectedVendor;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  final TextEditingController _noteController = TextEditingController();
  
  // Receipt Upload
  XFile? _receiptFile;
  Uint8List? _receiptBytes;

  final List<Map<String, dynamic>> _expenseCategories = [
    {"id": "COGS", "label": "Inventory & Ingredients", "icon": Icons.inventory_2_outlined, "color": const Color(0xFF00B69B)},
    {"id": "PAY", "label": "Staff Payroll", "icon": Icons.badge_outlined, "color": const Color(0xFF5065F6)},
    {"id": "UTIL", "label": "Utilities (Elec/Water)", "icon": Icons.lightbulb_outline, "color": const Color(0xFF8833FF)},
    {"id": "RENT", "label": "Rent & Assets", "icon": Icons.home_work_outlined, "color": const Color(0xFFFF9500)},
    {"id": "MAINT", "label": "Maintenance & Repair", "icon": Icons.build_circle_outlined, "color": Colors.pinkAccent},
    {"id": "MARK", "label": "Marketing & Admin", "icon": Icons.campaign_outlined, "color": Colors.teal},
  ];

  final Map<String, dynamic> _categoriesIconMap = {
    "COGS": {"color": const Color(0xFF00B69B), "icon": Icons.inventory_2_outlined},
    "PAY": {"color": const Color(0xFF5065F6), "icon": Icons.badge_outlined},
    "UTIL": {"color": const Color(0xFF8833FF), "icon": Icons.lightbulb_outline},
    "RENT": {"color": const Color(0xFFFF9500), "icon": Icons.home_work_outlined},
    "MAINT": {"color": Colors.pinkAccent, "icon": Icons.build_circle_outlined},
    "MARK": {"color": Colors.teal, "icon": Icons.campaign_outlined},
  };

  final List<String> _paymentModes = ["Cash", "QR/Fonepay", "Card", "Bank Transfer"];

  @override
  void initState() {
    super.initState();
    _loadDataForMode();
  }

  @override
  void didUpdateWidget(covariant ExpenseManagementScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.mode != oldWidget.mode) {
      _loadDataForMode();
    }
  }

  Future<void> _loadDataForMode() async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return;

    setState(() => _isLoading = true);
    
    if (widget.mode == "Expense Statement") {
      _dashboardData = await ApiService.fetchExpenseDashboard(tenant.id, "Month");
      _allExpenses = await ApiService.fetchExpenseList(tenant.id) ?? [];
      _vendors = await ApiService.fetchVendors(tenant.id) ?? [];
    } else if (widget.mode == "Manage Expense") {
      _allExpenses = await ApiService.fetchExpenseList(tenant.id) ?? [];
    } else if (widget.mode == "Manage Expense Item") {
      _vendors = await ApiService.fetchVendors(tenant.id) ?? [];
    } else if (widget.mode == "Add Expense Item") {
      _recurring = await ApiService.fetchRecurringExpenses(tenant.id) ?? [];
    } else if (widget.mode == "Add Expense") {
      _vendors = await ApiService.fetchVendors(tenant.id) ?? [];
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _pickReceipt() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _receiptFile = image;
        _receiptBytes = bytes;
      });
    }
  }

  Future<void> _saveAdvancedExpense() async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null || _amount == "0") return;

    setState(() => _isLoading = true);

    String? receiptUrl;
    if (_receiptBytes != null && _receiptFile != null) {
      receiptUrl = await ApiService.uploadReceipt(_receiptBytes!, _receiptFile!.name);
    }
    
    final combinedDateTime = DateTime(
      _selectedDate.year, _selectedDate.month, _selectedDate.day,
      _selectedTime.hour, _selectedTime.minute,
    );
    
    final success = await ApiService.saveAdvancedExpense({
      "tenant_id": tenant.id,
      "category": _selectedCategory,
      "amount": double.parse(_amount),
      "payment_mode": _selectedPaymentMode,
      "vendor_id": _selectedVendor?['id'],
      "note": _noteController.text,
      "date": DateFormat('yyyy-MM-dd HH:mm:ss').format(combinedDateTime),
      "receipt_url": receiptUrl,
    });

    if (success && mounted) {
      setState(() {
        _amount = "0";
        _noteController.clear();
        _selectedVendor = null;
        _receiptFile = null;
        _receiptBytes = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Expense logged successfully!"), backgroundColor: Colors.green));
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    Widget currentView;
    if (widget.mode == "Add Expense") {
      currentView = _buildAddExpenseView();
    } else if (widget.mode == "Manage Expense") {
      currentView = _buildManageExpenseView();
    } else if (widget.mode == "Expense Statement") {
      currentView = _buildStatementDashboard();
    } else if (widget.mode == "Manage Expense Item") {
      currentView = _buildVendorManagementView();
    } else if (widget.mode == "Add Expense Item") {
      currentView = _buildRecurringExpenseView();
    } else {
      currentView = const Center(child: Text("Invalid mode selected."));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : currentView,
    );
  }

  // --- 1. ADD EXPENSE (Interactive Dial & Keypad) ---

  Widget _buildAddExpenseView() {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 40),
          _buildHeaderTitle("Log New Transaction"),
          const SizedBox(height: 40),
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 1, child: _buildInteractiveDialColumn()),
                  const SizedBox(width: 48),
                  Expanded(flex: 1, child: _buildTransactionFormColumn()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveDialColumn() {
    return Column(
      children: [
        SizedBox(
          height: 400, width: 400,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("AMOUNT", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  Text("NPR $_amount", style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Color(0xFF202224))),
                  Text(_selectedCategory, style: const TextStyle(fontSize: 10, color: Color(0xFF00B69B), fontWeight: FontWeight.bold, letterSpacing: 1)),
                ],
              ),
              ..._expenseCategories.asMap().entries.map((entry) {
                 int idx = entry.key;
                 var cat = entry.value;
                 double angle = (idx * (360 / _expenseCategories.length) - 90) * math.pi / 180;
                 bool isSelected = _selectedCategory == cat['id'];
                 return Transform.translate(
                   offset: Offset(math.cos(angle) * 150, math.sin(angle) * 150),
                   child: GestureDetector(
                     onTap: () => setState(() => _selectedCategory = cat['id']),
                     child: Column(
                       mainAxisSize: MainAxisSize.min,
                       children: [
                         Container(
                           height: 64, width: 64,
                           decoration: BoxDecoration(
                             color: isSelected ? cat['color'] : Colors.white,
                             shape: BoxShape.circle,
                             boxShadow: [BoxShadow(color: isSelected ? cat['color'].withValues(alpha: 0.4) : Colors.black12, blurRadius: 15)],
                             border: Border.all(color: isSelected ? cat['color'] : Colors.transparent, width: 2),
                           ),
                           child: Icon(cat['icon'], size: 28, color: isSelected ? Colors.white : Colors.grey[400]),
                         ),
                         const SizedBox(height: 8),
                         Text(cat['id'], style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isSelected ? cat['color'] : Colors.grey)),
                       ],
                     ),
                   ),
                 );
              }),
            ],
          ),
        ),
        const SizedBox(height: 32),
        const Text("Tap a category icon to switch", style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildTransactionFormColumn() {
    return Column(
      children: [
        _buildFormDropdown("Payment Mode", _selectedPaymentMode, _paymentModes, (v) => setState(() => _selectedPaymentMode = v!)),
        const SizedBox(height: 20),
        _buildEntryRow("Vendor/Supplier", _selectedVendor?['name'] ?? "Select Supplier", Icons.storefront_outlined, onTap: _showVendorPicker),
        const SizedBox(height: 20),
        _buildEntryRow("Transaction Date", DateFormat('d MMMM, y').format(_selectedDate), Icons.calendar_today_outlined, onTap: () async {
           final d = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2020), lastDate: DateTime.now());
           if (d != null) setState(() => _selectedDate = d);
        }),
        const SizedBox(height: 20),
        _buildEntryRow("Transaction Time", _selectedTime.format(context), Icons.access_time_outlined, onTap: () async {
           final t = await showTimePicker(context: context, initialTime: _selectedTime);
           if (t != null) setState(() => _selectedTime = t);
        }),
        const SizedBox(height: 20),
        _buildEntryRow("Attach Receipt", _receiptFile != null ? "Image Attached" : "Tap to open camera/gallery", Icons.camera_alt_outlined, onTap: _pickReceipt),
        const SizedBox(height: 20),
        _buildTextField("Notes / Remarks", _noteController, hint: "Enter description..."),
        const SizedBox(height: 32),
        _buildCustomKeypad(),
        const SizedBox(height: 40),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveAdvancedExpense,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF5C00), minimumSize: const Size(double.infinity, 60), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
          child: _isLoading 
            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text("CONFIRM NPR $_amount", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        const SizedBox(height: 60),
      ],
    );
  }

  // --- 2. MANAGE EXPENSE (Premium Data Table) ---

  Widget _buildManageExpenseView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(40, 40, 40, 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Transaction Audit", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF4C49ED))),
              _buildTopActionToolbar(),
            ],
          ),
        ),
        _buildSearchAndFilterBar(),
        const SizedBox(height: 24),
        Expanded(child: _buildProfessionalTable()),
        _buildPaginationFooter(),
      ],
    );
  }

  Widget _buildTopActionToolbar() {
    return Row(
      children: [
        _buildCircleActionBtn(Icons.add, Colors.green, _showQuickAddExpenseDialog),
        const SizedBox(width: 12),
        _buildCircleActionBtn(Icons.refresh, Colors.blue, _loadDataForMode),
      ],
    );
  }

  Widget _buildCircleActionBtn(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: CircleAvatar(
        radius: 20,
        backgroundColor: color.withValues(alpha: 0.1),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Widget _buildSearchAndFilterBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: AdminTheme.softShadow),
              child: TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: const InputDecoration(hintText: "Search transactions...", prefixIcon: Icon(Icons.search, size: 20), border: InputBorder.none),
              ),
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildProfessionalTable() {
    final filtered = _allExpenses.where((e) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return (e['category']?.toString().toLowerCase().contains(q) ?? false) ||
             (e['note']?.toString().toLowerCase().contains(q) ?? false);
    }).toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: AdminTheme.softShadow),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: const BoxDecoration(color: Color(0xFF4C49ED), borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            child: const Row(
              children: [
                SizedBox(width: 40, child: Icon(Icons.check_box_outline_blank, color: Colors.white70, size: 20)),
                Expanded(flex: 3, child: Text("EXPENSE CATEGORY", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1))),
                Expanded(flex: 2, child: Text("METHOD", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1))),
                Expanded(flex: 2, child: Text("DATE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1))),
                Expanded(flex: 2, child: Text("AMOUNT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1))),
                SizedBox(width: 100, child: Text("ACTIONS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1))),
              ],
            ),
          ),
          // Table Rows
          Expanded(
            child: ListView.separated(
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F4F9)),
              itemBuilder: (ctx, i) => _buildTableRow(filtered[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableRow(Map<String, dynamic> e) {
    final catId = e['category'];
    final color = _categoriesIconMap[catId]?['color'] ?? Colors.blue;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          const SizedBox(width: 40, child: Icon(Icons.check_box_outline_blank, color: Colors.black12, size: 20)),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text(e['category'] ?? 'Other', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10)),
                ),
                const SizedBox(width: 12),
                if (e['note'] != null) Flexible(child: Text(e['note'], style: const TextStyle(fontSize: 12, color: Colors.grey), overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
          Expanded(flex: 2, child: Text(e['payment_mode'] ?? 'Cash', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
          Expanded(flex: 2, child: Text(e['date'] ?? '', style: const TextStyle(fontSize: 13, color: Colors.grey))),
          Expanded(flex: 2, child: Text("NPR ${e['amount']}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold))),
          SizedBox(
            width: 100,
            child: Row(
              children: [
                IconButton(onPressed: () {}, icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blue)),
                IconButton(onPressed: () async {
                   bool? confirm = await _showConfirmDelete();
                   if (confirm == true) {
                      await ApiService.deleteExpenseV3(int.parse(e['id'].toString()));
                      _loadDataForMode();
                   }
                }, icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showQuickAddExpenseDialog() {
    final amountCtrl = TextEditingController();
    String category = "COGS";
    String payMode = "Cash";
    Map<String, dynamic>? vendor;
    DateTime date = DateTime.now();
    TimeOfDay time = TimeOfDay.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text("Quick Log Expense", style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField("Amount (NPR)", amountCtrl, hint: "0.00"),
                const SizedBox(height: 16),
                _buildFormDropdown("Category", category, _expenseCategories.map((c) => c['id'].toString()).toList(), (v) => setModalState(() => category = v!)),
                const SizedBox(height: 16),
                _buildFormDropdown("Payment Method", payMode, _paymentModes, (v) => setModalState(() => payMode = v!)),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Vendor / Supplier", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                  subtitle: Text(vendor?['name'] ?? "Select Supplier", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    // Reuse existing vendor picker logic if possible or just show a simple one here
                     final selected = await showModalBottomSheet<Map<String, dynamic>>(
                      context: context,
                      builder: (c) => Container(
                        padding: const EdgeInsets.all(24),
                        child: ListView.builder(
                          itemCount: _vendors.length,
                          itemBuilder: (cc, i) => ListTile(
                            title: Text(_vendors[i]['name'] ?? ''),
                            onTap: () => Navigator.pop(c, _vendors[i]),
                          ),
                        ),
                      ),
                    );
                    if (selected != null) setModalState(() => vendor = selected);
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final d = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime.now());
                          if (d != null) setModalState(() => date = d);
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("DATE", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                            Text(DateFormat('MMM dd, yyyy').format(date), style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final t = await showTimePicker(context: context, initialTime: time);
                          if (t != null) setModalState(() => time = t);
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("TIME", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                            Text(time.format(context), style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
            ElevatedButton(
              onPressed: () async {
                final amt = double.tryParse(amountCtrl.text);
                if (amt == null || amt <= 0) return;
                
                final combined = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                final tenant = TenantService().currentTenant.value;
                
                final success = await ApiService.saveAdvancedExpense({
                  "tenant_id": tenant?.id,
                  "category": category,
                  "amount": amt,
                  "payment_mode": payMode,
                  "vendor_id": vendor?['id'],
                  "date": DateFormat('yyyy-MM-dd HH:mm:ss').format(combined),
                });

                if (success && context.mounted) {
                  Navigator.pop(ctx);
                  _loadDataForMode();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Expense Logged!"), backgroundColor: Colors.green));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4C49ED)),
              child: const Text("LOG EXPENSE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaginationFooter() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("Showing 1 to ${_allExpenses.length} of ${_allExpenses.length} entries", style: const TextStyle(color: Colors.grey, fontSize: 12)),
          Row(
            children: [
              _buildPageBtn("<", false),
              const SizedBox(width: 8),
              _buildPageBtn("1", true),
              const SizedBox(width: 8),
              _buildPageBtn(">", false),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildPageBtn(String label, bool active) {
    return Container(
      width: 32, height: 32,
      decoration: BoxDecoration(color: active ? const Color(0xFF4C49ED) : Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.black12)),
      child: Center(child: Text(label, style: TextStyle(color: active ? Colors.white : Colors.black87, fontWeight: FontWeight.bold))),
    );
  }

  // --- 3. EXPENSE STATEMENT (Eduka Dashboard) ---

  Widget _buildStatementDashboard() {
    final stats = _dashboardData?['stats'];
    final double sales = double.tryParse(_dashboardData?['total_sales']?.toString() ?? '0') ?? 0;
    final double expenses = double.tryParse(stats?['total_expense']?.toString() ?? '0') ?? 0;

    double totalDues = 0;
    for (var v in _vendors) {
      totalDues += double.tryParse(v['due_amount']?.toString() ?? '0') ?? 0;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Financial Command Center", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
              ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.file_download_outlined), label: const Text("EXPORT REPORT"))
            ],
          ),
          const SizedBox(height: 32),
          
          Row(
            children: [
              Expanded(child: _buildEdukaCard("Net Profit", "NPR ${(sales - expenses).toStringAsFixed(0)}", "Sales - Expenses", "Real-time", const Color(0xFF00B69B), Icons.trending_up)),
              const SizedBox(width: 24),
              Expanded(child: _buildEdukaCard("Total Sales", "NPR ${sales.toStringAsFixed(0)}", "Gross Revenue", "Monthly", const Color(0xFF5065F6), Icons.shopping_bag)),
              const SizedBox(width: 24),
              Expanded(child: _buildEdukaCard("Expenses", "NPR ${expenses.toStringAsFixed(0)}", "Total Outflow", "Monthly", const Color(0xFF8833FF), Icons.receipt)),
              const SizedBox(width: 24),
              Expanded(child: _buildEdukaCard("Total Dues", "NPR ${totalDues.toStringAsFixed(0)}", "Supplier Outstanding", "Payable", const Color(0xFFFF9500), Icons.timer)),
            ],
          ),
          
          const SizedBox(height: 32),
          
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: _buildCategoryBreakoutCard()),
              const SizedBox(width: 24),
              Expanded(flex: 1, child: _buildQuickActionCard()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakoutCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32), boxShadow: AdminTheme.softShadow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Spending Distribution", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 40),
          SizedBox(
            height: 300,
            child: PieChart(
              PieChartData(
                sectionsSpace: 4,
                centerSpaceRadius: 70,
                sections: _getPieSections(),
              ),
            ),
          ),
          const SizedBox(height: 40),
          Wrap(
            spacing: 24,
            runSpacing: 16,
            children: (_dashboardData?['categories'] as List? ?? []).map<Widget>((c) {
               final color = _categoriesIconMap[c['id']]?['color'] ?? Colors.blue;
               return Row(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                   const SizedBox(width: 8),
                   Text(c['id'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                   const SizedBox(width: 8),
                   Text("NPR ${c['amount']}", style: const TextStyle(color: Colors.grey, fontSize: 13)),
                 ],
               );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32), boxShadow: AdminTheme.softShadow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Quick Actions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          _buildActionItem(Icons.group_add_outlined, "Manage Vendors", "Track supplier dues", () {}),
          _buildActionItem(Icons.autorenew_outlined, "Recurring Setup", "Automate monthly bills", () {}),
          _buildActionItem(Icons.verified_user_outlined, "Approval Queue", "Review manager entries", () {}),
          _buildActionItem(Icons.cloud_upload_outlined, "Bulk Upload", "Import from CSV", () {}),
        ],
      ),
    );
  }

  Widget _buildActionItem(IconData icon, String title, String sub, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(backgroundColor: const Color(0xFFF1F4F9), child: Icon(icon, size: 20, color: const Color(0xFF4C49ED))),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Text(sub, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: onTap,
    );
  }

  // --- 4. MANAGE VENDORS VIEW ---

  Widget _buildVendorManagementView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderTitle("Supplier Network"),
          const SizedBox(height: 32),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 350, mainAxisSpacing: 24, crossAxisSpacing: 24, childAspectRatio: 1.5),
            itemCount: _vendors.length + 1,
            itemBuilder: (ctx, i) {
              if (i == 0) return _buildAddVendorBtn();
              final v = _vendors[i-1];
              return _buildVendorCard(v);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAddVendorBtn() {
    return InkWell(
      onTap: _showAddVendorDialog,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white, 
          borderRadius: BorderRadius.circular(24), 
          border: Border.all(color: AdminTheme.royalBlue.withValues(alpha: 0.2), style: BorderStyle.solid),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_business_outlined, size: 48, color: Color(0xFF4C49ED)),
            SizedBox(height: 12),
            Text("Register New Supplier", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4C49ED))),
          ],
        ),
      ),
    );
  }

  void _showAddVendorDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text("New Supplier Profile", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTextField("Supplier Name", nameCtrl, hint: "e.g. Fresh Dairy"),
            const SizedBox(height: 16),
            _buildTextField("Contact Number", phoneCtrl, hint: "98XXXXXXXX"),
            const SizedBox(height: 16),
            _buildTextField("Email Address", emailCtrl, hint: "dairy@example.com"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter supplier name")));
                return;
              }
              
              debugPrint("DEBUG UI: Saving Vendor: $name");
              final tenant = TenantService().currentTenant.value;
              final success = await ApiService.addVendor({
                "tenant_id": tenant?.id,
                "name": name,
                "phone": phoneCtrl.text.trim(),
                "email": emailCtrl.text.trim(),
              });
              
              if (success && mounted) {
                Navigator.pop(context); 
                _loadDataForMode();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vendor Registered!"), backgroundColor: Colors.green));
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to save vendor. Check connection."), backgroundColor: Colors.red));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4C49ED),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("SAVE SUPPLIER", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildVendorCard(Map<String, dynamic> v) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: AdminTheme.softShadow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(backgroundColor: Colors.blue.withValues(alpha: 0.1), child: const Icon(Icons.storefront, color: Colors.blue, size: 20)),
              const SizedBox(width: 12),
              Expanded(child: Text(v['name'] ?? 'Vendor', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis)),
            ],
          ),
          const Spacer(),
          const Text("OUTSTANDING DUE", style: TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1)),
          Text("NPR ${v['due_amount'] ?? '0'}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.redAccent)),
        ],
      ),
    );
  }

  // --- 5. RECURRING EXPENSE VIEW (Premium Redesign) ---

  Widget _buildRecurringExpenseView() {
    double monthlyTotal = 0;
    int activeCount = 0;
    for (var r in _recurring) {
      if (r['is_active'] == 1) {
        activeCount++;
        double amt = double.tryParse(r['amount']?.toString() ?? '0') ?? 0;
        if (r['frequency'] == 'Monthly') {
          monthlyTotal += amt;
        } else if (r['frequency'] == 'Daily') {
          monthlyTotal += (amt * 30);
        } else if (r['frequency'] == 'Weekly') {
          monthlyTotal += (amt * 4);
        } else if (r['frequency'] == 'Yearly') {
          monthlyTotal += (amt / 12);
        }
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderTitle("Monthly Expense Planner"),
                  const Text("Plan and track your upcoming restaurant commitments for the next cycle.", style: TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _showAddRecurringDialog, 
                icon: const Icon(Icons.add_task), 
                label: const Text("ADD COMMITMENT"),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4C49ED), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              ),
            ],
          ),
          const SizedBox(height: 32),
          
          // STATS BAR
          Row(
            children: [
              Expanded(child: _buildEdukaCard("Monthly Outlook", "NPR ${monthlyTotal.toStringAsFixed(0)}", "Estimated Outflow", "100%", const Color(0xFF5065F6), Icons.calendar_month)),
              const SizedBox(width: 24),
              Expanded(child: _buildEdukaCard("Active Items", "$activeCount", "Payment Templates", "Safe", const Color(0xFF8833FF), Icons.checklist_rtl)),
              const SizedBox(width: 24),
              Expanded(child: _buildEdukaCard("Next Month Projection", "NPR ${monthlyTotal.toStringAsFixed(0)}", "Projected Total", "Target", const Color(0xFF00B69B), Icons.trending_up)),
            ],
          ),
          
          const SizedBox(height: 48),
          
          // CONTENT AREA
          if (_recurring.isEmpty) 
            Center(
              child: Column(
                children: [
                  const SizedBox(height: 60),
                  Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey[200]),
                  const SizedBox(height: 24),
                  const Text("No Automated Expenses Found", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const Text("Register monthly items like Rent, Wi-Fi or Salaries here.", style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          else GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 400, mainAxisSpacing: 24, crossAxisSpacing: 24, childAspectRatio: 1.4),
            itemCount: _recurring.length,
            itemBuilder: (ctx, i) => _buildRecurringPremiumCard(_recurring[i]),
          ),
        ],
      ),
    );
  }

  Widget _buildRecurringPremiumCard(Map<String, dynamic> r) {
    final catId = r['category'];
    final color = _categoriesIconMap[catId]?['color'] ?? Colors.blue;
    final icon = _categoriesIconMap[catId]?['icon'] ?? Icons.autorenew;
    final bool isActive = r['is_active'] == 1;
    
    // Calculate days remaining
    int daysRemaining = 0;
    if (r['next_due_date'] != null) {
      try {
        final dueDate = DateFormat('yyyy-MM-dd').parse(r['next_due_date']);
        daysRemaining = dueDate.difference(DateTime.now()).inDays;
      } catch (e) {
        debugPrint(e.toString());
      }
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(32), 
        boxShadow: AdminTheme.softShadow,
        border: Border.all(color: isActive ? Colors.transparent : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: color, size: 12),
                    const SizedBox(width: 6),
                    Text(catId ?? 'EXPENSE', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10)),
                  ],
                ),
              ),
              Switch(value: isActive, activeTrackColor: color, onChanged: (v) {}),
            ],
          ),
          const Spacer(),
          Text(r['title'] ?? 'Subscription', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: daysRemaining < 0 ? Colors.red.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  daysRemaining < 0 ? "OVERDUE" : "$daysRemaining DAYS LEFT",
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: daysRemaining < 0 ? Colors.red : Colors.green),
                ),
              ),
              const SizedBox(width: 12),
              const Text("•", style: TextStyle(color: Colors.grey)),
              const SizedBox(width: 12),
              Text(r['frequency']?.toString().toUpperCase() ?? 'MONTHLY', style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("PAYMENT TARGET", style: TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  Text("NPR ${r['amount']}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                ],
              ),
              InkWell(
                onTap: () {},
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: const Color(0xFF4C49ED).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Text("PAY NOW", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF4C49ED))),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- HELPERS (Global) ---

  Widget _buildHeaderTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF202224)));
  }

  void _showAddRecurringDialog() {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String category = "RENT";
    String freq = "Monthly";
    DateTime dueDate = DateTime.now().add(const Duration(days: 30));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text("Plan Monthly Commitment", style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField("Commitment Title", titleCtrl, hint: "e.g. Staff Salary (Chef)"),
                const SizedBox(height: 16),
                _buildFormDropdown("Category", category, _expenseCategories.map((c) => c['id'].toString()).toList(), (v) => setModalState(() => category = v!)),
                const SizedBox(height: 16),
                _buildTextField("Target Amount (NPR)", amountCtrl, hint: "0.00"),
                const SizedBox(height: 16),
                _buildFormDropdown("Frequency", freq, ["Daily", "Weekly", "Monthly", "Yearly"], (v) => setModalState(() => freq = v!)),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final d = await showDatePicker(context: context, initialDate: dueDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                    if (d != null) setModalState(() => dueDate = d);
                  },
                  child: _buildEntryRow("Next Due Date", DateFormat('MMM dd, yyyy').format(dueDate), Icons.calendar_month),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx), 
              child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () async {
                final title = titleCtrl.text.trim();
                final amountStr = amountCtrl.text.trim();
                
                if (title.isEmpty || amountStr.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all required fields")));
                  return;
                }

                final amount = double.tryParse(amountStr);
                if (amount == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid amount format")));
                  return;
                }

                debugPrint("DEBUG UI: Planning Expense: $title");
                final tenant = TenantService().currentTenant.value;
                final success = await ApiService.saveRecurringExpense({
                  "tenant_id": tenant?.id,
                  "title": title,
                  "category": category,
                  "amount": amount,
                  "frequency": freq,
                  "next_due_date": DateFormat('yyyy-MM-dd').format(dueDate),
                });
                
                if (success && context.mounted) {
                  Navigator.pop(ctx);
                  _loadDataForMode();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Commitment Planned!"), backgroundColor: Colors.green));
                } else if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to save. Check server."), backgroundColor: Colors.red));
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4C49ED),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("SAVE PLAN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEdukaCard(String title, String mainVal, String subLabel, String subVal, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color, 
        borderRadius: BorderRadius.circular(24), 
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10))]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(mainVal, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                ],
              ),
              Icon(icon, color: Colors.white24, size: 48),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(subLabel, style: const TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold)),
              Text(subVal, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Future<bool?> _showConfirmDelete() async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Record?"),
        content: const Text("This action cannot be undone. Are you sure?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCEL")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("DELETE", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  // --- RESTORED HELPERS ---

  Widget _buildFormDropdown(String label, String value, List<String> items, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.black12)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEntryRow(String label, String val, IconData icon, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.black12)),
            child: Row(
              children: [
                Icon(icon, size: 18, color: const Color(0xFF5065F6)),
                const SizedBox(width: 16),
                Text(val, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                const Spacer(),
                const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showVendorPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Text("Select Supplier / Vendor", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Expanded(
              child: _vendors.isEmpty 
                ? const Center(child: Text("No vendors registered."))
                : ListView.builder(
                    itemCount: _vendors.length,
                    itemBuilder: (c, i) => ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      leading: const CircleAvatar(backgroundColor: Color(0xFFF3F5F9), child: Icon(Icons.storefront_outlined, color: Color(0xFF5065F6))),
                      title: Text(_vendors[i]['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("Outstanding: NPR ${_vendors[i]['due_amount'] ?? '0'}"),
                      onTap: () {
                        setState(() => _selectedVendor = _vendors[i]);
                        Navigator.pop(ctx);
                      },
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController ctrl, {String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
        const SizedBox(height: 10),
        TextField(
          controller: ctrl,
          decoration: InputDecoration(
            hintText: hint,
            filled: true, fillColor: Colors.white,
            contentPadding: const EdgeInsets.all(20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Colors.black12)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Colors.black12)),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomKeypad() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32), border: Border.all(color: Colors.black12)),
      child: Column(
        children: [
          _buildKeypadRow(["1", "2", "3"]),
          _buildKeypadRow(["4", "5", "6"]),
          _buildKeypadRow(["7", "8", "9"]),
          _buildKeypadRow([".", "0", "DEL"]),
        ],
      ),
    );
  }

  Widget _buildKeypadRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((k) {
        return Expanded(
          child: TextButton(
            onPressed: () {
              setState(() {
                if (k == "DEL") {
                  if (_amount.length > 1) {
                    _amount = _amount.substring(0, _amount.length - 1);
                  } else {
                    _amount = "0";
                  }
                } else {
                  if (_amount == "0") {
                    _amount = k;
                  } else {
                    _amount += k;
                  }
                }
              });
            },
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18)),
            child: k == "DEL" 
              ? const Icon(Icons.backspace_outlined, color: Color(0xFF202224), size: 22)
              : Text(k, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF202224))),
          ),
        );
      }).toList(),
    );
  }

  List<PieChartSectionData> _getPieSections() {
    final List cats = _dashboardData?['categories'] ?? [];
    if (cats.isEmpty) {
       return [PieChartSectionData(value: 100, color: Colors.grey[100], title: "", radius: 40)];
    }
    return cats.map((c) {
      final String catId = c['id'].toString();
      final color = _categoriesIconMap[catId]?['color'] ?? Colors.blue;
      return PieChartSectionData(
        value: double.tryParse(c['amount'].toString()) ?? 1,
        color: color, radius: 40, title: "",
      );
    }).toList();
  }
}
