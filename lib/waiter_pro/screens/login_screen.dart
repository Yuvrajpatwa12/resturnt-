import 'package:flutter/material.dart';
import '../theme.dart';
import '../waiter_hub.dart';
import '../../kitchen_pro/kitchen_hub.dart';
import '../../admin_pro/admin_hub.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _idController = TextEditingController();
  final _pinController = TextEditingController();
  String _selectedShift = 'Morning';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              const Center(
                child: Column(
                  children: [
                    Icon(Icons.restaurant_menu, size: 64, color: WaiterProTheme.royalBlue),
                    SizedBox(height: 16),
                    Text(
                      "Chiyalaa Waiter Pro",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: WaiterProTheme.darkNavy,
                      ),
                    ),
                    Text("Premium Service Management", style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
              const SizedBox(height: 60),
              const Text("Waiter ID", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _idController,
                decoration: const InputDecoration(
                  hintText: "Enter your Staff ID (e.g. WT-109)",
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 20),
              const Text("4-Digit PIN", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: const InputDecoration(
                  hintText: "****",
                  prefixIcon: Icon(Icons.lock_outline),
                  counterText: "",
                ),
              ),
              const SizedBox(height: 20),
              const Text("Select Shift", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedShift,
                    isExpanded: true,
                    items: ['Morning', 'Evening', 'Night'].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedShift = val!),
                  ),
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const WaiterHub()),
                  );
                },
                child: const Text("AUTHENTICATE & START SHIFT"),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const KitchenHub()),
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: WaiterProTheme.royalBlue),
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("KITCHEN KDS ACCESS", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AdminHub()),
                  );
                },
                icon: const Icon(Icons.admin_panel_settings_outlined, size: 18),
                label: const Text("ADMIN CONSOLE ACCESS", style: TextStyle(fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: WaiterProTheme.darkNavy),
                  foregroundColor: WaiterProTheme.darkNavy,
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
