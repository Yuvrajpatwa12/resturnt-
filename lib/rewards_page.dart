import 'package:flutter/material.dart';


import 'cart_manager.dart';
import 'services/api_service.dart';
import 'services/tenant_service.dart';

class RewardsPage extends StatefulWidget {
  const RewardsPage({super.key});

  @override
  State<RewardsPage> createState() => _RewardsPageState();
}

class _RewardsPageState extends State<RewardsPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _rewards = [];
  Map<String, dynamic>? _settings;
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
    _settings = ShopManager.instance.loyaltySettings.value;
    _userPoints = ShopManager.instance.userPoints.value;
    _rewards = await ApiService.fetchRewards(tenant.id) ?? [];
    
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFF5C00),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Rewards & Loyalty", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF5C00)))
        : SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // --- 1. LOYALTY DASHBOARD ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFFFF5C00),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
              ),
              child: Column(
                children: [
                  Text("$_userPoints", style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w900)),
                  const Text("TOTAL POINTS AVAILABLE", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const SizedBox(height: 30),
                  // Progress Bar
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text("Gold Tier", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13)),
                          Text("750 pts to Platinum", style: TextStyle(color: Colors.white70, fontSize: 11)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 8,
                        width: double.infinity,
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: 0.65,
                          child: Container(decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(4))),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // --- 2. AVAILABLE COUPONS ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text("Spend Your Points", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                  Text("Terms Apply", style: TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: _rewards.isEmpty 
                ? const Center(child: Text("No rewards available at this time.", style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _rewards.length,
                    itemBuilder: (context, index) {
                      final r = _rewards[index];
                      return _buildCouponCard(
                        r['title'] ?? 'Reward', 
                        "${r['points_required']} pts", 
                        r['image_url'] ?? "https://images.unsplash.com/photo-1573080496219-bb080dd4f877?w=500",
                        r['id'],
                      );
                    },
                  ),
            ),

            const SizedBox(height: 30),

            // --- 3. POINTS HISTORY ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: const Align(
                alignment: Alignment.centerLeft,
                child: Text("Recent Activity", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
              ),
            ),
            const SizedBox(height: 12),
            ListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _buildHistoryItem("Group Dining Bonus", "Added 2 members to Table 12", "+400 pts", Colors.green),
                _buildHistoryItem("Order #9823", "Classic Roast Beef Combo", "+85 pts", Colors.green),
                _buildHistoryItem("Daily Visit", "In-House Check-in", "+25 pts", Colors.green),
                _buildHistoryItem("Coupon Redeemed", "Small Shake", "-250 pts", Colors.red),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildCouponCard(String title, String pts, String imgUrl, dynamic id) {
    return GestureDetector(
      onTap: () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Redeem Reward?"),
            content: Text("Are you sure you want to spend $pts for $title?"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCEL")),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("REDEEM")),
            ],
          ),
        );
        
        if (confirm == true) {
          final tenant = TenantService().currentTenant.value;
          final staff = TenantService().currentStaff.value;
          final uid = staff != null ? staff.id.toString() : ShopManager.instance.guestId.value;
          if (tenant == null || uid.isEmpty) return;
          
          final pointsNeeded = int.parse(pts.replaceAll(RegExp(r'[^0-9]'), ''));
          
          final res = await ApiService.claimReward(tenant.id, uid, int.parse(id.toString()));
          if (!mounted) return;
          
          if (res['status'] == 'success') {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reward Redeemed!"), backgroundColor: Colors.green));
             ShopManager.instance.userPoints.value -= pointsNeeded;
             _loadData(); // Refresh UI
          } else {
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? "Redemption failed."), backgroundColor: Colors.red));
          }
        }
      },
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: Image.network(imgUrl, height: 90, width: double.infinity, fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(height: 90, color: Colors.grey[200], child: const Icon(Icons.fastfood, color: Colors.grey))),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFFFF5C00).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text(pts, style: const TextStyle(color: Color(0xFFFF5C00), fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem(String title, String subtitle, String value, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.05), shape: BoxShape.circle),
            child: Icon(value.startsWith('+') ? Icons.add_rounded : Icons.remove_rounded, color: color, size: 20),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
              ],
            ),
          ),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 14)),
        ],
      ),
    );
  }
}
