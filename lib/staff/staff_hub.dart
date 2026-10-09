import 'package:flutter/material.dart';
import '../cart_manager.dart';
import 'tabs/tables_tab.dart';
import 'tabs/menus_tab.dart';
import 'tabs/bills_tab.dart';
import 'tabs/admin_tab.dart';
import 'tabs/settings_tab.dart';
import 'widgets/staff_bottom_bar.dart';
import '../services/tenant_service.dart';
import '../services/api_service.dart';

class StaffHub extends StatefulWidget {
  const StaffHub({super.key});

  @override
  State<StaffHub> createState() => _StaffHubState();
}

class _StaffHubState extends State<StaffHub> {
  @override
  void initState() {
    super.initState();
    ShopManager.instance.initializeTables(20);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: waiterTabIndexNotifier,
      builder: (context, selectedIndex, child) {
        return Scaffold(
          backgroundColor: const Color(0xFFF7F8FA),
          body: Stack(
            children: [
              Column(
                children: [
                  _buildTopNavigationBar(selectedIndex),
                  
                  Expanded(
                    child: IndexedStack(
                      index: selectedIndex,
                      children: [
                        const TablesTab(),
                        ValueListenableBuilder<int?>(
                          valueListenable: activeStaffTableIdNotifier,
                          builder: (context, activeTableId, child) {
                            return MenusTab(tableId: activeTableId ?? 0);
                          },
                        ),
                        const BillsTab(),
                        const AdminTab(),
                        const SettingsTab(),
                      ],
                    ),
                  ),

                  const StaffBottomBar(),
                ],
              ),
              
              // --- GLOBAL ALERT OVERLAY ---
              _buildGlobalAlertOverlay(),
              
              // --- QR SCAN BUTTON (NEW) ---
              Positioned(
                bottom: 100,
                right: 20,
                child: FloatingActionButton.extended(
                  onPressed: _showRedemptionModal,
                  backgroundColor: Colors.black87,
                  icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white),
                  label: const Text("SCAN REWARD", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showRedemptionModal() {
    final codeCtrl = TextEditingController();
    bool isProcessing = false;
    bool isLookingUp = false;
    Map<String, dynamic>? matchedClaim;
    String? lookupError;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5C00).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.verified_rounded, color: Color(0xFFFF5C00), size: 24),
              ),
              const SizedBox(width: 12),
              const Text("Verify Customer Code", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Enter customer claim code (e.g. 55391 or MYS-A2BAF) to preview member & serve reward.", style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: codeCtrl,
                        autofocus: true,
                        style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 16),
                        decoration: InputDecoration(
                          hintText: "E.G. 55391 or MYS-A2BAF",
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          prefixIcon: const Icon(Icons.qr_code_2_rounded, color: Color(0xFFFF5C00)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFFFF5C00), width: 2),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: isLookingUp ? null : () async {
                        final code = codeCtrl.text.trim().toLowerCase();
                        if (code.isEmpty) return;
                        setModalState(() {
                          isLookingUp = true;
                          matchedClaim = null;
                          lookupError = null;
                        });
                        final tenant = TenantService().currentTenant.value;
                        if (tenant == null) return;
                        final res = await ApiService.verifyClaimCode(tenant.id, code);
                        setModalState(() {
                          isLookingUp = false;
                          if (res['status'] == 'success' && res['data'] != null) {
                            matchedClaim = Map<String, dynamic>.from(res['data']);
                            lookupError = null;
                          } else {
                            matchedClaim = null;
                            lookupError = res['message'] ?? "Invalid or non-existent claim code!";
                          }
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5C00),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: isLookingUp
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text("LOOKUP", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),

                if (matchedClaim != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.green.shade300, width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Colors.green, size: 18),
                            const SizedBox(width: 8),
                            const Text("MATCHED MEMBER RECORD", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 11)),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: (matchedClaim!['status'] ?? '').toString().toLowerCase() == 'redeemed' ? Colors.green.shade100 : Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                (matchedClaim!['status'] ?? '').toString().toUpperCase(),
                                style: TextStyle(
                                  color: (matchedClaim!['status'] ?? '').toString().toLowerCase() == 'redeemed' ? Colors.green.shade800 : Colors.orange.shade900,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text("Member: ${matchedClaim!['user_name'] ?? matchedClaim!['user_id']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                        Text("Email: ${matchedClaim!['user_email'] ?? matchedClaim!['user_id']}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        const SizedBox(height: 6),
                        Text("Item: ${matchedClaim!['reward_title'] ?? matchedClaim!['reward_name'] ?? 'Mystery Prize'}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFFF5C00))),
                      ],
                    ),
                  ),
                ],

                if (lookupError != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(lookupError!, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL", style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: isProcessing ? null : () async {
                final code = matchedClaim != null ? (matchedClaim!['claim_code']?.toString() ?? '') : codeCtrl.text.trim().toLowerCase();
                if (code.isEmpty) return;
                setModalState(() => isProcessing = true);
                
                final tenant = TenantService().currentTenant.value;
                if (tenant == null) return;
                
                final res = await ApiService.redeemClaimCode(tenant.id, code);
                
                if (!context.mounted) return;
                
                if (res['status'] == 'success') {
                   Navigator.pop(context);
                   ScaffoldMessenger.of(context).showSnackBar(
                     SnackBar(content: Text(res['message'] ?? "REWARD VERIFIED & SERVED SUCCESSFULLY!"), backgroundColor: Colors.green),
                   );
                } else {
                   setModalState(() => isProcessing = false);
                   ScaffoldMessenger.of(context).showSnackBar(
                     SnackBar(content: Text(res['message'] ?? "Invalid or non-existent claim code!"), backgroundColor: Colors.red),
                   );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5C00),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: isProcessing
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("CONFIRM & SERVE REWARD", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlobalAlertOverlay() {
    return ValueListenableBuilder<Map<int, String>>(
      valueListenable: ShopManager.instance.tableStatuses,
      builder: (context, statuses, child) {
        // Find tables that need help
        final helpNeeded = statuses.entries.where((e) => e.value == "Help Needed").toList();
        
        return ValueListenableBuilder<Map<int, int>>(
          valueListenable: ShopManager.instance.tableCountdownTimers,
          builder: (context, timers, child) {
            // Find tables that are ready
            final readyTables = timers.entries.where((e) => e.value <= 0 && statuses[e.key] == "Dining").toList();
            
            if (helpNeeded.isEmpty && readyTables.isEmpty) return const SizedBox.shrink();

            final int tableId = helpNeeded.isNotEmpty ? helpNeeded.first.key : readyTables.first.key;
            final bool isReady = readyTables.any((e) => e.key == tableId);
            final String floor = tableId < 200 ? "1F" : "2F";
            final String tableNum = (tableId % 100).toString().padLeft(2, '0');

            return Positioned(
              top: 50,
              left: 20,
              right: 20,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 500),
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(0, (1 - value) * -100),
                    child: Opacity(
                      opacity: value,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        decoration: BoxDecoration(
                          color: isReady ? Colors.green : const Color(0xFFFF5C00),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 15, offset: const Offset(0, 5))],
                        ),
                        child: Row(
                          children: [
                            Icon(isReady ? Icons.check_circle : Icons.notifications_active, color: Colors.white),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    isReady ? "ORDER READY" : "HELP NEEDED",
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1),
                                  ),
                                  Text(
                                    "Table $floor - $tableNum is waiting",
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                ShopManager.instance.activeStaffTableId.value = tableId;
                                ShopManager.instance.waiterTabIndex.value = 0; // Go to tables to see it
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: isReady ? Colors.green : const Color(0xFFFF5C00),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                elevation: 0,
                              ),
                              child: const Text("VIEW", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTopNavigationBar(int selectedIndex) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "PayDevice Duo",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black87),
              ),
              Container(
                width: 200,
                height: 35,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const TextField(
                  decoration: InputDecoration(
                    hintText: "Search...",
                    hintStyle: TextStyle(fontSize: 12, color: Colors.grey),
                    prefixIcon: Icon(Icons.search, size: 16, color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildNavItem(0, "Tables", Icons.table_restaurant_rounded, selectedIndex),
              _buildNavItem(1, "Menus", Icons.restaurant_menu_rounded, selectedIndex),
              _buildNavItem(2, "Bills", Icons.receipt_long_rounded, selectedIndex),
              _buildNavItem(3, "Admin", Icons.dashboard_rounded, selectedIndex),
              _buildNavItem(4, "Settings", Icons.settings_rounded, selectedIndex),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, String label, IconData icon, int selectedIndex) {
    bool isSelected = selectedIndex == index;
    return GestureDetector(
      onTap: () => ShopManager.instance.waiterTabIndex.value = index,
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: isSelected ? const Color(0xFFFF5C00) : Colors.grey[400]),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.black87 : Colors.grey[400],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (isSelected)
            Container(width: 40, height: 2, color: const Color(0xFFFF5C00)),
        ],
      ),
    );
  }
}
