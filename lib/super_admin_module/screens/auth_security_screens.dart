import 'package:flutter/material.dart';
import '../styles.dart';

class AuthSecurityScreens extends StatelessWidget {
  final String mode;
  const AuthSecurityScreens({super.key, required this.mode});

  @override
  Widget build(BuildContext context) {
    if (mode == "Login") return _buildLogin(context);
    if (mode == "Profile") return _buildProfile();
    return _buildAuditLogs();
  }

  Widget _buildLogin(BuildContext context) {
    return Scaffold(
      backgroundColor: SAMStyles.pearlWhite,
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: SAMStyles.pureWhite,
            borderRadius: BorderRadius.circular(32),
            boxShadow: SAMStyles.softShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.security, size: 64, color: SAMStyles.royalBlue),
              const SizedBox(height: 24),
              const Text("Super Admin Portal", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              const Text("Secure access for root administrators", style: TextStyle(color: SAMStyles.textGrey)),
              const SizedBox(height: 40),
              TextField(
                decoration: InputDecoration(
                  labelText: "Admin Username",
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Secret PIN / Password",
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 54)),
                child: const Text("AUTHENTICATE"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfile() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Admin Profile", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(color: SAMStyles.pureWhite, borderRadius: BorderRadius.circular(24), boxShadow: SAMStyles.softShadow),
            child: Row(
              children: [
                const CircleAvatar(radius: 50, backgroundColor: SAMStyles.royalBlue, child: Icon(Icons.person, size: 50, color: Colors.white)),
                const SizedBox(width: 32),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text("Yuvraj Patwa", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      Text("Role: Root Super Admin", style: TextStyle(color: SAMStyles.textGrey)),
                      SizedBox(height: 8),
                      Text("Last login: Aug 22, 2026 • 10:45 AM (IP: 192.168.1.1)", style: TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                ElevatedButton(onPressed: () {}, child: const Text("EDIT PROFILE")),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditLogs() {
    final logs = [
      {'user': 'Yuvraj', 'action': 'Client Deactivated', 'target': 'Mountain Cafe', 'time': '2026-08-22 14:30'},
      {'user': 'Admin_02', 'action': 'Plan Upgraded', 'target': 'Spice Garden', 'time': '2026-08-22 12:15'},
      {'user': 'System', 'action': 'Automatic Backup', 'target': 'Global DB', 'time': '2026-08-22 00:00'},
    ];

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Security Audit Logs", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: SAMStyles.softShadow),
              child: SingleChildScrollView(
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text("ADMIN USER")),
                    DataColumn(label: Text("ACTION")),
                    DataColumn(label: Text("TARGET")),
                    DataColumn(label: Text("TIMESTAMP")),
                  ],
                  rows: logs.map((log) => DataRow(cells: [
                    DataCell(Text(log['user']!, style: const TextStyle(fontWeight: FontWeight.bold))),
                    DataCell(Text(log['action']!)),
                    DataCell(Text(log['target']!)),
                    DataCell(Text(log['time']!)),
                  ])).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
