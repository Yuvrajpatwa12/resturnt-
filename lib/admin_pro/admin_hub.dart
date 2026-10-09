import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../services/tenant_service.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import 'admin_theme.dart';
import 'screens/dashboard_screen.dart';
import 'screens/pos_invoice_screen.dart';
import 'screens/order_management_screen.dart';
import 'screens/production_dashboard_screen.dart';
import 'screens/admin_settings_screen.dart';
import 'screens/purchase_management_screen.dart';
import 'screens/supplier_management_screen.dart';
import 'screens/ingredient_stock_screen.dart';
import 'screens/unit_measurement_screen.dart';
import 'screens/ingredient_inventory_screen.dart';
import 'screens/category_management_screen.dart';
import 'screens/food_catalog_screen.dart';
import 'screens/addons_management_screen.dart';
import 'screens/reservation_management_screen.dart';
import 'screens/room_maintenance_screen.dart';
import 'screens/coming_product_screen.dart';
import 'screens/reports/stock_food_report_screen.dart';
import 'screens/reports/stock_kitchen_report_screen.dart';
import 'screens/reports/sales_report_screen.dart';
import 'screens/reports/items_sales_report_screen.dart';
import 'screens/reports/waiters_sales_report_screen.dart';
import 'screens/reports/delivery_sales_report_screen.dart';
import 'screens/reports/order_source_report_screen.dart';
import 'screens/reports/cash_register_report_screen.dart';
import 'screens/reports/sale_by_table_report_screen.dart';
import 'screens/payment_method_list_screen.dart';
import 'screens/payment_setup_screen.dart';
import 'screens/payment_account_filter_screen.dart';
import 'screens/production_list_screen.dart';
import 'screens/hrm_management_screen.dart';
import 'screens/hrm/designation_screen.dart';
import 'screens/hrm/add_employee_screen.dart';
import 'screens/hrm/manage_employee_screen.dart';
import 'screens/hrm/employee_salary_screen.dart';
import 'screens/hrm/attendance_form_screen.dart';
import 'screens/hrm/attendance_report_screen.dart';
import 'screens/report_management_screen.dart';
import 'screens/table_configuration_screen.dart';
import 'screens/customer_management_screen.dart';
import 'screens/kitchen_management_screen.dart';
import 'screens/system_configuration_screen.dart';
import 'screens/expense_management_screen.dart';
import 'screens/reward_management_screen.dart';
import 'screens/hr_policy_screen.dart';
import 'screens/counter_management_screen.dart';
import 'screens/department_management_screen.dart';
import 'screens/support_ticket_screen.dart';
import 'screens/subscription_status_screen.dart';
import 'screens/purchase_report_screen.dart';
import 'screens/music_management_screen.dart';
import 'screens/theme_management_screen.dart';
import 'screens/social_media_management_screen.dart';

class AdminHub extends StatefulWidget {
  const AdminHub({super.key});

  @override
  State<AdminHub> createState() => _AdminHubState();
}

class _AdminHubState extends State<AdminHub> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;
  String _currentTitle = "Dashboard";
  int _alertCount = 0;
  bool _isDisposed = false;
  bool _isSidebarVisible = true;

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

  void _onNavigateIndex(int idx) {
    setState(() => _selectedIndex = idx);
  }

  List<Widget> get _screens => [
    const DashboardScreen(), // 0
    const POSInvoiceScreen(), // 1
    const OrderManagementScreen(key: ValueKey("order_all"), initialStatus: "All"), // 2
    const OrderManagementScreen(key: ValueKey("order_pending"), initialStatus: "Pending"), // 3
    const OrderManagementScreen(key: ValueKey("order_completed"), initialStatus: "Completed"), // 4
    const OrderManagementScreen(key: ValueKey("order_cancelled"), initialStatus: "Cancelled"), // 5
    const ProductionDashboardScreen(title: "Kitchen Dashboard"), // 6
    const CounterManagementScreen(), // 7
    const CounterManagementScreen(), // 8
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
    const RoomMaintenanceScreen(), // 20
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
    const ComingProductScreen(), // 33
    const ProductionListScreen(), // 34
    const ProductionListScreen(), // 35
    const ProductionListScreen(), // 36
    const DesignationScreen(), // 37
    const AddEmployeeScreen(), // 38
    const ManageEmployeeScreen(), // 39
    const EmployeeSalaryScreen(), // 40
    const AttendanceFormScreen(), // 41
    const AttendanceReportScreen(), // 42
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
    DepartmentManagementScreen(mode: "Department List", onNavigateIndex: _onNavigateIndex), // 54
    DepartmentManagementScreen(mode: "Add Division", onNavigateIndex: _onNavigateIndex), // 55
    DepartmentManagementScreen(mode: "Manage Division", onNavigateIndex: _onNavigateIndex), // 56
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
    const PurchaseReportScreen(), // 67
    const StockFoodReportScreen(), // 68
    const StockKitchenReportScreen(), // 69
    const SalesReportScreen(), // 70
    const ItemsSalesReportScreen(), // 71
    const WaitersSalesReportScreen(), // 72
    const DeliverySalesReportScreen(), // 73
    const OrderSourceReportScreen(), // 74
    const CashRegisterReportScreen(), // 75
    const SaleByTableReportScreen(), // 76
    const PaymentMethodListScreen(), // 77
    const PaymentSetupScreen(), // 78
    const PaymentAccountFilterScreen(), // 79
    const TableConfigurationScreen(mode: "Table List"), // 80
    const TableConfigurationScreen(mode: "Table Setting"), // 81
    const CustomerManagementScreen(mode: "Customer List"), // 82
    const CustomerManagementScreen(mode: "Customer Type List"), // 83
    const UnitMeasurementScreen(), // 84
    const IngredientInventoryScreen(), // 85
    const SystemConfigurationScreen(mode: "SMS Configuration"), // 86
    const SystemConfigurationScreen(mode: "SMS Template"), // 87
    const SystemConfigurationScreen(mode: "Bank List"), // 88
    const SystemConfigurationScreen(mode: "Bank Transaction"), // 89
    const SystemConfigurationScreen(mode: "Language"), // 90
    const SystemConfigurationScreen(mode: "Application Setting"), // 91
    const SystemConfigurationScreen(mode: "App Setting"), // 92
    const SystemConfigurationScreen(mode: "Factory Reset"), // 93
    const SystemConfigurationScreen(mode: "Currency"), // 94
    const SystemConfigurationScreen(mode: "Country"), // 95
    const SystemConfigurationScreen(mode: "State"), // 96
    const SystemConfigurationScreen(mode: "City"), // 97
    const SystemConfigurationScreen(mode: "Commission"), // 98
    const HRMManagementScreen(mode: "User Management"), // 99
    const AdminSettingsScreen(section: "Modules"), // 100
    const ThemeManagementScreen(), // 101
    const SupportTicketScreen(), // 102
    const SubscriptionStatusScreen(), // 103
    const RewardManagementScreen(mode: "Rewards Config"), // 104
    const RewardManagementScreen(mode: "Redeem Items"), // 105
    const RewardManagementScreen(mode: "Mystery Box"), // 106
    const RewardManagementScreen(mode: "Claim History"), // 107
    const RewardManagementScreen(mode: "Marketing Banners"), // 108
    const MusicManagementScreen(), // 109
    const TableConfigurationScreen(mode: "Room List"), // 110
    const TableConfigurationScreen(mode: "Room Setting"), // 111
    const SocialMediaManagementScreen(), // 112
  ];

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AdminTheme.lightTheme,
      child: ScrollConfiguration(
        behavior: const ScrollBehavior().copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
          },
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            bool isMobile = constraints.maxWidth < 1100;
            return Scaffold(
              key: _scaffoldKey,
              backgroundColor: const Color(0xFF1E1E2C), 
              drawer: isMobile ? _buildAdminDrawer(isFixed: false) : null,
              drawerEnableOpenDragGesture: true,
              body: Row(
                children: [
                  if (!isMobile && _isSidebarVisible) _buildAdminDrawer(isFixed: true),
                  Expanded(
                    child: Container(
                      margin: (isMobile || !_isSidebarVisible) ? EdgeInsets.zero : const EdgeInsets.fromLTRB(0, 20, 20, 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC), 
                        borderRadius: (isMobile || !_isSidebarVisible) ? BorderRadius.zero : const BorderRadius.all(Radius.circular(40)),
                      ),
                      child: ClipRRect(
                        borderRadius: (isMobile || !_isSidebarVisible) ? BorderRadius.zero : const BorderRadius.all(Radius.circular(40)),
                        child: Column(
                          children: [
                            _buildHeader(isMobile),
                            Expanded(
                              child: _screens[_selectedIndex],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      color: Colors.white,
      child: Row(
        children: [
          if (isMobile || !_isSidebarVisible)
            IconButton(
              icon: const Icon(Icons.menu_rounded, color: AdminTheme.royalBlue, size: 28),
              onPressed: () {
                if (isMobile) {
                  _scaffoldKey.currentState?.openDrawer();
                } else {
                  setState(() => _isSidebarVisible = true);
                }
              },
              tooltip: isMobile ? "Open Menu" : "Show Sidebar",
            ),
          if (!isMobile) ...[
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const TextField(
                  decoration: InputDecoration(
                    hintText: "Search anything...",
                    border: InputBorder.none,
                    icon: Icon(Icons.search, color: Colors.grey, size: 20),
                  ),
                ),
              ),
            ),
          ],
          if (isMobile)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_currentTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AdminTheme.darkNavy)),
                const Text("Admin Console", style: TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold)),
              ],
            ),
          const Spacer(),
          _buildLanguageSwitcher(),
          const SizedBox(width: 16),
          _buildHeaderAction(Icons.notifications_none_outlined, () {}),
          const SizedBox(width: 16),
          Row(
            children: [
              const CircleAvatar(
                radius: 18,
                backgroundColor: AdminTheme.royalBlue,
                child: Icon(Icons.person, color: Colors.white, size: 20),
              ),
              if (!isMobile) ...[
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text("Admin User", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AdminTheme.darkNavy)),
                    Text("Super Admin", style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderAction(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, color: AdminTheme.darkNavy, size: 24),
      ),
    );
  }

  Widget _buildLanguageSwitcher() {
    return ValueListenableBuilder<String>(
      valueListenable: LanguageService().currentLanguageCode,
      builder: (context, currentCode, child) {
        final currentLang = LanguageService().languages.value.firstWhere((l) => l.code == currentCode, orElse: () => LanguageService().languages.value.first);
        return PopupMenuButton<String>(
          onSelected: (code) => LanguageService().setLanguage(code),
          tooltip: "Switch Language",
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: AdminTheme.royalBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
            child: Row(
              children: [
                const Icon(Icons.language_rounded, color: AdminTheme.royalBlue, size: 18),
                const SizedBox(width: 8),
                Text(currentLang.nativeName, style: const TextStyle(color: AdminTheme.royalBlue, fontSize: 12, fontWeight: FontWeight.bold)),
                const Icon(Icons.arrow_drop_down, color: AdminTheme.royalBlue, size: 16),
              ],
            ),
          ),
          itemBuilder: (ctx) => LanguageService().languages.value.where((l) => l.status).map((l) => PopupMenuItem(
            value: l.code,
            child: Row(
              children: [
                if (l.code == currentCode) const Icon(Icons.check, size: 16, color: Colors.green),
                const SizedBox(width: 8),
                Text(l.nativeName),
              ],
            ),
          )).toList(),
        );
      },
    );
  }

  Widget _buildAdminDrawer({required bool isFixed}) {
    double width = isFixed ? 280 : MediaQuery.of(context).size.width * 0.8;
    return Material(
      color: const Color(0xFF1E1E2C),
      child: SizedBox(
        width: width,
        height: double.infinity,
        child: Column(
          children: [
            _buildDrawerHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 20),
                children: [
                  _buildDrawerItem(0, Icons.dashboard_outlined, "Dashboard", isFixed),

                  _buildExpandableDrawerItem(
                    icon: Icons.shopping_cart_outlined,
                    title: "Manage Order",
                    isFixed: isFixed,
                    children: [
                      _buildSubDrawerItem(1, "POS Invoice", isFixed),
                      _buildSubDrawerItem(2, "Order List", isFixed),
                      _buildSubDrawerItem(3, "Pending Order", isFixed),
                      _buildSubDrawerItem(4, "Complete Order", isFixed),
                      _buildSubDrawerItem(5, "Cancel Order", isFixed),
                      _buildSubDrawerItem(6, "Kitchen Dashboard", isFixed),
                      _buildSubDrawerItem(7, "Counter Dashboard", isFixed),
                      _buildSubDrawerItem(8, "Counter List", isFixed),
                      _buildSubDrawerItem(9, "POS Setting", isFixed),
                      _buildSubDrawerItem(10, "Sound Setting", isFixed),
                      _buildSubDrawerItem(114, "Live Jukebox Control", isFixed),
                    ],
                  ),

                  _buildExpandableDrawerItem(
                    icon: Icons.add_shopping_cart_rounded,
                    title: "Purchase Manage",
                    alertCount: _alertCount,
                    isFixed: isFixed,
                    children: [
                      _buildSubDrawerItem(11, "Purchase Item", isFixed),
                      _buildSubDrawerItem(12, "Add Purchase", isFixed),
                      _buildSubDrawerItem(13, "Purchase Return", isFixed),
                      _buildSubDrawerItem(14, "Return Invoice", isFixed),
                      _buildSubDrawerItem(15, "Supplier Manage", isFixed),
                      _buildSubDrawerItem(16, "Supplier Ledger", isFixed),
                      _buildSubDrawerItem(17, "Stock Out Ingredients", isFixed, hasBadge: _alertCount > 0),
                    ],
                  ),

                  _buildExpandableDrawerItem(
                    icon: Icons.event_available_outlined,
                    title: "Reservation",
                    isFixed: isFixed,
                    children: [
                      _buildSubDrawerItem(18, "Reservation", isFixed),
                      _buildSubDrawerItem(19, "Add Booking", isFixed),
                      _buildSubDrawerItem(115, "Room List", isFixed),
                      _buildSubDrawerItem(116, "Room Setting", isFixed),
                      _buildSubDrawerItem(20, "Room Maintenance", isFixed),
                      _buildSubDrawerItem(21, "Reservation Setting", isFixed),
                    ],
                  ),

                  _buildExpandableDrawerItem(
                    icon: Icons.restaurant_menu,
                    title: "Food Management",
                    isFixed: isFixed,
                    children: [
                      _buildNestedExpandableItem(
                        title: "Manage Category",
                        children: [
                          _buildSubDrawerItem(22, "Add Category", isFixed, isDoubleNested: true),
                          _buildSubDrawerItem(23, "Category List", isFixed, isDoubleNested: true),
                        ],
                      ),
                      _buildNestedExpandableItem(
                        title: "Manage Food",
                        children: [
                          _buildSubDrawerItem(24, "Add Food", isFixed, isDoubleNested: true),
                          _buildSubDrawerItem(25, "Food List", isFixed, isDoubleNested: true),
                          _buildSubDrawerItem(26, "Add Group Item", isFixed, isDoubleNested: true),
                          _buildSubDrawerItem(27, "Food Variant", isFixed, isDoubleNested: true),
                          _buildSubDrawerItem(28, "Food Availability", isFixed, isDoubleNested: true),
                          _buildSubDrawerItem(29, "Menu Type", isFixed, isDoubleNested: true),
                        ],
                      ),
                      _buildNestedExpandableItem(
                        title: "Manage Add-ons",
                        children: [
                          _buildSubDrawerItem(30, "Add Add-ons", isFixed, isDoubleNested: true),
                          _buildSubDrawerItem(31, "Add-ons List", isFixed, isDoubleNested: true),
                          _buildSubDrawerItem(32, "Add-ons Assign List", isFixed, isDoubleNested: true),
                        ],
                      ),
                    ],
                  ),

                  _buildExpandableDrawerItem(
                    icon: Icons.outdoor_grill_outlined,
                    title: "Production",
                    isFixed: isFixed,
                    children: [
                      _buildSubDrawerItem(33, "Coming Product", isFixed),
                      _buildSubDrawerItem(34, "Production List", isFixed),
                    ],
                  ),

                  _buildExpandableDrawerItem(
                    icon: Icons.people_outline,
                    title: "Human Resource",
                    isFixed: isFixed,
                    children: [
                      _buildNestedExpandableItem(
                        title: "HRM",
                        children: [
                          _buildSubDrawerItem(38, "Add Employee", isFixed, isDoubleNested: true),
                          _buildSubDrawerItem(39, "Manage Employee", isFixed, isDoubleNested: true),
                          _buildSubDrawerItem(40, "Employee Salary", isFixed, isDoubleNested: true),
                        ],
                      ),
                      _buildNestedExpandableItem(
                        title: "Attendance",
                        children: [
                          _buildSubDrawerItem(41, "Attendance Form", isFixed, isDoubleNested: true),
                          _buildSubDrawerItem(42, "Attendance Report", isFixed, isDoubleNested: true),
                        ],
                      ),
                      _buildNestedExpandableItem(
                        title: "Expense",
                        children: [
                          _buildSubDrawerItem(43, "Add Expense Item", isFixed, isDoubleNested: true),
                          _buildSubDrawerItem(46, "Manage Expense", isFixed, isDoubleNested: true),
                          _buildSubDrawerItem(47, "Expense Statement", isFixed, isDoubleNested: true),
                        ],
                      ),
                      _buildNestedExpandableItem(
                        title: "Loyalty & Rewards",
                        children: [
                          _buildSubDrawerItem(109, "Rewards Config", isFixed, isDoubleNested: true),
                          _buildSubDrawerItem(111, "Mystery Box", isFixed, isDoubleNested: true),
                          _buildSubDrawerItem(112, "Claim History", isFixed, isDoubleNested: true),
                          _buildSubDrawerItem(113, "Marketing Banners", isFixed, isDoubleNested: true),
                        ],
                      ),
                      _buildNestedExpandableItem(
                        title: "Award",
                        children: [
                          _buildSubDrawerItem(110, "Redeem Items", isFixed, isDoubleNested: true),
                        ],
                      ),
                      _buildNestedExpandableItem(
                        title: "Department",
                        children: [
                          _buildSubDrawerItem(54, "Department", isFixed, isDoubleNested: true),
                          _buildSubDrawerItem(55, "Add Division", isFixed, isDoubleNested: true),
                          _buildSubDrawerItem(56, "Manage Division", isFixed, isDoubleNested: true),
                        ],
                      ),
                      _buildNestedExpandableItem(
                        title: "Payroll",
                        children: [
                          _buildSubDrawerItem(64, "Salary Type Setup", isFixed, isDoubleNested: true),
                          _buildSubDrawerItem(65, "Salary Setup", isFixed, isDoubleNested: true),
                          _buildSubDrawerItem(66, "Salary Generate", isFixed, isDoubleNested: true),
                        ],
                      ),
                    ],
                  ),

                  _buildExpandableDrawerItem(
                    icon: Icons.bar_chart_outlined,
                    title: "Report",
                    isFixed: isFixed,
                    children: [
                      _buildSubDrawerItem(67, "Purchase Report", isFixed),
                      _buildSubDrawerItem(68, "Stock Report (Food Items)", isFixed),
                      _buildSubDrawerItem(69, "Stock Report (Kitchen)", isFixed),
                      _buildNestedExpandableItem(
                        title: "Sales Report",
                        children: [
                          _buildSubDrawerItem(70, "Sales Report", isFixed, isDoubleNested: true),
                          _buildSubDrawerItem(71, "Items Sales Report", isFixed, isDoubleNested: true),
                          _buildSubDrawerItem(72, "Waiters Sales Report", isFixed, isDoubleNested: true),
                          _buildSubDrawerItem(73, "Delivery Type Sales Report", isFixed, isDoubleNested: true),
                          _buildSubDrawerItem(74, "Order Source Report", isFixed, isDoubleNested: true),
                          _buildSubDrawerItem(75, "Cash Register Report", isFixed, isDoubleNested: true),
                          _buildSubDrawerItem(76, "Sale By Table", isFixed, isDoubleNested: true),
                        ],
                      ),
                    ],
                  ),

                  _buildExpandableDrawerItem(
                    icon: Icons.settings_outlined,
                    title: "Setting",
                    isFixed: isFixed,
                    children: [
                      _buildNestedExpandableItem(
                        title: "Payment Method Setting",
                        children: [
                          _buildSubDrawerItem(77, "Payment Method List", isFixed, isDoubleNested: true),
                          _buildSubDrawerItem(78, "Payment Setup", isFixed, isDoubleNested: true),
                          _buildSubDrawerItem(79, "Payment Account Filter", isFixed, isDoubleNested: true),
                        ],
                      ),
                      _buildSubDrawerItem(117, "Social Media", isFixed),
                      _buildNestedExpandableItem(
                        title: "Manage Table",
                        children: [
                          _buildSubDrawerItem(80, "Table List", isFixed, isDoubleNested: true),
                          _buildSubDrawerItem(81, "Table Setting", isFixed, isDoubleNested: true),
                        ],
                      ),
                      _buildNestedExpandableItem(
                        title: "Customer Type",
                        children: [
                          _buildSubDrawerItem(82, "Customer List", isFixed, isDoubleNested: true),
                          _buildSubDrawerItem(83, "Customer Type List", isFixed, isDoubleNested: true),
                        ],
                      ),
                      _buildNestedExpandableItem(
                        title: "Unit Measurement",
                        children: [
                          _buildSubDrawerItem(84, "Unit Measurement List", isFixed, isDoubleNested: true),
                          _buildSubDrawerItem(85, "Ingredient List", isFixed, isDoubleNested: true),
                        ],
                      ),
                      _buildNestedExpandableItem(
                        title: "SMS Setting",
                        children: [
                          _buildSubDrawerItem(86, "SMS Configuration", isFixed, isDoubleNested: true),
                          _buildSubDrawerItem(87, "SMS Template", isFixed, isDoubleNested: true),
                        ],
                      ),
                      _buildNestedExpandableItem(
                        title: "Bank",
                        children: [
                          _buildSubDrawerItem(88, "Bank List", isFixed, isDoubleNested: true),
                          _buildSubDrawerItem(89, "Bank Transaction", isFixed, isDoubleNested: true),
                        ],
                      ),
                      _buildSubDrawerItem(90, "Language", isFixed),
                      _buildSubDrawerItem(91, "Application Setting", isFixed),
                      _buildSubDrawerItem(92, "App Setting", isFixed),
                      _buildSubDrawerItem(93, "Factory Reset", isFixed),
                      _buildSubDrawerItem(94, "Currency", isFixed),
                      _buildSubDrawerItem(95, "Country", isFixed),
                      _buildSubDrawerItem(96, "State", isFixed),
                      _buildSubDrawerItem(97, "City", isFixed),
                      _buildSubDrawerItem(98, "Commission", isFixed),
                    ],
                  ),

                  const Divider(color: Colors.white10, height: 40),
                  _buildDrawerItem(103, Icons.card_membership_rounded, "Subscription Status", isFixed),
                  _buildDrawerItem(102, Icons.help_outline_rounded, "Support & Help", isFixed),
                  _buildDrawerItem(99, Icons.security_outlined, "User Management", isFixed),
                  _buildDrawerItem(100, Icons.grid_view_rounded, "Modules", isFixed, hasAddon: true),
                  _buildDrawerItem(101, Icons.palette_outlined, "Themes", isFixed),
                  
                  const SizedBox(height: 20),
                  const Center(
                    child: Text(
                      "SYSTEM VERSION: 3.0",
                      style: TextStyle(color: Colors.white24, fontSize: 8, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
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
          if (!_isSidebarVisible)
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, color: Colors.white30, size: 20),
            ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(int index, IconData icon, String title, bool isFixed, {bool hasAddon = false}) {
    bool isSelected = _selectedIndex == index;
    return ListTile(
      onTap: () {
        setState(() {
          _selectedIndex = index;
          _currentTitle = title;
        });
        if (!isFixed) Navigator.pop(context);
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

  Widget _buildExpandableDrawerItem({required IconData icon, required String title, required List<Widget> children, int alertCount = 0, required bool isFixed}) {
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

  Widget _buildSubDrawerItem(int index, String title, bool isFixed, {bool isDoubleNested = false, bool hasBadge = false}) {
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
                if (!isFixed) Navigator.pop(context);
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
