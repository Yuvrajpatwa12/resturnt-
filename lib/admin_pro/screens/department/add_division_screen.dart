import 'package:flutter/material.dart';
import '../../admin_theme.dart';
import '../../../services/api_service.dart';
import '../../../services/tenant_service.dart';
import '../../../cart_manager.dart';

class AddDivisionScreen extends StatefulWidget {
  final Function(String mode)? onNavigateMode;
  const AddDivisionScreen({super.key, this.onNavigateMode});

  @override
  State<AddDivisionScreen> createState() => _AddDivisionScreenState();
}

class _AddDivisionScreenState extends State<AddDivisionScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _codeCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();

  String _selectedDepartment = 'Kitchen';
  String _selectedSupervisor = 'Unassigned';
  bool _isActive = true;
  bool _isSaving = false;

  List<String> _departments = [
    'Kitchen',
    'Front of House',
    'Bar & Beverage',
    'Inventory & Procurement',
    'Management & Admin',
  ];

  List<String> _supervisors = [
    'Unassigned',
  ];

  final List<String> _availableShifts = ['Morning', 'Evening', 'Night', 'Full Day'];
  final Set<String> _selectedShifts = {'Morning', 'Evening'};

  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDepartments() async {
    final tenant = TenantService().currentTenant.value;
    final String tenantId = (tenant != null && tenant.id.isNotEmpty) ? tenant.id : 'startups_main';

    final depts = await ApiService.fetchDepartments(tenantId);
    final staffData = await ApiService.fetchStaff(tenantId);

    if (mounted) {
      setState(() {
        if (depts != null && depts.isNotEmpty) {
          _departments = depts.map((d) => (d['name'] ?? '').toString()).where((n) => n.isNotEmpty).toList();
          if (!_departments.contains(_selectedDepartment) && _departments.isNotEmpty) {
            _selectedDepartment = _departments.first;
          }
        }
        if (staffData != null && staffData.isNotEmpty) {
          final names = staffData
              .map((s) => (s['name'] ?? '').toString().trim())
              .where((n) => n.isNotEmpty)
              .toList();
          if (names.isNotEmpty) {
            _supervisors = [...names, 'Unassigned'];
            if (!_supervisors.contains(_selectedSupervisor)) {
              _selectedSupervisor = _supervisors.first;
            }
          }
        }
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    final tenant = TenantService().currentTenant.value;
    final String tenantId = (tenant != null && tenant.id.isNotEmpty) ? tenant.id : 'startups_main';

    setState(() => _isSaving = true);

    final success = await ApiService.addDivision({
      'tenant_id': tenantId,
      'department_name': _selectedDepartment,
      'name': _nameCtrl.text.trim(),
      'code': _codeCtrl.text.trim().toUpperCase(),
      'supervisor': _selectedSupervisor,
      'shifts': _selectedShifts.toList(),
      'description': _descCtrl.text.trim(),
      'status': _isActive ? 'Active' : 'Inactive',
    });

    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? "Division '${_nameCtrl.text.trim()}' saved successfully!" : "Failed to save division"),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
      if (success) {
        widget.onNavigateMode?.call("Manage Division");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- HEADER & BACK BUTTON ---
          Row(
            children: [
              IconButton(
                onPressed: () => widget.onNavigateMode?.call("Manage Division"),
                icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1F2937)),
                tooltip: "Back to Manage Division",
              ),
              const SizedBox(width: 8),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Add Division", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF1F2937))),
                  SizedBox(height: 2),
                  Text("Create operational sub-stations and assign supervisors under departments.", style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 28),

          // --- FORM CONTAINER CARD ---
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: AdminTheme.softShadow,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // DEPARTMENT SELECTION
                      const Text("PARENT DEPARTMENT *", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280), letterSpacing: 0.5)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedDepartment,
                        items: _departments.map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)))).toList(),
                        onChanged: (val) => setState(() => _selectedDepartment = val!),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // DIVISION NAME & CODE ROW
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("DIVISION NAME *", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280), letterSpacing: 0.5)),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _nameCtrl,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
                                  validator: (v) => (v == null || v.trim().isEmpty) ? "Division name required" : null,
                                  decoration: InputDecoration(
                                    hintText: "e.g. Hot Kitchen / Salad Bar",
                                    hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                                    filled: true,
                                    fillColor: const Color(0xFFF8FAFC),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("SHORT CODE *", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280), letterSpacing: 0.5)),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _codeCtrl,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
                                  validator: (v) => (v == null || v.trim().isEmpty) ? "Code required" : null,
                                  decoration: InputDecoration(
                                    hintText: "e.g. KIT-HOT",
                                    hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                                    filled: true,
                                    fillColor: const Color(0xFFF8FAFC),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // SUPERVISOR / IN-CHARGE
                      const Text("SUPERVISOR / LEAD *", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280), letterSpacing: 0.5)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedSupervisor,
                        items: _supervisors.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)))).toList(),
                        onChanged: (val) => setState(() => _selectedSupervisor = val!),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // OPERATIONAL SHIFTS
                      const Text("OPERATIONAL SHIFTS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280), letterSpacing: 0.5)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _availableShifts.map((shift) {
                          final isSelected = _selectedShifts.contains(shift);
                          return FilterChip(
                            label: Text(shift, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF4B5563))),
                            selected: isSelected,
                            selectedColor: const Color(0xFF2563EB).withValues(alpha: 0.12),
                            backgroundColor: const Color(0xFFF8FAFC),
                            checkmarkColor: const Color(0xFF2563EB),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE5E7EB))),
                            onSelected: (val) {
                              setState(() {
                                if (val) {
                                  _selectedShifts.add(shift);
                                } else {
                                  if (_selectedShifts.length > 1) _selectedShifts.remove(shift);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),

                      // DESCRIPTION TEXTAREA
                      const Text("DESCRIPTION & STATION DUTIES", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280), letterSpacing: 0.5)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _descCtrl,
                        maxLines: 3,
                        style: const TextStyle(fontSize: 14, color: Color(0xFF1F2937)),
                        decoration: InputDecoration(
                          hintText: "Specify station responsibilities, equipment, or operational guidelines...",
                          hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // STATUS TOGGLE
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Division Status", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1F2937))),
                                Text("Active divisions can receive orders and staff assignments.", style: TextStyle(color: Color(0xFF6B7280), fontSize: 11)),
                              ],
                            ),
                            Switch(
                              value: _isActive,
                              activeColor: const Color(0xFF2563EB),
                              onChanged: (val) => setState(() => _isActive = val),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // FOOTER ACTION BUTTONS
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: _isSaving ? null : () => widget.onNavigateMode?.call("Manage Division"),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              side: const BorderSide(color: Color(0xFFE5E7EB)),
                            ),
                            child: const Text("Cancel", style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 14),
                          ElevatedButton.icon(
                            onPressed: _isSaving ? null : _submitForm,
                            icon: const Icon(Icons.check_rounded, size: 18),
                            label: _isSaving
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text("Save Division", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 2,
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
        ],
      ),
    );
  }
}
