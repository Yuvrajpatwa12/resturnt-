import 'package:flutter/material.dart';
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
import 'music_voting_sheet.dart';
import 'services/tenant_service.dart';
import 'notifications_page.dart';
import 'widgets/smart_auth_overlay.dart';
import 'widgets/onboarding_modal.dart';
import 'widgets/notification_prompt.dart';
import 'widgets/proximity_offer_dialog.dart'; // Added

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
                  if (!visible) return const SizedBox.shrink();
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
        // Filter products based on featured_section
        final List<Map<String, dynamic>> gridTopItems = dbProducts.where((p) => p['featured_section'] == 'just_for_you').toList();
        final List<Map<String, dynamic>> rowScrollItems = dbProducts.where((p) => p['featured_section'] == 'trending').toList();
        final List<Map<String, dynamic>> popularItems = dbProducts.where((p) => p['featured_section'] == 'popular').toList();
        
        // Products with NO section selected (or 'none')
        final List<Map<String, dynamic>> otherProducts = dbProducts.where((p) => 
          p['featured_section'] == 'none' || p['featured_section'] == null || p['featured_section'] == ''
        ).toList();

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
                child: _buildSmartGreetingCard(),
              ),
            ),
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
                  child: _buildHorizontalList(
                    popularItems.map((e) => Map<String, String>.from(e.map((k, v) => MapEntry(k, v.toString())))).toList(), 
                    'popular'
                  ),
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

            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      );
    },
  );
}

  Widget _buildSmartGreetingCard() {
    final tenant = TenantService().currentTenant.value;
    if (tenant == null) return const SizedBox.shrink();

    return ValueListenableBuilder<bool>(
      valueListenable: ShopManager.instance.isEmailSynced,
      builder: (context, synced, _) {
        if (!synced) {
           return Container(
             padding: const EdgeInsets.all(20),
             decoration: BoxDecoration(
               color: Colors.white,
               borderRadius: BorderRadius.circular(24),
               boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)],
             ),
             child: Row(
               children: [
                 const CircleAvatar(backgroundColor: Color(0xFFF7F8FA), child: Icon(Icons.account_circle_outlined, color: Colors.grey)),
                 const SizedBox(width: 16),
                 Expanded(
                   child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                     Text("Welcome Guest!", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                     Text("Sync your profile to track coins globally.", style: TextStyle(color: Colors.grey, fontSize: 11)),
                   ]),
                 ),
                 TextButton(onPressed: () => ShopManager.instance.currentTabIndex.value = 4, child: const Text("SYNC")),
               ],
             ),
           );
        }

        return ValueListenableBuilder<bool>(
          valueListenable: ShopManager.instance.isNewToShop,
          builder: (context, isNew, _) {
            final String title = isNew ? "Welcome to ${tenant.name}!" : "Welcome Back, ${ShopManager.instance.customerName.value}!";
            final String sub = isNew ? "Join our loyalty program to earn rewards." : "You have ${ShopManager.instance.userPoints.value} coins waiting for you.";
            
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isNew ? [const Color(0xFF0047AB), const Color(0xFF002D62)] : [const Color(0xFFFF5C00), const Color(0xFFFF8C00)],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: (isNew ? Colors.blue : Colors.orange).withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    child: Icon(isNew ? Icons.celebration_rounded : Icons.auto_awesome, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                        Text(sub, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  if (!isNew)
                    const Icon(Icons.verified_rounded, color: Colors.white, size: 20),
                ],
              ),
            );
          },
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
            _buildHeaderAction(Icons.mic_none_outlined, () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const VoiceOrderPage()));
            }),
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
                        const Text("Table Number", style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.w600)),
                        ValueListenableBuilder<int?>(
                          valueListenable: ShopManager.instance.selectedTableId,
                          builder: (context, tableId, child) => Text(
                            tableId != null ? "TABLE ${tableId.toString().padLeft(2, '0')}" : "SELECT TABLE", 
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
            final allProducts = [...AppData.popularPicks.map((p) => ({...p, 'tag': 'Popular', 'rating': '4.9', 'discount': ''})), ...AppData.darazStyleProducts];
            showSearch(context: context, delegate: MySearchDelegate(allProducts));
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: GridView.count(
          shrinkWrap: true,
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
      ),
    );
  }

  Widget _buildPromoBanner() {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF8A1820), Color(0xFF5A0D12)]),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          Positioned(right: -10, bottom: 0, child: Image.network('https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=500', height: 140, fit: BoxFit.cover)),
          const Padding(
            padding: EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('MEAT CRAFT.\nPERFECTED.', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic)),
                SizedBox(height: 10),
                Text('Order Now', style: TextStyle(color: Color(0xFFFF5C00), fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
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

  Widget _buildHorizontalList(List<Map<String, String>> items, String prefix) {
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)]),
      child: const Row(
        children: [
          Icon(Icons.local_activity_outlined, color: Color(0xFFFF5C00), size: 20),
          SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("REWARDS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), Text('Earn points with every order.', style: TextStyle(fontSize: 9, color: Colors.grey))])),
        ],
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
