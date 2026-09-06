import 'package:flutter/material.dart';
import '../cart_manager.dart';

class SmartAuthOverlay extends StatefulWidget {
  const SmartAuthOverlay({super.key});

  @override
  State<SmartAuthOverlay> createState() => _SmartAuthOverlayState();
}

class _SmartAuthOverlayState extends State<SmartAuthOverlay> {
  final TextEditingController _pinCtrl = TextEditingController();
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ShopManager.instance.needsPin,
      builder: (context, needsPin, child) {
        if (!needsPin) return const SizedBox.shrink();

        return Material(
          color: Colors.black.withValues(alpha: 0.85),
          child: Container(
            width: double.infinity,
            height: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Center(
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 450),
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: 0.1), blurRadius: 20)],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.shield_outlined, size: 64, color: Color(0xFFFF5C00)),
                        const SizedBox(height: 24),
                        const Text(
                          "Secure Your Profile",
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Welcome ${ShopManager.instance.customerName.value}!\nPlease set a 4-digit PIN to secure your coins and orders.",
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                        const SizedBox(height: 32),
                        TextField(
                          controller: _pinCtrl,
                          keyboardType: TextInputType.number,
                          maxLength: 4,
                          obscureText: true,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 20),
                          decoration: const InputDecoration(
                            counterText: "",
                            hintText: "••••",
                            border: InputBorder.none,
                          ),
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _savePin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF5C00),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: _isSaving 
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text("Activate Profile", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _savePin() async {
    if (_pinCtrl.text.length != 4) return;
    setState(() => _isSaving = true);
    final success = await ShopManager.instance.finalizeSecurityPin(_pinCtrl.text);
    if (!success && mounted) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to save PIN. Try again.")));
    }
    setState(() => _isSaving = false);
  }
}
