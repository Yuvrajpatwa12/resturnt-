import 'package:flutter/material.dart';
import '../admin_theme.dart';

class DepartmentManagementScreen extends StatelessWidget {
  final String mode;
  const DepartmentManagementScreen({super.key, required this.mode});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(mode, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              IconButton(onPressed: () {}, icon: const Icon(Icons.add_business_outlined, color: AdminTheme.royalBlue)),
            ],
          ),
          const SizedBox(height: 16),
          _buildDepartmentCard("Kitchen Ops", "8 Employees"),
          _buildDepartmentCard("Front Desk", "4 Employees"),
          _buildDepartmentCard("Management", "2 Employees"),
          const SizedBox(height: 32),
          if (mode.contains("Division")) _buildDivisionView(),
        ],
      ),
    );
  }

  Widget _buildDepartmentCard(String name, String count) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: AdminTheme.softShadow),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.hub_outlined, color: AdminTheme.royalBlue),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(count, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        trailing: const Icon(Icons.chevron_right, size: 20),
      ),
    );
  }

  Widget _buildDivisionView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text("Division Hierarchy", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 16),
        Text("Define specific operational divisions within your restaurant departments.", style: TextStyle(color: Colors.grey, fontSize: 11)),
      ],
    );
  }
}
