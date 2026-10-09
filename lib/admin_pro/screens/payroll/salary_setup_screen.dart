import 'package:flutter/material.dart';
import '../../admin_theme.dart';
import '../../../services/api_service.dart';
import '../../../services/tenant_service.dart';
import '../../../cart_manager.dart';

class SalarySetupScreen extends StatefulWidget {
  const SalarySetupScreen({super.key});

  @override
  State<SalarySetupScreen> createState() => _SalarySetupScreenState();
}

class _SalarySetupScreenState extends State<SalarySetupScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _selectedDeptFilter = 'All';
  bool _isLoading = false;

  List<Map<String, dynamic>> _staffList = [];
  List<String> _deptFilters = ['All', 'Kitchen', 'Front of House', 'Bar & Beverage', 'Inventory & Procurement', 'Management & Admin'];

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

    ShopManager.instance.fetchCentralDepartments(tenantId);
    final data = await ApiService.fetchStaff(tenantId);
    final salarySetups = await ApiService.fetchSalarySetups(tenantId);
    final depts = await ApiService.fetchDepartments(tenantId);

    if (mounted && data != null) {
      if (depts != null && depts.isNotEmpty) {
        _deptFilters = ['All', ...depts.map((d) => (d['name'] ?? '').toString()).where((n) => n.isNotEmpty)];
      }

      for (var s in data) {
        final uid = int.tryParse(s['id'].toString()) ?? 0;
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
      }

      setState(() {
        _staffList = data;
        _isLoading = false;
      });
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showEditSalaryDialog(Map<String, dynamic> s) {
    final salaryCtrl = TextEditingController(text: (s['salary_amount'] ?? '0.00').toString());
    final cycleCtrl = TextEditingController(text: (s['payment_cycle_days'] ?? '30').toString());

    DateTime selectedStartDate = DateTime.tryParse(s['salary_start_date']?.toString() ?? '') ??
        DateTime.tryParse(s['created_at']?.toString() ?? s['joining_date']?.toString() ?? '') ??
        DateTime.now();

    String selectedSalaryType = s['salary_type']?.toString() ?? 'Fixed Monthly';
    final List<String> salaryTypes = ['Fixed Monthly', 'Hourly', 'Base + Incentive', 'Commission'];
    if (!salaryTypes.contains(selectedSalaryType)) selectedSalaryType = 'Fixed Monthly';

    String selectedDept = s['department']?.toString() ?? 'Kitchen';
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final depts = ShopManager.instance.departmentsList.value;
          final List<String> deptNames = depts.isNotEmpty
              ? depts.map((d) => (d['name'] ?? '').toString()).where((n) => n.isNotEmpty).toList()
              : ['Kitchen', 'Front of House', 'Bar & Beverage', 'Inventory & Procurement', 'Management & Admin'];
          if (!deptNames.contains(selectedDept) && deptNames.isNotEmpty) {
            selectedDept = deptNames.first;
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: Colors.white,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.payments_rounded, color: Color(0xFF2563EB), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Edit Salary Setup", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1F2937))),
                      Text("Staff: ${s['name']}", style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                    ],
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("MONTHLY BASE SALARY (NPR) *", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: salaryCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                      decoration: InputDecoration(
                        hintText: "e.g. 25000",
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text("SALARY START DATE *", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280))),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedStartDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setModalState(() => selectedStartDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "${selectedStartDate.year}-${selectedStartDate.month.toString().padLeft(2, '0')}-${selectedStartDate.day.toString().padLeft(2, '0')}",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1F2937)),
                            ),
                            const Icon(Icons.calendar_today_rounded, color: Color(0xFF2563EB), size: 18),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("SALARY TYPE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280))),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                initialValue: selectedSalaryType,
                                items: salaryTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13)))).toList(),
                                onChanged: (v) => setModalState(() => selectedSalaryType = v!),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("PAYMENT CYCLE (DAYS)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280))),
                              const SizedBox(height: 6),
                              TextField(
                                controller: cycleCtrl,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                                decoration: InputDecoration(
                                  hintText: "30",
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    const Text("DEPARTMENT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280))),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: selectedDept,
                      items: deptNames.map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 13)))).toList(),
                      onChanged: (v) => setModalState(() => selectedDept = v!),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: isSubmitting ? null : () => Navigator.pop(ctx), child: const Text("Cancel")),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final tenant = TenantService().currentTenant.value;
                        final tenantId = (tenant != null && tenant.id.isNotEmpty) ? tenant.id : 'startups_main';
                        final userId = int.tryParse(s['id']?.toString() ?? s['user_id']?.toString() ?? '0') ?? 0;

                        if (userId <= 0) return;

                        setModalState(() => isSubmitting = true);

                        final dateStr = "${selectedStartDate.year}-${selectedStartDate.month.toString().padLeft(2, '0')}-${selectedStartDate.day.toString().padLeft(2, '0')}";

                        final success = await ApiService.updateSalarySetup({
                          'tenant_id': tenantId,
                          'user_id': userId,
                          'salary_amount': double.tryParse(salaryCtrl.text.trim()) ?? 0.0,
                          'salary_start_date': dateStr,
                          'payment_cycle_days': int.tryParse(cycleCtrl.text.trim()) ?? 30,
                          'salary_type': selectedSalaryType,
                          'department': selectedDept,
                        });

                        if (ctx.mounted) Navigator.pop(ctx);
                        await _loadStaff();

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(success ? "Salary setup updated successfully!" : "Failed to update salary"),
                              backgroundColor: success ? Colors.green : Colors.red,
                            ),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                child: isSubmitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("SAVE CHANGES"),
              ),
            ],
          );
        },
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
      final matchesSearch = name.contains(q) || role.contains(q) || dept.contains(q);
      final matchesDept = _selectedDeptFilter == 'All' || (s['department'] ?? 'Kitchen') == _selectedDeptFilter;
      return matchesSearch && matchesDept;
    }).toList();

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
                  Text("Salary Setup", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF1F2937))),
                  SizedBox(height: 4),
                  Text("Configure employee base salaries, start dates, payment cycle days, and departments.", style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                ],
              ),
              IconButton(onPressed: _loadStaff, icon: const Icon(Icons.refresh_rounded, color: Color(0xFF2563EB), size: 24)),
            ],
          ),
          const SizedBox(height: 24),

          // SEARCH & FILTER CARD
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: AdminTheme.softShadow,
            ),
            child: Row(
              children: [
                Expanded(
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
                const SizedBox(width: 16),
                SizedBox(
                  height: 44,
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedDeptFilter,
                    items: _deptFilters.map((df) => DropdownMenuItem(value: df, child: Text(df, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)))).toList(),
                    onChanged: (val) => setState(() => _selectedDeptFilter = val!),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // MASTER STAFF SALARY LIST
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
                        final double salary = double.tryParse(s['salary_amount']?.toString() ?? '0') ?? 0;
                        final int cycle = int.tryParse(s['payment_cycle_days']?.toString() ?? '30') ?? 30;
                        final String salaryType = s['salary_type']?.toString() ?? 'Fixed Monthly';
                        final String dept = s['department']?.toString() ?? 'Kitchen';

                        DateTime joinDate = DateTime.tryParse(s['created_at']?.toString() ?? s['joining_date']?.toString() ?? '') ?? DateTime.now();
                        DateTime startDate = DateTime.tryParse(s['salary_start_date']?.toString() ?? '') ?? joinDate;

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
                                    decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.green.shade200)),
                                    child: Text(
                                      "NPR ${salary.toStringAsFixed(0)} / mo",
                                      style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.w900, fontSize: 13),
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
                                  Row(
                                    children: [
                                      const Icon(Icons.calendar_month_rounded, size: 16, color: Color(0xFF2563EB)),
                                      const SizedBox(width: 6),
                                      Text("Start: ${startDate.day} ${_months[startDate.month - 1]} ${startDate.year}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      const Icon(Icons.category_rounded, size: 16, color: Colors.grey),
                                      const SizedBox(width: 6),
                                      Text("$salaryType ($cycle Days)", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4B5563))),
                                    ],
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: () => _showEditSalaryDialog(s),
                                    icon: const Icon(Icons.edit_rounded, size: 14),
                                    label: const Text("Edit Salary Setup", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2563EB),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
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
}
