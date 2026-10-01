import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'product_card.dart';
import 'search_delegate.dart';
import 'cart_manager.dart';
import 'models.dart';
import 'product_details_page.dart';
import 'services/tenant_service.dart';
import 'services/api_service.dart';

class MenuPage extends StatefulWidget {
  const MenuPage({super.key});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  String _selectedCategory = 'All';
  String _selectedQuickToggle = '🌟 All Items';

  final List<String> _quickToggles = [
    '🌟 All Items', '✨ AI Picks', '⚡ Fast Food', '🔥 Popular', '🌱 Healthy', '😋 Sweet Cravings',
  ];

  String _resolveImageUrl(String raw) {
    if (raw.isEmpty) return '';
    if (raw.startsWith('assets/')) return raw;

    String url = raw;
    if (url.contains('startupsgotech') && !url.contains('startupsgo.tech')) {
      url = url.replaceFirst('startupsgotech', 'startupsgo.tech');
    }
    if (url.contains('/uploads/') && !url.contains('/saas_api/')) {
      url = url.replaceFirst('/uploads/', '/saas_api/uploads/');
    }
    while (url.contains('/saas_api/saas_api/')) {
      url = url.replaceFirst('/saas_api/saas_api/', '/saas_api/');
    }
    if (!url.startsWith('http')) {
      String baseUrl = ApiService.baseUrl;
      if (baseUrl.endsWith('/')) baseUrl = baseUrl.substring(0, baseUrl.length - 1);
      String cleanPath = url.startsWith('/') ? url.substring(1) : url;
      url = "$baseUrl/$cleanPath";
    }
    return url;
  }

  Map<String, String> _getTimeContext() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 11) {
      return {
        'slot': 'Morning',
        'greeting': 'Morning ☕',
        'sub': 'Fresh coffee, tea & warm breakfast!',
        'weather': '22°C Mild',
      };
    } else if (hour >= 11 && hour < 16) {
      return {
        'slot': 'Lunch',
        'greeting': 'Lunch 🍕',
        'sub': 'Heavy meals, rice & combos for your break.',
        'weather': '29°C Sunny',
      };
    } else if (hour >= 16 && hour < 22) {
      return {
        'slot': 'Evening',
        'greeting': 'Evening 🍔',
        'sub': 'Crispy sides & tasty burgers to unwind.',
        'weather': '24°C Pleasant',
      };
    } else {
      return {
        'slot': 'Late Night',
        'greeting': 'Late Night 🌙',
        'sub': 'Quick desserts & refreshing drinks.',
        'weather': '20°C Cool',
      };
    }
  }

  List<Map<String, dynamic>> _getAvailableProducts(List<Map<String, dynamic>> dbProducts) {
    return dbProducts.where((p) {
      final avail = p['is_available'];
      if (avail == false || avail == 0 || avail == '0' || avail == 'false') return false;
      return true;
    }).toList();
  }

  List<Map<String, dynamic>> _getRecommendedItems(List<Map<String, dynamic>> dbProducts, String slot) {
    final available = _getAvailableProducts(dbProducts);
    if (available.isEmpty) return [];

    final matching = available.where((p) {
      final String? time = p['suitable_time']?.toString();

      // 1. If admin explicitly chose suitable_time during upload
      if (time != null && time.isNotEmpty && time != 'null' && time != 'none') {
        return time == slot || time == 'All Day';
      }

      // 2. If suitable_time was NOT set, use strict slot keyword matching
      final title = (p['title'] ?? '').toString().toLowerCase();
      final category = (p['category'] ?? p['category_name'] ?? '').toString().toLowerCase();
      final fullText = "$title $category";

      if (slot == 'Morning') {
        return fullText.contains('tea') || fullText.contains('coffee') || fullText.contains('breakfast') || fullText.contains('toast');
      } else if (slot == 'Lunch') {
        return fullText.contains('thali') || fullText.contains('rice') || fullText.contains('lunch') || fullText.contains('combo');
      } else if (slot == 'Evening') {
        return fullText.contains('snack') || fullText.contains('fries') || fullText.contains('burger');
      } else if (slot == 'Late Night') {
        return fullText.contains('dessert') || fullText.contains('ice cream') || fullText.contains('juice') || fullText.contains('shake') || fullText.contains('sweet');
      }
      return false;
    }).toList();

    if (matching.isEmpty) return [];

    // Randomize and pick up to 4 items
    final seed = DateTime.now().day + DateTime.now().hour;
    final shuffled = List<Map<String, dynamic>>.from(matching)..shuffle(math.Random(seed));
    return shuffled.take(4).toList();
  }

  List<Map<String, dynamic>> _getFiltered(List<Map<String, dynamic>> dbProducts) {
    List<Map<String, dynamic>> items = _getAvailableProducts(dbProducts);

    // 1. Filter by Category
    if (_selectedCategory != 'All') {
      final allCats = TenantService().categories.value;
      final selectedCatObj = allCats.firstWhere(
        (c) => c['title'] == _selectedCategory,
        orElse: () => {'id': null},
      );

      final selectedId = selectedCatObj['id']?.toString();

      if (selectedId != null) {
        items = items.where((i) => i['category_id']?.toString() == selectedId).toList();
      } else {
        items = items.where((i) {
          final t = (i['title'] ?? '').toString().toLowerCase();
          final c = (i['category'] ?? i['category_name'] ?? '').toString().toLowerCase();
          final sel = _selectedCategory.toLowerCase();
          return t.contains(sel) || c.contains(sel);
        }).toList();
      }
    }

    // 2. Filter by Quick Toggle Meal Tag
    if (_selectedQuickToggle == '🌟 All Items') {
      return items;
    } else if (_selectedQuickToggle == '🔥 Popular') {
      items.sort((a, b) => (b['rating'] ?? '0').toString().compareTo((a['rating'] ?? '0').toString()));
      return items;
    } else if (_selectedQuickToggle == '✨ AI Picks') {
      return items.where((i) {
        final tag = (i['meal_tag'] ?? i['tag'] ?? '').toString();
        final r = double.tryParse(i['rating']?.toString() ?? '0') ?? 0;
        return tag.contains('AI Picks') || r >= 4.5;
      }).toList();
    } else if (_selectedQuickToggle == '⚡ Fast Order' || _selectedQuickToggle == '⚡ Fast Food') {
      return items.where((i) {
        final tag = (i['meal_tag'] ?? i['tag'] ?? '').toString();
        final title = (i['title'] ?? '').toString().toLowerCase();
        return tag.contains('Fast Food') || title.contains('burger') || title.contains('pizza') || title.contains('chowmein') || title.contains('chaumin') || title.contains('fry') || title.contains('sandwich');
      }).toList();
    } else if (_selectedQuickToggle == '🌱 Healthy') {
      return items.where((i) {
        final tag = (i['meal_tag'] ?? i['tag'] ?? '').toString();
        final title = (i['title'] ?? '').toString().toLowerCase();
        return tag.contains('Healthy') || title.contains('salad') || title.contains('tea') || title.contains('soup') || title.contains('veg');
      }).toList();
    } else if (_selectedQuickToggle == '😋 Sweet Craving' || _selectedQuickToggle == '😋 Sweet Cravings') {
      return items.where((i) {
        final tag = (i['meal_tag'] ?? i['tag'] ?? '').toString();
        final title = (i['title'] ?? '').toString().toLowerCase();
        return tag.contains('Sweet') || title.contains('ice cream') || title.contains('cake') || title.contains('dessert') || title.contains('shake') || title.contains('sweet');
      }).toList();
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: TenantService().products,
      builder: (context, dbProducts, child) {
        return ValueListenableBuilder<List<Map<String, dynamic>>>(
          valueListenable: TenantService().categories,
          builder: (context, dbCategories, child) {
            final timeContext = _getTimeContext();
            final filtered = _getFiltered(dbProducts);

            // Dynamic categories from DB + 'All'
            final List<String> menuCategories = ['All'];
            if (dbCategories.isNotEmpty) {
              menuCategories.addAll(dbCategories.map((c) => c['title'].toString()));
            }

            return RefreshIndicator(
              onRefresh: () async {
                final tenant = TenantService().currentTenant.value;
                if (tenant != null) {
                  await TenantService().fetchMenuData(tenant.id);
                }
              },
              color: const Color(0xFFFF5C00),
              backgroundColor: Colors.white,
              child: Container(
                color: const Color(0xFFF8FAFC),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // 1. Header
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 20, 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    elevation: 2,
                                  ),
                                  icon: const Icon(Icons.arrow_back, color: Colors.black87),
                                  onPressed: () {
                                    ShopManager.instance.currentTabIndex.value = 0; // Go Home
                                  },
                                ),
                                const SizedBox(width: 12),
                                const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Our Menu", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                                    Text("Smart AI Recommendations", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ],
                            ),
                            _buildSearchBtn(),
                          ],
                        ),
                      ),
                    ),

                    // 2. Premium AI Banner
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: _buildAIBanner(timeContext),
                      ),
                    ),

                    // 3. Quick Toggles
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 40,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _quickToggles.length,
                          itemBuilder: (context, index) => _buildToggleChip(_quickToggles[index]),
                        ),
                      ),
                    ),

                    // 4. Time-Based Recommendations (Replaces History)
                    SliverToBoxAdapter(
                      child: _buildRecommendationSection(dbProducts, timeContext),
                    ),

                    // 5. Category Selector
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(20, 32, 20, 12),
                        child: Text("Explore Menu", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    SliverToBoxAdapter(child: _buildCategoryList(menuCategories)),

                    // 6. Main Grid or Empty State
                    if (filtered.isEmpty)
                      SliverToBoxAdapter(
                        child: Container(
                          margin: const EdgeInsets.all(32),
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            children: const [
                              Icon(Icons.search_off_rounded, size: 48, color: Colors.grey),
                              SizedBox(height: 12),
                              Text(
                                "No food found for this filter",
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              SizedBox(height: 4),
                              Text(
                                "Try selecting another category or tag.",
                                style: TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
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
                            (context, index) => ProductCard(item: filtered[index], heroPrefix: 'menu_main'),
                            childCount: filtered.length,
                          ),
                        ),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSearchBtn() {
    return IconButton(
      style: IconButton.styleFrom(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 2,
      ),
      icon: const Icon(Icons.search, color: Colors.black87),
      onPressed: () {
        final dbProducts = TenantService().products.value;
        showSearch(context: context, delegate: MySearchDelegate(dbProducts));
      },
    );
  }

  Widget _buildAIBanner(Map<String, String> ctx) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFF5C00), Color(0xFFFF8C00)]),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF5C00).withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(ctx['greeting']!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Text(ctx['weather']!, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text(ctx['sub']!, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, height: 1.3)),
        ],
      ),
    );
  }

  Widget _buildToggleChip(String label) {
    bool isSelected = _selectedQuickToggle == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        onPressed: () => setState(() => _selectedQuickToggle = label),
        label: Text(label),
        backgroundColor: isSelected ? Colors.black87 : Colors.white,
        labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: isSelected ? Colors.black87 : Colors.grey[200]!),
        ),
      ),
    );
  }

  Widget _buildRecommendationSection(List<Map<String, dynamic>> dbProducts, Map<String, String> timeContext) {
    final slot = timeContext['slot'] ?? 'Morning';
    final recommended = _getRecommendedItems(_getAvailableProducts(dbProducts), slot);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Recommended for ${timeContext['greeting']} ✨",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              if (recommended.isNotEmpty)
                Text(
                  "${recommended.length} items",
                  style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                ),
            ],
          ),
        ),
        if (recommended.isEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey[200]!),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFFFF5C00).withValues(alpha: 0.1),
                  child: const Icon(Icons.restaurant, color: Color(0xFFFF5C00)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text("No food found for this time", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      SizedBox(height: 2),
                      Text("Explore full menu categories below.", style: TextStyle(color: Colors.grey, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 105,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: recommended.length,
              itemBuilder: (context, index) {
                final item = recommended[index];
                final String rawImg = item['image_url'] ?? item['image'] ?? '';
                final String imgUrl = _resolveImageUrl(rawImg);
                String priceStr = item['price']?.toString() ?? 'N/A';
                if (!priceStr.contains('NPR') && priceStr != 'N/A') priceStr = "NPR $priceStr";

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProductDetailsPage(
                          product: Product(
                            title: item['title'] ?? 'Product',
                            price: priceStr,
                            image: imgUrl,
                            tag: 'Recommended',
                            rating: item['rating']?.toString() ?? '4.9',
                          ),
                          heroTag: "rec_menu_${item['title']}",
                        ),
                      ),
                    );
                  },
                  child: Container(
                    width: 220,
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[100]!),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10),
                      ],
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _buildItemThumbnail(rawImg),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                item['title'] ?? '',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                item['slogan'] ?? "Fresh for ${timeContext['slot']}",
                                style: const TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                priceStr,
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Color(0xFFFF5C00)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildItemThumbnail(String? rawPath) {
    final String path = _resolveImageUrl(rawPath ?? '');

    if (path.isEmpty) {
      return Container(
        width: 55,
        height: 55,
        color: const Color(0xFFFFF0E5),
        child: const Icon(Icons.fastfood, color: Colors.orange, size: 24),
      );
    }
    if (path.startsWith('assets/')) {
      return Image.asset(
        path,
        width: 55,
        height: 55,
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) => Container(
          width: 55,
          height: 55,
          color: const Color(0xFFFFF0E5),
          child: const Icon(Icons.fastfood, color: Colors.orange, size: 24),
        ),
      );
    }
    return Image.network(
      path,
      width: 55,
      height: 55,
      fit: BoxFit.cover,
      errorBuilder: (c, e, s) => Container(
        width: 55,
        height: 55,
        color: const Color(0xFFFFF0E5),
        child: const Icon(Icons.fastfood, color: Colors.orange, size: 24),
      ),
    );
  }

  Widget _buildCategoryList(List<String> categories) {
    return SizedBox(
      height: 45,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final cat = categories[index];
          bool isSelected = _selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(cat),
              selected: isSelected,
              onSelected: (val) => setState(() => _selectedCategory = cat),
              selectedColor: const Color(0xFFFF5C00),
              backgroundColor: Colors.white,
              labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: isSelected ? const Color(0xFFFF5C00) : Colors.grey[200]!),
              ),
              showCheckmark: false,
            ),
          );
        },
      ),
    );
  }
}
