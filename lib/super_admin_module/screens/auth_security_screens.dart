import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../styles.dart';

class AuthSecurityScreens extends StatelessWidget {
  final String mode;
  final VoidCallback? onAuthenticated;

  const AuthSecurityScreens({
    super.key,
    required this.mode,
    this.onAuthenticated,
  });

  @override
  Widget build(BuildContext context) {
    if (mode == "Login") {
      return Scaffold(
        backgroundColor: SAMStyles.pearlWhite,
        body: Center(
          child: _SuperAdminLoginForm(onAuthenticated: onAuthenticated),
        ),
      );
    }
    if (mode == "Profile") return _buildProfile();
    return _buildAuditLogs();
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

class _SuperAdminLoginForm extends StatefulWidget {
  final VoidCallback? onAuthenticated;
  const _SuperAdminLoginForm({this.onAuthenticated});

  @override
  State<_SuperAdminLoginForm> createState() => _SuperAdminLoginFormState();
}

class _SuperAdminLoginFormState extends State<_SuperAdminLoginForm> {
  final _usernameCtrl = TextEditingController(text: "admin");
  final _passwordCtrl = TextEditingController(text: "patwa");
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handleLogin() async {
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = "Username and password/PIN are required.");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await ApiService.superAdminLogin(username, password);

    if (!mounted) return;

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Authenticated as Root Super Admin'),
          backgroundColor: SAMStyles.emeraldGreen,
        ),
      );
      if (widget.onAuthenticated != null) {
        widget.onAuthenticated!();
      }
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = res['message'] ?? 'Authentication failed.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
          const Icon(Icons.security_rounded, size: 64, color: SAMStyles.royalBlue),
          const SizedBox(height: 24),
          const Text("Super Admin Portal", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const Text("Secure access for root administrators", style: TextStyle(color: SAMStyles.textGrey)),
          const SizedBox(height: 32),
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _usernameCtrl,
            decoration: InputDecoration(
              labelText: "Admin Username",
              hintText: "admin",
              prefixIcon: const Icon(Icons.person_outline),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _passwordCtrl,
            obscureText: true,
            decoration: InputDecoration(
              labelText: "Secret PIN / Password",
              hintText: "patwa or 123456",
              prefixIcon: const Icon(Icons.lock_outline),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: SAMStyles.royalBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text("AUTHENTICATE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
          ),
        ],
      ),
    );
  }
}
