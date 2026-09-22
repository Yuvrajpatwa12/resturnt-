import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math';
import 'widgets/review_loading_dialog.dart';
import 'app_data.dart';
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
    const Color primaryColor = Color(0xFF6366F1); // Indigo
    const Color secondaryColor = Color(0xFF4F46E5); // Darker Indigo
    final screenHeight = MediaQuery.of(context).size.height;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: primaryColor))
            : _profile == null
                ? const Center(child: Text("Profile not found"))
                : Stack(
                    children: [
                      // 1. FIXED BACKGROUND HEADER
                      _buildFixedHeader(primaryColor, secondaryColor),
                      
                      // 2. SCROLLABLE CONTENT
                      SafeArea(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            children: [
                              // Gap to show header (Compact adjustment)
                              const SizedBox(height: 350),
                              Container(
                                width: double.infinity,
                                constraints: BoxConstraints(minHeight: screenHeight - 100),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(40),
                                    topRight: Radius.circular(40),
                                  ),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -10))
                                  ],
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(height: 20),
                                    _buildTabBar(primaryColor),
                                    ConstrainedBox(
                                      constraints: BoxConstraints(maxHeight: screenHeight * 1.5),
                                      child: SizedBox(
                                        height: 800,
                                        child: TabBarView(
                                          physics: const NeverScrollableScrollPhysics(),
                                          children: [
                                            _buildActivityTab(),
                                            _buildReviewTab(),
                                            _buildSocialTab(),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // 3. TOP NAVIGATION
                      _buildTopNavigation(),

                      // 4. CALL WAITER BUTTON (Fixed at bottom)
                      _buildBottomButton(primaryColor),
                    ],
                  ),
      ),
    );
  }

  Widget _buildFixedHeader(Color startColor, Color endColor) {
    final String gender = _profile?['gender'] ?? 'Male';
    final String avatarUrl = gender == 'Female'
        ? 'https://img.freepik.com/free-vector/beauty-woman-face-concept_23-2148679462.jpg'
        : 'https://img.freepik.com/free-vector/businessman-character-avatar-isolated_24877-60111.jpg';
    
    final bool isFollowing = _profile?['is_following'] ?? false;
    final bool followsMe = _profile?['follows_me'] ?? false;

    return Container(
      height: 440, // Reduced height as requested
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [startColor, endColor],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // CENTERED CONTENT
          Positioned(
            top: 25, // Moved even higher up
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
                          painter: ProfileRaysPainter(_animationController.value, Colors.white.withOpacity(0.2)),
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
                  children: [
                    ElevatedButton.icon(
                      onPressed: _toggleFollow,
                      icon: Icon(isFollowing ? Icons.check : Icons.person_add, size: 18),
                      label: Text(
                        isFollowing ? "FOLLOWING" : (followsMe ? "FOLLOW BACK" : "FOLLOW"),
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

  Widget _buildSmallCircleButton(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      child: Icon(icon, color: color, size: 16),
    );
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

  Widget _buildTabBar(Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(25),
        ),
        child: TabBar(
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            color: Colors.white,
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)
            ],
          ),
          labelColor: primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: "Activity"),
            Tab(text: "Review"),
            Tab(text: "Social"),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityTab() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          "Current Status",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildInfoCard(
          Icons.restaurant,
          "Seated at Table ${_profile!['current_table']}",
          "Live presence detected",
          const Color(0xFF6366F1),
        ),
        const SizedBox(height: 24),
        const Text(
          "Diner Statistics",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildStatBox(_profile!['order_count'].toString(), "Total Orders", Icons.shopping_bag_outlined)),
            const SizedBox(width: 16),
            Expanded(child: _buildStatBox(_profile!['points'].toString(), "Loyalty Points", Icons.stars_rounded)),
          ],
        ),
      ],
    );
  }

  Widget _buildReviewTab() {
    return RefreshIndicator(
      onRefresh: () => ShopManager.instance.fetchReviews(targetUserId: widget.userId),
      color: Colors.indigo,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 0. HEADER
            const Text("REVIEWS WRITTEN BY THIS DINER", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.grey, letterSpacing: 1.5)),
            const SizedBox(height: 24),

            // 3. REVIEW LIST
            FutureBuilder<List<Map<String, dynamic>>?>(
              future: ApiService.fetchReviews(TenantService().currentTenant.value?.id ?? '', targetUserId: widget.userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final reviews = snapshot.data ?? [];
                if (reviews.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: Text("No reviews posted yet.", style: TextStyle(color: Colors.grey))),
                  );
                }
                return Column(
                  children: reviews.map((r) => _buildReviewListItem(
                    id: int.tryParse(r['id']?.toString() ?? '0') ?? 0,
                    userId: r['user_id'] ?? '',
                    name: r['user_name'] ?? 'Diner',
                    rating: int.tryParse(r['rating']?.toString() ?? '5') ?? 5,
                    review: r['review'] ?? '',
                    likes: int.tryParse(r['likes']?.toString() ?? '0') ?? 0,
                    time: r['time_ago'] ?? 'Just now',
                    image: r['user_image'] ?? 'https://randomuser.me/api/portraits/men/32.jpg',
                  )).toList(),
                );
              },
            ),
            const SizedBox(height: 80), // Gap for bottom button
          ],
        ),
      ),
    );
  }

  void _showWriteReviewModal(BuildContext context) {
    final TextEditingController reviewCtrl = TextEditingController();
    int selectedRating = 5;
    bool isThinking = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 24),
                  const Text("Share Your Experience", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text("How was your meal and service today?", style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 24),

                  // STAR RATING
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        onPressed: () => setModalState(() => selectedRating = index + 1),
                        icon: Icon(
                          index < selectedRating ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: Colors.orange,
                          size: 40,
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 24),

                  // AI SUGGESTION CARD
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.auto_awesome, color: Colors.indigo, size: 20),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text("Need help? Generate an AI Review", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                            if (!isThinking)
                              TextButton(
                                onPressed: () async {
                                  setModalState(() => isThinking = true);
                                  await Future.delayed(const Duration(seconds: 2));
                                  final review = _generateMockAIReview(selectedRating);
                                  setModalState(() {
                                    reviewCtrl.text = review;
                                    isThinking = false;
                                  });
                                },
                                child: const Text("GENERATE"),
                              ),
                          ],
                        ),
                        if (isThinking)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: LinearProgressIndicator(minHeight: 2, color: Colors.indigo, backgroundColor: Colors.transparent),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // TEXT BOX
                  TextField(
                    controller: reviewCtrl,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: "Write your review here...",
                      hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // POST BUTTON
                  ElevatedButton(
                    onPressed: () async {
                      if (reviewCtrl.text.isEmpty) return;
                      final tenant = TenantService().currentTenant.value;

                      // 1. Post to backend
                      final res = await ApiService.submitReview({
                        "tenant_id": tenant?.id ?? 'startups_main',
                        "user_id": ShopManager.instance.currentUserId,
                        "user_name": ShopManager.instance.customerName.value.isNotEmpty ? ShopManager.instance.customerName.value : "Diner",
                        "user_image": ShopManager.instance.userGender.value == 'Female' 
                            ? 'https://randomuser.me/api/portraits/women/44.jpg' 
                            : 'https://randomuser.me/api/portraits/men/32.jpg',
                        "rating": selectedRating,
                        "review": reviewCtrl.text,
                      });

                      if (res['status'] == 'success') {
                        final int newReviewId = int.tryParse(res['id']?.toString() ?? '0') ?? 0;

                        // 2. Save local state for verification flow
                        await ShopManager.instance.submitLocalReview(reviewCtrl.text, selectedRating, reviewId: newReviewId);

                        // 3. Show Animated Loading (2 Seconds)
                        if (context.mounted) {
                          await showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => const ReviewLoadingDialog(),
                          );
                        }

                        // 4. Open Google Maps (Dynamic Link from Admin Panel)
                        final String googleReviewUrl = tenant?.googleMapsLink ?? "https://www.google.com/maps/search/?api=1&query=${tenant?.name ?? 'ChiyaBreak+Restaurant'}";

                        if (await canLaunchUrl(Uri.parse(googleReviewUrl))) {
                          await launchUrl(Uri.parse(googleReviewUrl), mode: LaunchMode.externalApplication);
                        }

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Review posted successfully!")));
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to post review. Try again.")));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text("POST TO GOOGLE MAPS", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ),
                  const SizedBox(height: 16),
                  const Text("Earn +20 Coins for every Google review!", style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _generateMockAIReview(int rating) {
    final random = Random();
    if (rating >= 5) {
      return AppData.fiveStarReviews[random.nextInt(AppData.fiveStarReviews.length)];
    } else if (rating == 4) {
      return AppData.fourStarReviews[random.nextInt(AppData.fourStarReviews.length)];
    } else if (rating == 3) {
      return AppData.threeStarReviews[random.nextInt(AppData.threeStarReviews.length)];
    } else if (rating == 2) {
      return AppData.twoStarReviews[random.nextInt(AppData.twoStarReviews.length)];
    } else {
      return AppData.oneStarReviews[random.nextInt(AppData.oneStarReviews.length)];
    }
  }

  Widget _buildRatingProgressRow(String label, double value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: value,
                backgroundColor: Colors.grey.shade100,
                color: Colors.orange,
                minHeight: 8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, {bool isSelected = false, IconData? icon}) {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) Icon(icon, size: 14, color: isSelected ? Colors.white : Colors.orange),
            if (icon != null) const SizedBox(width: 4),
            Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
          ],
        ),
        selected: isSelected,
        onSelected: (val) {},
        backgroundColor: Colors.white,
        selectedColor: Colors.indigo,
        checkmarkColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: isSelected ? Colors.indigo : Colors.orange, width: 1.5),
        ),
        showCheckmark: false,
      ),
    );
  }

  Widget _buildReviewListItem({
    required int id,
    required String userId,
    required String name,
    required int rating,
    required String review,
    required int likes,
    required String time,
    required String image,
  }) {
    final bool isMyReview = userId == ShopManager.instance.currentUserId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(radius: 20, backgroundImage: NetworkImage(image)),
            const SizedBox(width: 12),
            Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.orange),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, color: Colors.orange, size: 14),
                  const SizedBox(width: 4),
                  Text("$rating", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isMyReview)
              PopupMenuButton<String>(
                onSelected: (val) {
                  if (val == 'delete') {
                    _showDeleteConfirm(id);
                  }
                },
                icon: const Icon(Icons.more_vert, color: Colors.grey),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'delete', child: Text("Delete Review", style: TextStyle(color: Colors.red))),
                ],
              )
            else
              const Icon(Icons.more_vert, color: Colors.grey),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          review,
          style: const TextStyle(color: Colors.black87, fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            InkWell(
              onTap: () async {
                await ApiService.toggleReviewLike(id, ShopManager.instance.currentUserId);
                ShopManager.instance.fetchReviews();
              },
              child: const Icon(Icons.favorite_border, size: 18, color: Colors.grey),
            ),
            const SizedBox(width: 8),
            Text("$likes", style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(width: 24),
            Text(time, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 24),
        const Divider(height: 1, color: Color(0xFFF1F5F9)),
        const SizedBox(height: 24),
      ],
    );
  }

  void _showDeleteConfirm(int id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Review?"),
        content: const Text("Are you sure you want to permanently remove this review?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await ShopManager.instance.deleteReview(id);
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Review deleted.")));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text("DELETE"),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialTab() {
    return RefreshIndicator(
      onRefresh: _loadProfile,
      color: const Color(0xFF6366F1),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSectionHeader("Social Connections"),
          const SizedBox(height: 12),
          _buildSocialListTile(
            Icons.people_rounded, 
            "Mutual Friends", 
            "See connections you share", 
            Colors.green, 
            () {
              // Show Mutual Friends for this guest
              _showGuestSocialListModal("Mutual Friends", "get_friends");
            }
          ),
          _buildSocialListTile(
            Icons.assignment_ind_rounded, 
            "Following", 
            "People this diner follows", 
            Colors.blue, 
            () {
              _showGuestSocialListModal("Following List", "get_following");
            }
          ),
          _buildSocialListTile(
            Icons.person_pin_circle_rounded, 
            "Followers", 
            "People following this diner", 
            Colors.orange, 
            () {
              _showGuestSocialListModal("Followers List", "get_followers");
            }
          ),
        ],
      ),
    );
  }

  Widget _buildSocialListTile(IconData icon, String title, String sub, Color color, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(20), 
        border: Border.all(color: Colors.grey.withOpacity(0.05)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1), 
          child: Icon(icon, color: color, size: 20)
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text(sub, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 1.5),
      ),
    );
  }

  Widget _buildInfoCard(IconData icon, String title, String sub, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
              Text(sub, style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.7))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox(String value, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF6366F1), size: 20),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildBottomButton(Color color) {
    return Positioned(
      bottom: 20,
      left: 24,
      right: 24,
      child: ElevatedButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Waiter notified! Someone will be with you shortly."),
              backgroundColor: Color(0xFF6366F1),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 8,
          shadowColor: color.withValues(alpha: 0.4),
        ),
        child: const Text(
          "CALL WAITER",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
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
        ..color = color.withOpacity(color.opacity * (1.0 - rayProgress))
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round;
        
      canvas.drawLine(Offset(startDist, 0), Offset(endDist, 0), linePaint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(ProfileRaysPainter oldDelegate) => oldDelegate.progress != progress;
}
