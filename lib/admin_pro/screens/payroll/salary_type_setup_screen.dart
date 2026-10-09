import 'package:flutter/material.dart';
import '../../admin_theme.dart';

class SalaryTypeSetupScreen extends StatefulWidget {
  const SalaryTypeSetupScreen({super.key});

  @override
  State<SalaryTypeSetupScreen> createState() => _SalaryTypeSetupScreenState();
}

class _SalaryTypeSetupScreenState extends State<SalaryTypeSetupScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  final List<Map<String, dynamic>> _salaryTypes = [
    {
      'id': '1',
      'title': 'Fixed Monthly',
      'category': 'Fixed Salary',
      'unit': 'NPR / Month',
      'description': 'Standard fixed monthly base salary cleared at end of payment cycle (e.g. 30 days).',
      'status': 'Active',
      'icon': Icons.calendar_month_rounded,
      'color': Color(0xFF2563EB),
    },
    {
      'id': '2',
      'title': 'Hourly Rate',
      'category': 'Hourly Wage',
      'unit': 'NPR / Hour',
      'description': 'Wage calculated based on exact clocked-in attendance hours per daily shift.',
      'status': 'Active',
      'icon': Icons.timer_rounded,
      'color': Color(0xFF10B981),
    },
    {
      'id': '3',
      'title': 'Base + Incentive',
      'category': 'Incentive / Bonus',
      'unit': 'Base + Bonus',
      'description': 'Fixed base monthly salary plus performance bonuses for high sales or order volume.',
      'status': 'Active',
      'icon': Icons.trending_up_rounded,
      'color': Color(0xFFF59E0B),
    },
    {
      'id': '4',
      'title': 'Sales Commission',
      'category': 'Commission',
      'unit': '% of Order Sales',
      'description': 'Percentage-based payout computed directly from order sales served by the staff.',
      'status': 'Active',
      'icon': Icons.percent_rounded,
      'color': Color(0xFF8B5CF6),
    },
    {
      'id': '5',
      'title': 'Overtime Rate',
      'category': 'Hourly Wage',
      'unit': '1.5x Hourly Rate',
      'description': 'Additional compensation for extra hours worked beyond normal daily shift hours.',
      'status': 'Active',
      'icon': Icons.access_time_filled_rounded,
      'color': Color(0xFFEC4899),
    },
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showAddEditTypeDialog([Map<String, dynamic>? typeItem]) {
    final titleCtrl = TextEditingController(text: typeItem?['title'] ?? '');
    final unitCtrl = TextEditingController(text: typeItem?['unit'] ?? '');
    final descCtrl = TextEditingController(text: typeItem?['description'] ?? '');

    String selectedCategory = typeItem?['category'] ?? 'Fixed Salary';
    bool isActive = (typeItem?['status'] ?? 'Active') == 'Active';

    final List<String> categories = ['Fixed Salary', 'Hourly Wage', 'Incentive / Bonus', 'Commission'];

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
                child: const Icon(Icons.category_rounded, color: Color(0xFF2563EB), size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                typeItem == null ? "Add Salary Type" : "Edit Salary Type",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1F2937)),
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
                  const Text("TYPE TITLE *", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: titleCtrl,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                    decoration: InputDecoration(
                      hintText: "e.g. Fixed Monthly / Shift Wage",
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("CATEGORY *", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280))),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              value: selectedCategory,
                              items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)))).toList(),
                              onChanged: (v) => setModalState(() => selectedCategory = v!),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
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
                            const Text("PAYMENT UNIT / RATE *", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280))),
                            const SizedBox(height: 6),
                            TextField(
                              controller: unitCtrl,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                              decoration: InputDecoration(
                                hintText: "e.g. NPR / Month",
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

                  const Text("DESCRIPTION", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6B7280))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: "Brief explanation of how compensation is calculated...",
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Active Status", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1F2937))),
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
              onPressed: () => Navigator.pop(ctx),
              style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: const Text("Cancel", style: TextStyle(color: Color(0xFF6B7280))),
            ),
            ElevatedButton(
              onPressed: () {
                if (titleCtrl.text.trim().isEmpty) return;
                setState(() {
                  if (typeItem == null) {
                    _salaryTypes.add({
                      'id': DateTime.now().millisecondsSinceEpoch.toString(),
                      'title': titleCtrl.text.trim(),
                      'category': selectedCategory,
                      'unit': unitCtrl.text.trim().isEmpty ? 'NPR / Month' : unitCtrl.text.trim(),
                      'description': descCtrl.text.trim(),
                      'status': isActive ? 'Active' : 'Inactive',
                      'icon': Icons.payments_rounded,
                      'color': const Color(0xFF2563EB),
                    });
                  } else {
                    typeItem['title'] = titleCtrl.text.trim();
                    typeItem['category'] = selectedCategory;
                    typeItem['unit'] = unitCtrl.text.trim();
                    typeItem['description'] = descCtrl.text.trim();
                    typeItem['status'] = isActive ? 'Active' : 'Inactive';
                  }
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(typeItem == null ? "Salary Type Added!" : "Salary Type Updated!"), backgroundColor: Colors.green),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: Text(typeItem == null ? "Save Type" : "Update"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _salaryTypes.where((t) {
      final q = _searchQuery.toLowerCase();
      final title = (t['title'] ?? '').toString().toLowerCase();
      final cat = (t['category'] ?? '').toString().toLowerCase();
      return title.contains(q) || cat.contains(q);
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
                  Text("Salary Type Setup", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF1F2937))),
                  SizedBox(height: 4),
                  Text("Manage employee compensation structures, hourly rates, and commission rules.", style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddEditTypeDialog(),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text("Add Salary Type", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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

          // SEARCH BAR
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
                  hintText: "Search salary structure title or category...",
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

          // CARDS GRID VIEW
          filtered.isEmpty
              ? const Padding(padding: EdgeInsets.all(60), child: Center(child: Text("No salary structure types found.", style: TextStyle(color: Colors.grey))))
              : GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 360,
                    mainAxisSpacing: 20,
                    crossAxisSpacing: 20,
                    childAspectRatio: 1.15,
                  ),
                  itemBuilder: (context, index) {
                    final t = filtered[index];
                    final bool isActive = t['status'] == 'Active';
                    final Color iconColor = t['color'] as Color;

                    return Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                        boxShadow: AdminTheme.softShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: iconColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(t['icon'] as IconData, color: iconColor, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(t['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1F2937))),
                                    Text(t['category'], style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isActive ? const Color(0xFFDEF7EC) : const Color(0xFFFDE8E8),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  t['status'],
                                  style: TextStyle(
                                    color: isActive ? const Color(0xFF03543F) : const Color(0xFF9B1C1C),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(t['description'], style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
                          const Spacer(),
                          const Divider(height: 1),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(t['unit'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: iconColor)),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_rounded, color: Color(0xFF2563EB), size: 18),
                                    tooltip: "Edit Type",
                                    onPressed: () => _showAddEditTypeDialog(t),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                                    tooltip: "Delete Type",
                                    onPressed: () {
                                      setState(() => _salaryTypes.removeWhere((item) => item['id'] == t['id']));
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Salary type '${t['title']}' deleted."), backgroundColor: Colors.redAccent));
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }
}
