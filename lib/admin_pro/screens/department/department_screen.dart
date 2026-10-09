import 'package:flutter/material.dart';
import '../../admin_theme.dart';
import '../../../services/api_service.dart';
import '../../../services/tenant_service.dart';
import '../../../cart_manager.dart';

class DepartmentScreen extends StatefulWidget {
  final Function(String mode)? onNavigateMode;
  const DepartmentScreen({super.key, this.onNavigateMode});

  @override
  State<DepartmentScreen> createState() => _DepartmentScreenState();
}

class _DepartmentScreenState extends State<DepartmentScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = false;
  List<Map<String, dynamic>> _departments = [];

  final List<String> _positions = [
    'Admin / Manager',
    'Head Chef',
    'Waiter / FOH Lead',
    'Bar Assistant',
    'Cashier / Billing',
    'Store / Inventory In-Charge',
    'General Staff',
    'Unassigned',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final tenant = TenantService().currentTenant.value;
    final String tenantId = (tenant != null && tenant.id.isNotEmpty) ? tenant.id : 'startups_main';

    setState(() => _isLoading = true);
    final data = await ApiService.fetchDepartments(tenantId);
    final divs = await ApiService.fetchDivisions(tenantId);
    final staff = await ApiService.fetchStaff(tenantId);

    if (mounted) {
      setState(() {
        _departments = data ?? [];
        if (divs != null && _departments.isNotEmpty) {
          for (var dept in _departments) {
            final deptName = (dept['name'] ?? '').toString().trim().toLowerCase();
            final deptCode = (dept['code'] ?? '').toString().trim().toLowerCase();

            int matchedDivs = divs.where((div) {
              final parent = (div['department_name'] ?? div['department'] ?? '').toString().trim().toLowerCase();
              return parent == deptName || parent == deptCode;
            }).length;

            int matchedStaff = (staff ?? []).where((s) {
              final deptAssigned = (s['department'] ?? '').toString().trim().toLowerCase();
              return deptAssigned == deptName || deptAssigned == deptCode;
            }).length;

            if (matchedDivs > 0) dept['divisions'] = matchedDivs;
            dept['employees'] = matchedStaff;
          }
        }
        _isLoading = false;
      });
      ShopManager.instance.fetchCentralDepartments(tenantId);
    }
  }

  void _showAddEditDepartmentDialog([Map<String, dynamic>? dept]) {
    final nameCtrl = TextEditingController(text: dept?['name'] ?? '');
    final codeCtrl = TextEditingController(text: dept?['code'] ?? '');
    String initialPos = dept?['manager'] ?? _positions.first;
    if (!_positions.contains(initialPos)) initialPos = _positions.first;
    String selectedManager = initialPos;
    bool isActive = (dept?['status'] ?? 'Active') == 'Active';
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
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
                child: const Icon(Icons.business_rounded, color: Color(0xFF2563EB), size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                dept == null ? "Add Department" : "Edit Department",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1F2937)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("DEPARTMENT NAME *", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
                    decoration: InputDecoration(
                      hintText: "e.g. Kitchen Operations",
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text("DEPARTMENT CODE *", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: codeCtrl,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
                    decoration: InputDecoration(
                      hintText: "e.g. KIT, FOH, BAR",
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text("HEAD POSITION / ROLE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280))),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedManager,
                    items: _positions.map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 14)))).toList(),
                    onChanged: (val) => setModalState(() => selectedManager = val!),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Status", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1F2937))),
                      Switch(
                        value: isActive,
                        activeColor: const Color(0xFF2563EB),
                        onChanged: (val) => setModalState(() => isActive = val),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                side: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              child: const Text("Cancel", style: TextStyle(color: Color(0xFF6B7280))),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (nameCtrl.text.trim().isEmpty) return;
                      final tenant = TenantService().currentTenant.value;
                      final String tenantId = (tenant != null && tenant.id.isNotEmpty) ? tenant.id : 'startups_main';

                      setModalState(() => isSubmitting = true);

                      bool success;
                      if (dept == null) {
                        success = await ApiService.addDepartment({
                          'tenant_id': tenantId,
                          'name': nameCtrl.text.trim(),
                          'code': codeCtrl.text.trim().toUpperCase(),
                          'manager': selectedManager,
                          'status': isActive ? 'Active' : 'Inactive',
                        });
                      } else {
                        success = await ApiService.updateDepartment({
                          'id': int.tryParse(dept['id'].toString()) ?? 0,
                          'tenant_id': tenantId,
                          'name': nameCtrl.text.trim(),
                          'code': codeCtrl.text.trim().toUpperCase(),
                          'manager': selectedManager,
                          'status': isActive ? 'Active' : 'Inactive',
                        });
                      }

                      if (ctx.mounted) Navigator.pop(ctx);
                      await _loadData();

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(success
                                ? (dept == null ? "Department Added Successfully!" : "Department Updated!")
                                : "Failed to save department"),
                            backgroundColor: success ? Colors.green : Colors.red,
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: isSubmitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(dept == null ? "Save Department" : "Update"),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteDepartment(String id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Delete Department"),
        content: Text("Are you sure you want to delete '$name'? All associated data will be unassigned."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final idInt = int.tryParse(id) ?? 0;
              if (idInt > 0) {
                await ApiService.deleteDepartment(idInt);
                if (ctx.mounted) Navigator.pop(ctx);
                await _loadData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Department '$name' deleted."), backgroundColor: Colors.redAccent),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _departments.where((d) {
      final query = _searchQuery.toLowerCase();
      final name = (d['name'] ?? '').toString().toLowerCase();
      final code = (d['code'] ?? '').toString().toLowerCase();
      final mgr = (d['manager'] ?? '').toString().toLowerCase();
      return name.contains(query) || code.contains(query) || mgr.contains(query);
    }).toList();

    int totalDivisions = _departments.fold(0, (sum, d) => sum + (int.tryParse(d['divisions']?.toString() ?? '0') ?? 0));
    int totalEmployees = _departments.fold(0, (sum, d) => sum + (int.tryParse(d['employees']?.toString() ?? '0') ?? 0));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- HEADER & ACTION ROW ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Department", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF1F2937))),
                  SizedBox(height: 4),
                  Text("Manage restaurant departments, managers, and employee distribution.", style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddEditDepartmentDialog(),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text("Add Department", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // --- METRICS ROW ---
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildMetricCard("Total Departments", "${_departments.length}", Icons.apartment_rounded, const Color(0xFF2563EB)),
              _buildMetricCard("Total Divisions", "$totalDivisions", Icons.account_tree_rounded, const Color(0xFF10B981)),
              _buildMetricCard("Assigned Staff", "$totalEmployees", Icons.people_alt_rounded, const Color(0xFFF59E0B)),
            ],
          ),
          const SizedBox(height: 28),

          // --- MAIN DATA CARD WITH SEARCH & TABLE ---
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: AdminTheme.softShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // SEARCH BAR
                Row(
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
                            hintText: "Search department name, code, or manager...",
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
                  ],
                ),
                const SizedBox(height: 20),

                // DEPARTMENTS TABLE
                _isLoading
                    ? const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: Color(0xFF2563EB))))
                    : (filtered.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(40),
                              child: Text("No departments found.", style: TextStyle(color: Color(0xFF9CA3AF))),
                            ),
                          )
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 800),
                              child: DataTable(
                                headingRowHeight: 48,
                                dataRowMaxHeight: 64,
                                horizontalMargin: 12,
                                columnSpacing: 24,
                                columns: const [
                                  DataColumn(label: Text("DEPARTMENT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280)))),
                                  DataColumn(label: Text("CODE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280)))),
                                  DataColumn(label: Text("HEAD POSITION / ROLE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280)))),
                                  DataColumn(label: Text("DIVISIONS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280)))),
                                  DataColumn(label: Text("EMPLOYEES", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280)))),
                                  DataColumn(label: Text("STATUS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280)))),
                                  DataColumn(label: Text("ACTIONS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280)))),
                                ],
                                rows: filtered.map((d) {
                                  final bool isActive = d['status'] == 'Active';
                                  final divCount = d['divisions']?.toString() ?? '0';
                                  final empCount = d['employees']?.toString() ?? '0';

                                  return DataRow(
                                    cells: [
                                      DataCell(
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 16,
                                              backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                              child: const Icon(Icons.business_rounded, color: Color(0xFF2563EB), size: 16),
                                            ),
                                            const SizedBox(width: 10),
                                            Text(d['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1F2937))),
                                          ],
                                        ),
                                      ),
                                      DataCell(
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(d['code'] ?? '', style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 11)),
                                        ),
                                      ),
                                      DataCell(Text(d['manager'] ?? 'Unassigned', style: const TextStyle(fontSize: 13, color: Color(0xFF374151)))),
                                      DataCell(Text("$divCount Divisions", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4B5563)))),
                                      DataCell(Text("$empCount Staff", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4B5563)))),
                                      DataCell(
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: isActive ? const Color(0xFFDEF7EC) : const Color(0xFFFDE8E8),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            d['status'] ?? 'Active',
                                            style: TextStyle(
                                              color: isActive ? const Color(0xFF03543F) : const Color(0xFF9B1C1C),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit_rounded, color: Color(0xFF2563EB), size: 18),
                                              tooltip: "Edit Department",
                                              onPressed: () => _showAddEditDepartmentDialog(d),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                                              tooltip: "Delete Department",
                                              onPressed: () => _deleteDepartment(d['id'].toString(), d['name'] ?? 'Department'),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.arrow_forward_rounded, color: Color(0xFF6B7280), size: 18),
                                              tooltip: "Manage Divisions",
                                              onPressed: () => widget.onNavigateMode?.call("Manage Division"),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: 220,
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
              Text(value, style: const TextStyle(color: Color(0xFF1F2937), fontSize: 18, fontWeight: FontWeight.w900)),
            ],
          ),
        ],
      ),
    );
  }
}
