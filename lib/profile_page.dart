import 'package:chiyabreak/staff/staff_hub.dart';
import 'package:flutter/material.dart';
import 'cart_manager.dart';
import 'billing_page.dart';
import 'passport_page.dart';
import 'mystery_box_page.dart';
import 'rewards_page.dart';
import 'live_order_tracking_screen.dart';
import 'my_orders_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 1. PREMIUM HEADER
          SliverToBoxAdapter(child: _buildPremiumHeader()),

          // 2. STATS SECTION
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: _buildStatGrid(),
            ),
          ),

          // 3. LIVE ORDERS TRACKING
          SliverToBoxAdapter(child: _buildLiveOrdersRow()),

          // 4. DASHBOARD ITEMS
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 24),
                _buildSectionHeader("Activity & Rewards"),
                _buildMenuItem(Icons.history, "My Orders", "Track live orders & history", Colors.blue, () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const MyOrdersPage()));
                }),
                _buildMenuItem(Icons.auto_stories, "Meat Master Passport", "Collect stamps & earn rewards", const Color(0xFFFF5C00), () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const PassportPage()));
                }),
                _buildMenuItem(Icons.auto_awesome, "Surprise Mystery Box", "Win free items while in-house", Colors.purple, () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const MysteryBoxPage()));
                }),
                _buildMenuItem(Icons.card_giftcard, "Redeem Rewards", "Spend your loyalty points", Colors.green, () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const RewardsPage()));
                }),

                const SizedBox(height: 24),
                _buildSectionHeader("Account Settings"),
                _buildMenuItem(Icons.payment_rounded, "Payment Methods", "Visa •••• 4242", Colors.teal, () {}),
                _buildMenuItem(Icons.notifications_none_rounded, "Notifications", "Sounds & Alerts", Colors.amber, () {}),
                _buildMenuItem(Icons.language_rounded, "App Language", "English (US)", Colors.indigo, () {}),

                const SizedBox(height: 24),
                _buildSectionHeader("Internal Tools"),
                _buildMenuItem(Icons.admin_panel_settings_rounded, "Staff Dashboard", "Access management suite", Colors.redAccent, () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const StaffHub()));
                }),
                _buildMenuItem(Icons.hub_rounded, "Master Hub (SaaS)", "Super Admin root access", Colors.black87, () {
                  Navigator.pushNamed(context, '/super-admin');
                }),

                const SizedBox(height: 40),
                _buildLogoutButton(),
                const SizedBox(height: 60),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumHeader() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Background Decorative Shape
        Container(
          height: 200,
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 60),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0047AB), Color(0xFF002D62)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(50)),
          ),
        ),
        // Profile Info
        Positioned(
          bottom: 0,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: const CircleAvatar(
                  radius: 55,
                  backgroundImage: NetworkImage('https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=400'),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "Yuraj Singh",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const Text(
                "GOLD MEMBER • SINCE 2024",
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFFFF5C00), letterSpacing: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatGrid() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem("50", "Coins", Icons.monetization_on_rounded, Colors.amber),
          _buildDivider(),
          _buildStatItem("42", "Visits", Icons.restaurant_rounded, const Color(0xFFFF5C00)),
          _buildDivider(),
          _buildStatItem("1.2K", "G-Points", Icons.stars_rounded, Colors.blueAccent),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 26),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(height: 30, width: 1, color: Colors.grey[200]);
  }

  Widget _buildLiveOrdersRow() {
    return ValueListenableBuilder<int?>(
      valueListenable: ShopManager.instance.activeOrderId,
      builder: (context, orderId, child) {
        if (orderId == null) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => LiveOrderTrackingScreen(orderId: orderId))),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFF5C00), Color(0xFFFF8C00)]),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: const Color(0xFFFF5C00).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Row(
                children: [
                  const CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.delivery_dining, color: Color(0xFFFF5C00))),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("ACTIVE ORDER IN PROGRESS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5)),
                        Text("Order #$orderId • Tap to track live status", style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 14),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 16),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 1.5),
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, String sub, Color color, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withOpacity(0.05)),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text(sub, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 18),
        label: const Text("LOGOUT ACCOUNT", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.redAccent, width: 1)),
        ),
      ),
    );
  }
}
