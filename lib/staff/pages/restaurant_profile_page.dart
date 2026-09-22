import 'package:flutter/material.dart';
import '../../services/tenant_service.dart';
import '../../services/api_service.dart';

class RestaurantProfilePage extends StatefulWidget {
  const RestaurantProfilePage({super.key});

  @override
  State<RestaurantProfilePage> createState() => _RestaurantProfilePageState();
}

class _RestaurantProfilePageState extends State<RestaurantProfilePage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _googleLinkController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final tenant = TenantService().currentTenant.value;
    if (tenant != null) {
      _nameController.text = tenant.name;
      _googleLinkController.text = tenant.googleMapsLink ?? "";
    }
  }

  Future<void> _saveProfile() async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return;

    setState(() => _isSaving = true);
    
    final success = await ApiService.updateGoogleMapsLink(tenant.id, _googleLinkController.text.trim());
    
    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        // Refresh local tenant data without global loading screen
        await TenantService().initialize(tenant.domain, showLoading: false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile updated successfully!"), backgroundColor: Colors.green));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to update profile."), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text("Restaurant Profile", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Basic Information", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildTextField("Restaurant Name", _nameController, readOnly: true),
            const SizedBox(height: 24),
            const Text("Google Maps Settings", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text("Provide your Google Maps Business URL to encourage diners to leave reviews.", style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 16),
            _buildTextField("Google Maps Review Link", _googleLinkController, hint: "https://g.page/r/your-id/review"),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5C00),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isSaving 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("SAVE CHANGES", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool readOnly = false, String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          readOnly: readOnly,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: readOnly ? Colors.grey[100] : Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
          ),
        ),
      ],
    );
  }
}
