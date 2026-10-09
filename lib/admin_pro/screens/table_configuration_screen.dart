import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../services/api_service.dart';
import '../../services/tenant_service.dart';
import '../admin_theme.dart';
import '../../services/app_config.dart';

class TableConfigurationScreen extends StatefulWidget {
  final String mode;
  const TableConfigurationScreen({super.key, required this.mode});

  @override
  State<TableConfigurationScreen> createState() => _TableConfigurationScreenState();
}

class _TableConfigurationScreenState extends State<TableConfigurationScreen> {
  List<Map<String, dynamic>> _tables = [];
  List<Map<String, dynamic>> _expansionRequests = [];
  Map<String, double> _tableRevenueMap = {};
  bool _isLoading = true;
  bool _isLoadingSettings = false;

  @override
  void initState() {
    super.initState();
    if (widget.mode == "Table List") {
      _loadTables();
    } else if (widget.mode == "Table Setting") {
      _loadTableSettingsData();
    }
  }

  Future<void> _loadTables() async {
    final tenant = TenantService().currentTenant.value;
    final tenantId = tenant?.id ?? 'startups_main';

    if (mounted) setState(() => _isLoading = true);
    final data = await ApiService.fetchTables(tenantId);
    final orders = await ApiService.fetchAllOrders(tenantId);

    if (mounted) {
      if (data != null) {
        setState(() => _tables = data);
      }
      if (orders != null) {
        final Map<String, double> revMap = {};
        for (var ord in orders) {
          String tNum = (ord['table_number'] ?? ord['table'] ?? '').toString().replaceAll(RegExp(r'[^0-9]'), '');
          double amt = double.tryParse(ord['amount']?.toString() ?? ord['total_amount']?.toString() ?? ord['total_price']?.toString() ?? '0') ?? 0.0;
          if (tNum.isNotEmpty) {
            revMap[tNum] = (revMap[tNum] ?? 0.0) + amt;
          }
        }
        _tableRevenueMap = revMap;
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTableSettingsData() async {
    final tenant = TenantService().currentTenant.value;
    final tenantId = tenant?.id ?? 'startups_main';

    if (mounted) setState(() => _isLoadingSettings = true);
    final tablesData = await ApiService.fetchTables(tenantId);
    final ticketsData = await ApiService.fetchMyTickets(tenantId);
    final orders = await ApiService.fetchAllOrders(tenantId);

    if (mounted) {
      setState(() {
        if (tablesData != null) _tables = tablesData;
        if (ticketsData != null) {
          _expansionRequests = ticketsData.where((t) => 
            (t['subject']?.toString() ?? '').toUpperCase().contains('TABLE')
          ).toList();
        }
        if (orders != null) {
          final Map<String, double> revMap = {};
          for (var ord in orders) {
            String tNum = (ord['table_number'] ?? ord['table'] ?? '').toString().replaceAll(RegExp(r'[^0-9]'), '');
            double amt = double.tryParse(ord['amount']?.toString() ?? ord['total_amount']?.toString() ?? ord['total_price']?.toString() ?? '0') ?? 0.0;
            if (tNum.isNotEmpty) {
              revMap[tNum] = (revMap[tNum] ?? 0.0) + amt;
            }
          }
          _tableRevenueMap = revMap;
        }
        _isLoadingSettings = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _addTable() async {
    final tenant = TenantService().currentTenant.value;
    final tenantId = tenant?.id ?? 'startups_main';
    final bool isPremium = tenant?.isPremiumEnabled ?? false;
    final int currentTableCount = _tables.length;

    // Free Plan Enforcement: Max 5 Tables
    if (!isPremium && currentTableCount >= 5) {
      _showUpgradeToPremiumModal();
      return;
    }

    final controller = TextEditingController();

    final bool? shouldAdd = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: const [
                  Icon(Icons.table_restaurant_rounded, color: AdminTheme.royalBlue, size: 24),
                  SizedBox(width: 10),
                  Text("Add New Table", style: TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.darkNavy)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPremium
                        ? "Enter a unique table number (Standard limit: 12 tables)."
                        : "Enter table number (Free plan limit: 5 tables).",
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: "Table Number",
                      hintText: "e.g. ${currentTableCount + 1}",
                      filled: true,
                      fillColor: AdminTheme.pearlWhite,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx, false),
                  child: const Text("CANCEL"),
                ),
                ElevatedButton(
                  onPressed: isSaving ? null : () async {
                    if (controller.text.trim().isEmpty) return;
                    final num = int.tryParse(controller.text.trim());
                    if (num == null) return;

                    // Non-premium > 5 tables check
                    if (!isPremium && (num > 5 || currentTableCount >= 5)) {
                      Navigator.pop(ctx, false);
                      _showUpgradeToPremiumModal();
                      return;
                    }

                    // Premium > 12 tables check (Triggers Super Admin Extension Request)
                    if (isPremium && (num > 12 || currentTableCount >= 12)) {
                      Navigator.pop(ctx, false);
                      _showExtraTableRequestModal(num);
                      return;
                    }

                    setModalState(() => isSaving = true);
                    final success = await ApiService.addTable(tenantId, num);
                    if (ctx.mounted) Navigator.pop(ctx, success);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.royalBlue),
                  child: isSaving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text("SAVE TABLE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );

    if (shouldAdd == true) {
      _loadTables();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Table registered successfully!"), backgroundColor: AdminTheme.emeraldGreen),
        );
      }
    }
  }

  void _showUpgradeToPremiumModal() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 28),
            SizedBox(width: 10),
            Text("Free Plan Limit Reached", style: TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.darkNavy)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              "Your restaurant is currently on the Free Plan, which supports a maximum of 5 tables.",
              style: TextStyle(fontSize: 13, color: AdminTheme.darkNavy, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 12),
            Text(
              "Upgrade your subscription to Premium to unlock up to 12 floor tables and custom extension requests!",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CLOSE")),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Please contact Super Admin to upgrade to Premium Plan!")),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade800),
            icon: const Icon(Icons.star_rounded, size: 18, color: Colors.white),
            label: const Text("UPGRADE TO PREMIUM", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showExtraTableRequestModal(int requestedTableNumber) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.add_business_rounded, color: AdminTheme.royalBlue, size: 28),
            SizedBox(width: 10),
            Text("Request Extra Table Access", style: TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.darkNavy)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Standard Premium Plan supports up to 12 floor tables. You are requesting access for Table #$requestedTableNumber.",
              style: const TextStyle(fontSize: 13, color: AdminTheme.darkNavy, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(
              "Would you like to submit a Table Expansion Request for Table #$requestedTableNumber to Super Admin for approval?",
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              final tenant = TenantService().currentTenant.value;
              final tenantId = tenant?.id ?? 'startups_main';

              final ticketPayload = {
                'tenant_id': tenantId,
                'subject': '[TABLE_EXPANSION_REQUEST] Table #$requestedTableNumber Access Request',
                'description': 'Restaurant ${tenant?.name ?? tenantId} is requesting Super Admin approval to add Table #$requestedTableNumber beyond the standard 12-table limit.',
                'priority': 'High',
              };

              await ApiService.createSupportTicket(ticketPayload);

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Table expansion request for Table #$requestedTableNumber submitted to Super Admin!"),
                    backgroundColor: AdminTheme.emeraldGreen,
                    duration: const Duration(seconds: 4),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.royalBlue),
            icon: const Icon(Icons.send_rounded, size: 16, color: Colors.white),
            label: const Text("SEND REQUEST TO SUPER ADMIN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTable(int tableId, int num) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Remove Table?"),
        content: Text("Are you sure you want to permanently delete Table T-$num?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCEL")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("DELETE", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await ApiService.deleteTable(tableId);
      if (success) {
        _loadTables();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Table removed.")));
      }
    }
  }

  void _showQRCode(Map<String, dynamic> table) {
    final String orderUrl = "${AppConfig.fullBaseUrl}/?table=${table['table_number']}";
    final tenantName = TenantService().currentTenant.value?.name ?? 'ChiyaBreak Restaurant';

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 680),
          child: AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
            contentPadding: const EdgeInsets.all(24),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Restaurant Name & Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AdminTheme.royalBlue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      tenantName.toUpperCase(),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AdminTheme.royalBlue, letterSpacing: 1.2),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Order & Entertainment",
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: AdminTheme.darkNavy),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF5C00).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "TABLE T-${table['table_number']}",
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFFF5C00), letterSpacing: 0.5),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // QR Card Container
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AdminTheme.royalBlue.withValues(alpha: 0.15), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AdminTheme.royalBlue.withValues(alpha: 0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        SizedBox(
                          width: 180, height: 180,
                          child: QrImageView(
                            data: orderUrl,
                            version: QrVersions.auto,
                            size: 180.0,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1, thickness: 1, color: Colors.black12),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.camera_alt_rounded, size: 14, color: Colors.grey),
                            SizedBox(width: 6),
                            Text(
                              "Scan camera to order & play games",
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  Text(
                    orderUrl,
                    style: const TextStyle(fontSize: 9, color: Colors.blueAccent, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text("CLOSE", style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Sending QR Code to receipt printer..."), backgroundColor: AdminTheme.emeraldGreen),
                            );
                          }, 
                          icon: const Icon(Icons.print, size: 16, color: Colors.white),
                          label: const Text("PRINT", style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AdminTheme.royalBlue,
                            padding: const EdgeInsets.symmetric(vertical: 12),
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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.mode == "Table List") _buildTableListView()
          else if (widget.mode == "Table Setting") _buildTableSettings()
          else _buildGenericConfigView(),
        ],
      ),
    );
  }

  Widget _buildTableListView() {
    final tenant = TenantService().currentTenant.value;
    final bool isPremium = tenant?.isPremiumEnabled ?? false;
    final String limitBadge = isPremium ? "Premium Plan (Max 12 Tables)" : "Free Plan (Max 5 Tables)";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Floor Layout", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPremium ? Colors.amber.shade100 : Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    limitBadge,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isPremium ? Colors.amber.shade900 : AdminTheme.royalBlue,
                    ),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                IconButton(
                  onPressed: _loadTables, 
                  icon: const Icon(Icons.sync_rounded, color: AdminTheme.royalBlue),
                  tooltip: "Sync with Backend",
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _addTable,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text("ADD TABLE", style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5C00),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (_isLoading)
          const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
        else if (_tables.isEmpty)
          Container(
            padding: const EdgeInsets.all(48),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: AdminTheme.softShadow,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AdminTheme.royalBlue.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.table_restaurant_outlined, size: 48, color: AdminTheme.royalBlue),
                  ),
                  const SizedBox(height: 16),
                  const Text("No Tables Configured Yet", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AdminTheme.darkNavy)),
                  const SizedBox(height: 8),
                  const Text("Click 'ADD TABLE' above to set up your restaurant floor plan.", style: TextStyle(fontSize: 13, color: Colors.grey), textAlign: TextAlign.center),
                ],
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 20,
              crossAxisSpacing: 20,
              childAspectRatio: 1.15,
            ),
            itemCount: _tables.length,
            itemBuilder: (context, index) {
              final t = _tables[index];
              final tableNum = t['table_number'];
              final tableId = int.tryParse(t['id']?.toString() ?? '');
              final numVal = int.tryParse(tableNum?.toString() ?? '');

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AdminTheme.royalBlue.withValues(alpha: 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                  border: Border.all(color: AdminTheme.royalBlue.withValues(alpha: 0.08), width: 1.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _showQRCode(t),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AdminTheme.emeraldGreen.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    "ACTIVE",
                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AdminTheme.emeraldGreen),
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      onPressed: () => _showQRCode(t),
                                      icon: const Icon(Icons.qr_code_rounded, size: 18, color: AdminTheme.royalBlue),
                                      tooltip: "View QR Code",
                                      constraints: const BoxConstraints(),
                                      padding: EdgeInsets.zero,
                                    ),
                                    if (tableId != null && numVal != null) ...[
                                      const SizedBox(width: 8),
                                      IconButton(
                                        onPressed: () => _deleteTable(tableId, numVal),
                                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                                        tooltip: "Delete Table",
                                        constraints: const BoxConstraints(),
                                        padding: EdgeInsets.zero,
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                            
                            // Center Content: Total Order Revenue Booked through this table
                            Expanded(
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      "TOTAL REVENUE",
                                      style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Rs. ${(_tableRevenueMap[tableNum.toString()] ?? 0.0).toStringAsFixed(0)}",
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        color: AdminTheme.royalBlue,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [AdminTheme.royalBlue, AdminTheme.royalBlue.withValues(alpha: 0.8)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(Icons.table_restaurant_rounded, color: Colors.white, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Table T-$tableNum",
                                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AdminTheme.darkNavy),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      "Tap to View QR",
                                      style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildTableSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text("Table Settings & Live Control", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AdminTheme.darkNavy)),
                SizedBox(height: 4),
                Text("Manage table availability, enable/disable status, and live expansion requests.", style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            IconButton(
              onPressed: _loadTableSettingsData,
              icon: const Icon(Icons.sync_rounded, color: AdminTheme.royalBlue),
              tooltip: "Sync Real-Time Data",
            ),
          ],
        ),
        const SizedBox(height: 24),
        
        // --- SECTION 1: LIVE TABLE ENABLE / DISABLE CONTROLS ---
        const Text("Table Availability & Status", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AdminTheme.darkNavy)),
        const SizedBox(height: 12),
        if (_isLoadingSettings || _isLoading)
          const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator()))
        else if (_tables.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: AdminTheme.pearlWhite, borderRadius: BorderRadius.circular(16)),
            child: const Center(child: Text("No tables found. Please add tables in Table List first.", style: TextStyle(color: Colors.grey))),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 2.3,
            ),
            itemCount: _tables.length,
            itemBuilder: (context, index) {
              final t = _tables[index];
              final tableNum = t['table_number'];
              bool isEnabled = t['is_enabled'] ?? t['is_active'] ?? true;
              if (isEnabled.toString() == '0' || isEnabled.toString() == 'false') isEnabled = false;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isEnabled ? AdminTheme.emeraldGreen.withValues(alpha: 0.3) : Colors.red.withValues(alpha: 0.3), width: 1.5),
                  boxShadow: AdminTheme.softShadow,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Table T-$tableNum", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AdminTheme.darkNavy)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isEnabled ? AdminTheme.emeraldGreen.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isEnabled ? "ACTIVE" : "DISABLED",
                            style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: isEnabled ? AdminTheme.emeraldGreen : Colors.red),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isEnabled ? "Ready for Orders" : "Offline / Closed",
                          style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.w600),
                        ),
                        Switch.adaptive(
                          value: isEnabled,
                          activeColor: AdminTheme.emeraldGreen,
                          onChanged: (val) async {
                            setState(() {
                              _tables[index]['is_enabled'] = val;
                            });
                            final tableId = t['id'];
                            if (tableId != null) {
                              await ApiService.updateTableStatus(tableId, val);
                            }
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Table T-$tableNum is now ${val ? 'Enabled & Active' : 'Disabled'}"),
                                  backgroundColor: val ? AdminTheme.emeraldGreen : Colors.redAccent,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          
        const SizedBox(height: 32),
        
        // --- SECTION 2: LIVE TABLE EXPANSION REQUESTS STATUS ---
        const Text("Table Expansion Requests (Super Admin)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AdminTheme.darkNavy)),
        const SizedBox(height: 4),
        const Text("Track live status of your extra table capacity requests sent to Super Admin.", style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 16),
        
        if (_isLoadingSettings)
          const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
        else if (_expansionRequests.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: AdminTheme.softShadow),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.assignment_turned_in_rounded, size: 36, color: Colors.grey),
                  SizedBox(height: 8),
                  Text("No pending table expansion requests.", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600, fontSize: 13)),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _expansionRequests.length,
            itemBuilder: (context, index) {
              final req = _expansionRequests[index];
              final subject = req['subject'] ?? 'Table Request';
              final desc = req['description'] ?? '';
              final status = req['status'] ?? 'Pending';
              final priority = req['priority'] ?? 'Normal';
              final date = req['created_at'] ?? 'Recent';

              Color statusColor = Colors.orange;
              if (status.toString().toLowerCase() == 'resolved' || status.toString().toLowerCase() == 'approved') {
                statusColor = AdminTheme.emeraldGreen;
              } else if (status.toString().toLowerCase() == 'in progress') {
                statusColor = AdminTheme.royalBlue;
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AdminTheme.softShadow,
                  border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 1.5),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                      child: Icon(Icons.business_center_rounded, color: statusColor, size: 20),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: Text(subject, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AdminTheme.darkNavy))),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(6)),
                                child: Text(status.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(desc, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text("Priority: $priority", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AdminTheme.darkNavy)),
                              const SizedBox(width: 16),
                              Text("Submitted: $date", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildGenericConfigView() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: AdminTheme.softShadow),
      child: const Text("Floor Configuration Settings"),
    );
  }
}
