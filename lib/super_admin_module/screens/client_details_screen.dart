import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../styles.dart';
import 'staff_detail_subview.dart';

class ClientDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> tenant;
  final VoidCallback onBack;

  const ClientDetailsScreen({super.key, required this.tenant, required this.onBack});

  @override
  State<ClientDetailsScreen> createState() => _ClientDetailsScreenState();
}

class _ClientDetailsScreenState extends State<ClientDetailsScreen> {
  Map<String, dynamic>? _selectedStaff;
  List<Map<String, dynamic>> _realStaff = [];
  bool _isUpdating = false;
  bool _isStaffLoading = true;
  String? _currentEmail;

  @override
  void initState() {
    super.initState();
    _currentEmail = widget.tenant['admin_email'];
    _loadStaffData();
    _refreshTenantData();
  }

  Future<void> _refreshTenantData() async {
    final domain = widget.tenant['domain'] ?? widget.tenant['custom_domain'] ?? widget.tenant['tenant_id'];
    if (domain != null && domain.toString().isNotEmpty) {
      final freshData = await ApiService.initTenant(domain.toString());
      if (freshData != null && mounted) {
        setState(() {
          widget.tenant.addAll(freshData);
          if (freshData['admin_email'] != null) {
            _currentEmail = freshData['admin_email'];
          }
        });
      }
    }
  }

  Future<void> _loadStaffData() async {
    setState(() => _isStaffLoading = true);
    final data = await ApiService.fetchTenantStaff(widget.tenant['tenant_id']);
    if (data != null) {
      setState(() => _realStaff = data);
    }
    setState(() => _isStaffLoading = false);
  }

  Color _parseHexColor(String? hexString) {
    if (hexString == null || hexString.isEmpty) return const Color(0xFFFF5C00);
    try {
      String cleanHex = hexString.replaceAll('#', '');
      if (cleanHex.length == 6) {
        cleanHex = 'FF$cleanHex';
      }
      return Color(int.parse(cleanHex, radix: 16));
    } catch (_) {
      return const Color(0xFFFF5C00);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedStaff != null) {
      return StaffDetailSubview(
        staff: _selectedStaff!,
        onBack: () => setState(() => _selectedStaff = null),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: 32),
          _buildQuickStats(),
          const SizedBox(height: 32),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    _buildOnboardingProfileCard(),
                    const SizedBox(height: 24),
                    _buildCredentialCard(),
                    const SizedBox(height: 24),
                    _buildSystemConfigCard(),
                    const SizedBox(height: 24),
                    _buildSocialLinksCard(),
                    const SizedBox(height: 24),
                    _buildPremiumFeaturesCard(),
                    const SizedBox(height: 24),
                    _buildLocationCard(),
                    const SizedBox(height: 24),
                    _buildPaymentHistory(),
                  ],
                ),
              ),
              const SizedBox(width: 32),
              Expanded(child: _buildCategorizedStaffDirectory()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOnboardingProfileCard() {
    final tenantId = widget.tenant['tenant_id'] ?? 'N/A';
    final domain = widget.tenant['domain'] ?? 'N/A';
    final customDomain = widget.tenant['custom_domain'] ?? 'N/A';
    final createdAt = widget.tenant['created_at'] ?? widget.tenant['start_date'] ?? 'N/A';
    final plan = widget.tenant['plan']?.toString().toUpperCase() ?? 'BASIC';
    final hexColor = widget.tenant['primary_color'] ?? widget.tenant['color'] ?? '#FF5C00';
    final color = _parseHexColor(hexColor);
    final phone = widget.tenant['phone'] ?? widget.tenant['phone_number'] ?? widget.tenant['contact_number'] ?? 'Not Configured';
    final address = widget.tenant['address'] ?? widget.tenant['restaurant_address'] ?? 'Not Configured';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: SAMStyles.softShadow,
        border: Border.all(color: SAMStyles.royalBlue.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.storefront_outlined, color: SAMStyles.royalBlue, size: 20),
              SizedBox(width: 12),
              Text("Onboarding & Registration Metadata", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            "Primary registration details recorded during restaurant onboarding.",
            style: TextStyle(color: SAMStyles.textGrey, fontSize: 12),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildMetaDetail("TENANT ID", tenantId.toString())),
              Expanded(child: _buildMetaDetail("PRIMARY DOMAIN", domain.toString())),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildMetaDetail("CUSTOM DOMAIN", customDomain.toString())),
              Expanded(child: _buildMetaDetail("ONBOARDING DATE", createdAt.toString())),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildMetaDetail("PHONE / CONTACT", phone.toString())),
              Expanded(child: _buildMetaDetail("PHYSICAL ADDRESS", address.toString())),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("PRIMARY BRAND COLOR", style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(hexColor.toString(), style: const TextStyle(fontWeight: FontWeight.bold, color: SAMStyles.darkNavy)),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(child: _buildMetaDetail("SUBSCRIPTION PLAN", plan)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSystemConfigCard() {
    final country = widget.tenant['country'] ?? 'Nepal';
    final state = widget.tenant['state'] ?? 'Bagmati Province';
    final currencyCode = widget.tenant['currency_code'] ?? widget.tenant['currency'] ?? 'NPR';
    final currencySymbol = widget.tenant['currency_symbol'] ?? 'Rs.';
    final appLanguage = widget.tenant['app_language'] ?? widget.tenant['language'] ?? 'en';

    String flag = '🇳🇵';
    if (country.toString().toLowerCase() == 'india') flag = '🇮🇳';

    String langName = 'English (en)';
    if (appLanguage.toString().toLowerCase() == 'ne') langName = 'Nepali (नेपाली - ne)';
    if (appLanguage.toString().toLowerCase() == 'hi') langName = 'Hindi (हिन्दी - hi)';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: SAMStyles.softShadow,
        border: Border.all(color: Colors.teal.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.tune_rounded, color: Colors.teal, size: 20),
                  SizedBox(width: 12),
                  Text("Regional & System Preferences", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 18, color: Colors.teal),
                onPressed: _refreshTenantData,
                tooltip: "Sync Latest Data from Server",
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            "Active location, currency, and language preferences saved for this restaurant.",
            style: TextStyle(color: SAMStyles.textGrey, fontSize: 12),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildMetaDetail("COUNTRY / REGION", "$country $flag")),
              Expanded(child: _buildMetaDetail("STATE / PROVINCE", state.toString())),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildMetaDetail("ACTIVE CURRENCY", "$currencyCode ($currencySymbol)")),
              Expanded(child: _buildMetaDetail("APP LANGUAGE", langName)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSocialLinksCard() {
    final mapsLink = widget.tenant['google_maps_link'] ?? 'Not Configured';
    final instaLink = widget.tenant['instagram_link'] ?? 'Not Configured';
    final fbLink = widget.tenant['facebook_link'] ?? 'Not Configured';
    final tiktokLink = widget.tenant['tiktok_link'] ?? 'Not Configured';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: SAMStyles.softShadow,
        border: Border.all(color: Colors.indigo.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.share_outlined, color: Colors.indigo, size: 20),
              SizedBox(width: 12),
              Text("Digital & Social Media Presence", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            "Configured social links and Google Maps location profile.",
            style: TextStyle(color: SAMStyles.textGrey, fontSize: 12),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          _buildLinkRow(Icons.map_outlined, "Google Maps Link", mapsLink.toString()),
          const SizedBox(height: 12),
          _buildLinkRow(Icons.camera_alt_outlined, "Instagram Profile", instaLink.toString()),
          const SizedBox(height: 12),
          _buildLinkRow(Icons.facebook_outlined, "Facebook Page", fbLink.toString()),
          const SizedBox(height: 12),
          _buildLinkRow(Icons.video_library_outlined, "TikTok Handle", tiktokLink.toString()),
        ],
      ),
    );
  }

  Widget _buildMetaDetail(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: SAMStyles.darkNavy, fontSize: 13)),
      ],
    );
  }

  Widget _buildLinkRow(IconData icon, String label, String url) {
    bool isConfigured = url.toLowerCase() != 'not configured' && url.trim().isNotEmpty;
    return Row(
      children: [
        Icon(icon, size: 16, color: isConfigured ? SAMStyles.royalBlue : Colors.grey),
        const SizedBox(width: 10),
        Text("$label: ", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: SAMStyles.textGrey)),
        Expanded(
          child: Text(
            url,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isConfigured ? SAMStyles.royalBlue : Colors.grey,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildCredentialCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: SAMStyles.softShadow,
        border: Border.all(color: SAMStyles.royalBlue.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.vpn_key_outlined, color: SAMStyles.royalBlue, size: 20),
              SizedBox(width: 12),
              Text("Credential Management", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            "Manage the primary Admin login for this restaurant tenant.",
            style: TextStyle(color: SAMStyles.textGrey, fontSize: 12),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("CURRENT ADMIN EMAIL", style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(_currentEmail ?? 'Not Configured', style: const TextStyle(fontWeight: FontWeight.bold, color: SAMStyles.darkNavy)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _showUpdateLoginModal,
                icon: const Icon(Icons.edit, size: 14),
                label: const Text("UPDATE ACCESS"),
                style: ElevatedButton.styleFrom(backgroundColor: SAMStyles.royalBlue, minimumSize: const Size(140, 44)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumFeaturesCard() {
    final dynamic rawValue = widget.tenant['is_premium_enabled'];
    bool isPremium = rawValue.toString() == "1" || rawValue == true;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: SAMStyles.softShadow,
        border: Border.all(color: Colors.purple.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.purple, size: 20),
              SizedBox(width: 12),
              Text("Premium Package Management", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text("Premium Services (Master Toggle)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: const Text("Enable AR, Voice, Loyalty & Proximity for this restaurant.", style: TextStyle(fontSize: 11)),
            value: isPremium,
            activeColor: Colors.purple,
            onChanged: (val) async {
              setState(() => _isUpdating = true);
              final result = await ApiService.updateTenantPremiumStatus(
                tenantId: widget.tenant['tenant_id']?.toString() ?? '',
                isEnabled: val,
              );
              setState(() => _isUpdating = false);
              
              if (result['success'] == true || result['status'] == 'success') {
                setState(() {
                  widget.tenant['is_premium_enabled'] = val ? 1 : 0;
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Premium Services: ${val ? 'ENABLED' : 'DISABLED'}"), backgroundColor: Colors.purple)
                  );
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error: ${result['message'] ?? 'Check API'}"), backgroundColor: Colors.red)
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: SAMStyles.softShadow,
        border: Border.all(color: Colors.orange.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.location_on_outlined, color: Colors.orange, size: 20),
              SizedBox(width: 12),
              Text("Geofencing Setup", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            "Configure the GPS coordinates for proximity-based notifications.",
            style: TextStyle(color: SAMStyles.textGrey, fontSize: 12),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("CURRENT COORDINATES", style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    (widget.tenant['latitude'] != null && widget.tenant['longitude'] != null)
                      ? "Lat: ${widget.tenant['latitude']} | Lng: ${widget.tenant['longitude']}"
                      : "Not Set", 
                    style: const TextStyle(fontWeight: FontWeight.bold, color: SAMStyles.darkNavy)
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _showUpdateLocationModal,
                icon: const Icon(Icons.map_outlined, size: 14),
                label: const Text("EDIT LOCATION"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, minimumSize: const Size(140, 44)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showUpdateLocationModal() {
    final latController = TextEditingController(text: widget.tenant['latitude']?.toString() ?? '');
    final lngController = TextEditingController(text: widget.tenant['longitude']?.toString() ?? '');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit GPS Coordinates"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Set exact latitude and longitude for proximity offers.", style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 24),
            TextField(
              controller: latController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: "Latitude", hintText: "e.g. 27.7172"),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: lngController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: "Longitude", hintText: "e.g. 85.3240"),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final lat = double.tryParse(latController.text);
              final lng = double.tryParse(lngController.text);
              if (lat == null || lng == null) return;
              
              Navigator.pop(context);
              setState(() => _isUpdating = true);
              
              final result = await ApiService.updateTenantLocation(
                (widget.tenant['tenant_id'] ?? widget.tenant['id'] ?? '').toString(),
                latitude: lat,
                longitude: lng,
              );
              
              setState(() => _isUpdating = false);
              if (result['success'] == true) {
                widget.tenant['latitude'] = lat;
                widget.tenant['longitude'] = lng;
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Location updated successfully."), backgroundColor: Colors.green));
                }
              } else if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("FAILED: ${result['message']}"), backgroundColor: Colors.red));
              }
            },
            child: const Text("Save Location"),
          ),
        ],
      ),
    );
  }

  void _showUpdateLoginModal() {
    final emailController = TextEditingController(text: widget.tenant['admin_email']);
    final pinController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text("Setup Admin Login"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Set the email and security PIN for the restaurant owner.", style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 24),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: "Admin Email", hintText: "admin@startupsgo.tech"),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pinController,
                obscureText: true,
                decoration: const InputDecoration(labelText: "Security PIN", hintText: "4-6 digits"),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                if (emailController.text.isEmpty || pinController.text.isEmpty) return;
                
                Navigator.pop(context);
                setState(() => _isUpdating = true);
                
                final result = await ApiService.updateCredentials(
                  tenantId: widget.tenant['tenant_id'],
                  email: emailController.text.trim(),
                  pin: pinController.text.trim(),
                );
                
                setState(() => _isUpdating = false);
                if (result['success'] == true) {
                  setState(() => _currentEmail = emailController.text.trim());
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message']), backgroundColor: Colors.green));
                  }
                } else if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("FAILED: ${result['message']}"), backgroundColor: Colors.red));
                }
              },
              child: const Text("Save Login"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final String name = widget.tenant['restaurant_name'] ?? widget.tenant['name'] ?? 'Unknown';
    final String firstLetter = name.isNotEmpty ? name[0].toUpperCase() : 'R';

    return Row(
      children: [
        IconButton(
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back, color: SAMStyles.darkNavy),
        ),
        const SizedBox(width: 16),
        CircleAvatar(
          radius: 35,
          backgroundColor: SAMStyles.royalBlue.withValues(alpha: 0.1),
          child: Text(firstLetter, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: SAMStyles.royalBlue)),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
              Row(
                children: [
                  const Icon(Icons.link, size: 14, color: Colors.blue),
                  const SizedBox(width: 4),
                  Text(widget.tenant['custom_domain'] ?? 'no-domain.com', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: SAMStyles.emeraldGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text(widget.tenant['plan'].toString().toUpperCase(), style: const TextStyle(color: SAMStyles.emeraldGreen, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: _refreshTenantData,
          icon: const Icon(Icons.refresh_rounded, color: SAMStyles.royalBlue),
          tooltip: "Sync Latest Data",
        ),
        const SizedBox(width: 8),
        if (_isUpdating) const CircularProgressIndicator() else _buildStatusBadge(),
        const SizedBox(width: 16),
        IconButton(
          onPressed: () => _confirmDelete(context),
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          tooltip: "Delete Restaurant",
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Restaurant?"),
        content: Text("Are you sure you want to permanently delete '${widget.tenant['restaurant_name'] ?? 'this restaurant'}'? All data will be lost."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCEL")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("DELETE", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isUpdating = true);
      final success = await ApiService.deleteTenant(widget.tenant['tenant_id']);
      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Restaurant deleted successfully.")));
        widget.onBack();
      } else {
        setState(() => _isUpdating = false);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to delete restaurant.")));
        }
      }
    }
  }

  Widget _buildStatusBadge() {
    bool isActive = (widget.tenant['is_active'] == 1 || widget.tenant['is_active'] == true);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? SAMStyles.emeraldGreen.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: isActive ? SAMStyles.emeraldGreen : Colors.red, width: 1.5),
      ),
      child: Row(
        children: [
          CircleAvatar(radius: 4, backgroundColor: isActive ? SAMStyles.emeraldGreen : Colors.red),
          const SizedBox(width: 8),
          Text(
            isActive ? "ACTIVE" : "BLOCKED",
            style: TextStyle(color: isActive ? SAMStyles.emeraldGreen : Colors.red, fontWeight: FontWeight.w900, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Row(
      children: [
        _buildStatCard("Total Orders", widget.tenant['total_orders']?.toString() ?? "0", Icons.shopping_bag_outlined, Colors.blue),
        const SizedBox(width: 24),
        _buildStatCard("Active Staff", widget.tenant['active_staff']?.toString() ?? "0", Icons.people_outline, Colors.orange),
        const SizedBox(width: 24),
        _buildStatCard("Storage Used", widget.tenant['storage_display'] ?? "0.0 KB", Icons.storage, SAMStyles.royalBlue),
        const SizedBox(width: 24),
        _buildStatCard("Onboarded", widget.tenant['created_at']?.toString().split(' ')[0] ?? "N/A", Icons.event_note, SAMStyles.emeraldGreen),
      ],
    );
  }

  Widget _buildStatCard(String label, String val, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: SAMStyles.softShadow),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(val, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                Text(label, style: const TextStyle(color: SAMStyles.textGrey, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentHistory() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: SAMStyles.softShadow),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Financial History", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 40),
          Center(
            child: Column(
              children: [
                Icon(Icons.account_balance_wallet_outlined, size: 48, color: Color(0xFFE2E8F0)),
                SizedBox(height: 16),
                Text("No recent transactions found.", style: TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorizedStaffDirectory() {
    if (_isStaffLoading) return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
    if (_realStaff.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(40), child: Text("No staff members registered.")));

    final managers = _realStaff.where((s) => s['role'] == 'Admin').toList();
    final waiters = _realStaff.where((s) => s['role'] == 'Waiter').toList();
    final kitchen = _realStaff.where((s) => s['role'] == 'Kitchen').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (managers.isNotEmpty) ...[
          _buildStaffSection("MANAGERS / ADMINS", managers, Colors.blue),
          const SizedBox(height: 24),
        ],
        if (waiters.isNotEmpty) ...[
          _buildStaffSection("WAITERS & FLOOR STAFF", waiters, Colors.orange),
          const SizedBox(height: 24),
        ],
        if (kitchen.isNotEmpty) ...[
          _buildStaffSection("KITCHEN CHEFS", kitchen, Colors.purple),
          const SizedBox(height: 24),
        ],
      ],
    );
  }

  Widget _buildStaffSection(String title, List<Map<String, dynamic>> staffList, Color badgeColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: SAMStyles.softShadow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: staffList.length,
            separatorBuilder: (_, __) => const Divider(height: 24),
            itemBuilder: (context, index) {
              final staff = staffList[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: badgeColor.withValues(alpha: 0.1),
                  child: Text(
                    (staff['name'] ?? 'S')[0].toUpperCase(),
                    style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(staff['name'] ?? 'Unknown Staff', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(staff['email'] ?? 'No Email', style: const TextStyle(fontSize: 12, color: SAMStyles.textGrey)),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: badgeColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                  child: Text(staff['role'] ?? 'Staff', style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                onTap: () => setState(() => _selectedStaff = staff),
              );
            },
          ),
        ],
      ),
    );
  }
}
