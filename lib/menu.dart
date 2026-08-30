import 'package:flutter/material.dart';
import 'cart_manager.dart';
import 'app_data.dart';
import 'product_card.dart';
import 'search_delegate.dart';
import 'models.dart';
import 'product_details_page.dart';
import 'services/tenant_service.dart';

class MenuPage extends StatefulWidget {
  const MenuPage({super.key});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  String _selectedCategory = 'All';
  String _selectedQuickToggle = '✨ AI Picks';

  final List<String> _quickToggles = [
    '✨ AI Picks', '⚡ Fast Order', '🔥 Popular', '🌱 Healthy', '😋 Sweet Craving',
  ];

  Map<String, String> _getTimeContext() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 11) {
      return {'greeting': 'Morning ☕', 'sub': 'Fresh coffee & warm sandwiches!', 'weather': '22°C Mild'};
    } else if (hour >= 11 && hour < 16) {
      return {'greeting': 'Lunch 🍕', 'sub': 'Heavy meals & combos for your break.', 'weather': '29°C Sunny'};
    } else if (hour >= 16 && hour < 22) {
      return {'greeting': 'Evening 🍔', 'sub': 'Crispy sides & juicy burgers to unwind.', 'weather': '24°C Pleasant'};
    } else {
      return {'greeting': 'Late Night 🌙', 'sub': 'Quick desserts & refreshing drinks.', 'weather': '20°C Cool'};
    }
  }

  List<Map<String, dynamic>> _getFiltered(List<Map<String, dynamic>> dbProducts) {
    List<Map<String, dynamic>> items = dbProducts.isEmpty ? List.from(AppData.darazStyleProducts) : List.from(dbProducts);
    
    if (_selectedCategory != 'All') {
      items = items.where((i) => (i['title'] ?? '').toString().toLowerCase().contains(_selectedCategory.toLowerCase())).toList();
    }
    if (_selectedQuickToggle == '🔥 Popular') {
      items.sort((a, b) => (b['rating'] ?? '0').toString().compareTo((a['rating'] ?? '0').toString()));
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
            } else {
              // Fallback to static categories for testing
              menuCategories.addAll(['Sandwiches', 'Roast Beef', 'Sides', 'Drinks', 'Desserts', 'Pizza', 'Salads', 'Combos']);
            }

            return Container(
              color: const Color(0xFFF8FAFC),
              child: CustomScrollView(
                physics: const ClampingScrollPhysics(),
                slivers: [
                  // 1. Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Our Menu", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                              Text("Smart AI Recommendations", style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
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

                  // 4. History List
                  const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.fromLTRB(20, 24, 20, 12), child: Text("Based on History 🎯", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)))),
                  SliverToBoxAdapter(child: _buildHistoryList()),

                  // 5. Category Selector
                  const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.fromLTRB(20, 32, 20, 12), child: Text("Explore Menu", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)))),
                  SliverToBoxAdapter(child: _buildCategoryList(menuCategories)),

                  // 6. Main Grid
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2, mainAxisSpacing: 14, crossAxisSpacing: 14, childAspectRatio: 0.8,
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
            );
          },
        );
      },
    );
  }

  Widget _buildSearchBtn() {
    return IconButton(
      style: IconButton.styleFrom(backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 2),
      icon: const Icon(Icons.search, color: Colors.black87),
      onPressed: () {
        final all = [...AppData.popularPicks.map((p) => ({...p, 'tag': 'Popular', 'rating': '4.9', 'discount': ''})), ...AppData.darazStyleProducts];
        showSearch(context: context, delegate: MySearchDelegate(all));
      },
    );
  }

  Widget _buildAIBanner(Map<String, String> ctx) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFF5C00), Color(0xFFFF8C00)]),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: const Color(0xFFFF5C00).withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8))],
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSelected ? Colors.black87 : Colors.grey[200]!)),
      ),
    );
  }

  Widget _buildHistoryList() {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: AppData.popularPicks.length,
        itemBuilder: (context, index) {
          final item = AppData.popularPicks[index];
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProductDetailsPage(
                    product: Product(
                      title: item['title'] ?? 'Product',
                      price: item['price'] ?? 'N/A',
                      image: item['image'] ?? '',
                      tag: 'History',
                      rating: '4.9',
                    ),
                    heroTag: "history_menu_${item['title']}",
                  ),
                ),
              );
            },
            child: Container(
              width: 220, margin: const EdgeInsets.only(right: 12), padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[100]!), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]),
              child: Row(children: [
                ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(item['image'] ?? '', width: 55, height: 55, fit: BoxFit.cover)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(item['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1), const Text("Ordered 4x", style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)), Text(item['price'] ?? '', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Color(0xFFFF5C00)))]))
              ]),
            ),
          );
        },
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
              label: Text(cat), selected: isSelected,
              onSelected: (val) => setState(() => _selectedCategory = cat),
              selectedColor: const Color(0xFFFF5C00), backgroundColor: Colors.white,
              labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSelected ? const Color(0xFFFF5C00) : Colors.grey[200]!)),
              showCheckmark: false,
            ),
          );
        },
      ),
    );
  }
}
