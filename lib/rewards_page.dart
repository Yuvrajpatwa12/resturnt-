import 'package:flutter/material.dart';
import 'cart_manager.dart';
import 'services/api_service.dart';
import 'services/tenant_service.dart';
import 'widgets/claim_details_modal.dart';
import 'package:intl/intl.dart';

class RewardsPage extends StatefulWidget {
  const RewardsPage({super.key});

  @override
  State<RewardsPage> createState() => _RewardsPageState();
}

class _RewardsPageState extends State<RewardsPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _rewards = [];
  List<Map<String, dynamic>> _claimHistory = []; // Added
  int _userPoints = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return;

    setState(() => _isLoading = true);
    
    await ShopManager.instance.refreshUserPoints();
    _userPoints = ShopManager.instance.userPoints.value;
    
    final List<dynamic> results = await Future.wait([
       ApiService.fetchRewards(tenant.id),
       ApiService.fetchClaimHistory(tenant.id, ShopManager.instance.currentUserId)
    ]);

    _rewards = List<Map<String, dynamic>>.from(results[0] ?? []);
    _claimHistory = List<Map<String, dynamic>>.from(results[1] ?? []);
    
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Rewards & Benefits", 
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w900, fontSize: 18)
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {}, 
            icon: const Icon(Icons.notifications_none_rounded, color: Colors.black87)
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF5C00)))
        : RefreshIndicator(
            onRefresh: _loadData,
            color: const Color(0xFFFF5C00),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  const Text(
                    "Tokens That Pay Back", 
                    style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold)
                  ),
                  const SizedBox(height: 20),

                  // --- 1. PREMIUM POINTS CARD ---
                  _buildPremiumPointsCard(),

                  const SizedBox(height: 32),
                  
                  // --- 2. MANAGE YOUR REWARDS ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Spend Your Coins", 
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))
                      ),
                      TextButton(
                        onPressed: () {}, 
                        child: const Text("View All", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12))
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (_rewards.isEmpty)
                    _buildEmptyState()
                  else
                    ..._rewards.map((r) => _buildRewardCard(r)),

                  const SizedBox(height: 32),

                  // --- 3. RECENT ACTIVITY ---
                  const Text(
                    "Recent Activity", 
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))
                  ),
                  const SizedBox(height: 16),
                  if (_claimHistory.isEmpty)
                    const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("No activity yet", style: TextStyle(color: Colors.grey))))
                  else
                    ..._claimHistory.map((c) => _buildHistoryItem(c)),
                  
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildPremiumPointsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2D3282), Color(0xFF3B82F6)], // Premium Deep Blue to Light Blue
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                  SizedBox(width: 12),
                  Text("Total Coins", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                child: const Icon(Icons.north_east_rounded, color: Colors.white, size: 14),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            "$_userPoints", 
            style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900, letterSpacing: -1)
          ),
          const Text(
            "AVAILABLE TO REDEEM", 
            style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)
          ),
          const SizedBox(height: 32),
          // Tier Progress
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text("Gold Tier", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.w900, fontSize: 12)),
                  Text("750 pts to Platinum", style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                height: 6,
                width: double.infinity,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: 0.65,
                  child: Container(decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(10))),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRewardCard(Map<String, dynamic> r) {
    final int pointsReq = int.tryParse(r['points_required']?.toString() ?? '0') ?? 0;
    final bool canClaim = _userPoints >= pointsReq;
    final String title = r['title'] ?? 'Reward';
    final String img = r['image_url'] ?? "https://images.unsplash.com/photo-1573080496219-bb080dd4f877?w=500";

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Row(
        children: [
          // Reward Image
          Container(
            width: 70, height: 70,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                img, 
                fit: BoxFit.cover,
                errorBuilder: (c,e,s) => const Icon(Icons.fastfood, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title, 
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF1E293B)),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: canClaim ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    canClaim ? "Ready to Claim" : "Need ${pointsReq - _userPoints} more pts",
                    style: TextStyle(
                      color: canClaim ? Colors.green[700] : Colors.red[700], 
                      fontSize: 10, 
                      fontWeight: FontWeight.bold
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Action Button
          _buildClaimButton(r, canClaim),
        ],
      ),
    );
  }

  Widget _buildClaimButton(Map<String, dynamic> r, bool enabled) {
    return InkWell(
      onTap: enabled ? () => _handleClaim(r) : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: enabled 
              ? const LinearGradient(colors: [Color(0xFFFF5C00), Color(0xFFFF8C00)]) 
              : null,
          color: enabled ? null : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            if (!enabled) const Icon(Icons.lock_outline_rounded, size: 14, color: Colors.grey),
            if (!enabled) const SizedBox(width: 6),
            Text(
              enabled ? "Claim Now" : "${r['points_required']} pts",
              style: TextStyle(
                color: enabled ? Colors.white : Colors.grey[600],
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleClaim(Map<String, dynamic> r) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Redeem Reward?"),
        content: Text("Spend ${r['points_required']} coins for ${r['title']}?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCEL")),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("YES, REDEEM")),
        ],
      ),
    );
    
    if (confirm == true) {
      final tenant = TenantService().currentTenant.value;
      final uid = ShopManager.instance.currentUserId;
      if (tenant == null || uid.isEmpty) return;

      setState(() => _isLoading = true);
      final res = await ApiService.claimReward(tenant.id, uid, int.parse(r['id'].toString()));
      
      if (res['status'] == 'success') {
        if (mounted) {
           showDialog(
             context: context,
             builder: (c) => AlertDialog(
               title: const Text("Claim Successful! 🎉"),
               content: Column(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   const Text("Show this code to the waiter:"),
                   const SizedBox(height: 16),
                   Text(res['claim_code'], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2, color: Color(0xFFFF5C00))),
                 ],
               ),
               actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("DONE"))],
             ),
           );
        }
        await _loadData(); // Reload points
      } else {
        setState(() => _isLoading = false);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? "Error"), backgroundColor: Colors.red));
      }
    }
  }

  Widget _buildHistoryItem(Map<String, dynamic> c) {
    final String title = c['reward_title'] ?? 'Mystery Prize';
    final String dateStr = c['created_at'] ?? '';
    final String pts = "-${c['points_required'] ?? 0}";
    final bool isClaimed = c['status'] == 'Claimed';

    DateTime date;
    try { date = DateTime.parse(dateStr); } catch (e) { date = DateTime.now(); }

    return GestureDetector(
      onTap: () => _showClaimDetails(c),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isClaimed ? Colors.blue.withValues(alpha: 0.1) : const Color(0xFFFF5C00).withValues(alpha: 0.1), 
                shape: BoxShape.circle
              ),
              child: Icon(
                isClaimed ? Icons.check_circle_outline : Icons.qr_code_2_rounded, 
                color: isClaimed ? Colors.blue : const Color(0xFFFF5C00), 
                size: 18
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B))),
                  Text(
                    DateFormat('MMM dd, hh:mm a').format(date), 
                    style: const TextStyle(color: Colors.grey, fontSize: 11)
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(pts, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w900, fontSize: 15)),
                Text(
                  isClaimed ? "SERVED" : "ACTIVE", 
                  style: TextStyle(
                    color: isClaimed ? Colors.blue : const Color(0xFFFF5C00), 
                    fontSize: 9, 
                    fontWeight: FontWeight.bold
                  )
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showClaimDetails(Map<String, dynamic> c) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ClaimDetailsModal(claim: c),
    ).then((_) => _loadData()); // Refresh on close in case it was served
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(Icons.card_giftcard_rounded, size: 64, color: Color(0xFFE2E8F0)),
            SizedBox(height: 16),
            Text("No rewards available right now.", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
