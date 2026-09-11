import 'package:flutter/material.dart';
import 'cart_manager.dart';

class AccountSettingsPage extends StatefulWidget {
  const AccountSettingsPage({super.key});

  @override
  State<AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  final _nameController = TextEditingController();
  String _selectedGender = "Male";
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = ShopManager.instance.customerName.value;
    _selectedGender = ShopManager.instance.userGender.value;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Account Details",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- PROFILE HEADER ---
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: const Color(0xFFFF5C00).withValues(alpha: 0.1),
                    child: Icon(
                      _selectedGender == 'Female' ? Icons.face_3_rounded : Icons.face_6_rounded,
                      color: const Color(0xFFFF5C00),
                      size: 50,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ValueListenableBuilder<String>(
                    valueListenable: ShopManager.instance.customerEmail,
                    builder: (context, email, _) => Text(
                      email.isNotEmpty ? email : "Guest Account",
                      style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
            _buildLabel("FULL NAME"),
            _buildTextField(_nameController, "Enter your name"),

            const SizedBox(height: 24),
            _buildLabel("GENDER"),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildGenderChip("Male"),
                const SizedBox(width: 12),
                _buildGenderChip("Female"),
                const SizedBox(width: 12),
                _buildGenderChip("Other"),
              ],
            ),

            const SizedBox(height: 48),
            _isUpdating 
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF5C00)))
              : SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5C00),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: const Text(
                      "SAVE CHANGES",
                      style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.5),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.all(20),
        ),
      ),
    );
  }

  Widget _buildGenderChip(String label) {
    bool isSelected = _selectedGender == label;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedGender = label),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFF5C00) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? Colors.transparent : Colors.grey[200]!),
            boxShadow: isSelected ? [BoxShadow(color: const Color(0xFFFF5C00).withValues(alpha: 0.2), blurRadius: 8)] : [],
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isEmpty) return;

    setState(() => _isUpdating = true);
    
    final success = await ShopManager.instance.updateProfile(
      name: _nameController.text.trim(), 
      gender: _selectedGender
    );

    if (mounted) {
      setState(() => _isUpdating = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile updated successfully!"), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Update failed. Please try again."), backgroundColor: Colors.red),
        );
      }
    }
  }
}
