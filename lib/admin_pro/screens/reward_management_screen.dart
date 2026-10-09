import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
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
  final Set<String> _locallyRedeemedCodes = {};
  final Set<String> _locallyRedeemedIds = {};

  // Controllers for Settings
  final TextEditingController _fixedPointsCtrl = TextEditingController();
  final TextEditingController _ptsPer100Ctrl = TextEditingController();
  final TextEditingController _groupBonusCtrl = TextEditingController();
  final TextEditingController _minRedeemCtrl = TextEditingController();
  final TextEditingController _codeVerifyCtrl = TextEditingController();
  bool _mboxEnabled = true;

  Map<String, dynamic>? _searchedClaimData;
  bool _isSearchingCode = false;
  String? _searchCodeError;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _lookupClaimCode() async {
    final queryCode = _codeVerifyCtrl.text.trim().toLowerCase();
    if (queryCode.isEmpty) {
      setState(() {
        _searchedClaimData = null;
        _searchCodeError = "Please enter a claim code first!";
      });
      return;
    }

    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return;

    setState(() {
      _isSearchingCode = true;
      _searchedClaimData = null;
      _searchCodeError = null;
    });

    final res = await ApiService.verifyClaimCode(tenant.id, queryCode);

    if (mounted) {
      setState(() {
        _isSearchingCode = false;
        if (res['status'] == 'success' && res['data'] != null) {
          _searchedClaimData = Map<String, dynamic>.from(res['data']);
          _searchCodeError = null;
        } else {
          _searchedClaimData = null;
          _searchCodeError = res['message'] ?? "Invalid or non-existent claim code!";
        }
      });
    }
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
      final fetched = await ApiService.fetchAdminClaimHistory(tenant.id) ?? [];
      for (var c in fetched) {
        final code = (c['claim_code'] ?? '').toString().trim().toLowerCase();
        final id = (c['id'] ?? '').toString().trim();
        final redeemedAt = (c['redeemed_at'] ?? '').toString().trim();
        if ((redeemedAt.isNotEmpty && redeemedAt != 'null') || _locallyRedeemedCodes.contains(code) || _locallyRedeemedIds.contains(id)) {
          c['status'] = 'redeemed';
        }
      }
      _claims = fetched;
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Redeemable Items", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                  SizedBox(height: 4),
                  Text("Manage customer redeemable rewards and verify claim codes.", style: TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _showAddRewardDialog, 
                icon: const Icon(Icons.add), 
                label: const Text("ADD REWARD"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4C49ED),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // QUICK CODE VERIFIER BAR WITH LIVE MEMBER PREVIEW
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: AdminTheme.softShadow,
              border: Border.all(
                color: _searchCodeError != null
                    ? Colors.red.shade300
                    : (_searchedClaimData != null ? Colors.green.shade300 : const Color(0xFF4C49ED).withValues(alpha: 0.2)),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4C49ED).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF4C49ED), size: 24),
                        ),
                        const SizedBox(width: 16),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Quick Code Verifier & Redemption", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            SizedBox(height: 2),
                            Text("Type claim code (e.g. 55391 or MYS-A2BAF) to preview member & confirm redemption.", style: TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 240,
                          height: 46,
                          child: TextField(
                            controller: _codeVerifyCtrl,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            onSubmitted: (_) => _lookupClaimCode(),
                            decoration: InputDecoration(
                              hintText: "Enter Code (e.g. 55391)...",
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFF4C49ED), width: 2),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _isSearchingCode ? null : _lookupClaimCode,
                          icon: _isSearchingCode
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.search_rounded, size: 18),
                          label: const Text("SEARCH CODE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4C49ED),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // LIVE PREVIEW CARD IF SEARCH MATCHES A CLAIM
                if (_searchedClaimData != null) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.green.shade200, width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.verified_user_rounded, color: Colors.green, size: 20),
                            const SizedBox(width: 8),
                            const Text("MATCHED CLAIM RECORD FOUND", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.green, fontSize: 12, letterSpacing: 0.5)),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: (_searchedClaimData!['status'] ?? '').toString().toLowerCase() == 'redeemed' ? Colors.green.shade100 : Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                ((_searchedClaimData!['status'] ?? '').toString().toUpperCase()),
                                style: TextStyle(
                                  color: (_searchedClaimData!['status'] ?? '').toString().toLowerCase() == 'redeemed' ? Colors.green.shade800 : Colors.orange.shade900,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("CLAIM MEMBER", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                                  const SizedBox(height: 2),
                                  Text(_formatUserName(_searchedClaimData!['user_name'], _searchedClaimData!['user_id']), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B))),
                                  Text("Email: ${_searchedClaimData!['user_email'] ?? _searchedClaimData!['user_id'] ?? 'N/A'}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("REWARD ITEM", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                                  const SizedBox(height: 2),
                                  Text(_searchedClaimData!['reward_title'] ?? _searchedClaimData!['reward_name'] ?? 'Mystery Prize', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF4C49ED))),
                                  Text("Code: ${_searchedClaimData!['claim_code']}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () async {
                                final tenant = TenantService().currentTenant.value;
                                if (tenant == null) return;
                                final code = _searchedClaimData!['claim_code']?.toString() ?? '';
                                final res = await ApiService.redeemClaimCode(tenant.id, code);
                                if (res['status'] == 'success') {
                                  setState(() {
                                    _searchedClaimData = null;
                                    _codeVerifyCtrl.clear();
                                  });
                                  _loadData();
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(res['message'] ?? "Reward code $code REDEEMED successfully!"), backgroundColor: Colors.green),
                                    );
                                  }
                                } else {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(res['message'] ?? "Failed to redeem code!"), backgroundColor: Colors.red),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.check_circle_rounded, size: 18),
                              label: const Text("CONFIRM & REDEEM REWARD", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                // ERROR DISPLAY IF CODE NOT FOUND
                if (_searchCodeError != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(_searchCodeError!, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          _rewards.isEmpty 
            ? const Center(child: Padding(padding: EdgeInsets.all(40), child: Text("No rewards configured. Tap '+ ADD REWARD' to start!")))
            : GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 280, 
                  mainAxisSpacing: 20, 
                  crossAxisSpacing: 20, 
                  childAspectRatio: 0.78,
                ),
                itemCount: _rewards.length,
                itemBuilder: (context, index) {
                  final r = _rewards[index];
                  return _buildRewardCard(r);
                },
              ),
          const SizedBox(height: 60),
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
                  title: Text(p['reward_name'] ?? p['prize_name'] ?? p['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
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
    final filteredClaims = _claims.where((c) {
      if (_codeVerifyCtrl.text.trim().isEmpty) return true;
      final query = _codeVerifyCtrl.text.trim().toLowerCase();
      final code = (c['claim_code'] ?? '').toString().toLowerCase();
      final title = (c['reward_title'] ?? '').toString().toLowerCase();
      final user = (c['user_id'] ?? '').toString().toLowerCase();
      return code.contains(query) || title.contains(query) || user.contains(query);
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text("Redemption History & Code Verification", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                  Text("Verify customer claim codes and redeem rewards.", style: TextStyle(color: Colors.grey)),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Color(0xFF4C49ED)),
                onPressed: _loadData,
                tooltip: "Refresh Claims",
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Code Verification Input for Waiters / Staff
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: AdminTheme.softShadow),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeVerifyCtrl,
                    onChanged: (v) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: "Enter 5-digit customer claim code (e.g. 83462)...",
                      prefixIcon: const Icon(Icons.qr_code_rounded, color: Color(0xFF4C49ED)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4C49ED),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final queryCode = _codeVerifyCtrl.text.trim().toLowerCase();
                    if (queryCode.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter a claim code first!")));
                      return;
                    }

                    final tenant = TenantService().currentTenant.value;
                    if (tenant == null) return;

                    // Optimistically update matching claim in memory for instant visual feedback
                    _locallyRedeemedCodes.add(queryCode);
                    for (var c in _claims) {
                      if ((c['claim_code'] ?? '').toString().toLowerCase() == queryCode) {
                        setState(() {
                          c['status'] = 'redeemed';
                        });
                        if (c['id'] != null) _locallyRedeemedIds.add(c['id'].toString());
                      }
                    }

                    final res = await ApiService.redeemClaimCode(tenant.id, queryCode);
                    if (res['status'] == 'success') {
                      _codeVerifyCtrl.clear();
                      await _loadData();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(res['message'] ?? "Reward code $queryCode REDEEMED successfully!"), backgroundColor: Colors.green),
                        );
                      }
                    } else {
                      // Fallback: match by local claim ID
                      final match = _claims.firstWhere(
                        (c) => (c['claim_code'] ?? '').toString().toLowerCase() == queryCode,
                        orElse: () => {},
                      );
                      if (match.isNotEmpty) {
                        final claimId = int.tryParse(match['id']?.toString() ?? '0') ?? 0;
                        if (claimId > 0) _locallyRedeemedIds.add(claimId.toString());
                        final success = await ApiService.updateClaimStatus(claimId, 'redeemed');
                        if (success) {
                          _codeVerifyCtrl.clear();
                          await _loadData();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Code verified! Reward '${match['reward_title'] ?? match['reward_name']}' REDEEMED!"), backgroundColor: Colors.green),
                            );
                          }
                          return;
                        }
                      }
                      await _loadData();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(res['message'] ?? "Invalid or non-existent claim code!"), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.verified_rounded, size: 18),
                  label: const Text("VERIFY & REDEEM CODE"),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Expanded(
            child: Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: AdminTheme.softShadow),
              child: filteredClaims.isEmpty
                ? const Center(child: Text("No claims found matching code or user.", style: TextStyle(color: Colors.grey)))
                : ListView.separated(
                    itemCount: filteredClaims.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final c = filteredClaims[i];
                      final st = (c['status'] ?? '').toString().toLowerCase();
                      final redeemedAt = (c['redeemed_at'] ?? '').toString().trim();
                      final isRedeemed = st == 'redeemed' || st == 'claimed' || st == 'verified' || st == 'claimed_by_staff' || (redeemedAt.isNotEmpty && redeemedAt != 'null');
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        leading: CircleAvatar(
                          backgroundColor: isRedeemed ? Colors.green.shade50 : const Color(0xFFF1F4F9),
                          child: Icon(isRedeemed ? Icons.check_circle_rounded : Icons.person_rounded, color: isRedeemed ? Colors.green : const Color(0xFF4C49ED)),
                        ),
                        title: Text(_formatUserName(c['user_name'], c['user_id']), style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("Reward: ${c['reward_title'] ?? 'Surprise Prize'} • Code: ${c['claim_code'] ?? 'N/A'}"),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isRedeemed ? Colors.green.shade50 : Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                isRedeemed ? "REDEEMED" : "PENDING",
                                style: TextStyle(color: isRedeemed ? Colors.green.shade800 : Colors.orange.shade800, fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ),
                            if (!isRedeemed) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                                tooltip: "Mark as Redeemed",
                                onPressed: () async {
                                  final claimId = int.parse(c['id'].toString());
                                  final code = (c['claim_code'] ?? '').toString().toLowerCase();
                                  _locallyRedeemedIds.add(claimId.toString());
                                  if (code.isNotEmpty) _locallyRedeemedCodes.add(code);
                                  setState(() {
                                    c['status'] = 'redeemed';
                                  });
                                  final success = await ApiService.updateClaimStatus(claimId, 'redeemed');
                                  if (!success && code.isNotEmpty) {
                                    final tenant = TenantService().currentTenant.value;
                                    if (tenant != null) await ApiService.redeemClaimCode(tenant.id, code);
                                  }
                                  await _loadData();
                                },
                              ),
                            ],
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

  String _formatUserName(dynamic name, dynamic userId) {
    if (name != null && name.toString().trim().isNotEmpty) {
      return name.toString().trim();
    }
    final uId = (userId ?? '').toString().trim();
    if (uId.isEmpty) return 'Guest Customer';
    if (uId.toLowerCase().startsWith('guest_')) {
      final parts = uId.split('_');
      if (parts.length > 1) {
        return "Guest Customer (#${parts.last})";
      }
      return "Guest Customer";
    }
    return uId;
  }

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

  String _formatImageUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) return "";
    final trimmed = rawUrl.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://') || trimmed.startsWith('data:image')) {
      return trimmed;
    }
    return "${ApiService.baseUrl}/${trimmed.replaceFirst(RegExp(r'^\/'), '')}";
  }

  Widget _buildRewardCard(Map<String, dynamic> r) {
    final String formattedImg = _formatImageUrl(r['image_url']);
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: AdminTheme.softShadow),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: formattedImg.isNotEmpty
                      ? Image.network(
                          formattedImg,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: const Color(0xFFF8FAFC),
                            child: const Center(
                              child: Icon(Icons.fastfood_rounded, size: 44, color: Color(0xFFFF5C00)),
                            ),
                          ),
                        )
                      : Container(
                          color: const Color(0xFFF8FAFC),
                          child: const Center(
                            child: Icon(Icons.fastfood_rounded, size: 44, color: Color(0xFFFF5C00)),
                          ),
                        ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.white.withValues(alpha: 0.95),
                        child: IconButton(
                          icon: const Icon(Icons.edit, color: Color(0xFF4C49ED), size: 16),
                          padding: EdgeInsets.zero,
                          tooltip: "Edit Reward",
                          onPressed: () => _showEditRewardDialog(r),
                        ),
                      ),
                      const SizedBox(width: 6),
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.white.withValues(alpha: 0.95),
                        child: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red, size: 16),
                          padding: EdgeInsets.zero,
                          tooltip: "Delete Reward",
                          onPressed: () async {
                            await ApiService.deleteReward(int.parse(r['id'].toString()));
                            _loadData();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Text(
                  r['title'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4C49ED).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "${r['points_required']} Pts Required",
                    style: const TextStyle(color: Color(0xFF4C49ED), fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
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
    final imageUrlCtrl = TextEditingController();
    Uint8List? selectedImageBytes;
    String? selectedImageName;
    bool isUploading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text("New Redeemable Reward", style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDialogField("Item Name *", titleCtrl, "e.g. Free Burger"),
                const SizedBox(height: 16),
                _buildDialogField("Points Required *", pointsCtrl, "e.g. 500"),
                const SizedBox(height: 16),

                // Image File Picker Button
                const Text("Reward Image (Pick from PC/Phone) *", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final picker = ImagePicker();
                    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
                    if (pickedFile != null) {
                      final bytes = await pickedFile.readAsBytes();
                      setModalState(() {
                        selectedImageBytes = bytes;
                        selectedImageName = pickedFile.name;
                      });
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: selectedImageBytes != null ? Colors.green.shade50 : const Color(0xFFF1F4F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: selectedImageBytes != null ? Colors.green : Colors.black12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selectedImageBytes != null ? Icons.check_circle_rounded : Icons.cloud_upload_outlined,
                          color: selectedImageBytes != null ? Colors.green : const Color(0xFF4C49ED),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            selectedImageBytes != null ? (selectedImageName ?? "Image Selected") : "Select Image from PC/Phone",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: selectedImageBytes != null ? Colors.green.shade800 : Colors.black87,
                            ),
                          ),
                        ),
                        if (selectedImageBytes != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(selectedImageBytes!, width: 36, height: 36, fit: BoxFit.cover),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Center(child: Text("— OR PASTE IMAGE URL —", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold))),
                const SizedBox(height: 8),
                _buildDialogField("Direct Image URL (Optional)", imageUrlCtrl, "https://..."),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: isUploading ? null : () => Navigator.pop(ctx), child: const Text("CANCEL")),
            ElevatedButton(
              onPressed: isUploading ? null : () async {
                final tenant = TenantService().currentTenant.value;
                if (tenant == null || titleCtrl.text.trim().isEmpty) return;

                setModalState(() => isUploading = true);

                String imageUrl = imageUrlCtrl.text.trim();
                if (selectedImageBytes != null && selectedImageName != null) {
                  final uploadedUrl = await ApiService.uploadProductImage(selectedImageBytes!, selectedImageName!);
                  if (uploadedUrl != null && uploadedUrl.isNotEmpty) imageUrl = uploadedUrl;
                }

                await ApiService.addReward({
                  "tenant_id": tenant.id,
                  "title": titleCtrl.text.trim(),
                  "points_required": int.tryParse(pointsCtrl.text.trim()) ?? 100,
                  "image_url": imageUrl,
                });

                if (ctx.mounted) Navigator.pop(ctx);
                _loadData();
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4C49ED), foregroundColor: Colors.white),
              child: isUploading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("ADD ITEM"),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditRewardDialog(Map<String, dynamic> r) {
    final titleCtrl = TextEditingController(text: r['title'] ?? '');
    final pointsCtrl = TextEditingController(text: r['points_required']?.toString() ?? '100');
    final imageUrlCtrl = TextEditingController(text: r['image_url'] ?? '');
    Uint8List? selectedImageBytes;
    String? selectedImageName;
    bool isUploading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text("Edit Redeemable Reward", style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDialogField("Item Name *", titleCtrl, "e.g. Free Burger"),
                const SizedBox(height: 16),
                _buildDialogField("Points Required *", pointsCtrl, "e.g. 500"),
                const SizedBox(height: 16),

                // Image File Picker Button
                const Text("Reward Image (Pick from PC/Phone)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final picker = ImagePicker();
                    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
                    if (pickedFile != null) {
                      final bytes = await pickedFile.readAsBytes();
                      setModalState(() {
                        selectedImageBytes = bytes;
                        selectedImageName = pickedFile.name;
                      });
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: selectedImageBytes != null ? Colors.green.shade50 : const Color(0xFFF1F4F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: selectedImageBytes != null ? Colors.green : Colors.black12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selectedImageBytes != null ? Icons.check_circle_rounded : Icons.cloud_upload_outlined,
                          color: selectedImageBytes != null ? Colors.green : const Color(0xFF4C49ED),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            selectedImageBytes != null ? (selectedImageName ?? "New Image Selected") : "Replace Image from PC/Phone",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: selectedImageBytes != null ? Colors.green.shade800 : Colors.black87,
                            ),
                          ),
                        ),
                        if (selectedImageBytes != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(selectedImageBytes!, width: 36, height: 36, fit: BoxFit.cover),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Center(child: Text("— OR UPDATE IMAGE URL —", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold))),
                const SizedBox(height: 8),
                _buildDialogField("Direct Image URL", imageUrlCtrl, "https://..."),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: isUploading ? null : () => Navigator.pop(ctx), child: const Text("CANCEL")),
            ElevatedButton(
              onPressed: isUploading ? null : () async {
                final tenant = TenantService().currentTenant.value;
                if (tenant == null || titleCtrl.text.trim().isEmpty) return;

                setModalState(() => isUploading = true);

                String imageUrl = imageUrlCtrl.text.trim();
                if (selectedImageBytes != null && selectedImageName != null) {
                  final uploadedUrl = await ApiService.uploadProductImage(selectedImageBytes!, selectedImageName!);
                  if (uploadedUrl != null && uploadedUrl.isNotEmpty) imageUrl = uploadedUrl;
                }

                await ApiService.updateReward({
                  "id": int.parse(r['id'].toString()),
                  "tenant_id": tenant.id,
                  "title": titleCtrl.text.trim(),
                  "points_required": int.tryParse(pointsCtrl.text.trim()) ?? 100,
                  "image_url": imageUrl,
                });

                if (ctx.mounted) Navigator.pop(ctx);
                _loadData();
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4C49ED), foregroundColor: Colors.white),
              child: isUploading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("SAVE CHANGES"),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddMysteryDialog() {
    final nameCtrl = TextEditingController();
    final probCtrl = TextEditingController();
    Uint8List? selectedImageBytes;
    String? selectedImageName;
    bool isUploading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text("New Mystery Prize", style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDialogField("Prize Name *", nameCtrl, "e.g. Free Jamocha Shake"),
                const SizedBox(height: 16),
                _buildDialogField("Win Probability (%) *", probCtrl, "e.g. 10"),
                const SizedBox(height: 16),

                // Image File Picker Button
                const Text("Prize Image *", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final picker = ImagePicker();
                    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
                    if (pickedFile != null) {
                      final bytes = await pickedFile.readAsBytes();
                      setModalState(() {
                        selectedImageBytes = bytes;
                        selectedImageName = pickedFile.name;
                      });
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: selectedImageBytes != null ? Colors.green.shade50 : const Color(0xFFF1F4F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: selectedImageBytes != null ? Colors.green : Colors.black12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selectedImageBytes != null ? Icons.check_circle_rounded : Icons.cloud_upload_outlined,
                          color: selectedImageBytes != null ? Colors.green : const Color(0xFF4C49ED),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            selectedImageBytes != null ? (selectedImageName ?? "Image Selected") : "Select Image from PC/Phone",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: selectedImageBytes != null ? Colors.green.shade800 : Colors.black87,
                            ),
                          ),
                        ),
                        if (selectedImageBytes != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(selectedImageBytes!, width: 36, height: 36, fit: BoxFit.cover),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: isUploading ? null : () => Navigator.pop(ctx), child: const Text("CANCEL")),
            ElevatedButton(
              onPressed: isUploading ? null : () async {
                final tenant = TenantService().currentTenant.value;
                final String name = nameCtrl.text.trim();
                if (tenant == null || name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Prize name is required!")));
                  return;
                }

                setModalState(() => isUploading = true);

                String imageUrl = "";
                if (selectedImageBytes != null && selectedImageName != null) {
                  final uploadedUrl = await ApiService.uploadProductImage(selectedImageBytes!, selectedImageName!);
                  if (uploadedUrl != null) imageUrl = uploadedUrl;
                }

                final res = await ApiService.addMysteryPrize({
                  "tenant_id": tenant.id,
                  "title": name,
                  "prize_name": name,
                  "reward_name": name,
                  "probability": double.tryParse(probCtrl.text.trim()) ?? 10.0,
                  "image_url": imageUrl,
                });

                if (ctx.mounted) Navigator.pop(ctx);
                if (res['success'] == true) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mystery Prize added successfully!"), backgroundColor: Colors.green));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${res['message']}"), backgroundColor: Colors.red));
                }
                _loadData();
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4C49ED)),
              child: isUploading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("ADD PRIZE"),
            ),
          ],
        ),
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
