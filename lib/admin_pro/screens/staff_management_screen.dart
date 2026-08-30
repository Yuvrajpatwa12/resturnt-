import 'package:flutter/material.dart';
import '../../cart_manager.dart';
import '../admin_theme.dart';

class StaffManagementScreen extends StatelessWidget {
  const StaffManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: ShopManager.instance.staffDirectory,
      builder: (context, staff, child) {
        return Column(
          children: [
            _buildStaffHeader(context),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: staff.length,
                itemBuilder: (context, index) {
                  return _buildStaffMemberCard(staff[index]);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStaffHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("Staff Directory", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.person_add, size: 18),
            label: const Text("NEW STAFF", style: TextStyle(fontSize: 11)),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              minimumSize: const Size(0, 45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffMemberCard(Map<String, dynamic> person) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AdminTheme.softShadow,
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.all(20),
            leading: CircleAvatar(
              radius: 25,
              backgroundColor: AdminTheme.royalBlue.withOpacity(0.1),
              child: Text(person['name'][0], style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.royalBlue)),
            ),
            title: Text(person['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: person['role'] == 'Chef' ? Colors.orange[50] : Colors.blue[50], borderRadius: BorderRadius.circular(6)),
                      child: Text(person['role'], style: TextStyle(fontSize: 9, color: person['role'] == 'Chef' ? Colors.orange : Colors.blue, fontWeight: FontWeight.w900)),
                    ),
                    const SizedBox(width: 8),
                    Text("ID: ${person['id']}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ],
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStaffStat("Sales", "NPR ${person['sales']}"),
                _buildStaffStat("Tips", "NPR ${person['tips']}"),
                _buildStaffStat("Shift", person['shift']),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
