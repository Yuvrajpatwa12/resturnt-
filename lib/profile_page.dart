import 'package:chiyabreak/staff/staff_hub.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'cart_manager.dart';

import 'passport_page.dart';
import 'mystery_box_page.dart';
import 'rewards_page.dart';
import 'live_order_tracking_screen.dart';
import 'my_orders_page.dart';
import 'user_profile_view_page.dart';
import 'messages_list_page.dart';
import 'chat_page.dart'; // Added
import 'settings_page.dart';
import 'services/tenant_service.dart';
import 'activity_share_page.dart';
import 'group_dining_wrapper.dart';


class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  void initState() {
    super.initState();
    // Refresh social data when profile is opened
    ShopManager.instance.fetchSocialLists();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => ShopManager.instance.currentTabIndex.value = 0,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.black),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsPage()));
            },
          ),
        ],
      ),
      body: DefaultTabController(
        length: (TenantService().currentTenant.value?.isPremiumEnabled ?? false) ? 3 : 2,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            final isPremium = TenantService().currentTenant.value?.isPremiumEnabled ?? false;
            return [
            SliverToBoxAdapter(child: _buildSocialHeader()),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(
                TabBar(
                  labelColor: Colors.black,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: const Color(0xFFFF5C00),
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.grid_view, size: 18),
                          SizedBox(width: 8),
                          Text("Activity", style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.person_outline, size: 18),
                          SizedBox(width: 8),
                          Text("About", style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    if (isPremium)
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.people_outline, size: 18),
                            SizedBox(width: 8),
                            Text("Social", style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ];
          },
          body: TabBarView(
            children: [
              _buildActivityTab(),
              _buildAboutTab(),
              if (TenantService().currentTenant.value?.isPremiumEnabled ?? false)
                _buildSocialTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSocialHeader() {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ValueListenableBuilder<String>(
                valueListenable: ShopManager.instance.userGender,
                builder: (context, gender, _) {
                  return CircleAvatar(
                    radius: 45,
                    backgroundImage: NetworkImage(
                      gender == 'Female'
                          ? 'https://img.freepik.com/free-vector/beauty-woman-face-concept_23-2148679462.jpg'
                          : 'https://img.freepik.com/free-vector/businessman-character-avatar-isolated_24877-60111.jpg',
                    ),
                  );
                },
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    ValueListenableBuilder<int>(
                      valueListenable: ShopManager.instance.totalOrdersCount,
                      builder: (context, val, child) => _buildSocialStat("$val", "Orders"),
                    ),
                    ValueListenableBuilder<int>(
                      valueListenable: ShopManager.instance.followersCount,
                      builder: (context, val, child) => _buildSocialStat("$val", "Followers"),
                    ),
                    ValueListenableBuilder<int>(
                      valueListenable: ShopManager.instance.followingCount,
                      builder: (context, val, child) => _buildSocialStat("$val", "Following"),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ValueListenableBuilder<String>(
            valueListenable: ShopManager.instance.customerName,
            builder: (context, name, _) => Text(
              name.isNotEmpty ? name : "Diner Profile", 
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
          Row(
            children: [
              Text(
                tenant.name.toUpperCase(),
                style: const TextStyle(color: Color(0xFFFF5C00), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
              const Text("  |  ", style: TextStyle(color: Colors.grey)),
              ValueListenableBuilder<String>(
                valueListenable: ShopManager.instance.customerEmail,
                builder: (context, email, _) => Text(
                  email,
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<bool>(
            valueListenable: ShopManager.instance.isEmailSynced,
            builder: (context, synced, _) {
              if (synced) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextButton.icon(
                  onPressed: () => _showManualSyncDialog(context),
                  icon: const Icon(Icons.sync, size: 16),
                  label: const Text("Sync Google Profile", style: TextStyle(fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFFFF5C00), backgroundColor: const Color(0xFFFF5C00).withValues(alpha: 0.05)),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          if (TenantService().currentTenant.value?.isPremiumEnabled ?? false)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ShopManager.instance.currentTabIndex.value = 2; // Navigate to Nearby
                    },
                    icon: const Icon(Icons.bolt, color: Colors.white),
                    label: const Text("Connect", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5C00),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const MessagesListPage()));
                    },
                    icon: const Icon(Icons.chat_bubble_outline, color: Colors.black, size: 20),
                    label: const Text("Messages", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSocialStat(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildActivityTab() {
    final isPremium = TenantService().currentTenant.value?.isPremiumEnabled ?? false;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLiveOrdersRow(),
          const SizedBox(height: 24),
          _buildSectionHeader("Recent Activity"),
          _buildMenuItem(Icons.history, "My Orders", "Track live orders & history", Colors.blue, () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const MyOrdersPage()));
          }),
          _buildMenuItem(Icons.auto_stories_outlined, "Share Your Story", "Post on Instagram & Earn 50 Points", Colors.pinkAccent, () {
            // Need to import activity_share_page.dart first
            Navigator.push(context, MaterialPageRoute(builder: (context) => const ActivitySharePage()));
          }),
          _buildMenuItem(Icons.account_balance_wallet_outlined, "Group Dining Session", "Live host & guest sync tools", Colors.deepOrange, () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const GroupDiningWrapper()));
          }),
          if (isPremium)
            _buildMenuItem(Icons.auto_stories, "Meat Master Passport", "Collect stamps & earn rewards", const Color(0xFFFF5C00), () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const PassportPage()));
            }),
          if (isPremium)
            _buildMenuItem(Icons.auto_awesome, "Surprise Mystery Box", "Win free items while in-house", Colors.purple, () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const MysteryBoxPage()));
            }),
          if (isPremium)
            _buildMenuItem(Icons.card_giftcard, "Redeem Rewards", "Spend your loyalty points", Colors.green, () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const RewardsPage()));
            }),
        ],
      ),
    );
  }

  Widget _buildAboutTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
        ],
      ),
    );
  }

  Widget _buildSocialTab() {
    return RefreshIndicator(
      onRefresh: () => ShopManager.instance.fetchSocialLists(),
      color: const Color(0xFFFF5C00),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionHeader("My Social Circle"),
              IconButton(
                onPressed: () => ShopManager.instance.fetchSocialLists(),
                icon: const Icon(Icons.sync, size: 16, color: Colors.grey),
              ),
            ],
          ),
          _buildSocialListTile(Icons.people_rounded, "Mutual Friends", "Connect & Message", Colors.green, () {
            _showSocialListModal("Mutual Friends", ShopManager.instance.friendsList);
          }),
          _buildSocialListTile(Icons.person_add_alt_1_rounded, "Requests", "Follow them back", Colors.orange, () {
            _showSocialListModal("Follow Requests", ShopManager.instance.requestsList, isRequest: true);
          }),
          _buildSocialListTile(Icons.assignment_ind_rounded, "Following", "People you follow", Colors.blue, () {
            _showSocialListModal("Following List", ShopManager.instance.followingList);
          }),
        ],
      ),
    );
  }

  Widget _buildSocialListTile(IconData icon, String title, String sub, Color color, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.withValues(alpha: 0.05))),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.1), child: Icon(icon, color: color, size: 20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text(sub, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
      ),
    );
  }

  void _showSocialListModal(String title, ValueListenable<List<Map<String, dynamic>>> list, {bool isRequest = false}) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => ValueListenableBuilder<List<Map<String, dynamic>>>(
        valueListenable: list,
        builder: (context, users, _) {
          return Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                if (users.isEmpty)
                  const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Text("No users found", style: TextStyle(color: Colors.grey))),
                ...users.map((u) {
                  String avatarUrl = u['gender'] == 'Female'
                      ? 'https://img.freepik.com/free-vector/beauty-woman-face-concept_23-2148679462.jpg'
                      : 'https://img.freepik.com/free-vector/businessman-character-avatar-isolated_24877-60111.jpg';
                  
                  return ListTile(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => UserProfileViewPage(userId: u['email'], name: u['name'])),
                      );
                    },
                    leading: CircleAvatar(backgroundImage: NetworkImage(avatarUrl)),
                    title: Text(u['name'] ?? 'Guest'),
                    subtitle: Text(u['email'] ?? ''),
                    trailing: isRequest 
                      ? ElevatedButton(
                          onPressed: () async {
                            final success = await ShopManager.instance.toggleFollow(u['email']);
                            if (success) {
                              ShopManager.instance.fetchSocialLists();
                            }
                          }, 
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF5C00), foregroundColor: Colors.white),
                          child: const Text("Follow Back"),
                        )
                      : (title == "Mutual Friends" 
                          ? IconButton(
                              icon: const Icon(Icons.chat_bubble_outline, color: Color(0xFFFF5C00)),
                              onPressed: () {
                                Navigator.pop(context); // Close modal
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => ChatPage(
                                    userId: u['email'], 
                                    userName: u['name'], 
                                    userImage: avatarUrl
                                  )),
                                );
                              },
                            ) 
                          : null),
                  );
                }),
              ],
            ),
          );
        }
      ),
    );
  }

  Widget _buildLiveOrdersRow() {
    return ValueListenableBuilder<int?>(
      valueListenable: ShopManager.instance.activeOrderId,
      builder: (context, orderId, child) {
        if (orderId == null) return const SizedBox.shrink();

        return InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => LiveOrderTrackingScreen(orderId: orderId))),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFF5C00), Color(0xFFFF8C00)]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: const Color(0xFFFF5C00).withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
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
                      Text("Order $orderId • Tap to track live status", style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 14),
              ],
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
        border: Border.all(color: Colors.grey.withValues(alpha: 0.05)),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
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

  void _showManualSyncDialog(BuildContext context) {
    final TextEditingController emailCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Sync Profile"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Enter your Google Email to sync your coins and orders across devices."),
            const SizedBox(height: 16),
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(labelText: "Google Email", border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (emailCtrl.text.contains('@')) {
                ShopManager.instance.syncCustomerIdentity(emailCtrl.text, name: emailCtrl.text.split('@').first);
                Navigator.pop(context);
              }
            },
            child: const Text("Sync Now"),
          ),
        ],
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
