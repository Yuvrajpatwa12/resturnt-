import 'package:flutter/material.dart';
import '../../admin_theme.dart';
import '../../../services/api_service.dart';
import '../../../services/tenant_service.dart';
import '../../../cart_manager.dart';

class ManageDivisionScreen extends StatefulWidget {
  final Function(String mode)? onNavigateMode;
  const ManageDivisionScreen({super.key, this.onNavigateMode});

  @override
  State<ManageDivisionScreen> createState() => _ManageDivisionScreenState();
}

class _ManageDivisionScreenState extends State<ManageDivisionScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _selectedDeptFilter = 'All';
  bool _isLoading = false;

  List<String> _deptFilters = [
    'All',
    'Kitchen',
    'Front of House',
    'Bar & Beverage',
    'Inventory & Procurement',
    'Management & Admin',
  ];

  List<Map<String, dynamic>> _divisions = [];

  List<String> _staffDirectory = [];

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
    final depts = await ApiService.fetchDepartments(tenantId);
    final divs = await ApiService.fetchDivisions(tenantId);
    final staffData = await ApiService.fetchStaff(tenantId);

    if (mounted) {
      setState(() {
        if (depts != null && depts.isNotEmpty) {
          _deptFilters = ['All', ...depts.map((d) => (d['name'] ?? '').toString()).where((n) => n.isNotEmpty)];
        }
        if (staffData != null && staffData.isNotEmpty) {
          _staffDirectory = staffData
              .map((s) => (s['name'] ?? '').toString().trim())
              .where((n) => n.isNotEmpty)
              .toList();
        }
        _divisions = divs ?? [];
        _isLoading = false;
      });
    }
  }

  void _showAssignStaffModal(Map<String, dynamic> div) {
    List<dynamic> rawAssigned = div['assigned_staff'] is List ? div['assigned_staff'] : [];
    Set<String> assigned = Set<String>.from(rawAssigned.map((e) => e.toString()));

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
                child: const Icon(Icons.people_alt_rounded, color: Color(0xFF2563EB), size: 24),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Assign Staff", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1F2937))),
                  Text("Division: ${div['name']} (${div['code']})", style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                ],
              ),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("SELECT EMPLOYEES TO ASSIGN:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280))),
                  const SizedBox(height: 12),
                  ..._staffDirectory.map((staff) {
                    final isChecked = assigned.contains(staff);
                    return CheckboxListTile(
                      value: isChecked,
                      activeColor: const Color(0xFF2563EB),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(staff, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      subtitle: Text(staff == div['supervisor'] ? 'Supervisor / Lead' : 'Staff Member', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      onChanged: (val) {
                        setModalState(() {
                          if (val == true) {
                            assigned.add(staff);
                          } else {
                            assigned.remove(staff);
                          }
                        });
                      },
                    );
                  }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel", style: TextStyle(color: Color(0xFF6B7280))),
            ),
            ElevatedButton(
              onPressed: () async {
                final divId = int.tryParse(div['id'].toString()) ?? 0;
                final staffList = assigned.toList();

                setState(() {
                  div['staff_count'] = assigned.length;
                  div['assigned_staff'] = staffList;
                });

                if (divId > 0) {
                  await ApiService.assignDivisionStaff(divId, assigned.length, staffList);
                  await _loadData();
                }

                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Staff updated for ${div['name']} (${assigned.length} assigned)"), backgroundColor: Colors.green),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
              child: const Text("Save Assignments"),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDivisionModal(Map<String, dynamic> div) {
    final nameCtrl = TextEditingController(text: div['name'] ?? '');
    final codeCtrl = TextEditingController(text: div['code'] ?? '');

    final List<String> availableDepts = _deptFilters
        .where((d) => d != 'All')
        .toSet()
        .toList();
    if (availableDepts.isEmpty) availableDepts.add('Kitchen');

    String initialDept = (div['department_name'] ?? div['department'] ?? availableDepts.first).toString();
    if (!availableDepts.contains(initialDept)) {
      availableDepts.insert(0, initialDept);
    }
    String selectedDept = initialDept;

    final List<String> availableSups = _staffDirectory.toSet().toList();
    if (!availableSups.contains('Unassigned')) availableSups.add('Unassigned');

    String initialSup = (div['supervisor'] ?? 'Unassigned').toString();
    if (initialSup.isEmpty) initialSup = 'Unassigned';
    if (!availableSups.contains(initialSup)) {
      availableSups.insert(0, initialSup);
    }
    String selectedSup = initialSup;

    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          title: const Text("Edit Division", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("DIVISION NAME", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Text("SHORT CODE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: codeCtrl,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Text("PARENT DEPARTMENT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280))),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedDept,
                    items: availableDepts.map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 13)))).toList(),
                    onChanged: (val) => setModalState(() => selectedDept = val!),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Text("SUPERVISOR", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280))),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedSup,
                    items: availableSups.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13)))).toList(),
                    onChanged: (val) => setModalState(() => selectedSup = val!),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: isSaving ? null : () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      setModalState(() => isSaving = true);
                      await ApiService.updateDivision({
                        'id': int.tryParse(div['id'].toString()) ?? 0,
                        'department_name': selectedDept,
                        'name': nameCtrl.text.trim(),
                        'code': codeCtrl.text.trim().toUpperCase(),
                        'supervisor': selectedSup,
                        'status': div['status'] ?? 'Active',
                      });
                      if (ctx.mounted) Navigator.pop(ctx);
                      await _loadData();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Division updated!"), backgroundColor: Colors.green));
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
              child: isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("Save Changes"),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteDivision(String id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Delete Division"),
        content: Text("Are you sure you want to delete division '$name'?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final idInt = int.tryParse(id) ?? 0;
              if (idInt > 0) {
                await ApiService.deleteDivision(idInt);
                if (ctx.mounted) Navigator.pop(ctx);
                await _loadData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Division '$name' deleted."), backgroundColor: Colors.redAccent),
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
    final filtered = _divisions.where((d) {
      final query = _searchQuery.toLowerCase();
      final deptName = d['department_name'] ?? d['department'] ?? '';
      final matchesSearch = (d['name'] ?? '').toString().toLowerCase().contains(query) ||
          (d['code'] ?? '').toString().toLowerCase().contains(query) ||
          (d['supervisor'] ?? '').toString().toLowerCase().contains(query);
      final matchesDept = _selectedDeptFilter == 'All' || deptName == _selectedDeptFilter;
      return matchesSearch && matchesDept;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- HEADER ROW ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Manage Division", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF1F2937))),
                  SizedBox(height: 4),
                  Text("Overview of operational divisions, staff assignments, and active stations.", style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => widget.onNavigateMode?.call("Add Division"),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text("Add Division", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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

          // --- FILTER & SEARCH CARD ---
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
                // SEARCH & DROPDOWN FILTER ROW
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 44,
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: (val) => setState(() => _searchQuery = val.trim()),
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF9CA3AF), size: 20),
                            hintText: "Search division name, code, or supervisor...",
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
                        value: _selectedDeptFilter,
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
                const SizedBox(height: 20),

                // DIVISIONS DATA TABLE
                _isLoading
                    ? const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: Color(0xFF2563EB))))
                    : (filtered.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(40),
                              child: Text("No divisions found matching your filter.", style: TextStyle(color: Color(0xFF9CA3AF))),
                            ),
                          )
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 850),
                              child: DataTable(
                                headingRowHeight: 48,
                                dataRowMaxHeight: 64,
                                horizontalMargin: 12,
                                columnSpacing: 24,
                                columns: const [
                                  DataColumn(label: Text("DIVISION NAME", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280)))),
                                  DataColumn(label: Text("CODE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280)))),
                                  DataColumn(label: Text("PARENT DEPARTMENT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280)))),
                                  DataColumn(label: Text("SUPERVISOR / LEAD", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280)))),
                                  DataColumn(label: Text("STAFF COUNT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280)))),
                                  DataColumn(label: Text("STATUS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280)))),
                                  DataColumn(label: Text("ACTIONS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280)))),
                                ],
                                rows: filtered.map((div) {
                                  final bool isActive = div['status'] == 'Active';
                                  final deptName = div['department_name'] ?? div['department'] ?? 'Kitchen';
                                  final staffCount = div['staff_count']?.toString() ?? '0';

                                  return DataRow(
                                    cells: [
                                      DataCell(
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 16,
                                              backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.1),
                                              child: const Icon(Icons.account_tree_rounded, color: Color(0xFF10B981), size: 16),
                                            ),
                                            const SizedBox(width: 10),
                                            Text(div['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1F2937))),
                                          ],
                                        ),
                                      ),
                                      DataCell(
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF10B981).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(div['code'] ?? '', style: const TextStyle(color: Color(0xFF047857), fontWeight: FontWeight.bold, fontSize: 11)),
                                        ),
                                      ),
                                      DataCell(Text(deptName, style: const TextStyle(fontSize: 13, color: Color(0xFF374151)))),
                                      DataCell(Text(div['supervisor'] ?? 'Unassigned', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)))),
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text("$staffCount Staff", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                                            const SizedBox(width: 6),
                                            InkWell(
                                              onTap: () => _showAssignStaffModal(div),
                                              borderRadius: BorderRadius.circular(6),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: const Text("Assign", style: TextStyle(color: Color(0xFF2563EB), fontSize: 10, fontWeight: FontWeight.bold)),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      DataCell(
                                        Switch(
                                          value: isActive,
                                          activeColor: const Color(0xFF10B981),
                                          onChanged: (val) async {
                                            setState(() => div['status'] = val ? 'Active' : 'Inactive');
                                            await ApiService.updateDivision({
                                              'id': int.tryParse(div['id'].toString()) ?? 0,
                                              'department_name': deptName,
                                              'name': div['name'],
                                              'code': div['code'],
                                              'supervisor': div['supervisor'],
                                              'status': val ? 'Active' : 'Inactive',
                                            });
                                          },
                                        ),
                                      ),
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit_rounded, color: Color(0xFF2563EB), size: 18),
                                              tooltip: "Edit Division",
                                              onPressed: () => _showEditDivisionModal(div),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF10B981), size: 18),
                                              tooltip: "Assign Staff",
                                              onPressed: () => _showAssignStaffModal(div),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                                              tooltip: "Delete Division",
                                              onPressed: () => _deleteDivision(div['id'].toString(), div['name'] ?? 'Division'),
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
}
