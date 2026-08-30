import 'package:flutter/material.dart';
import '../services/tenant_service.dart';
import '../services/api_service.dart';
import 'admin_login_screen.dart';
import 'admin_theme.dart';
import 'screens/dashboard_screen.dart';

import 'screens/placeholder_screen.dart';
import 'screens/pos_invoice_screen.dart';
import 'screens/order_management_screen.dart';
import 'screens/production_dashboard_screen.dart';
import 'screens/admin_settings_screen.dart';
import 'screens/purchase_management_screen.dart';
import 'screens/supplier_management_screen.dart';
import 'screens/ingredient_stock_screen.dart';
import 'screens/category_management_screen.dart';
import 'screens/food_catalog_screen.dart';
import 'screens/addons_management_screen.dart';
import 'screens/reservation_management_screen.dart';
import 'screens/production_management_screen.dart';
import 'screens/hrm_management_screen.dart';
import 'screens/report_management_screen.dart';
import 'screens/table_configuration_screen.dart';
import 'screens/system_configuration_screen.dart';
import 'screens/expense_management_screen.dart';
import 'screens/hr_policy_screen.dart';
import 'screens/department_management_screen.dart';
import 'screens/support_ticket_screen.dart';
import 'screens/subscription_status_screen.dart';

class AdminHub extends StatefulWidget {
  const AdminHub({super.key});

  @override
  State<AdminHub> createState() => _AdminHubState();
}

class _AdminHubState extends State<AdminHub> {
  int _selectedIndex = 0;
  String _currentTitle = "Dashboard";
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  int _alertCount = 0;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _startAlertPolling();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  void _startAlertPolling() async {
    while (!_isDisposed) {
      final tenant = TenantService().currentTenant.value;
      if (tenant != null) {
        final count = await ApiService.fetchUnseenStockAlertCount(tenant.id);
        if (mounted) setState(() => _alertCount = count);
      }
      await Future.delayed(const Duration(seconds: 15));
    }
  }

  final List<Widget> _screens = [
    const DashboardScreen(), // 0
    const POSInvoiceScreen(), // 1
    const OrderManagementScreen(initialStatus: "All"), // 2
    const OrderManagementScreen(initialStatus: "Pending"), // 3
    const OrderManagementScreen(initialStatus: "Complete"), // 4
    const OrderManagementScreen(initialStatus: "Cancel"), // 5
    const ProductionDashboardScreen(title: "Kitchen Dashboard"), // 6
    const ProductionDashboardScreen(title: "Counter Dashboard"), // 7
    const AdminPlaceholderScreen(title: "Counter List"), // 8
    const AdminSettingsScreen(section: "POS Setting"), // 9
    const AdminSettingsScreen(section: "Sound Setting"), // 10
    const PurchaseManagementScreen(mode: "Purchase Item"), // 11
    const PurchaseManagementScreen(mode: "Add Purchase"), // 12
    const PurchaseManagementScreen(mode: "Purchase Return"), // 13
    const PurchaseManagementScreen(mode: "Return Invoice"), // 14
    const SupplierManagementScreen(mode: "Supplier Manage"), // 15
    const SupplierManagementScreen(mode: "Supplier Ledger"), // 16
    const IngredientStockScreen(), // 17
    const ReservationManagementScreen(mode: "Reservation"), // 18
    const ReservationManagementScreen(mode: "Add Booking"), // 19
    const ReservationManagementScreen(mode: "Unavailable Day"), // 20
    const ReservationManagementScreen(mode: "Reservation Setting"), // 21
    const CategoryManagementScreen(mode: "Add Category"), // 22
    const CategoryManagementScreen(mode: "Category List"), // 23
    const FoodCatalogScreen(mode: "Add Food"), // 24
    const FoodCatalogScreen(mode: "Food List"), // 25
    const FoodCatalogScreen(mode: "Add Group Item"), // 26
    const FoodCatalogScreen(mode: "Food Variant"), // 27
    const FoodCatalogScreen(mode: "Food Availability"), // 28
    const FoodCatalogScreen(mode: "Menu Type"), // 29
    const AddonsManagementScreen(mode: "Add Add-ons"), // 30
    const AddonsManagementScreen(mode: "Add-ons List"), // 31
    const AddonsManagementScreen(mode: "Add-ons Assign List"), // 32
    const ProductionManagementScreen(mode: "Set Production Unit"), // 33
    const ProductionManagementScreen(mode: "Production Set List"), // 34
    const ProductionManagementScreen(mode: "Add Production"), // 35
    const ProductionManagementScreen(mode: "Production Setting"), // 36
    const HRMManagementScreen(mode: "Designation"), // 37
    const HRMManagementScreen(mode: "Add Employee"), // 38
    const HRMManagementScreen(mode: "Manage Employee"), // 39
    const HRMManagementScreen(mode: "Manage Employee Salary"), // 40
    const HRMManagementScreen(mode: "Attendance Form"), // 41
    const HRMManagementScreen(mode: "Attendance Report"), // 42
    const ExpenseManagementScreen(mode: "Add Expense Item"), // 43
    const ExpenseManagementScreen(mode: "Manage Expense Item"), // 44
    const ExpenseManagementScreen(mode: "Add Expense"), // 45
    const ExpenseManagementScreen(mode: "Manage Expense"), // 46
    const ExpenseManagementScreen(mode: "Expense Statement"), // 47
    const HRPolicyScreen(mode: "New Award"), // 48
    const HRMManagementScreen(mode: "Add New Candidate"), // 49
    const HRMManagementScreen(mode: "Manage Candidate"), // 50
    const HRMManagementScreen(mode: "Candidate Shortlist"), // 51
    const HRMManagementScreen(mode: "Interview"), // 52
    const HRMManagementScreen(mode: "Candidate Selection"), // 53
    const DepartmentManagementScreen(mode: "Department List"), // 54
    const DepartmentManagementScreen(mode: "Add Division"), // 55
    const DepartmentManagementScreen(mode: "Manage Division"), // 56
    const HRPolicyScreen(mode: "Weekly Holiday"), // 57
    const HRPolicyScreen(mode: "Holiday List"), // 58
    const HRPolicyScreen(mode: "Add Leave Type"), // 59
    const HRPolicyScreen(mode: "Leave Application"), // 60
    const HRPolicyScreen(mode: "Grant Loan"), // 61
    const HRPolicyScreen(mode: "Loan Installment"), // 62
    const HRPolicyScreen(mode: "Loan Report"), // 63
    const HRMManagementScreen(mode: "Salary Type Setup"), // 64
    const HRMManagementScreen(mode: "Salary Setup"), // 65
    const HRMManagementScreen(mode: "Salary Generate"), // 66
    const ReportManagementScreen(mode: "Purchase Report"), // 67
    const ReportManagementScreen(mode: "Stock Report (Food Items)"), // 68
    const ReportManagementScreen(mode: "Stock Report (Kitchen)"), // 69
    const ReportManagementScreen(mode: "Sales Report"), // 70
    const ReportManagementScreen(mode: "Items Sales Report"), // 71
    const ReportManagementScreen(mode: "Service Charge Report"), // 72
    const ReportManagementScreen(mode: "Waiters Sales Report"), // 73
    const ReportManagementScreen(mode: "Kitchen Sales Report"), // 74
    const ReportManagementScreen(mode: "Delivery Type Sales Report"), // 75
    const ReportManagementScreen(mode: "Sale Report Cashier"), // 76
    const ReportManagementScreen(mode: "Cash Register Report"), // 77
    const ReportManagementScreen(mode: "Sale Report Filtering"), // 78
    const ReportManagementScreen(mode: "Sale By Date"), // 79
    const ReportManagementScreen(mode: "Commission"), // 80
    const ReportManagementScreen(mode: "Sale By Table"), // 81
    const SystemConfigurationScreen(mode: "Payment Method List"), // 82
    const SystemConfigurationScreen(mode: "Payment Setup"), // 83
    const SystemConfigurationScreen(mode: "Shipping Method Setting"), // 84
    const TableConfigurationScreen(mode: "Table List"), // 85
    const TableConfigurationScreen(mode: "Table Setting"), // 86
    const SystemConfigurationScreen(mode: "Customer List"), // 87
    const SystemConfigurationScreen(mode: "Customer Type List"), // 88
    const SystemConfigurationScreen(mode: "Third-Party Customers"), // 89
    const SystemConfigurationScreen(mode: "Card Terminal List"), // 90
    const SystemConfigurationScreen(mode: "Kitchen List"), // 91
    const SystemConfigurationScreen(mode: "Kitchen Assign"), // 92
    const SystemConfigurationScreen(mode: "Kitchen Dashboard Setting"), // 93
    const SystemConfigurationScreen(mode: "Unit Measurement List"), // 94
    const SystemConfigurationScreen(mode: "Ingredient List"), // 95
    const SystemConfigurationScreen(mode: "SMS Configuration"), // 96
    const SystemConfigurationScreen(mode: "SMS Template"), // 97
    const SystemConfigurationScreen(mode: "Bank List"), // 98
    const SystemConfigurationScreen(mode: "Bank Transaction"), // 99
    const SystemConfigurationScreen(mode: "Language"), // 100
    const SystemConfigurationScreen(mode: "Application Setting"), // 101
    const SystemConfigurationScreen(mode: "App Setting"), // 102
    const SystemConfigurationScreen(mode: "Factory Reset"), // 103
    const SystemConfigurationScreen(mode: "Currency"), // 104
    const SystemConfigurationScreen(mode: "Country"), // 105
    const SystemConfigurationScreen(mode: "State"), // 106
    const SystemConfigurationScreen(mode: "City"), // 107
    const SystemConfigurationScreen(mode: "Commission"), // 108
    const HRMManagementScreen(mode: "User Management"), // 109
    const AdminSettingsScreen(section: "Modules"), // 110
    const AdminPlaceholderScreen(title: "Themes"), // 111
    const SupportTicketScreen(), // 112
    const SubscriptionStatusScreen(), // 113
  ];

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AdminTheme.lightTheme,
      child: Scaffold(
            key: _scaffoldKey,
            appBar: AppBar(
              titleSpacing: 0,
              leading: IconButton(
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                icon: const Icon(Icons.menu_rounded, color: AdminTheme.royalBlue, size: 28),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_currentTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const Text("Admin Console", style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
                ],
              ),
              actions: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    const CircleAvatar(
                      radius: 16,
                      backgroundColor: AdminTheme.darkNavy,
                      child: Icon(Icons.admin_panel_settings, color: Colors.white, size: 18),
                    ),
                    if (_alertCount > 0)
                      Positioned(
                        right: 0, top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                          child: Text("$_alertCount", style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 24),
              ],
            ),
            drawer: _buildAdminDrawer(),
            body: IndexedStack(
          index: _selectedIndex,
          children: _screens,
        ),
      ),
    );
  }

  Widget _buildAdminDrawer() {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.8,
      backgroundColor: const Color(0xFF1E1E2C),
      child: Column(
        children: [
          _buildDrawerHeader(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 20),
              children: [
                _buildDrawerItem(0, Icons.dashboard_outlined, "Dashboard"),

                _buildExpandableDrawerItem(
                  icon: Icons.shopping_cart_outlined,
                  title: "Manage Order",
                  children: [
                    _buildSubDrawerItem(1, "POS Invoice"),
                    _buildSubDrawerItem(2, "Order List"),
                    _buildSubDrawerItem(3, "Pending Order"),
                    _buildSubDrawerItem(4, "Complete Order"),
                    _buildSubDrawerItem(5, "Cancel Order"),
                    _buildSubDrawerItem(6, "Kitchen Dashboard"),
                    _buildSubDrawerItem(7, "Counter Dashboard"),
                    _buildSubDrawerItem(8, "Counter List"),
                    _buildSubDrawerItem(9, "POS Setting"),
                    _buildSubDrawerItem(10, "Sound Setting"),
                  ],
                ),

                _buildExpandableDrawerItem(
                  icon: Icons.add_shopping_cart_rounded,
                  title: "Purchase Manage",
                  alertCount: _alertCount,
                  children: [
                    _buildSubDrawerItem(11, "Purchase Item"),
                    _buildSubDrawerItem(12, "Add Purchase"),
                    _buildSubDrawerItem(13, "Purchase Return"),
                    _buildSubDrawerItem(14, "Return Invoice"),
                    _buildSubDrawerItem(15, "Supplier Manage"),
                    _buildSubDrawerItem(16, "Supplier Ledger"),
                    _buildSubDrawerItem(17, "Stock Out Ingredients", hasBadge: _alertCount > 0),
                  ],
                ),

                _buildExpandableDrawerItem(
                  icon: Icons.event_available_outlined,
                  title: "Reservation",
                  children: [
                    _buildSubDrawerItem(18, "Reservation"),
                    _buildSubDrawerItem(19, "Add Booking"),
                    _buildSubDrawerItem(20, "Unavailable Day"),
                    _buildSubDrawerItem(21, "Reservation Setting"),
                  ],
                ),

                _buildExpandableDrawerItem(
                  icon: Icons.restaurant_menu,
                  title: "Food Management",
                  children: [
                    _buildNestedExpandableItem(
                      title: "Manage Category",
                      children: [
                        _buildSubDrawerItem(22, "Add Category", isDoubleNested: true),
                        _buildSubDrawerItem(23, "Category List", isDoubleNested: true),
                      ],
                    ),
                    _buildNestedExpandableItem(
                      title: "Manage Food",
                      children: [
                        _buildSubDrawerItem(24, "Add Food", isDoubleNested: true),
                        _buildSubDrawerItem(25, "Food List", isDoubleNested: true),
                        _buildSubDrawerItem(26, "Add Group Item", isDoubleNested: true),
                        _buildSubDrawerItem(27, "Food Variant", isDoubleNested: true),
                        _buildSubDrawerItem(28, "Food Availability", isDoubleNested: true),
                        _buildSubDrawerItem(29, "Menu Type", isDoubleNested: true),
                      ],
                    ),
                    _buildNestedExpandableItem(
                      title: "Manage Add-ons",
                      children: [
                        _buildSubDrawerItem(30, "Add Add-ons", isDoubleNested: true),
                        _buildSubDrawerItem(31, "Add-ons List", isDoubleNested: true),
                        _buildSubDrawerItem(32, "Add-ons Assign List", isDoubleNested: true),
                      ],
                    ),
                  ],
                ),

                _buildExpandableDrawerItem(
                  icon: Icons.outdoor_grill_outlined,
                  title: "Production",
                  children: [
                    _buildSubDrawerItem(33, "Set Production Unit"),
                    _buildSubDrawerItem(34, "Production Set List"),
                    _buildSubDrawerItem(35, "Add Production"),
                    _buildSubDrawerItem(36, "Production Setting"),
                  ],
                ),

                _buildExpandableDrawerItem(
                  icon: Icons.people_outline,
                  title: "Human Resource",
                  children: [
                    _buildNestedExpandableItem(
                      title: "HRM",
                      children: [
                        _buildSubDrawerItem(37, "Designation", isDoubleNested: true),
                        _buildSubDrawerItem(38, "Add Employee", isDoubleNested: true),
                        _buildSubDrawerItem(39, "Manage Employee", isDoubleNested: true),
                        _buildSubDrawerItem(40, "Manage Employee Salary", isDoubleNested: true),
                      ],
                    ),
                    _buildNestedExpandableItem(
                      title: "Attendance",
                      children: [
                        _buildSubDrawerItem(41, "Attendance Form", isDoubleNested: true),
                        _buildSubDrawerItem(42, "Attendance Report", isDoubleNested: true),
                      ],
                    ),
                    _buildNestedExpandableItem(
                      title: "Expense",
                      children: [
                        _buildSubDrawerItem(43, "Add Expense Item", isDoubleNested: true),
                        _buildSubDrawerItem(44, "Manage Expense Item", isDoubleNested: true),
                        _buildSubDrawerItem(45, "Add Expense", isDoubleNested: true),
                        _buildSubDrawerItem(46, "Manage Expense", isDoubleNested: true),
                        _buildSubDrawerItem(47, "Expense Statement", isDoubleNested: true),
                      ],
                    ),
                    _buildNestedExpandableItem(
                      title: "Award",
                      children: [
                        _buildSubDrawerItem(48, "New Award", isDoubleNested: true),
                      ],
                    ),
                    _buildNestedExpandableItem(
                      title: "Recruitment",
                      children: [
                        _buildSubDrawerItem(49, "Add New Candidate", isDoubleNested: true),
                        _buildSubDrawerItem(50, "Manage Candidate", isDoubleNested: true),
                        _buildSubDrawerItem(51, "Candidate Shortlist", isDoubleNested: true),
                        _buildSubDrawerItem(52, "Interview", isDoubleNested: true),
                        _buildSubDrawerItem(53, "Candidate Selection", isDoubleNested: true),
                      ],
                    ),
                    _buildNestedExpandableItem(
                      title: "Department",
                      children: [
                        _buildSubDrawerItem(54, "Department", isDoubleNested: true),
                        _buildSubDrawerItem(55, "Add Division", isDoubleNested: true),
                        _buildSubDrawerItem(56, "Manage Division", isDoubleNested: true),
                      ],
                    ),
                    _buildNestedExpandableItem(
                      title: "Leave",
                      children: [
                        _buildSubDrawerItem(57, "Weekly Holiday", isDoubleNested: true),
                        _buildSubDrawerItem(58, "Holiday", isDoubleNested: true),
                        _buildSubDrawerItem(59, "Add Leave Type", isDoubleNested: true),
                        _buildSubDrawerItem(60, "Leave Application", isDoubleNested: true),
                      ],
                    ),
                    _buildNestedExpandableItem(
                      title: "Loan",
                      children: [
                        _buildSubDrawerItem(61, "Grant Loan", isDoubleNested: true),
                        _buildSubDrawerItem(62, "Loan Installment", isDoubleNested: true),
                        _buildSubDrawerItem(63, "Loan Report", isDoubleNested: true),
                      ],
                    ),
                    _buildNestedExpandableItem(
                      title: "Payroll",
                      children: [
                        _buildSubDrawerItem(64, "Salary Type Setup", isDoubleNested: true),
                        _buildSubDrawerItem(65, "Salary Setup", isDoubleNested: true),
                        _buildSubDrawerItem(66, "Salary Generate", isDoubleNested: true),
                      ],
                    ),
                  ],
                ),

                _buildExpandableDrawerItem(
                  icon: Icons.bar_chart_outlined,
                  title: "Report",
                  children: [
                    _buildSubDrawerItem(67, "Purchase Report"),
                    _buildSubDrawerItem(68, "Stock Report (Food Items)"),
                    _buildSubDrawerItem(69, "Stock Report (Kitchen)"),
                    _buildNestedExpandableItem(
                      title: "Sales Report",
                      children: [
                        _buildSubDrawerItem(70, "Sales Report", isDoubleNested: true),
                        _buildSubDrawerItem(71, "Items Sales Report", isDoubleNested: true),
                        _buildSubDrawerItem(72, "Service Charge Report", isDoubleNested: true),
                        _buildSubDrawerItem(73, "Waiters Sales Report", isDoubleNested: true),
                        _buildSubDrawerItem(74, "Kitchen Sales Report", isDoubleNested: true),
                        _buildSubDrawerItem(75, "Delivery Type Sales Report", isDoubleNested: true),
                        _buildSubDrawerItem(76, "Sale Report Cashier", isDoubleNested: true),
                      ],
                    ),
                    _buildSubDrawerItem(77, "Cash Register Report"),
                    _buildSubDrawerItem(78, "Sale Report Filtering"),
                    _buildSubDrawerItem(79, "Sale By Date"),
                    _buildSubDrawerItem(80, "Commission"),
                    _buildSubDrawerItem(81, "Sale By Table"),
                  ],
                ),

                _buildExpandableDrawerItem(
                  icon: Icons.settings_outlined,
                  title: "Setting",
                  children: [
                    _buildNestedExpandableItem(
                      title: "Payment Method Setting",
                      children: [
                        _buildSubDrawerItem(82, "Payment Method List", isDoubleNested: true),
                        _buildSubDrawerItem(83, "Payment Setup", isDoubleNested: true),
                        _buildSubDrawerItem(84, "Shipping Method Setting", isDoubleNested: true),
                      ],
                    ),
                    _buildNestedExpandableItem(
                      title: "Manage Table",
                      children: [
                        _buildSubDrawerItem(85, "Table List", isDoubleNested: true),
                        _buildSubDrawerItem(86, "Table Setting", isDoubleNested: true),
                      ],
                    ),
                    _buildNestedExpandableItem(
                      title: "Customer Type",
                      children: [
                        _buildSubDrawerItem(87, "Customer List", isDoubleNested: true),
                        _buildSubDrawerItem(88, "Customer Type List", isDoubleNested: true),
                        _buildSubDrawerItem(89, "Third-Party Customers", isDoubleNested: true),
                        _buildSubDrawerItem(90, "Card Terminal List", isDoubleNested: true),
                      ],
                    ),
                    _buildNestedExpandableItem(
                      title: "kitchen Setting",
                      children: [
                        _buildSubDrawerItem(91, "Kitchen List", isDoubleNested: true),
                        _buildSubDrawerItem(92, "Kitchen Assign", isDoubleNested: true),
                        _buildSubDrawerItem(93, "Kitchen Dashboard Setting", isDoubleNested: true),
                      ],
                    ),
                    _buildNestedExpandableItem(
                      title: "Unit Measurement",
                      children: [
                        _buildSubDrawerItem(94, "Unit Measurement List", isDoubleNested: true),
                        _buildSubDrawerItem(95, "Ingredient List", isDoubleNested: true),
                      ],
                    ),
                    _buildNestedExpandableItem(
                      title: "SMS Setting",
                      children: [
                        _buildSubDrawerItem(96, "SMS Configuration", isDoubleNested: true),
                        _buildSubDrawerItem(97, "SMS Template", isDoubleNested: true),
                      ],
                    ),
                    _buildNestedExpandableItem(
                      title: "Bank",
                      children: [
                        _buildSubDrawerItem(98, "Bank List", isDoubleNested: true),
                        _buildSubDrawerItem(99, "Bank Transaction", isDoubleNested: true),
                      ],
                    ),
                    _buildSubDrawerItem(100, "Language"),
                    _buildSubDrawerItem(101, "Application Setting"),
                    _buildSubDrawerItem(102, "App Setting"),
                    _buildSubDrawerItem(103, "Factory Reset"),
                    _buildSubDrawerItem(104, "Currency"),
                    _buildSubDrawerItem(105, "Country"),
                    _buildSubDrawerItem(106, "State"),
                    _buildSubDrawerItem(107, "City"),
                    _buildSubDrawerItem(108, "Commission"),
                  ],
                ),

                const Divider(color: Colors.white10, height: 40),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Text("ACCESS", style: TextStyle(color: Colors.white30, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ),
                _buildDrawerItem(113, Icons.card_membership_rounded, "Subscription Status"),
                _buildDrawerItem(112, Icons.help_outline_rounded, "Support & Help"),
                _buildDrawerItem(109, Icons.security_outlined, "User Management"),
                _buildDrawerItem(110, Icons.grid_view_rounded, "Modules", hasAddon: true),
                _buildDrawerItem(111, Icons.palette_outlined, "Themes"),
                
                const SizedBox(height: 20),
                const Center(
                  child: Text(
                    "SYSTEM VERSION: 2.0 (QR FIXED)",
                    style: TextStyle(color: Colors.white24, fontSize: 8, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
      color: const Color(0xFF161621),
      child: Row(
        children: [
          const CircleAvatar(backgroundColor: AdminTheme.royalBlue, radius: 4),
          const SizedBox(width: 12),
          const Expanded(
            child: Text("Chiyalaa Admin", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white30, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(int index, IconData icon, String title, {bool hasAddon = false}) {
    bool isSelected = _selectedIndex == index;
    return ListTile(
      onTap: () {
        setState(() {
          _selectedIndex = index;
          _currentTitle = title;
        });
        Navigator.pop(context);
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
      leading: Icon(icon, color: isSelected ? AdminTheme.royalBlue : Colors.white60, size: 20),
      title: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white70,
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
          if (hasAddon) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
              child: const Text("Addon", style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExpandableDrawerItem({required IconData icon, required String title, required List<Widget> children, int alertCount = 0}) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        leading: Icon(icon, color: Colors.white60, size: 20),
        title: Row(
          children: [
            Text(title, style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
            if (alertCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                child: Text("$alertCount", style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
        trailing: const Icon(Icons.keyboard_arrow_down, color: Colors.white30, size: 16),
        childrenPadding: EdgeInsets.zero,
        children: children,
      ),
    );
  }

  Widget _buildNestedExpandableItem({required String title, required List<Widget> children}) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.only(left: 45, right: 16),
        title: Row(
          children: [
            Container(width: 10, height: 1, color: Colors.white10),
            const SizedBox(width: 12),
            Text(title, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w400)),
          ],
        ),
        trailing: const Icon(Icons.keyboard_arrow_down, color: Colors.white30, size: 14),
        childrenPadding: EdgeInsets.zero,
        children: children,
      ),
    );
  }

  Widget _buildSubDrawerItem(int index, String title, {bool isDoubleNested = false, bool hasBadge = false}) {
    bool isSelected = _selectedIndex == index;
    return IntrinsicHeight(
      child: Row(
        children: [
          SizedBox(width: isDoubleNested ? 75 : 44),
          Container(width: 1, color: Colors.white10),
          Expanded(
            child: ListTile(
              onTap: () {
                setState(() {
                  _selectedIndex = index;
                  _currentTitle = title;
                });
                Navigator.pop(context);
              },
              dense: true,
              title: Row(
                children: [
                  Container(width: 10, height: 1, color: Colors.white10),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white60,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w400,
                    ),
                  ),
                  if (hasBadge) ...[
                    const SizedBox(width: 8),
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
