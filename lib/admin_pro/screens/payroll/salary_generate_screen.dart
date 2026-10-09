import 'package:flutter/material.dart';
import '../../admin_theme.dart';
import '../../../services/api_service.dart';
import '../../../services/tenant_service.dart';
import '../../../cart_manager.dart';
import '../../../widgets/signature_canvas_widget.dart';

class SalaryGenerateScreen extends StatefulWidget {
  const SalaryGenerateScreen({super.key});

  @override
  State<SalaryGenerateScreen> createState() => _SalaryGenerateScreenState();
}

class _SalaryGenerateScreenState extends State<SalaryGenerateScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = false;

  List<Map<String, dynamic>> _staffList = [];
  final List<String> _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStaff() async {
    final tenant = TenantService().currentTenant.value;
    final String tenantId = (tenant != null && tenant.id.isNotEmpty) ? tenant.id : 'startups_main';

    setState(() => _isLoading = true);

    final data = await ApiService.fetchStaff(tenantId);
    final salarySetups = await ApiService.fetchSalarySetups(tenantId);
    final allPayouts = await ApiService.fetchSalaryPayoutHistory(tenantId);

    if (mounted && data != null) {
      final month = "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}";
      for (var s in data) {
        final uid = int.tryParse(s['id'].toString()) ?? 0;
        if (uid > 0) {
          final statsData = await ApiService.fetchEmployeeStats(uid, month);
          if (statsData != null && statsData['status'] == 'success') {
            s['present_days'] = statsData['stats']['present'] ?? 0;
          } else {
            s['present_days'] = 0;
          }
        }

        if (salarySetups != null) {
          final setup = salarySetups.firstWhere(
            (st) => int.tryParse(st['user_id']?.toString() ?? '0') == uid,
            orElse: () => <String, dynamic>{},
          );
          if (setup.isNotEmpty) {
            if (setup['salary_amount'] != null) s['salary_amount'] = setup['salary_amount'];
            if (setup['salary_start_date'] != null) s['salary_start_date'] = setup['salary_start_date'];
            if (setup['payment_cycle_days'] != null) s['payment_cycle_days'] = setup['payment_cycle_days'];
            if (setup['salary_type'] != null) s['salary_type'] = setup['salary_type'];
            if (setup['department'] != null) s['department'] = setup['department'];
          }
        }

        // Calculate total paid and remaining unpaid balance
        double totalPaid = 0.0;
        if (allPayouts != null) {
          final userPayouts = allPayouts.where((p) => (int.tryParse(p['user_id']?.toString() ?? '0') ?? 0) == uid);
          for (var p in userPayouts) {
            totalPaid += double.tryParse(p['payout_amount']?.toString() ?? '0') ?? 0.0;
          }
        }
        s['total_paid'] = totalPaid;

        final double baseSalary = double.tryParse(s['salary_amount']?.toString() ?? '0') ?? 0;
        final int cycle = int.tryParse(s['payment_cycle_days']?.toString() ?? '30') ?? 30;
        final int daysPassed = int.tryParse(s['present_days']?.toString() ?? '0') ?? 0;
        final double dailyRate = cycle > 0 ? baseSalary / cycle : 0;
        final double totalEarned = daysPassed * dailyRate > 0 ? daysPassed * dailyRate : baseSalary;
        s['total_earned'] = totalEarned;

        final double remainingUnpaid = totalEarned > totalPaid ? (totalEarned - totalPaid) : 0.0;
        s['remaining_unpaid'] = remainingUnpaid;
      }

      setState(() {
        _staffList = data;
        _isLoading = false;
      });
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSalaryClearanceModal(Map<String, dynamic> s) {
    final GlobalKey<SignatureCanvasWidgetState> sigKey = GlobalKey<SignatureCanvasWidgetState>();
    final notesCtrl = TextEditingController(text: "Salary payout cleared for ${s['name']}");
    String paymentMethod = "Cash";
    final List<String> methods = ["Cash", "Bank Transfer", "eSewa", "Khalti", "Cheque"];
    bool isSaving = false;

    final double baseSalary = double.tryParse(s['salary_amount']?.toString() ?? '0') ?? 0;
    final int cycle = int.tryParse(s['payment_cycle_days']?.toString() ?? '30') ?? 30;
    final int daysPassed = int.tryParse(s['present_days']?.toString() ?? '0') ?? 0;
    final double dailyRate = cycle > 0 ? baseSalary / cycle : 0;
    final double totalEarned = s['total_earned'] != null ? (double.tryParse(s['total_earned'].toString()) ?? 0.0) : (daysPassed * dailyRate > 0 ? daysPassed * dailyRate : baseSalary);
    final double totalPaid = s['total_paid'] != null ? (double.tryParse(s['total_paid'].toString()) ?? 0.0) : 0.0;
    final double remainingUnpaid = s['remaining_unpaid'] != null ? (double.tryParse(s['remaining_unpaid'].toString()) ?? 0.0) : (totalEarned > totalPaid ? totalEarned - totalPaid : 0.0);

    final String monthStr = "${_months[DateTime.now().month - 1]} ${DateTime.now().year}";

    final payoutAmountCtrl = TextEditingController(
      text: remainingUnpaid > 0 ? remainingUnpaid.toStringAsFixed(2) : "0.00",
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: Colors.white,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.verified_user_rounded, color: Colors.green, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Salary Payout & Clearance", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1F2937))),
                    Text("Clearance for ${s['name']} (${s['role'] ?? 'Staff'})", style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Total Earned: NPR ${totalEarned.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1F2937))),
                            Text("Already Paid: NPR ${totalPaid.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue)),
                          ],
                        ),
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("UNPAID REMAINING BALANCE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                            Text("NPR ${remainingUnpaid.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.green)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text("PAYOUT AMOUNT TO CLEAR (NPR) *", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: payoutAmountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1F2937)),
                    decoration: InputDecoration(
                      hintText: "Enter amount to pay...",
                      suffixText: remainingUnpaid > 0 ? "Max Cap: NPR ${remainingUnpaid.toStringAsFixed(2)}" : null,
                      suffixStyle: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text("PAYMENT METHOD *", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280))),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: paymentMethod,
                    items: methods.map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 13)))).toList(),
                    onChanged: (v) => setModalState(() => paymentMethod = v!),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text("PAYMENT NOTES / REMARKS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: notesCtrl,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: "e.g. Salary paid in cash for Oct 2026",
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Text("EMPLOYEE DIGITAL SIGNATURE *", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280))),
                  const SizedBox(height: 8),
                  SignatureCanvasWidget(
                    key: sigKey,
                    height: 160,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: const Text("Cancel", style: TextStyle(color: Color(0xFF6B7280))),
            ),
            ElevatedButton.icon(
              onPressed: isSaving
                  ? null
                  : () async {
                      final double enteredPayout = double.tryParse(payoutAmountCtrl.text.trim()) ?? 0.0;
                      if (enteredPayout <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter a valid payout amount!"), backgroundColor: Colors.orange));
                        return;
                      }
                      if (remainingUnpaid > 0 && enteredPayout > (remainingUnpaid + 0.01)) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Payout amount cannot exceed remaining unpaid balance (NPR ${remainingUnpaid.toStringAsFixed(2)})!"), backgroundColor: Colors.red));
                        return;
                      }

                      final sigState = sigKey.currentState;
                      if (sigState == null || !sigState.hasSignature) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please draw employee digital signature before clearing!"), backgroundColor: Colors.orange));
                        return;
                      }

                      final tenant = TenantService().currentTenant.value;
                      final tenantId = (tenant != null && tenant.id.isNotEmpty) ? tenant.id : 'startups_main';
                      final userId = int.tryParse(s['id']?.toString() ?? '') ?? int.tryParse(s['user_id']?.toString() ?? '') ?? 0;

                      if (userId <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cannot save payout: Invalid employee ID"), backgroundColor: Colors.red));
                        return;
                      }

                      setModalState(() => isSaving = true);

                      final sigStrokesStr = sigState.exportStrokesData();

                      final res = await ApiService.saveSalaryPayout({
                        'tenant_id': tenantId,
                        'user_id': userId,
                        'payout_month': monthStr,
                        'payout_amount': enteredPayout,
                        'payment_method': paymentMethod,
                        'payment_notes': notesCtrl.text.trim(),
                        'signature_data': sigStrokesStr,
                        'paid_by': 'Admin',
                      });

                      if (ctx.mounted) Navigator.pop(ctx);
                      await _loadStaff();

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(res['status'] == 'success' ? "Salary payout cleared & signature saved!" : "Failed to save payout receipt"),
                            backgroundColor: res['status'] == 'success' ? Colors.green : Colors.red,
                          ),
                        );
                      }
                    },
              icon: const Icon(Icons.check_circle_rounded, size: 18),
              label: isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("CONFIRM PAYOUT & SAVE RECEIPT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ],
        ),
      ),
    );
  }

  void _showPayoutHistoryModal(Map<String, dynamic> s) {
    final tenant = TenantService().currentTenant.value;
    final tenantId = (tenant != null && tenant.id.isNotEmpty) ? tenant.id : 'startups_main';
    final userId = int.tryParse(s['id']?.toString() ?? '') ?? int.tryParse(s['user_id']?.toString() ?? '') ?? 0;
    bool showAll = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => FutureBuilder<List<Map<String, dynamic>>?>(
          future: ApiService.fetchSalaryPayoutHistory(tenantId, userId: showAll ? null : userId),
          builder: (context, snapshot) {
            final history = snapshot.data ?? [];
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              backgroundColor: Colors.white,
              title: Row(
                children: [
                  const Icon(Icons.history_edu_rounded, color: Color(0xFF2563EB), size: 26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Salary Payout Receipts & History", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1F2937))),
                        Text(showAll ? "All Restaurant Receipts" : "Receipts for ${s['name']}", style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 500,
                height: 420,
                child: snapshot.connectionState == ConnectionState.waiting
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
                    : (history.isEmpty
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey),
                              const SizedBox(height: 12),
                              Text("No payout receipts found for ${s['name']}.", style: const TextStyle(color: Colors.grey, fontSize: 13)),
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                onPressed: () => setModalState(() => showAll = true),
                                icon: const Icon(Icons.list_alt_rounded, size: 16),
                                label: const Text("View All Restaurant Receipts"),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF2563EB),
                                  side: const BorderSide(color: Color(0xFF2563EB)),
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            itemCount: history.length,
                            itemBuilder: (context, index) {
                              final h = history[index];
                              final DateTime paidAt = DateTime.tryParse(h['paid_at']?.toString() ?? '') ?? DateTime.now();
                              final String sigStr = h['signature_data']?.toString() ?? '';
                              final String empName = (h['user_name'] != null && h['user_name'].toString().isNotEmpty)
                                  ? h['user_name']
                                  : (s['name'] ?? 'Employee');

                              return Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text("Staff: $empName", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1F2937))),
                                        Text("NPR ${(double.tryParse(h['payout_amount']?.toString() ?? '0') ?? 0).toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.green, fontSize: 16)),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text("Cycle: ${h['payout_month'] ?? 'N/A'} • Paid on: ${paidAt.day} ${_months[paidAt.month - 1]} ${paidAt.year} (${h['payment_method'] ?? 'Cash'})", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                    if ((h['payment_notes'] ?? '').toString().isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text("Notes: ${h['payment_notes']}", style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                                    ],
                                    const SizedBox(height: 12),
                                    const Text("SAVED DIGITAL SIGNATURE:", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                                    const SizedBox(height: 6),
                                    SavedSignatureViewer(
                                      strokesData: sigStr,
                                      height: 80,
                                    ),
                                  ],
                                ),
                              );
                            },
                          )),
              ),
              actions: [
                if (!showAll)
                  TextButton(
                    onPressed: () => setModalState(() => showAll = true),
                    child: const Text("View All Receipts"),
                  )
                else
                  TextButton(
                    onPressed: () => setModalState(() => showAll = false),
                    child: Text("Filter for ${s['name']}"),
                  ),
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close")),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _staffList.where((s) {
      final q = _searchQuery.toLowerCase();
      final name = (s['name'] ?? '').toString().toLowerCase();
      final role = (s['role'] ?? '').toString().toLowerCase();
      final dept = (s['department'] ?? '').toString().toLowerCase();
      return name.contains(q) || role.contains(q) || dept.contains(q);
    }).toList();

    double totalEarnedSum = 0;
    double totalPaidSum = 0;
    double totalUnpaidSum = 0;

    for (var s in _staffList) {
      totalEarnedSum += double.tryParse(s['total_earned']?.toString() ?? '0') ?? 0;
      totalPaidSum += double.tryParse(s['total_paid']?.toString() ?? '0') ?? 0;
      totalUnpaidSum += double.tryParse(s['remaining_unpaid']?.toString() ?? '0') ?? 0;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER ROW
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Salary Generation & Payout Clearance", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF1F2937))),
                  SizedBox(height: 4),
                  Text("Attendance-based payout estimations, clearance processing, and digital signature receipts.", style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                ],
              ),
              IconButton(onPressed: _loadStaff, icon: const Icon(Icons.refresh_rounded, color: Color(0xFF2563EB), size: 24)),
            ],
          ),
          const SizedBox(height: 24),

          // SUMMARY METRICS CARDS
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildSummaryCard("Total Earned Payroll", "NPR ${totalEarnedSum.toStringAsFixed(0)}", Icons.payments_rounded, const Color(0xFF2563EB)),
              _buildSummaryCard("Total Cleared Payout", "NPR ${totalPaidSum.toStringAsFixed(0)}", Icons.verified_rounded, const Color(0xFF10B981)),
              _buildSummaryCard("Unpaid Remaining Balance", "NPR ${totalUnpaidSum.toStringAsFixed(0)}", Icons.pending_actions_rounded, const Color(0xFFF59E0B)),
            ],
          ),
          const SizedBox(height: 28),

          // SEARCH CARD
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: AdminTheme.softShadow,
            ),
            child: SizedBox(
              height: 44,
              child: TextField(
                controller: _searchCtrl,
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF9CA3AF), size: 20),
                  hintText: "Search employee name, role, or department...",
                  hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // MASTER STAFF CLEARANCE LIST
          _isLoading
              ? const Padding(padding: EdgeInsets.all(60), child: Center(child: CircularProgressIndicator(color: Color(0xFF2563EB))))
              : (filtered.isEmpty
                  ? const Padding(padding: EdgeInsets.all(60), child: Center(child: Text("No employees found matching filter.", style: TextStyle(color: Colors.grey))))
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final s = filtered[index];
                        final String dept = s['department']?.toString() ?? 'Kitchen';

                        DateTime joinDate = DateTime.tryParse(s['created_at']?.toString() ?? s['joining_date']?.toString() ?? '') ?? DateTime.now();

                        final double totalEarned = s['total_earned'] != null ? (double.tryParse(s['total_earned'].toString()) ?? 0.0) : 0.0;
                        final double totalPaid = s['total_paid'] != null ? (double.tryParse(s['total_paid'].toString()) ?? 0.0) : 0.0;
                        final double remainingUnpaid = s['remaining_unpaid'] != null ? (double.tryParse(s['remaining_unpaid'].toString()) ?? 0.0) : 0.0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: AdminTheme.softShadow,
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                    backgroundImage: (s['profile_pic_url'] != null && s['profile_pic_url'].isNotEmpty)
                                        ? NetworkImage(s['profile_pic_url'])
                                        : null,
                                    child: (s['profile_pic_url'] == null || s['profile_pic_url'].isEmpty)
                                        ? Text((s['name'] ?? 'E')[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB)))
                                        : null,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(s['name'] ?? 'Staff', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1F2937))),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(color: const Color(0xFF2563EB).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                                              child: Text(dept, style: const TextStyle(fontSize: 10, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text("${s['role'] ?? 'Employee'} • Joined: ${joinDate.day} ${_months[joinDate.month - 1]} ${joinDate.year}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: remainingUnpaid > 0 ? Colors.orange.shade50 : Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: remainingUnpaid > 0 ? Colors.orange.shade300 : Colors.green.shade300),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          "Unpaid: NPR ${remainingUnpaid.toStringAsFixed(0)}",
                                          style: TextStyle(color: remainingUnpaid > 0 ? Colors.orange.shade900 : Colors.green.shade800, fontWeight: FontWeight.w900, fontSize: 13),
                                        ),
                                        Text(
                                          "Paid: NPR ${totalPaid.toStringAsFixed(0)}",
                                          style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 14),
                                child: Divider(height: 1),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("Earned Total: NPR ${totalEarned.toStringAsFixed(0)}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF374151))),
                                  Row(
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: () => _showSalaryClearanceModal(s),
                                        icon: const Icon(Icons.check_circle_rounded, size: 14),
                                        label: const Text("PAY SALARY & CLEARANCE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.history_edu_rounded, color: Color(0xFF2563EB), size: 20),
                                        tooltip: "View Paid Receipts & Signatures",
                                        onPressed: () => _showPayoutHistoryModal(s),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    )),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: 240,
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
              Text(title, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900)),
            ],
          ),
        ],
      ),
    );
  }
}
