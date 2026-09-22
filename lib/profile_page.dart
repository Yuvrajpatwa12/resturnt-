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
import 'services/api_service.dart';
import 'activity_share_page.dart';
import 'group_dining_wrapper.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math';
import 'widgets/review_loading_dialog.dart';
import 'app_data.dart';


class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    ShopManager.instance.fetchSocialLists();
    
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

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF6366F1); // Indigo
    const Color secondaryColor = Color(0xFF4F46E5); // Darker Indigo
    final screenHeight = MediaQuery.of(context).size.height;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            // 1. FIXED BACKGROUND HEADER
            _buildFixedIndigoHeader(primaryColor, secondaryColor),
            
            // 2. SCROLLABLE CONTENT
            SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    // Gap to show header (Compact adjustment)
                    const SizedBox(height: 350),
                    
                    // The White Card that scrolls over
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
                          // Custom Tab Bar
                          Padding(
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
                          ),
                          
                          // Dynamic height container for TabBarView
                          SizedBox(
                            height: 480, // Optimized height to minimize empty space
                            child: TabBarView(
                              physics: const NeverScrollableScrollPhysics(),
                              children: [
                                _buildActivityTab(),
                                _buildReviewTab(),
                                _buildSocialTab(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 3. TOP NAVIGATION (Always on top)
            _buildTopNavigation(),
          ],
        ),
      ),
    );
  }

  Widget _buildFixedIndigoHeader(Color startColor, Color endColor) {
    final isPremium = TenantService().currentTenant.value?.isPremiumEnabled ?? false;

    return Container(
      height: 440, // Reduced height as requested
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
            top: 25, // Moved even higher
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Avatar with RAYS
                Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        return CustomPaint(
                          painter: ProfileRaysPainter(_animationController.value, Colors.white.withOpacity(0.2)),
                          size: const Size(160, 160), // Reduced ray size
                        );
                      },
                    ),
                    
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        ValueListenableBuilder<String>(
                          valueListenable: ShopManager.instance.userGender,
                          builder: (context, gender, _) {
                            return Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: CircleAvatar(
                                radius: 45,
                                backgroundImage: NetworkImage(
                                  gender == 'Female'
                                      ? 'https://img.freepik.com/free-vector/beauty-woman-face-concept_23-2148679462.jpg'
                                      : 'https://img.freepik.com/free-vector/businessman-character-avatar-isolated_24877-60111.jpg',
                                ),
                              ),
                            );
                          },
                        ),
                        // Badge integrated correctly at the edge of the circle
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: const Icon(Icons.near_me, color: Colors.white, size: 10),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 2), // Tighter gap
                ValueListenableBuilder<String>(
                  valueListenable: ShopManager.instance.customerName,
                  builder: (context, name, _) => Text(
                    name.isNotEmpty ? name : "Diner Profile",
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
                const Text(
                  "Nearby & Active",
                  style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500, height: 1.0),
                ),
                const SizedBox(height: 8), 
                
                // 4-STAT BAR (Interactive like Instagram)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ValueListenableBuilder<int>(
                      valueListenable: ShopManager.instance.totalOrdersCount,
                      builder: (context, val, child) => _buildCenteredStat("$val", "Orders"),
                    ),
                    _buildStatDivider(),
                    ValueListenableBuilder<int>(
                      valueListenable: ShopManager.instance.followersCount,
                      builder: (context, val, child) => _buildInteractiveStat(
                        "$val", 
                        "Followers",
                        () => _showSocialListModal("Followers", ShopManager.instance.friendsList) 
                      ),
                    ),
                    _buildStatDivider(),
                    ValueListenableBuilder<int>(
                      valueListenable: ShopManager.instance.followingCount,
                      builder: (context, val, child) => _buildInteractiveStat(
                        "$val", 
                        "Following",
                        () => _showSocialListModal("Following", ShopManager.instance.followingList)
                      ),
                    ),
                    _buildStatDivider(),
                    ValueListenableBuilder<int>(
                      valueListenable: ShopManager.instance.connectionsCount,
                      builder: (context, val, child) => _buildInteractiveStat(
                        "$val", 
                        "Friends",
                        () => _showSocialListModal("Mutual Friends", ShopManager.instance.friendsList)
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 15),

                // ACTION BUTTONS (FOR SELF PROFILE)
                if (isPremium)
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          ShopManager.instance.currentTabIndex.value = 2; // Nearby
                        },
                        icon: const Icon(Icons.bolt, size: 18),
                        label: const Text("CONNECT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
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
                          Navigator.push(context, MaterialPageRoute(builder: (context) => MessagesListPage()));
                        },
                        icon: const Icon(Icons.chat_bubble_outline, size: 18, color: Colors.white),
                        label: const Text("MESSAGES", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white, letterSpacing: 1)),
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
              onPressed: () => ShopManager.instance.currentTabIndex.value = 0,
            ),
            const Text(
              "MY PROFILE",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 12),
            ),
            IconButton(
              icon: const CircleAvatar(
                backgroundColor: Colors.white24,
                child: Icon(Icons.settings, color: Colors.white, size: 20),
              ),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => SettingsPage()));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialStat(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7))),
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
          // HIGH VISIBILITY VERSION BADGE
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: const Color(0xFFFF5C00).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFF5C00).withValues(alpha: 0.3), width: 1.5),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_rounded, color: Color(0xFFFF5C00)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text("SYSTEM v1.1.6 LOADED", style: TextStyle(color: Color(0xFFFF5C00), fontWeight: FontWeight.w900, fontSize: 13)),
                      Text("Full stability shield and network guardrails active.", style: TextStyle(color: Colors.black54, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          _buildLiveOrdersRow(),
          const SizedBox(height: 24),
          _buildSectionHeader("Recent Activity"),
          
          // CORE COLLABORATIVE FEATURES (ALWAYS VISIBLE)
          _buildMenuItem(Icons.auto_stories_outlined, "Share Your Story", "Post on Instagram & Earn 50 Points", Colors.pinkAccent, () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => ActivitySharePage()));
          }),
          _buildMenuItem(Icons.account_balance_wallet_outlined, "Group Dining Session", "Live host & guest sync tools", Colors.deepOrange, () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => DineWrapper()));
          }),

          _buildMenuItem(Icons.history, "My Orders", "Track live orders & history", Colors.blue, () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => MyOrdersPage()));
          }),
          
          if (isPremium)
            _buildMenuItem(Icons.auto_stories, "Meat Master Passport", "Collect stamps & earn rewards", const Color(0xFFFF5C00), () {
              if (ShopManager.instance.isEmailSynced.value) {
                Navigator.push(context, MaterialPageRoute(builder: (context) => PassportPage()));
              } else {
                _showAuthRequiredDialog(context, "Meat Master Passport");
              }
            }),
          if (isPremium)
            _buildMenuItem(Icons.auto_awesome, "Surprise Mystery Box", "Win free items while in-house", Colors.purple, () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => MysteryBoxPage()));
            }),
          if (isPremium)
            _buildMenuItem(Icons.card_giftcard, "Redeem Rewards", "Spend your loyalty points", Colors.green, () {
              if (ShopManager.instance.isEmailSynced.value) {
                Navigator.push(context, MaterialPageRoute(builder: (context) => RewardsPage()));
              } else {
                _showAuthRequiredDialog(context, "Redeem Rewards");
              }
            }),

          // --- NEW: SOCIAL MEDIA LINKS SECTION ---
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _showAuthRequiredDialog(BuildContext context, String featureName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.lock_outline_rounded, color: Color(0xFFFF5C00)),
            const SizedBox(width: 12),
            const Text("Login Required", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "The '$featureName' feature is only available for registered users.",
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            const Text(
              "Please sync your Google profile first to track your stamps and coins at this restaurant.",
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("NOT NOW", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showManualSyncDialog(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5C00),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("SYNC NOW", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewTab() {
    return RefreshIndicator(
      onRefresh: () => ShopManager.instance.fetchReviews(),
      color: Colors.indigo,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 0. WRITE REVIEW ACTION
            InkWell(
              onTap: () => _showWriteReviewModal(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.indigo.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.indigo.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.edit_note_rounded, color: Colors.indigo),
                    SizedBox(width: 12),
                    Text("WRITE A REVIEW", style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ],
                ),
              ),
            ),

            // 1. SUMMARY SECTION
            ValueListenableBuilder<double>(
              valueListenable: ShopManager.instance.averageRating,
              builder: (context, avg, _) => ValueListenableBuilder<int>(
                valueListenable: ShopManager.instance.totalReviewsCount,
                builder: (context, count, _) => Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          Text(avg.toStringAsFixed(1), style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (index) => Icon(
                              index < avg.round() ? Icons.star : Icons.star_border, 
                              color: Colors.orange, 
                              size: 18
                            )),
                          ),
                          const SizedBox(height: 4),
                          Text("($count reviews)", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: ValueListenableBuilder<Map<int, double>>(
                        valueListenable: ShopManager.instance.ratingDistribution,
                        builder: (context, dist, _) => Column(
                          children: [
                            _buildRatingProgressRow("5", dist[5] ?? 0.0),
                            _buildRatingProgressRow("4", dist[4] ?? 0.0),
                            _buildRatingProgressRow("3", dist[3] ?? 0.0),
                            _buildRatingProgressRow("2", dist[2] ?? 0.0),
                            _buildRatingProgressRow("1", dist[1] ?? 0.0),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 24),

            // 2. FILTER SECTION (Simplified for real data)
            const Text("LATEST REVIEWS", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.grey, letterSpacing: 1.5)),
            const SizedBox(height: 16),

            // 3. REVIEW LIST
            ValueListenableBuilder<List<Map<String, dynamic>>>(
              valueListenable: ShopManager.instance.activeReviews,
              builder: (context, reviews, _) {
                if (reviews.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: Text("No reviews yet. Be the first!", style: TextStyle(color: Colors.grey))),
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
          ],
        ),
      ),
    );
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

          // --- NEW: OFFICIAL SOCIAL LINKS ---
          const SizedBox(height: 32),
          _buildSectionHeader("Connect With Us"),
          const SizedBox(height: 16),
          _buildOfficialSocialLinks(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildOfficialSocialLinks() {
    return ValueListenableBuilder<Tenant?>(
      valueListenable: TenantService().currentTenant,
      builder: (context, tenant, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildSocialLinkItem(
              "https://cdn-icons-png.flaticon.com/512/174/174855.png", 
              Colors.pink, 
              "Instagram", 
              tenant?.instagramLink ?? ""
            ),
            _buildSocialLinkItem(
              "https://cdn-icons-png.flaticon.com/512/124/124010.png", 
              Colors.blueAccent, 
              "Facebook", 
              tenant?.facebookLink ?? ""
            ),
            _buildSocialLinkItem(
              "https://cdn-icons-png.flaticon.com/512/3046/3046121.png", 
              Colors.black, 
              "TikTok", 
              tenant?.tiktokLink ?? ""
            ),
          ],
        );
      }
    );
  }

  Widget _buildSocialLinkItem(String logoUrl, Color color, String name, String url) {
    return InkWell(
      onTap: () async {
        String trimmedUrl = url.trim();
        if (trimmedUrl.isNotEmpty) {
          // Normalize URL: add https:// if missing (fixes yuraj.com issue)
          String finalUrl = trimmedUrl;
          if (!finalUrl.toLowerCase().startsWith('http://') && !finalUrl.toLowerCase().startsWith('https://')) {
            finalUrl = 'https://$finalUrl';
          }

          final uri = Uri.parse(finalUrl);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Could not launch: $finalUrl"))
              );
            }
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Social profile coming soon! Stay tuned."),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.05),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.1)),
            ),
            child: ClipOval(
              child: Image.network(
                logoUrl,
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Icon(Icons.public, color: color, size: 28),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87),
          ),
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
        onPressed: () {
          ShopManager.instance.resetSession();
          TenantService().logout();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Logged out successfully.")));
          ShopManager.instance.currentTabIndex.value = 0; // Go Home
        },
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
  _SliverAppBarDelegate(this.widget);

  final PreferredSizeWidget widget;

  @override
  double get minExtent => widget.preferredSize.height;
  @override
  double get maxExtent => widget.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return widget;
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}

class ProfileRaysPainter extends CustomPainter {
  final double progress;
  final Color color;

  ProfileRaysPainter(this.progress, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const rayCount = 12; // More rays for better look

    for (int i = 0; i < rayCount; i++) {
      // Rotate rays slowly
      final double angle = (i * 2 * 3.14159 / rayCount) + (progress * 0.8);
      
      // Calculate length: start from avatar edge, move outwards
      final double rayProgress = (progress + (i / rayCount)) % 1.0;
      final double startDist = 52.0; // Starts exactly at the avatar edge
      final double endDist = startDist + (60 * rayProgress); // Extends slightly less for compact look
      
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);
      
      final linePaint = Paint()
        ..color = color.withOpacity(color.opacity * (1.0 - rayProgress)) // Fades out
        ..strokeWidth = 3.5 // Thicker rays
        ..strokeCap = StrokeCap.round;
        
      canvas.drawLine(Offset(startDist, 0), Offset(endDist, 0), linePaint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(ProfileRaysPainter oldDelegate) => oldDelegate.progress != progress;
}
