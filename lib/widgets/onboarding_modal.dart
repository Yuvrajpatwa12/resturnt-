import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../cart_manager.dart';
import '../services/tenant_service.dart';
import '../services/api_service.dart';

class OnboardingModal extends StatefulWidget {
  const OnboardingModal({super.key});

  @override
  State<OnboardingModal> createState() => _OnboardingModalState();
}

class _OnboardingModalState extends State<OnboardingModal> {
  final TextEditingController _nameCtrl = TextEditingController();
  String _selectedGender = 'Male';
  bool _isSaving = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ShopManager.instance.isOnboardingComplete,
      builder: (context, complete, child) {
        if (complete) return const SizedBox.shrink();

        return Material(
          color: Colors.black.withValues(alpha: 0.7),
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutBack,
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, value, child) {
              return Transform.scale(
                scale: 0.8 + (0.2 * value),
                child: Opacity(
                  opacity: value,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 450),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            )
                          ],
                        ),
                        child: Stack(
                          children: [
                            // Main Content
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(height: 12),
                                    const Text(
                                      "WELCOME!",
                                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFFFF5C00)),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      "Tell us who you are to start dining.",
                                      style: TextStyle(color: Colors.grey, fontSize: 13),
                                    ),
                                    const SizedBox(height: 32),
                                    TextField(
                                      controller: _nameCtrl,
                                      decoration: InputDecoration(
                                        hintText: "Enter your name",
                                        prefixIcon: const Icon(Icons.person_outline),
                                        filled: true,
                                        fillColor: Colors.grey[100],
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    const Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text("Select Gender", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Expanded(child: _buildGenderBtn("Male", Icons.man_rounded)),
                                        const SizedBox(width: 12),
                                        Expanded(child: _buildGenderBtn("Female", Icons.woman_rounded)),
                                      ],
                                    ),
                                    const SizedBox(height: 32),
                                    if (_errorMessage != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        margin: const EdgeInsets.only(bottom: 24),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withValues(alpha: 0.05),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                                        ),
                                        child: Text(
                                          _errorMessage!,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: _isSaving ? null : _submit,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFFFF5C00),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 18),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        ),
                                        child: _isSaving 
                                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                          : const Text("Continue", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                ),
                              ),
                            ),
                            
                            // Top Right Skip Button
                            Positioned(
                              top: 16,
                              right: 16,
                              child: IconButton(
                                icon: const Icon(Icons.close_rounded, color: Colors.grey),
                                onPressed: () => _submit(isAnon: true),
                                tooltip: "Skip and continue anonymously",
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildGenderBtn(String label, IconData icon) {
    bool isSelected = _selectedGender == label;
    Color color = label == "Male" ? const Color(0xFF0077B5) : Colors.pinkAccent;
    
    String avatarUrl = label == "Male" 
        ? 'https://cdn-icons-png.flaticon.com/512/3135/3135715.png'
        : 'https://cdn-icons-png.flaticon.com/512/3135/3135789.png';

    return GestureDetector(
      onTap: () => setState(() {
        _selectedGender = label;
        _errorMessage = null;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.08) : Colors.grey[50],
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isSelected ? color : Colors.grey[200]!, width: 2),
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.white,
              child: ClipOval(
                child: Image.network(
                  avatarUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Icon(icon, color: isSelected ? color : Colors.grey, size: 32),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Icon(icon, color: isSelected ? color : Colors.grey, size: 20),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? color : Colors.grey, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Future<void> _submit({bool isAnon = false}) async {
    if (TenantService().currentTenant.value == null) {
      setState(() => _errorMessage = "Please wait... loading restaurant data.");
      return;
    }

    if (!isAnon && _nameCtrl.text.trim().isEmpty) {
      setState(() => _errorMessage = "Please enter your name");
      return;
    }
    
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final tenant = TenantService().currentTenant.value;
      final staff = TenantService().currentStaff.value;
      final uid = staff != null ? staff.id.toString() : (ShopManager.instance.customerEmail.value.isNotEmpty ? ShopManager.instance.customerEmail.value : ShopManager.instance.guestId.value);

      final response = await http.post(
        Uri.parse("${ApiService.baseUrl}/onboarding_api.php?tenant_id=${tenant!.id}"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "tenant_id": tenant.id,
          "user_id": uid,
          "name": isAnon ? "Guest Diner" : _nameCtrl.text.trim(),
          "gender": _selectedGender,
          "is_anonymous": isAnon,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.body.isEmpty) throw Exception("Empty response from server");

      final data = json.decode(response.body);
      
      if (data['status'] == 'success') {
         await ShopManager.instance.updateProfile(
           name: isAnon ? "Guest Diner" : _nameCtrl.text.trim(),
           gender: _selectedGender,
           isAnon: isAnon,
         );
      } else {
         setState(() => _errorMessage = "Server Error: ${data['message']}");
      }
    } catch (e) {
      setState(() => _errorMessage = "System Error: $e");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
