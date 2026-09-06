import 'package:flutter/material.dart';
import '../admin_theme.dart';
import '../../services/api_service.dart';
import '../../services/tenant_service.dart';

class RewardManagementScreen extends StatefulWidget {
  final String mode;
  const RewardManagementScreen({super.key, required this.mode});

  @override
  State<RewardManagementScreen> createState() => _RewardManagementScreenState();
}

class _RewardManagementScreenState extends State<RewardManagementScreen> {
  bool _isLoading = false;
  Map<String, dynamic>? _settings;
  List<Map<String, dynamic>> _rewards = [];
  List<Map<String, dynamic>> _mysteryPrizes = [];
  List<Map<String, dynamic>> _claims = [];

  // Controllers for Settings
  final TextEditingController _fixedPointsCtrl = TextEditingController();
  final TextEditingController _ptsPer100Ctrl = TextEditingController();
  final TextEditingController _groupBonusCtrl = TextEditingController();
  final TextEditingController _minRedeemCtrl = TextEditingController();
  bool _mboxEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant RewardManagementScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.mode != oldWidget.mode) _loadData();
  }

  Future<void> _loadData() async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return;

    setState(() => _isLoading = true);
    
    if (widget.mode == "Rewards Config") {
      _settings = await ApiService.fetchLoyaltySettings(tenant.id);
      if (_settings != null) {
        setState(() {
          _fixedPointsCtrl.text = _settings!['points_per_order_fixed']?.toString() ?? '50';
          _ptsPer100Ctrl.text = (_settings!['points_per_amount'] ?? 0.05).toString();
          _groupBonusCtrl.text = _settings!['group_join_bonus']?.toString() ?? '200';
          _minRedeemCtrl.text = _settings!['min_redeem_points']?.toString() ?? '100';
          _mboxEnabled = _settings!['mystery_box_enabled'] == 1;
        });
      }
    } else if (widget.mode == "Redeem Items") {
      _rewards = await ApiService.fetchRewards(tenant.id) ?? [];
    } else if (widget.mode == "Mystery Box") {
      _mysteryPrizes = await ApiService.fetchMysteryBoxConfig(tenant.id) ?? [];
    } else if (widget.mode == "Claim History") {
      _claims = await ApiService.fetchClaimHistory(tenant.id) ?? [];
    } else if (widget.mode == "Marketing Banners") {
      _rewards = await ApiService.fetchOffers(tenant.id) ?? []; // Reusing _rewards list for simplicity
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _saveSettings() async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return;

    setState(() => _isLoading = true);
    try {
      final res = await ApiService.updateLoyaltySettings({
        "tenant_id": tenant.id,
        "points_per_order_fixed": int.tryParse(_fixedPointsCtrl.text) ?? 50,
        "points_per_amount": double.tryParse(_ptsPer100Ctrl.text) ?? 0.05,
        "group_join_bonus": int.tryParse(_groupBonusCtrl.text) ?? 200,
        "mystery_box_enabled": _mboxEnabled ? 1 : 0,
        "min_redeem_points": int.tryParse(_minRedeemCtrl.text) ?? 100,
      });

      if (res['status'] == 'success' && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Settings Saved Successfully!"), backgroundColor: Colors.green));
        _loadData();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("❌ Save Failed: ${res['message'] ?? 'Unknown Error'}"), 
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(label: "DETAILS", textColor: Colors.white, onPressed: () {
             _showDetailsDialog(res['message'] ?? 'No details', res['raw']?.toString() ?? '');
          }),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("⚠️ System Error: ${e.toString()}"), backgroundColor: Colors.red));
      }
    }
    setState(() => _isLoading = false);
  }

  void _showDetailsDialog(String msg, String raw) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Error Details"),
        content: SingleChildScrollView(child: Text("Message: $msg\n\nRaw Response: $raw")),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CLOSE"))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
      bottomNavigationBar: (widget.mode == "Rewards Config" && !_isLoading)
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))],
              ),
              child: ElevatedButton.icon(
                onPressed: _saveSettings, 
                icon: const Icon(Icons.save_rounded, color: Colors.white), 
                label: const Text("SAVE LOYALTY SETTINGS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5C00), 
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildBody() {
    switch (widget.mode) {
      case "Rewards Config": return _buildConfigView();
      case "Redeem Items": return _buildRewardsListView();
      case "Mystery Box": return _buildMysteryBoxView();
      case "Claim History": return _buildHistoryView();
      case "Marketing Banners": return _buildBannersListView();
      default: return const Center(child: Text("Select a loyalty mode"));
    }
  }

  Widget _buildConfigView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Loyalty Engine Configuration", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
          const Text("Control how users earn points and interact with rewards.", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 40),
          _buildSettingCard(
            title: "Point Earning Logic",
            icon: Icons.monetization_on_outlined,
            children: [
              _buildEditableSettingRow("Fixed Points per Order", "Points given on every order checkout", _fixedPointsCtrl, isDecimal: false),
              _buildEditableSettingRow("Points per NPR 100 Spent", "Percentage points (0.05 = 5 pts per 100)", _ptsPer100Ctrl, isDecimal: true),
              _buildEditableSettingRow("Group Join Bonus", "Points for joining a group table", _groupBonusCtrl, isDecimal: false),
            ],
          ),
          const SizedBox(height: 24),
          _buildSettingCard(
            title: "Redemption Rules",
            icon: Icons.shopping_bag_outlined,
            children: [
              _buildToggleRow("Enable Mystery Box", "Allow users to unlock surprise rewards", _mboxEnabled, (v) => setState(() => _mboxEnabled = v)),
              const SizedBox(height: 16),
              _buildEditableSettingRow("Min Redeem Balance", "User needs at least this much to redeem", _minRedeemCtrl, isDecimal: false),
            ],
          ),
          const SizedBox(height: 100), // Space for bottom bar
        ],
      ),
    );
  }

  Widget _buildRewardsListView() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Redeemable Items", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
              ElevatedButton.icon(
                onPressed: _showAddRewardDialog, 
                icon: const Icon(Icons.add), 
                label: const Text("ADD REWARD"),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4C49ED), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
              ),
            ],
          ),
          const SizedBox(height: 32),
          _rewards.isEmpty 
            ? const Center(child: Text("No rewards configured. Add one to start!"))
            : Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 300, mainAxisSpacing: 20, crossAxisSpacing: 20, childAspectRatio: 0.8),
                  itemCount: _rewards.length,
                  itemBuilder: (context, index) {
                    final r = _rewards[index];
                    return _buildRewardCard(r);
                  },
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildMysteryBoxView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Mystery Box Contents", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
              ElevatedButton.icon(
                onPressed: _showAddMysteryDialog, 
                icon: const Icon(Icons.add), 
                label: const Text("ADD PRIZE"),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4C49ED), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
              ),
            ],
          ),
          const Text("Define what users can win and their probabilities.", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 40),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: AdminTheme.softShadow),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _mysteryPrizes.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final p = _mysteryPrizes[i];
                return ListTile(
                  contentPadding: const EdgeInsets.all(20),
                  title: Text(p['reward_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Win Probability: ${p['probability']}%"),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red), 
                    onPressed: () async {
                      await ApiService.deleteMysteryPrize(int.parse(p['id'].toString()));
                      _loadData();
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannersListView() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Marketing Banners", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
              ElevatedButton.icon(
                onPressed: _showAddBannerDialog, 
                icon: const Icon(Icons.add), 
                label: const Text("ADD BANNER"),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4C49ED), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
              ),
            ],
          ),
          const SizedBox(height: 32),
          _rewards.isEmpty 
            ? const Center(child: Text("No active banners. Add one to show on Homepage!"))
            : Expanded(
                child: ListView.builder(
                  itemCount: _rewards.length,
                  itemBuilder: (context, index) {
                    final b = _rewards[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(b['image_url'] ?? '', width: 100, height: 60, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.image))),
                        title: Text(b['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(b['subtitle'] ?? ''),
                        trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () async {
                           await ApiService.deleteOffer(int.parse(b['id'].toString()));
                           _loadData();
                        }),
                      ),
                    );
                  },
                ),
              ),
        ],
      ),
    );
  }

  void _showAddBannerDialog() {
    final titleCtrl = TextEditingController();
    final subCtrl = TextEditingController();
    final tagCtrl = TextEditingController();
    final imgCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text("New Marketing Banner", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogField("Main Title", titleCtrl, "e.g. SUMMER SPECIAL"),
            const SizedBox(height: 16),
            _buildDialogField("Subtitle", subCtrl, "e.g. Get flat discount..."),
            const SizedBox(height: 16),
            _buildDialogField("Discount Tag", tagCtrl, "e.g. 50% OFF"),
            const SizedBox(height: 16),
            _buildDialogField("Image URL", imgCtrl, "https://..."),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () async {
              final tenant = TenantService().currentTenant.value;
              if (tenant == null) return;
              await ApiService.addOffer({
                "tenant_id": tenant.id,
                "title": titleCtrl.text,
                "subtitle": subCtrl.text,
                "discount_tag": tagCtrl.text,
                "image_url": imgCtrl.text,
              });
              if (ctx.mounted) Navigator.pop(ctx);
              _loadData();
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4C49ED)),
            child: const Text("SAVE BANNER"),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryView() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Redemption History", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
          const Text("Real-time audit of customer reward claims.", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 32),
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: AdminTheme.softShadow),
              child: ListView.separated(
                itemCount: _claims.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final c = _claims[i];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    leading: const CircleAvatar(backgroundColor: Color(0xFFF1F4F9), child: Icon(Icons.person, color: Color(0xFF4C49ED))),
                    title: Text(c['user_name'] ?? c['user_id'] ?? 'Guest User', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("Reward: ${c['reward_title']} • Code: ${c['claim_code']}"),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(c['status'] ?? 'Pending', style: TextStyle(color: c['status'] == 'Claimed' ? Colors.green : Colors.orange, fontWeight: FontWeight.bold)),
                        if (c['status'] == 'Pending')
                          IconButton(
                            icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                            onPressed: () async {
                              await ApiService.updateClaimStatus(int.parse(c['id'].toString()), 'Claimed');
                              _loadData();
                            },
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- HELPERS ---

  Widget _buildSettingCard({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: AdminTheme.softShadow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF4C49ED)),
              const SizedBox(width: 12),
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const Divider(height: 32),
          ...children,
        ],
      ),
    );
  }

  Widget _buildEditableSettingRow(String label, String sub, TextEditingController ctrl, {bool isDecimal = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(sub, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          SizedBox(
            width: 120,
            child: TextField(
              controller: ctrl,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.numberWithOptions(decimal: isDecimal),
              decoration: InputDecoration(
                filled: true, fillColor: const Color(0xFFF1F4F9),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRow(String label, String sub, bool val, Function(bool) onChanged) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(sub, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
        Switch(value: val, onChanged: onChanged, activeThumbColor: const Color(0xFF4C49ED)),
      ],
    );
  }

  Widget _buildRewardCard(Map<String, dynamic> r) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: AdminTheme.softShadow),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: Image.network(
                    r['image_url'] ?? '', 
                    width: double.infinity, height: double.infinity, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: Colors.grey[200], child: const Icon(Icons.image, size: 40, color: Colors.grey)),
                  ),
                ),
                Positioned(
                  top: 10, right: 10,
                  child: CircleAvatar(
                    backgroundColor: Colors.white.withValues(alpha: 0.9),
                    child: IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 18), onPressed: () async {
                       await ApiService.deleteReward(int.parse(r['id'].toString()));
                       _loadData();
                    }),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(r['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text("${r['points_required']} Pts", style: const TextStyle(color: Color(0xFF4C49ED), fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddRewardDialog() {
    final titleCtrl = TextEditingController();
    final pointsCtrl = TextEditingController();
    final imgCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text("New Redeemable Reward", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogField("Item Name", titleCtrl, "e.g. Free Burger"),
            const SizedBox(height: 16),
            _buildDialogField("Points Required", pointsCtrl, "e.g. 500"),
            const SizedBox(height: 16),
            _buildDialogField("Image URL", imgCtrl, "https://..."),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () async {
              final tenant = TenantService().currentTenant.value;
              if (tenant == null) return;
              await ApiService.addReward({
                "tenant_id": tenant.id,
                "title": titleCtrl.text,
                "points_required": int.tryParse(pointsCtrl.text) ?? 100,
                "image_url": imgCtrl.text,
              });
              if (ctx.mounted) Navigator.pop(ctx);
              _loadData();
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4C49ED)),
            child: const Text("ADD ITEM"),
          ),
        ],
      ),
    );
  }

  void _showAddMysteryDialog() {
    final nameCtrl = TextEditingController();
    final probCtrl = TextEditingController();
    final imgCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text("New Mystery Prize", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogField("Prize Name", nameCtrl, "e.g. Free Jamocha Shake"),
            const SizedBox(height: 16),
            _buildDialogField("Win Probability (%)", probCtrl, "e.g. 10"),
            const SizedBox(height: 16),
            _buildDialogField("Image URL", imgCtrl, "https://..."),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () async {
              final tenant = TenantService().currentTenant.value;
              if (tenant == null) return;
              await ApiService.addMysteryPrize({
                "tenant_id": tenant.id,
                "reward_name": nameCtrl.text,
                "probability": double.tryParse(probCtrl.text) ?? 10.0,
                "image_url": imgCtrl.text,
              });
              if (ctx.mounted) Navigator.pop(ctx);
              _loadData();
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4C49ED)),
            child: const Text("ADD PRIZE"),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogField(String label, TextEditingController ctrl, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 8),
        TextField(controller: ctrl, decoration: InputDecoration(hintText: hint, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
      ],
    );
  }
}
