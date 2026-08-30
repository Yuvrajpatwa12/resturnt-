import 'package:flutter/material.dart';
import '../services/tenant_service.dart';

class AdminLoginScreen extends StatefulWidget {
  final String? roleHint;
  const AdminLoginScreen({super.key, this.roleHint});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _emailController = TextEditingController();
  final _pinController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_emailController.text.isEmpty || _pinController.text.isEmpty) {
      setState(() => _error = "Please fill in all fields.");
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await TenantService().login(
      _emailController.text.trim(),
      _pinController.text.trim(),
    );

    if (result['success'] != true && mounted) {
      setState(() {
        _error = result['message'];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tenant = TenantService().currentTenant.value;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 450),
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Dynamic Branding Header
                if (tenant != null && tenant.logo.isNotEmpty)
                  Image.network(tenant.logo, height: 60, errorBuilder: (c, e, s) => const Icon(Icons.restaurant, size: 50, color: Color(0xFFFF5C00)))
                else
                  const Icon(Icons.lock_person_rounded, size: 64, color: Color(0xFF002D62)),
                
                const SizedBox(height: 24),
                Text(
                  tenant?.name ?? "ChiyaBreak Access",
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF002D62)),
                ),
                Text(
                  widget.roleHint != null ? "${widget.roleHint!.toUpperCase()} LOGIN" : "SECURE STAFF ACCESS",
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.5),
                ),
                
                const SizedBox(height: 40),

                // 2. Login Fields
                _buildTextField("Email Address", _emailController, Icons.email_outlined, false),
                const SizedBox(height: 20),
                _buildTextField("Security PIN", _pinController, Icons.lock_outline_rounded, true),
                
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold)),
                  ),

                const SizedBox(height: 40),

                // 3. Action Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5C00),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _isLoading 
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("LOGIN TO SYSTEM", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  ),
                ),
                
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel & Return", style: TextStyle(color: Colors.grey, fontSize: 12)),
                ),

                // --- DEVELOPMENT BYPASS TOOL ---
                if (Uri.base.host == "localhost" || Uri.base.host == "127.0.0.1") ...[
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 20),
                  const Text("DEVELOPMENT TOOLS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.blueGrey, letterSpacing: 1)),
                  const SizedBox(height: 16),
                  _buildDevBypassButton("Admin"),
                  const SizedBox(height: 8),
                  _buildDevBypassButton("Waiter"),
                  const SizedBox(height: 8),
                  _buildDevBypassButton("Kitchen"),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDevBypassButton(String role) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => TenantService().devModeBypass(role),
        icon: const Icon(Icons.developer_board_rounded, size: 14),
        label: Text("LOGIN AS $role (BYPASS)"),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.blueGrey,
          side: const BorderSide(color: Colors.blueGrey),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, bool isPin) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF64748B))),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: isPin,
          keyboardType: isPin ? TextInputType.number : TextInputType.emailAddress,
          style: const TextStyle(fontWeight: FontWeight.bold),
          onSubmitted: (_) => _handleLogin(),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 20, color: const Color(0xFFFF5C00)),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey[100]!)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFFF5C00))),
          ),
        ),
      ],
    );
  }
}
