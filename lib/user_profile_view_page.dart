import 'package:flutter/material.dart';
import 'services/tenant_service.dart';
import 'services/api_service.dart';
import 'cart_manager.dart';

class UserProfileViewPage extends StatefulWidget {
  final String userId;
  final String? name; // Optional, can be shown while loading

  const UserProfileViewPage({super.key, required this.userId, this.name});

  @override
  State<UserProfileViewPage> createState() => _UserProfileViewPageState();
}

class _UserProfileViewPageState extends State<UserProfileViewPage> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final tenant = TenantService().currentTenant.value;
    final myId = ShopManager.instance.currentUserId;
    if (tenant == null || myId.isEmpty) return;

    final data = await ApiService.fetchPublicProfile(
      tenantId: tenant.id,
      targetId: widget.userId,
      myId: myId,
    );

    if (mounted) {
      setState(() {
        _profile = data;
        _isLoading = false;
      });
    }
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
        title: Text(
          _isLoading ? (widget.name ?? "Profile") : (_profile?['name'] ?? "Diner"),
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF5C00)))
          : _profile == null
              ? const Center(child: Text("Profile not found"))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final bool isFollowing = _profile?['is_following'] ?? false;
    final bool followsMe = _profile?['follows_me'] ?? false;
    final bool isFriend = isFollowing && followsMe;
    final String gender = _profile?['gender'] ?? 'Male';
    final String avatarUrl = gender == 'Female'
        ? 'https://img.freepik.com/free-vector/beauty-woman-face-concept_23-2148679462.jpg'
        : 'https://img.freepik.com/free-vector/businessman-character-avatar-isolated_24877-60111.jpg';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // 1. Header with Avatar & Stats
          Row(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundImage: NetworkImage(avatarUrl),
              ),
              const SizedBox(width: 32),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(_profile!['order_count'].toString(), "Orders"),
                    _buildStatItem(_profile!['points'].toString(), "Points"),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 2. Name & Table
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _profile!['name'] ?? "Anonymous Diner",
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.restaurant, size: 14, color: Color(0xFFFF5C00)),
                    const SizedBox(width: 6),
                    Text(
                      "Sitting at Table ${_profile!['current_table']}",
                      style: TextStyle(color: Colors.grey[600], fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),

          // 3. Social Actions
          Row(
            children: [
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _toggleFollow,
                  icon: Icon(isFollowing ? Icons.check : Icons.person_add, color: isFollowing ? Colors.black87 : Colors.white),
                  label: Text(
                    isFollowing ? "Following" : (followsMe ? "Follow Back" : "Follow"),
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isFollowing ? Colors.black87 : Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isFollowing ? Colors.grey[200] : const Color(0xFFFF5C00),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: isFriend ? () {} : null,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    side: BorderSide(color: isFriend ? const Color(0xFFFF5C00) : Colors.grey[300]!),
                  ),
                  child: Text(
                    "Message",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isFriend ? const Color(0xFFFF5C00) : Colors.grey[400],
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          if (!isFriend && isFollowing)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                "Waiting for ${_profile!['name']} to follow back to unlock messaging.",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ),
          
          if (!isFollowing && followsMe)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Text(
                "This user is already following you! Follow back to become friends.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFFF5C00), fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Future<void> _toggleFollow() async {
    final success = await ShopManager.instance.toggleFollow(widget.userId);
    if (success) {
      _loadProfile(); // Refresh to show updated states
    }
  }
}
