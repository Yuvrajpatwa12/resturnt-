import 'package:flutter/material.dart';
import '../../admin_theme.dart';

class DesignationScreen extends StatelessWidget {
  const DesignationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Designation & Roles", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 4),
          Text("Manage staff roles and access designations", style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: AdminTheme.softShadow),
            child: Column(
              children: const [
                ListTile(
                  leading: Icon(Icons.badge_outlined, color: AdminTheme.royalBlue),
                  title: Text("Manager", style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Full access to POS, inventory, and HRM"),
                ),
                Divider(),
                ListTile(
                  leading: Icon(Icons.badge_outlined, color: AdminTheme.royalBlue),
                  title: Text("Waiter", style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Access to tables, orders, and customer service"),
                ),
                Divider(),
                ListTile(
                  leading: Icon(Icons.badge_outlined, color: AdminTheme.royalBlue),
                  title: Text("Chef / Kitchen", style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Access to kitchen dashboard and production"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
