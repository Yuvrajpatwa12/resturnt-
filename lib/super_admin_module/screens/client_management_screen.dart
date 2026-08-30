import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../styles.dart';
import 'client_details_screen.dart';
import 'restaurant_onboarding_form.dart';

class ClientManagementScreen extends StatefulWidget {
  const ClientManagementScreen({super.key});

  @override
  State<ClientManagementScreen> createState() => _ClientManagementScreenState();
}

class _ClientManagementScreenState extends State<ClientManagementScreen> {
  List<Map<String, dynamic>> _tenants = [];
  bool _isLoading = true;
  Map<String, dynamic>? _selectedTenant;
  bool _isOnboarding = false;
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _loadTenants();
  }

  Future<void> _loadTenants() async {
    setState(() => _isLoading = true);
    final data = await ApiService.fetchTenants();
    if (data != null) {
      setState(() => _tenants = data);
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isOnboarding) {
      return RestaurantOnboardingForm(
        onCancel: () => setState(() => _isOnboarding = false),
        onRegister: (newTenantData) async {
          final success = await ApiService.registerTenant(newTenantData);
          if (success) {
            _loadTenants();
            setState(() => _isOnboarding = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Restaurant registered successfully!"),
                backgroundColor: SAMStyles.emeraldGreen,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Failed to register restaurant. Check Tenant ID or Domain."),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      );
    }

    if (_selectedTenant != null) {
      return ClientDetailsScreen(
        tenant: _selectedTenant!,
        onBack: () => setState(() => _selectedTenant = null),
      );
    }

    final filteredTenants = _tenants.where((t) => (t['restaurant_name'] ?? '').toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopRow(),
          const SizedBox(height: 32),
          _buildSearchBar(),
          const SizedBox(height: 32),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : filteredTenants.isEmpty 
                  ? const Center(child: Text("No restaurants found."))
                  : _buildClientGrid(filteredTenants),
          ),
        ],
      ),
    );
  }

  Widget _buildTopRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Client Directory", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text("Manage active restaurant instances and access status.", style: TextStyle(color: SAMStyles.textGrey)),
          ],
        ),
        ElevatedButton.icon(
          onPressed: () => setState(() => _isOnboarding = true),
          icon: const Icon(Icons.add_business),
          label: const Text("ONBOARD NEW RESTAURANT"),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Row(
      children: [
        Container(
          width: 400,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: SAMStyles.softShadow,
          ),
          child: TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: "Search restaurants...",
              prefixIcon: const Icon(Icons.search, color: SAMStyles.textGrey),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
          ),
        ),
        const SizedBox(width: 16),
        IconButton(
          onPressed: _loadTenants,
          icon: const Icon(Icons.refresh, color: SAMStyles.royalBlue),
          tooltip: "Refresh List",
        ),
      ],
    );
  }

  Widget _buildClientGrid(List<Map<String, dynamic>> tenants) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 24,
        mainAxisSpacing: 24,
        childAspectRatio: 1.5,
      ),
      itemCount: tenants.length,
      itemBuilder: (context, index) {
        final t = tenants[index];
        return _buildProfileCard(t);
      },
    );
  }

  Widget _buildProfileCard(Map<String, dynamic> t) {
    bool isActive = (t['is_active'] == 1 || t['is_active'] == true);
    return InkWell(
      onTap: () => setState(() => _selectedTenant = t),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: SAMStyles.softShadow,
          border: Border.all(color: isActive ? Colors.transparent : Colors.red.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: SAMStyles.royalBlue.withOpacity(0.1),
                  child: Text(
                    (t['restaurant_name'] ?? t['name'] ?? 'R').toString().isNotEmpty 
                        ? (t['restaurant_name'] ?? t['name'] ?? 'R').toString()[0].toUpperCase()
                        : 'R', 
                    style: const TextStyle(fontWeight: FontWeight.bold, color: SAMStyles.royalBlue),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t['restaurant_name'] ?? t['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      Text(t['custom_domain'] ?? t['subdomain'] ?? 'No Domain', style: const TextStyle(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                // Status indicator instead of switch for safer control
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isActive ? SAMStyles.emeraldGreen : Colors.red).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isActive ? "ACTIVE" : "BLOCKED",
                    style: TextStyle(color: isActive ? SAMStyles.emeraldGreen : Colors.red, fontSize: 8, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("PLAN", style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
                    Text(t['plan'] ?? 'Basic', style: const TextStyle(fontWeight: FontWeight.w900, color: SAMStyles.darkNavy)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text("EXPIRY", style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
                    Text(t['expiry_date'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
