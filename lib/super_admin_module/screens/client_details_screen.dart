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
  String? _currentEmail; // Local state to show email instantly

  @override
  void initState() {
    super.initState();
    _currentEmail = widget.tenant['admin_email'];
    _loadStaffData();
  }

  Future<void> _loadStaffData() async {
    setState(() => _isStaffLoading = true);
    final data = await ApiService.fetchTenantStaff(widget.tenant['tenant_id']);
    if (data != null) {
      setState(() => _realStaff = data);
    }
    setState(() => _isStaffLoading = false);
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
                    _buildCredentialCard(),
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
    final latController = TextEditingController(text: widget.tenant['latitude']?.toString());
    final lngController = TextEditingController(text: widget.tenant['longitude']?.toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Update Restaurant Location"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Enter decimal coordinates for the 600m notification system.", style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 24),
            TextField(
              controller: latController,
              decoration: const InputDecoration(labelText: "Latitude", hintText: "e.g. 27.7172"),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: lngController,
              decoration: const InputDecoration(labelText: "Longitude", hintText: "e.g. 85.3240"),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                tenantId: widget.tenant['tenant_id'],
                latitude: lat,
                longitude: lng,
              );
              
              setState(() => _isUpdating = false);
              if (result['success'] == true) {
                // Update local model
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
      children: [
        if (managers.isNotEmpty) ...[
          _buildStaffGroup("Management", managers, SAMStyles.darkNavy, Icons.admin_panel_settings),
          const SizedBox(height: 24),
        ],
        if (waiters.isNotEmpty) ...[
          _buildStaffGroup("Waiters", waiters, SAMStyles.royalBlue, Icons.person_pin_circle),
          const SizedBox(height: 24),
        ],
        if (kitchen.isNotEmpty) ...[
          _buildStaffGroup("Kitchen Staff", kitchen, Colors.orange, Icons.restaurant_menu),
        ],
      ],
    );
  }

  Widget _buildStaffGroup(String title, List<Map<String, dynamic>> members, Color accentColor, IconData groupIcon) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: SAMStyles.softShadow,
        border: Border(left: BorderSide(color: accentColor, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(groupIcon, color: accentColor, size: 20),
              const SizedBox(width: 12),
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text("${members.length} Active", style: TextStyle(color: SAMStyles.textGrey, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 24),
          ...members.map((s) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: accentColor.withValues(alpha: 0.1),
                  radius: 18,
                  child: Text(
                    (s['name'] != null && s['name'].toString().isNotEmpty) ? s['name'].toString()[0].toUpperCase() : 'S',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: accentColor)
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s['name']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text(s['role']!, style: const TextStyle(color: SAMStyles.textGrey, fontSize: 11)),
                    ],
                  ),
                ),
                _buildStatusIndicator(s['status'] == 'Online'),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(bool isOnline) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: (isOnline ? Colors.green : Colors.grey).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isOnline ? "ONLINE" : "OFFLINE",
        style: TextStyle(color: isOnline ? Colors.green : Colors.grey, fontSize: 8, fontWeight: FontWeight.w900),
      ),
    );
  }
}
