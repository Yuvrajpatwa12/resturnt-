import 'package:flutter/material.dart';
import 'cart_manager.dart';
import 'user_profile_view_page.dart';


class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isRefreshing = false;

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
          TextButton.icon(
            onPressed: () => ShopManager.instance.clearNotificationBadge(),
            icon: const Icon(Icons.done_all, size: 18),
            label: const Text("Mark all as read", style: TextStyle(fontWeight: FontWeight.bold)),
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
        : all.where((n) => n['type'] == filter).toList();

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
        setState(() => _isRefreshing = true);
        await ShopManager.instance.refreshNotifications();
        setState(() => _isRefreshing = false);
      },
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: filtered.length,
        separatorBuilder: (context, index) => const SizedBox(height: 24),
        itemBuilder: (context, index) {
          final n = filtered[index];
          return InkWell(
            onTap: () {
              if (n['sender_id'] != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => UserProfileViewPage(userId: n['sender_id'])),
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

    if (n['type'] == 'follow') { icon = Icons.person_add; color = Colors.orange; }
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
