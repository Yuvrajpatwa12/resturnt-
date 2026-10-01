import 'package:flutter/material.dart';
import 'dart:math';
import 'widgets/waiter_assistance_modal.dart';
import 'services/tenant_service.dart';
import 'services/api_service.dart';
import 'cart_manager.dart';
import 'chat_page.dart';

class UserProfileViewPage extends StatefulWidget {
  final String userId;
  final String? name; // Optional, can be shown while loading

  const UserProfileViewPage({super.key, required this.userId, this.name});

  @override
  State<UserProfileViewPage> createState() => _UserProfileViewPageState();
}

class _UserProfileViewPageState extends State<UserProfileViewPage> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _socialStats;
  bool _isLoading = true;
  late AnimationController _animationController;
  late Color primaryColor;
  late Color secondaryColor;

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return const Color(0xFFFF5C00);
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (e) {
      return const Color(0xFFFF5C00);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
    
    final social = await ApiService.fetchSocialStats(tenant.id, widget.userId);

    if (mounted) {
      setState(() {
        _profile = data;
        _socialStats = social;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tenant = TenantService().currentTenant.value;
    primaryColor = _parseColor(tenant?.color);
    secondaryColor = primaryColor.withValues(alpha: 0.8);

    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : _profile == null
              ? const Center(child: Text("Profile not found"))
              : Stack(
                  children: [
                    // 1. FIXED BACKGROUND GRADIENT & RAYS ONLY
                    _buildFixedBackground(primaryColor, secondaryColor),
                    
                    // 2. SCROLLABLE CONTENT (Header + White Card)
                    SafeArea(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          children: [
                            const SizedBox(height: 12),
                            // Interactive Profile Header Content
                            _buildProfileHeaderContent(primaryColor),
                            const SizedBox(height: 16),

                            // White Rounded Card
                            Container(
                              width: double.infinity,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(36),
                                  topRight: Radius.circular(36),
                                ),
                                boxShadow: [
                                  BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -10))
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(height: 12),
                                  _buildSwipeGuidance(primaryColor),
                                  const SizedBox(height: 8),
                                  _buildActivitySection(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 3. TOP NAVIGATION
                    _buildTopNavigation(),
                  ],
                ),
    );
  }

  Widget _buildSwipeGuidance(Color color) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        // Simple vertical slide animation
        final double slide = 8.0 * sin(_animationController.value * 2 * pi);
        return Opacity(
          opacity: 0.6 + (0.4 * sin(_animationController.value * 2 * pi).abs()),
          child: Transform.translate(
            offset: Offset(0, slide),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.touch_app_rounded, color: color, size: 24),
                const SizedBox(height: 2),
                Text(
                  "SWIPE UP",
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    color: color,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFixedBackground(Color startColor, Color endColor) {
    return Container(
      height: 440,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [startColor, endColor],
        ),
      ),
    );
  }

  Widget _buildProfileHeaderContent(Color startColor) {
    final String gender = _profile?['gender'] ?? 'Male';
    final String avatarUrl = gender == 'Female'
        ? 'https://img.freepik.com/free-vector/beauty-woman-face-concept_23-2148679462.jpg'
        : 'https://img.freepik.com/free-vector/businessman-character-avatar-isolated_24877-60111.jpg';
    
    final bool isFollowing = _profile?['is_following'] ?? false;
    final bool followsMe = _profile?['follows_me'] ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // 1. ANIMATED RAYS
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: ProfileRaysPainter(_animationController.value, Colors.white.withValues(alpha: 0.2)),
                    size: const Size(140, 140),
                  );
                },
              ),

              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 45,
                      backgroundImage: NetworkImage(avatarUrl),
                    ),
                  ),
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: const Icon(Icons.location_on, color: Colors.white, size: 10),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            _profile!['name'] ?? "Anonymous",
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const Text(
            "Currently Dining Nearby",
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.0),
          ),
          const SizedBox(height: 8),
          
          // 4-STAT BAR (Interactive like Instagram)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildCenteredStat(_profile!['order_count'].toString(), "Orders"),
              _buildStatDivider(),
              _buildInteractiveStat(
                (_socialStats?['followers'] ?? 0).toString(), 
                "Followers",
                () => _showGuestSocialListModal("Followers", "get_followers")
              ),
              _buildStatDivider(),
              _buildInteractiveStat(
                (_socialStats?['following'] ?? 0).toString(), 
                "Following",
                () => _showGuestSocialListModal("Following", "get_following")
              ),
              _buildStatDivider(),
              _buildInteractiveStat(
                (_socialStats?['connections'] ?? 0).toString(), 
                "Friends",
                () => _showGuestSocialListModal("Mutual Friends", "get_friends")
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // ACTION BUTTONS
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _toggleFollow,
                icon: Icon(isFollowing ? (followsMe ? Icons.people : Icons.check) : Icons.person_add, size: 18),
                label: Text(
                  isFollowing ? (followsMe ? "FRIEND" : "FOLLOWING") : (followsMe ? "FOLLOW BACK" : "FOLLOW"),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: startColor,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  elevation: 0,
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatPage(
                        userId: widget.userId,
                        userName: _profile!['name'] ?? "Guest",
                        userImage: avatarUrl,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.chat_bubble_outline, size: 18, color: Colors.white),
                label: const Text("MESSAGE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white, letterSpacing: 1)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white54),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCenteredStat(String value, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          Text(label.toUpperCase(), style: const TextStyle(fontSize: 8, color: Colors.white70, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _buildInteractiveStat(String value, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            Text(label.toUpperCase(), style: const TextStyle(fontSize: 8, color: Colors.white70, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(height: 20, width: 1, color: Colors.white12);
  }

  Widget _buildTopNavigation() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const CircleAvatar(
                backgroundColor: Colors.white24,
                child: Icon(Icons.arrow_back, color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            const Text(
              "GUEST PROFILE",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 12),
            ),
            const SizedBox(width: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildActivitySection() {
    final String currentTable = _profile?['current_table']?.toString() ?? 'N/A';
    final String orderCount = _profile?['order_count']?.toString() ?? '0';
    final String points = _profile?['points']?.toString() ?? '0';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title Header Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.stars_rounded, color: primaryColor, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    "ACTIVITY & STATUS",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
              // Live Online Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      "LIVE NOW",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 1. Current Seating Card (Interactive Gradient Card)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primaryColor.withValues(alpha: 0.08),
                  primaryColor.withValues(alpha: 0.03),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.04),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.restaurant_rounded, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Seated at Table $currentTable",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        "In-Restaurant Presence Verified",
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 2. Statistics Grid
          Row(
            children: [
              Expanded(
                child: _buildModernStatCard(
                  icon: Icons.shopping_bag_rounded,
                  iconBg: const Color(0xFFE0E7FF),
                  iconColor: const Color(0xFF4F46E5),
                  value: orderCount,
                  label: "Total Orders",
                  sublabel: "Completed Meals",
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildModernStatCard(
                  icon: Icons.military_tech_rounded,
                  iconBg: const Color(0xFFFEF3C7),
                  iconColor: const Color(0xFFD97706),
                  value: points,
                  label: "Loyalty Points",
                  sublabel: "Diner Rewards",
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 3. Member Engagement Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.verified_user_rounded, color: Color(0xFF10B981), size: 22),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Active Diner Community Member",
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                      SizedBox(height: 2),
                      Text(
                        "Eligible for table sharing & chat",
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 4. Assistance Call Banner
          InkWell(
            onTap: () => WaiterAssistanceModal.show(context),
            borderRadius: BorderRadius.circular(22),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.orange.shade50,
                    Colors.amber.shade50,
                  ],
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.orange.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Call Waiter / Assistance",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xFFC2410C),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          "Request immediate assistance, water, or bill",
                          style: TextStyle(fontSize: 11, color: Color(0xFF7C2D12)),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFFC2410C)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildModernStatCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String value,
    required String label,
    required String sublabel,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF334155),
            ),
          ),
          Text(
            sublabel,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  void _showGuestSocialListModal(String title, String action) async {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return;

    // Show loading first
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => FutureBuilder<List<Map<String, dynamic>>?>(
        future: ApiService.fetchSocialList(action: action, tenantId: tenant.id, userId: widget.userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(height: 300, child: Center(child: CircularProgressIndicator()));
          }
          final users = snapshot.data ?? [];
          return Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                if (users.isEmpty)
                  const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Text("No public data found", style: TextStyle(color: Colors.grey))),
                ...users.take(5).map((u) {
                  String avatarUrl = u['gender'] == 'Female'
                      ? 'https://img.freepik.com/free-vector/beauty-woman-face-concept_23-2148679462.jpg'
                      : 'https://img.freepik.com/free-vector/businessman-character-avatar-isolated_24877-60111.jpg';
                  
                  return ListTile(
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => UserProfileViewPage(userId: u['email'], name: u['name'])),
                      );
                    },
                    leading: CircleAvatar(backgroundImage: NetworkImage(avatarUrl)),
                    title: Text(u['name'] ?? 'Guest'),
                    subtitle: Text(u['email'] ?? ''),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _toggleFollow() async {
    final success = await ShopManager.instance.toggleFollow(widget.userId);
    if (success) {
      _loadProfile(); // Refresh to show updated states
    }
  }
}

class ProfileRaysPainter extends CustomPainter {
  final double progress;
  final Color color;

  ProfileRaysPainter(this.progress, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const rayCount = 12; // More rays

    for (int i = 0; i < rayCount; i++) {
      final double angle = (i * 2 * 3.14159 / rayCount) + (progress * 0.8);
      final double rayProgress = (progress + (i / rayCount)) % 1.0;
      final double startDist = 52.0; // Right at avatar edge
      final double endDist = startDist + (60 * rayProgress); // Extending slightly less
      
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);
      
      final linePaint = Paint()
        ..color = color.withValues(alpha: color.a * (1.0 - rayProgress))
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round;
        
      canvas.drawLine(Offset(startDist, 0), Offset(endDist, 0), linePaint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(ProfileRaysPainter oldDelegate) => oldDelegate.progress != progress;
}
