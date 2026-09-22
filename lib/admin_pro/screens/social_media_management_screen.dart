import 'package:flutter/material.dart';
import '../../services/tenant_service.dart';
import '../../services/api_service.dart';
import '../admin_theme.dart';

class SocialMediaManagementScreen extends StatefulWidget {
  const SocialMediaManagementScreen({super.key});

  @override
  State<SocialMediaManagementScreen> createState() => _SocialMediaManagementScreenState();
}

class _SocialMediaManagementScreenState extends State<SocialMediaManagementScreen> {
  final TextEditingController _googleController = TextEditingController();
  final TextEditingController _instagramController = TextEditingController();
  final TextEditingController _facebookController = TextEditingController();
  final TextEditingController _tiktokController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final tenant = TenantService().currentTenant.value;
    if (tenant != null) {
      _googleController.text = tenant.googleMapsLink ?? "";
      _instagramController.text = tenant.instagramLink ?? "";
      _facebookController.text = tenant.facebookLink ?? "";
      _tiktokController.text = tenant.tiktokLink ?? "";
    }
  }

  Future<void> _saveLinks() async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return;

    setState(() => _isSaving = true);

    final Map<String, String> linksPayload = {
      "google_maps_link": _googleController.text.trim(),
      "instagram_link": _instagramController.text.trim(),
      "facebook_link": _facebookController.text.trim(),
      "tiktok_link": _tiktokController.text.trim(),
    };

    final success = await ApiService.updateSocialLinks(tenant.id.trim(), linksPayload);

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        // Force refresh the tenant data to update the local state
        await TenantService().initialize(tenant.domain, showLoading: false);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Social profile updated successfully!"), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Server error: Failed to update database record."), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tenant = TenantService().currentTenant.value;
    final bool hasExistingLinks = tenant != null && 
        ((tenant.googleMapsLink?.isNotEmpty ?? false) || 
         (tenant.instagramLink?.isNotEmpty ?? false) || 
         (tenant.facebookLink?.isNotEmpty ?? false) || 
         (tenant.tiktokLink?.isNotEmpty ?? false));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Social & Search Profile",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AdminTheme.darkNavy),
          ),
          const Text(
            "Manage your restaurant's external presence to engage with diners.",
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 32),

          _buildLinkInput(
            "Google Maps Review Link", 
            _googleController, 
            Icons.location_on_outlined, 
            "Encourage diners to leave reviews on your business profile.",
            hint: "https://g.page/r/your-id/review"
          ),
          const SizedBox(height: 24),

          _buildLinkInput(
            "Instagram Profile", 
            _instagramController, 
            Icons.camera_alt_outlined, 
            "Link your Instagram to showcase your dishes and stories.",
            hint: "https://instagram.com/yourhandle"
          ),
          const SizedBox(height: 24),

          _buildLinkInput(
            "Facebook Page", 
            _facebookController, 
            Icons.facebook_outlined, 
            "Connect your Facebook community page.",
            hint: "https://facebook.com/yourpage"
          ),
          const SizedBox(height: 24),

          _buildLinkInput(
            "TikTok Profile", 
            _tiktokController, 
            Icons.video_collection_outlined, 
            "Link your TikTok for trending food videos.",
            hint: "https://tiktok.com/@yourhandle"
          ),

          const SizedBox(height: 48),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveLinks,
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminTheme.royalBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isSaving 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(
                    hasExistingLinks ? "UPDATE SOCIAL PROFILE" : "SAVE SOCIAL PROFILE", 
                    style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)
                  ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildLinkInput(String label, TextEditingController controller, IconData icon, String subtitle, {String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: AdminTheme.royalBlue),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
}
