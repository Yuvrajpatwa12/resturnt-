import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/gestures.dart';
import 'cart_manager.dart';
import 'cart_page.dart';
import 'voice_order_page.dart';
import 'app_data.dart';
import 'product_card.dart';
import 'menu.dart';
import 'search_delegate.dart';
import 'nearby_page.dart';
import 'profile_page.dart';
import 'rewards_page.dart';
import 'music_voting_sheet.dart';
import 'services/tenant_service.dart';
import 'notifications_page.dart';
import 'activity_share_page.dart';
import 'widgets/smart_auth_overlay.dart';
import 'widgets/onboarding_modal.dart';
import 'widgets/notification_prompt.dart';
import 'widgets/proximity_offer_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

// Enables Mouse Drag Scrolling on Web/Desktop
class MyCustomScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    // Listen for the trigger to open Table Picker automatically
    ShopManager.instance.openTablePickerTrigger.addListener(_handleTablePickerTrigger);
    
    // 1. CHECK FOR PENDING REVIEW VERIFICATION
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ShopManager.instance.isWaitingForGoogleReview.value) {
        _showReviewVerificationDialog();
      }
    });
  }

  void _showReviewVerificationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.verified_rounded, color: Colors.indigo),
            const SizedBox(width: 12),
            const Text("Review Posted?", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Did you successfully post your review on Google Maps?",
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            Text(
              "\"${ShopManager.instance.lastReviewText.value ?? ''}\"",
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final tenant = TenantService().currentTenant.value;
              final String googleReviewUrl = tenant?.googleMapsLink ?? "https://www.google.com/maps/search/?api=1&query=${tenant?.name ?? 'ChiyaBreak+Restaurant'}";
              
              if (await canLaunchUrl(Uri.parse(googleReviewUrl))) {
                await launchUrl(Uri.parse(googleReviewUrl), mode: LaunchMode.externalApplication);
              }
              Navigator.pop(context);
            },
            child: const Text("FINISH REVIEW", style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () async {
              await ShopManager.instance.verifyReviewSuccess();
              Navigator.pop(context);
              _showSuccessAnimation();
              // Add Points as reward
              ShopManager.instance.addPoints(
                TenantService().currentTenant.value?.id ?? '', 
                ShopManager.instance.currentUserId,
                points: 10
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("YES, POSTED!", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showSuccessAnimation() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Success",
      pageBuilder: (context, _, __) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 600),
              tween: Tween(begin: 0.0, end: 1.0),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.indigo.withValues(alpha: 0.3), blurRadius: 20, spreadRadius: 5)],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.check_circle_rounded, color: Colors.green, size: 80),
                        SizedBox(height: 16),
                        Text("AWESOME!", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo)),
                        Text("+10 COINS EARNED", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.green, letterSpacing: 1)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    ShopManager.instance.openTablePickerTrigger.removeListener(_handleTablePickerTrigger);
    super.dispose();
  }

  void _handleTablePickerTrigger() {
    if (ShopManager.instance.openTablePickerTrigger.value) {
      ShopManager.instance.openTablePickerTrigger.value = false;
      // Small delay to ensure the page has switched and context is ready
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _showTablePicker();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: MyCustomScrollBehavior(),
      child: ValueListenableBuilder<int>(
        valueListenable: ShopManager.instance.currentTabIndex,
        builder: (context, currentIndex, child) {
          return Stack(
            children: [
              Scaffold(
                backgroundColor: const Color(0xFFF7F8FA),
                body: IndexedStack(
                  index: currentIndex,
                  children: [
                    _buildHomeContent(),
                    const MenuPage(),
                    const NearbyPage(),
                    const CartPage(),
                    const ProfilePage(),
                  ],
                ),
                bottomNavigationBar: _buildBottomNav(currentIndex),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: ShopManager.instance.isOnboardingComplete,
                builder: (context, complete, _) {
                  if (!complete) return const OnboardingModal();
                  
                  return ValueListenableBuilder<bool>(
                    valueListenable: ShopManager.instance.needsPin,
                    builder: (context, needs, _) => needs ? const SmartAuthOverlay() : const SizedBox.shrink(),
                  );
                },
              ),
              ValueListenableBuilder<bool>(
                valueListenable: ShopManager.instance.showNotificationPrompt,
                builder: (context, show, _) {
                  if (!show) return const SizedBox.shrink();
                  return Material(
                    color: Colors.black.withValues(alpha: 0.5),
                    child: InkWell(
                      onTap: () => ShopManager.instance.showNotificationPrompt.value = false,
                      overlayColor: WidgetStateProperty.all(Colors.transparent),
                      child: const NotificationPrompt(),
                    ),
                  );
                },
              ),
              ValueListenableBuilder<bool>(
                valueListenable: ShopManager.instance.isNearbyOfferVisible,
                builder: (context, visible, _) {
                  final isPremium = TenantService().currentTenant.value?.isPremiumEnabled ?? false;
                  if (!visible || !isPremium) return const SizedBox.shrink();
                  return Container(
                    color: Colors.black.withValues(alpha: 0.6),
                    child: ProximityOfferDialog(
                      restaurantName: TenantService().currentTenant.value?.name ?? "Us",
                      onDismiss: () => ShopManager.instance.isNearbyOfferVisible.value = false,
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBottomNav(int currentIndex) {
    final isPremium = TenantService().currentTenant.value?.isPremiumEnabled ?? false;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, -4),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildNavItem(Icons.home_outlined, Icons.home, 'Home', 0, currentIndex),
          _buildNavItem(Icons.grid_view_outlined, Icons.grid_view, 'Menu', 1, currentIndex),
          if (isPremium)
            _buildNavItem(Icons.people_alt_outlined, Icons.people_alt, 'Nearby', 2, currentIndex),
          ValueListenableBuilder<List<CartItem>>(
            valueListenable: ShopManager.instance.items,
            builder: (context, items, child) {
              return _buildNavItem(
                Icons.shopping_cart_outlined,
                Icons.shopping_cart,
                'Cart',
                3,
                currentIndex,
                badgeCount: ShopManager.instance.cartCount,
              );
            },
          ),
          _buildNavItem(Icons.person_outline, Icons.person, 'Profile', 4, currentIndex),
        ],
      ),
    );
  }

  Widget _buildHomeContent() {
    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: TenantService().products,
      builder: (context, dbProducts, child) {
        final List<Map<String, dynamic>> sourceList = dbProducts.isNotEmpty ? dbProducts : List<Map<String, dynamic>>.from(AppData.popularPicks);

        // Filter products based on featured_section
        final List<Map<String, dynamic>> gridTopItems = sourceList.where((p) => p['featured_section'] == 'just_for_you').toList();
        final List<Map<String, dynamic>> rowScrollItems = sourceList.where((p) => p['featured_section'] == 'trending').toList();
        final List<Map<String, dynamic>> popularItems = sourceList.where((p) => p['featured_section'] == 'popular').toList();
        
        // Products with NO section selected (or fallback if no sections set)
        final List<Map<String, dynamic>> otherProducts = sourceList.where((p) {
          final sec = p['featured_section'];
          return sec == 'none' || sec == null || sec == '' || (gridTopItems.isEmpty && rowScrollItems.isEmpty && popularItems.isEmpty);
        }).toList();

        return RefreshIndicator(
          onRefresh: () async {
            final tenant = TenantService().currentTenant.value;
            if (tenant != null) {
              await Future.wait([
                TenantService().initialize(tenant.domain),
                ShopManager.instance.refreshUserPoints(),
                ShopManager.instance.refreshNotifications(),
              ]);
            }
          },
          color: const Color(0xFFFF5C00),
          backgroundColor: Colors.white,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(), // Required for RefreshIndicator
            slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: _buildHeader(),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: _buildSearchAndTable(),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: _buildShareStoryShortcut(),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: _buildPromoBanner(),
              ),
            ),
            SliverToBoxAdapter(child: _buildNowPlayingCard()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: _buildCategories(),
              ),
            ),

            // 1. Popular Picks
            if (popularItems.isNotEmpty) ...[
              SliverToBoxAdapter(child: _buildSectionTitle('Popular Picks', 'View All →', onTap: () => ShopManager.instance.navigateToCategory(null))),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: _buildHorizontalList(popularItems, 'popular'),
                ),
              ),
            ],

            // 2. Just For You
            if (gridTopItems.isNotEmpty) ...[
              SliverToBoxAdapter(child: _buildSectionTitle('Just For You', 'Explore →', onTap: () => ShopManager.instance.navigateToCategory(null))),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.8,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => ProductCard(item: gridTopItems[index], heroPrefix: 'grid_top'),
                    childCount: gridTopItems.length,
                  ),
                ),
              ),
            ],

            // 3. Trending Scroll
            if (rowScrollItems.isNotEmpty) ...[
              SliverToBoxAdapter(child: _buildSectionTitle('Trending Scroll', 'More →', onTap: () => ShopManager.instance.navigateToCategory(null))),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: _buildHorizontalLargeList(rowScrollItems, 'trending'),
                ),
              ),
            ],

            if (TenantService().currentTenant.value?.isPremiumEnabled ?? false)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: _buildRewardsCard(),
                ),
              ),

            // 4. "All Products" (None Section) - Now positioned at the very bottom
            if (otherProducts.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: _buildSectionTitle('All Products', 'Explore More →', onTap: () {
                  ShopManager.instance.currentTabIndex.value = 1; // Go to Menu Tab
                }),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.8,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => ProductCard(item: otherProducts[index], heroPrefix: 'all_home'),
                    childCount: otherProducts.length,
                  ),
                ),
              ),
            ],

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 8, height: 8,
                          decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Chiyala Web Build v1.1.6",
                          style: TextStyle(color: Colors.grey[500], fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "STABILITY SHIELD ACTIVE",
                      style: TextStyle(color: Colors.grey[300], fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 2),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      );
    },
  );
}



  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "ChiyaBreak",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFFFF5C00), fontStyle: FontStyle.italic),
            ),
            Text(
              "TIME FOR A REFRESHING BREAK",
              style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.grey[600], letterSpacing: 0.5),
            ),
          ],
        ),
        Row(
          children: [
            if (TenantService().currentTenant.value?.isPremiumEnabled ?? false)
              _buildHeaderAction(Icons.mic_none_outlined, () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const VoiceOrderPage()));
              }),
            if (TenantService().currentTenant.value?.isPremiumEnabled ?? false)
              const SizedBox(width: 10),
            ValueListenableBuilder<int>(
              valueListenable: ShopManager.instance.unseenNotificationsCount,
              builder: (context, count, _) => Stack(
                clipBehavior: Clip.none,
                children: [
                  _buildHeaderAction(Icons.notifications_none_outlined, () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsPage()));
                  }),
                  if (count > 0)
                    Positioned(
                      top: -2, right: -2,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text("$count", style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _buildHeaderAction(Icons.person_outline, () {
              ShopManager.instance.currentTabIndex.value = 4;
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildHeaderAction(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4)],
        ),
        child: Icon(icon, color: Colors.black87, size: 20),
      ),
    );
  }

  Widget _buildSearchAndTable() {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: _showTablePicker,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 4))],
              ),
              child: Row(
                children: [
                  const Icon(Icons.restaurant, color: Color(0xFFFF5C00), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("SELECT TABLE NUMBER", style: TextStyle(fontSize: 9, color: Color(0xFFFF5C00), fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                        ValueListenableBuilder<int?>(
                          valueListenable: ShopManager.instance.selectedTableId,
                          builder: (context, tableId, child) => Text(
                            tableId != null ? "TABLE ${tableId.toString().padLeft(2, '0')}" : "TAP TO CHOOSE", 
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: tableId != null ? Colors.black87 : const Color(0xFFFF5C00)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.grey),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () {
            final dbProducts = TenantService().products.value;
            final searchProducts = dbProducts.isNotEmpty
                ? dbProducts
                : AppData.popularPicks.map((p) => ({...p, 'tag': 'Popular', 'rating': '4.9', 'discount': ''})).toList();
            showSearch(context: context, delegate: MySearchDelegate(searchProducts));
          },
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFFF5C00),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF5C00).withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.search, color: Colors.white, size: 22),
          ),
        ),
      ],
    );
  }

  void _showTablePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "SELECT TABLE NUMBER",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFFF5C00),
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 24),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 5,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                children: List.generate(20, (index) {
                  int id = index + 1;
                  return InkWell(
                    onTap: () {
                      ShopManager.instance.switchTable(id);
                      Navigator.pop(context);
                    },
                    child: ValueListenableBuilder<int?>(
                      valueListenable: ShopManager.instance.selectedTableId,
                      builder: (context, currentId, child) => Container(
                        decoration: BoxDecoration(color: currentId == id ? const Color(0xFFFF5C00) : Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                        child: Center(child: Text(id.toString().padLeft(2, '0'), style: TextStyle(color: currentId == id ? Colors.white : Colors.black87, fontWeight: FontWeight.bold))),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShareStoryShortcut() {
    return ValueListenableBuilder<bool>(
      valueListenable: ShopManager.instance.hasConfirmedOrderAbove1000,
      builder: (context, hasQualifiedOrder, _) {
        if (!hasQualifiedOrder) return const SizedBox.shrink();

        return InkWell(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const ActivitySharePage()));
          },
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF97316).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFF97316), width: 2.5),
              boxShadow: [
                BoxShadow(color: const Color(0xFFF97316).withValues(alpha: 0.1), blurRadius: 15, offset: const Offset(0, 8))
              ],
            ),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(color: Color(0xFFF97316), shape: BoxShape.circle),
                      child: const Icon(Icons.auto_stories_outlined, color: Colors.white, size: 24),
                    ),
                    Positioned(
                      top: -8, right: -8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)),
                        child: const Text("NEW", style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        "SHARE YOUR STORY", 
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5, color: Color(0xFFF97316)),
                      ),
                      Text(
                        "Post on Instagram & earn +50 Points instantly!", 
                        style: TextStyle(color: Colors.black87, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFFF97316), size: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPromoBanner() {
    return const _PromoBannerCarousel();
  }

  Widget _buildCategories() {
    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: TenantService().categories,
      builder: (context, dbCats, child) {
        if (dbCats.isEmpty) return const SizedBox.shrink();

        return SizedBox(
          height: 85,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: dbCats.length,
            itemBuilder: (context, index) {
              final cat = dbCats[index];
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: InkWell(
                  onTap: () => ShopManager.instance.navigateToCategory(cat['title'] as String),
                  child: Column(
                    children: [
                      Container(
                        width: 55, height: 55,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)]),
                        child: Icon(_getIconData(cat['icon']), color: const Color(0xFFFF5C00), size: 24),
                      ),
                      const SizedBox(height: 6),
                      Text(cat['title'] as String, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  IconData _getIconData(dynamic iconName) {
    switch (iconName?.toString()) {
      case 'lunch_dining': return Icons.lunch_dining;
      case 'local_cafe': return Icons.local_cafe;
      case 'local_drink': return Icons.local_drink;
      case 'icecream': return Icons.icecream;
      case 'local_pizza': return Icons.local_pizza;
      case 'fastfood': return Icons.fastfood;
      case 'kebab_dining': return Icons.kebab_dining;
      case 'cake': return Icons.cake;
      case 'restaurant_menu': return Icons.restaurant_menu;
      case 'breakfast_dining': return Icons.breakfast_dining;
      default: return Icons.restaurant_menu_rounded;
    }
  }

  Widget _buildSectionTitle(String title, String action, {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          InkWell(onTap: onTap, child: Text(action, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFFF5C00)))),
        ],
      ),
    );
  }

  Widget _buildHorizontalList(List<Map<String, dynamic>> items, String prefix) {
    return SizedBox(
      height: 190,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        itemBuilder: (context, index) => Padding(padding: const EdgeInsets.only(right: 14.0), child: SizedBox(width: 130, child: ProductCard(item: items[index], heroPrefix: prefix))),
      ),
    );
  }

  Widget _buildHorizontalLargeList(List<Map<String, dynamic>> items, String prefix) {
    return SizedBox(
      height: 250,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        itemBuilder: (context, index) => Padding(padding: const EdgeInsets.only(right: 14.0), child: SizedBox(width: 180, child: ProductCard(item: items[index], isLarge: true, heroPrefix: prefix))),
      ),
    );
  }

  Widget _buildRewardsCard() {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const RewardsPage()),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
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
                color: const Color(0xFFFF5C00).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.stars_rounded, color: Color(0xFFFF5C00), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "REWARDS & BENEFITS 🎁",
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Use coins to redeem free food & exclusive rewards",
                    style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFFFF5C00), size: 14),
          ],
        ),
      ),
    );
  }





  Widget _buildNowPlayingCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () => showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true, builder: (context) => const MusicVotingSheet()),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)]),
          child: Row(children: [const Icon(Icons.equalizer_rounded, color: Color(0xFFFF5C00), size: 18), const SizedBox(width: 12), const Text("Now Playing...", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))]),
        ),
      ),
    );
  }

  Widget _buildStatusTag(IconData icon, String label, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 6),
          CircleAvatar(radius: 3, backgroundColor: isActive ? Colors.greenAccent : Colors.grey),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, IconData activeIcon, String label, int index, int currentIndex, {int badgeCount = 0}) {
    bool isSelected = currentIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => ShopManager.instance.currentTabIndex.value = index,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: const BoxDecoration(color: Colors.transparent),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(isSelected ? activeIcon : icon, color: isSelected ? const Color(0xFFFF5C00) : Colors.grey, size: 24),
                  if (badgeCount > 0)
                    Positioned(
                      right: -6, top: -6,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text('$badgeCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 10, color: isSelected ? const Color(0xFFFF5C00) : Colors.grey, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PromoBannerCarousel extends StatefulWidget {
  const _PromoBannerCarousel();

  @override
  State<_PromoBannerCarousel> createState() => _PromoBannerCarouselState();
}

class _PromoBannerCarouselState extends State<_PromoBannerCarousel> {
  final PageController _pageController = PageController();
  Timer? _timer;
  int _currentPage = 0;

  final List<String> _images = [
    'assets/images/food1.png',
    'assets/images/food2.png',
    'assets/images/food3.png',
  ];

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_pageController.hasClients) {
        _currentPage = (_currentPage + 1) % _images.length;
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _goToMenuPage() {
    ShopManager.instance.currentTabIndex.value = 1;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _goToMenuPage,
      child: Container(
        height: 175,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFF4EC),
              Color(0xFFFFE4D3),
            ],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE8C8B5).withValues(alpha: 0.3),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Text Content on the left
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              right: 150,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top Pill Badge: Hot Deals
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '🔥',
                            style: TextStyle(fontSize: 11),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Hot Deals',
                            style: TextStyle(
                              color: Color(0xFFD8521D),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Main Title - Single Line
                    const Text(
                      'Delicious Fast Food',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xFF3B1E13),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),

                    // Subtitle / Slogan - Fills space nicely
                    const Text(
                      'Craving deliciousness? Enjoy hot, fresh & flavorful meals delivered fast right to your door!',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xFF7A5C50),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        height: 1.25,
                      ),
                    ),

                    // Order Now Button (Arrow on the LEFT)
                    GestureDetector(
                      onTap: _goToMenuPage,
                      child: Container(
                        padding: const EdgeInsets.only(left: 6, right: 14, top: 4, bottom: 4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF8A00), Color(0xFFFF5500)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF6600).withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.arrow_forward_rounded,
                                size: 11,
                                color: Color(0xFFFF5500),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Order Now',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Auto-scrolling image carousel on the right half
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              child: SizedBox(
                width: 155,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _images.length,
                  onPageChanged: (index) {
                    _currentPage = index;
                  },
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.asset(
                          _images[index],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: const Color(0xFFFFF0E5),
                              child: const Center(
                                child: Icon(Icons.fastfood_rounded, color: Color(0xFFFF7A00), size: 32),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
