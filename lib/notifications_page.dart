import 'package:flutter/material.dart';
import 'cart_manager.dart';
import 'user_profile_view_page.dart';
import 'my_orders_page.dart';
import 'rewards_page.dart';
import 'nearby_page.dart';
import 'services/tenant_service.dart';
import 'services/api_service.dart';


class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    ShopManager.instance.clearNotificationBadge();
    ShopManager.instance.refreshNotifications();
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
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Your notifications", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 22)),
        actions: [
          ElevatedButton.icon(
            onPressed: () async {
              await ShopManager.instance.checkOrRequestNotificationOnAction();
              final tenant = TenantService().currentTenant.value;
              if (tenant != null && ShopManager.instance.currentUserId.isNotEmpty) {
                final success = await ApiService.sendTestOfferNotification(tenant.id, ShopManager.instance.currentUserId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success ? "🎉 Test offer push sent to your device!" : "⚠️ Failed to send test push"),
                      backgroundColor: success ? Colors.green : Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5C00),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            icon: const Icon(Icons.local_offer_rounded, size: 16),
            label: const Text("Test Offer", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const SizedBox(width: 6),
          TextButton.icon(
            onPressed: () => ShopManager.instance.clearNotificationBadge(),
            icon: const Icon(Icons.done_all, size: 18),
            label: const Text("Read All", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: const Color(0xFF6236FF),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF6236FF),
          tabs: const [
            Tab(text: "View all"),
            Tab(text: "Mentions"),
            Tab(text: "Followers"),
            Tab(text: "Invites"),
          ],
        ),
      ),
      body: ValueListenableBuilder<List<Map<String, dynamic>>>(
        valueListenable: ShopManager.instance.notificationsList,
        builder: (context, notifications, _) {
          return TabBarView(
            controller: _tabController,
            children: [
              _buildList(notifications, "all"),
              _buildList(notifications, "message"),
              _buildList(notifications, "follow"),
              _buildList(notifications, "wave"),
            ],
          );
        },
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> all, String filter) {
    final filtered = filter == "all" 
        ? all 
        : all.where((n) {
            final type = n['type'];
            return type == filter || (filter == 'follow' && type == 'follow_back');
          }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey[200]),
            const SizedBox(height: 16),
            const Text("No notifications yet", style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ShopManager.instance.refreshNotifications();
      },
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: filtered.length,
        separatorBuilder: (context, index) => const SizedBox(height: 24),
        itemBuilder: (context, index) {
          final n = filtered[index];
          return InkWell(
            onTap: () async {
              final notificationId =
                  int.tryParse(n['id']?.toString() ?? '');
              if (notificationId != null) {
                await ShopManager.instance.acknowledgeNotification(
                  notificationId,
                );
                if (!context.mounted) return;
              }
              final senderId = n['sender_id']?.toString().trim();
              final type = n['type']?.toString();
              final message = n['message']?.toString() ?? '';

              // 1. Direct match by sender_id if valid
              if (senderId != null && senderId.isNotEmpty && senderId != 'null') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => UserProfileViewPage(userId: senderId)),
                );
                return;
              }

              // 2. Fallback: Extract @username from message text if sender_id was null in old database rows
              if (message.contains('@')) {
                final match = RegExp(r'@([a-zA-Z0-9_\.\-]+)').firstMatch(message);
                if (match != null) {
                  final extractedHandle = match.group(1);
                  if (extractedHandle != null && extractedHandle.isNotEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => UserProfileViewPage(userId: extractedHandle)),
                    );
                    return;
                  }
                }
              }

              // 3. Fallback by notification type
              if (type == 'follow' || type == 'follow_back' || type == 'wave') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const NearbyPage()),
                );
              } else if (type == 'order') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MyOrdersPage()),
                );
              } else if (type == 'points') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const RewardsPage()),
                );
              }
            },
            child: _buildNotificationItem(n),
          );
        },
      ),
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> n) {
    bool isRead = (n['is_read'] ?? 0) == 1;
    IconData icon = Icons.notifications;
    Color color = Colors.blue;

    if (n['type'] == 'follow' || n['type'] == 'follow_back') { icon = Icons.person_add; color = Colors.orange; }
    if (n['type'] == 'wave') { icon = Icons.back_hand; color = Colors.amber; }
    if (n['type'] == 'points') { icon = Icons.monetization_on; color = Colors.green; }
    if (n['type'] == 'message') { icon = Icons.chat_bubble; color = Colors.purple; }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      n['title'] ?? "Activity",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                  if (!isRead)
                    const CircleAvatar(radius: 4, backgroundColor: Colors.blue),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                n['message'] ?? "",
                style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 8),
              Text(
                _formatTime(n['created_at']),
                style: TextStyle(color: Colors.grey[400], fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null) return "Just now";
    try {
      DateTime dt = DateTime.parse(timestamp);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return "${diff.inMinutes} mins ago";
      if (diff.inHours < 24) return "${diff.inHours} hours ago";
      return "${diff.inDays} days ago";
    } catch (e) { return "Recent"; }
  }
}
