import 'package:flutter/material.dart';
import '../../cart_manager.dart';
import '../../services/api_service.dart';
import '../../services/tenant_service.dart';
import '../theme.dart';
import '../widgets/order_customization_dialog.dart';
import 'running_order_summary_screen.dart';

class DigitalMenuScreen extends StatefulWidget {
  final String tableId;
  const DigitalMenuScreen({super.key, required this.tableId});

  @override
  State<DigitalMenuScreen> createState() => _DigitalMenuScreenState();
}

class _DigitalMenuScreenState extends State<DigitalMenuScreen> {
  String _selectedCategory = 'All';
  String _selectedDiet = 'All';
  final TextEditingController _searchController = TextEditingController();

  late int tableIdInt;

  @override
  void initState() {
    super.initState();
    tableIdInt = ShopManager.parseTableId(widget.tableId);
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _getFilteredProducts() {
    List<Map<String, dynamic>> products = TenantService().products.value.where((
      item,
    ) {
      final available = item['is_available'];
      return available == null ||
          available == true ||
          available == 1 ||
          available == '1' ||
          available == 'true';
    }).toList();

    if (_selectedCategory != 'All') {
      final categories = TenantService().categories.value;
      final selected = categories.where(
        (category) => category['title']?.toString() == _selectedCategory,
      );
      final selectedId = selected.isEmpty
          ? null
          : selected.first['id']?.toString();
      products = products.where((item) {
        if (selectedId != null) {
          return item['category_id']?.toString() == selectedId;
        }
        return (item['category_name'] ?? item['category'] ?? '')
                .toString()
                .toLowerCase() ==
            _selectedCategory.toLowerCase();
      }).toList();
    }

    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      products = products.where((item) {
        final searchable = [
          item['title'],
          item['description'],
          item['category_name'],
          item['category'],
        ].whereType<Object>().join(' ').toLowerCase();
        return searchable.contains(query);
      }).toList();
    }

    if (_selectedDiet != 'All') {
      products = products.where((item) {
        final diet = [
          item['dietary_tag'],
          item['dietary'],
          item['food_type'],
          item['tag'],
          item['tags'],
          item['meal_tag'],
          item['category_name'],
        ].whereType<Object>().join(' ').toLowerCase();
        final isNonVeg =
            diet.contains('non-veg') ||
            diet.contains('non veg') ||
            diet.contains('nonveg');
        final isVeg =
            item['is_veg'] == true ||
            item['is_veg'] == 1 ||
            item['is_veg']?.toString().toLowerCase() == 'true' ||
            item['is_veg']?.toString() == '1';
        if (_selectedDiet == 'Veg') {
          return !isNonVeg && (isVeg || diet.contains('veg'));
        }
        if (_selectedDiet == 'Vegan') {
          return diet.contains('vegan');
        }
        return isNonVeg;
      }).toList();
    }
    return products;
  }

  List<String> _getCategories() => [
    'All',
    ...TenantService().categories.value
        .map((category) => category['title']?.toString() ?? '')
        .where((title) => title.isNotEmpty),
  ];

  String _getProductImageUrl(Map<String, dynamic> product) {
    var image = (product['image_url'] ?? product['image'] ?? '').toString();
    if (image.isEmpty || image.startsWith('http')) return image;
    if (image.startsWith('/')) image = image.substring(1);
    return '${ApiService.baseUrl}/$image';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        TenantService().products,
        TenantService().categories,
        TenantService().isLoading,
      ]),
      builder: (context, _) {
        final filteredProducts = _getFilteredProducts();
        final categories = _getCategories();

        return ValueListenableBuilder<Map<int, String>>(
          valueListenable: ShopManager.instance.tableStatuses,
          builder: (context, statuses, _) {
            final tableStatus = statuses[tableIdInt]?.toLowerCase();
            final bool isOccupied =
                tableStatus == "dining" || tableStatus == "readyforbilling";

            return ValueListenableBuilder<Map<int, List<CartItem>>>(
              valueListenable: ShopManager.instance.tableOrders,
              builder: (context, allOrders, child) {
                final tableOrders = allOrders[tableIdInt] ?? [];

                return ValueListenableBuilder<Map<int, Map<String, CartItem>>>(
                  valueListenable: ShopManager.instance.pendingTableOrders,
                  builder: (context, allPending, child) {
                    final tablePending = allPending[tableIdInt] ?? {};
                    int cartCount = 0;

                    tablePending.forEach((_, item) {
                      cartCount += item.quantity;
                    });

                    return Scaffold(
                      appBar: AppBar(
                        title: Text(
                          "Order: ${widget.tableId}",
                          style: const TextStyle(fontSize: 18),
                        ),
                        actions: [
                          if (isOccupied)
                            TextButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        RunningOrderSummaryScreen(
                                          tableId: widget.tableId,
                                        ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.list_alt, size: 16),
                              label: const Text(
                                "VIEW ORDER",
                                style: TextStyle(fontSize: 11),
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: WaiterProTheme.royalBlue,
                              ),
                            ),
                        ],
                      ),
                      body: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                            child: TextField(
                              controller: _searchController,
                              textInputAction: TextInputAction.search,
                              decoration: InputDecoration(
                                hintText: "Search menu items",
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: _searchController.text.isEmpty
                                    ? null
                                    : IconButton(
                                        tooltip: "Clear search",
                                        onPressed: _searchController.clear,
                                        icon: const Icon(Icons.close),
                                      ),
                              ),
                            ),
                          ),
                          // Category Slider
                          SizedBox(
                            height: 50,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              itemCount: categories.length,
                              itemBuilder: (context, index) {
                                bool isSelected =
                                    _selectedCategory == categories[index];
                                return Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: ChoiceChip(
                                    label: Text(
                                      categories[index],
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    selected: isSelected,
                                    onSelected: (val) => setState(
                                      () =>
                                          _selectedCategory = categories[index],
                                    ),
                                    selectedColor: WaiterProTheme.royalBlue,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    labelStyle: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : WaiterProTheme.darkNavy,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          SizedBox(
                            height: 48,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              children: ['All', 'Veg', 'Non-veg', 'Vegan']
                                  .map(
                                    (diet) => Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: FilterChip(
                                        label: Text(diet),
                                        selected: _selectedDiet == diet,
                                        onSelected: (_) => setState(
                                          () => _selectedDiet = diet,
                                        ),
                                        selectedColor:
                                            WaiterProTheme.emeraldGreen,
                                        labelStyle: TextStyle(
                                          color: _selectedDiet == diet
                                              ? Colors.white
                                              : WaiterProTheme.darkNavy,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                          // Items Grid
                          Expanded(
                            child:
                                TenantService().isLoading.value &&
                                    TenantService().products.value.isEmpty
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : filteredProducts.isEmpty
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.search_off,
                                            size: 48,
                                            color: Colors.grey,
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            _searchController.text.isNotEmpty ||
                                                    _selectedCategory !=
                                                        'All' ||
                                                    _selectedDiet != 'All'
                                                ? "No menu items match these filters."
                                                : "No restaurant products are available.",
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : GridView.builder(
                                    padding: const EdgeInsets.all(12),
                                    gridDelegate:
                                        const SliverGridDelegateWithMaxCrossAxisExtent(
                                          maxCrossAxisExtent: 220,
                                          crossAxisSpacing: 12,
                                          mainAxisSpacing: 12,
                                          childAspectRatio: 0.72,
                                        ),
                                    itemCount: filteredProducts.length,
                                    itemBuilder: (context, index) {
                                      final productMap =
                                          filteredProducts[index];
                                      final title = productMap['title'];

                                      final pendingQty =
                                          tablePending[title]?.quantity ?? 0;
                                      final existingQty = tableOrders.fold<int>(
                                        0,
                                        (sum, item) =>
                                            item.product.title == title
                                            ? sum + item.quantity
                                            : sum,
                                      );

                                      return _buildItemCard(
                                        productMap,
                                        pendingQty,
                                        existingQty,
                                      );
                                    },
                                  ),
                          ),
                          // Sticky Cart Bar
                          if (cartCount > 0)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: WaiterProTheme.royalBlue,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(20),
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 10,
                                    offset: Offset(0, -2),
                                  ),
                                ],
                              ),
                              child: SafeArea(
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "$cartCount New Items",
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const Text(
                                            "Final total confirmed by server",
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        ShopManager.instance.addOrderToTable(
                                          tableIdInt,
                                          tablePending.values.toList(),
                                        );
                                        ShopManager.instance.clearPendingOrder(
                                          tableIdInt,
                                        );

                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              "Order updated for Table ${widget.tableId}",
                                            ),
                                          ),
                                        );

                                        Navigator.pushReplacement(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                RunningOrderSummaryScreen(
                                                  tableId: widget.tableId,
                                                ),
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor:
                                            WaiterProTheme.royalBlue,
                                        minimumSize: const Size(120, 40),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                        ),
                                      ),
                                      child: const Text(
                                        "SEND KOT",
                                        style: TextStyle(fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildItemCard(
    Map<String, dynamic> p,
    int pendingQty,
    int existingQty,
  ) {
    String title = p['title'];
    String price = p['price'];
    final imageUrl = _getProductImageUrl(p);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: WaiterProTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: WaiterProTheme.pearlWhite,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    child: imageUrl.isEmpty
                        ? const Center(
                            child: Icon(
                              Icons.restaurant,
                              color: Colors.grey,
                              size: 32,
                            ),
                          )
                        : Image.network(
                            imageUrl,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Center(
                                  child: Icon(
                                    Icons.restaurant,
                                    color: Colors.grey,
                                    size: 32,
                                  ),
                                ),
                          ),
                  ),
                ),
                if (existingQty > 0)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        "On Table: $existingQty",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(6.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  price.replaceAll("NPR ", ""),
                  style: const TextStyle(
                    color: WaiterProTheme.royalBlue,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: InkWell(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) => OrderCustomizationDialog(
                              itemName: title,
                              onSave: (notes) {
                                ShopManager.instance.setPendingItem(
                                  tableIdInt,
                                  p,
                                  pendingQty + 1,
                                );
                              },
                            ),
                          );
                        },
                        child: const Icon(
                          Icons.settings_outlined,
                          size: 20,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: WaiterProTheme.royalBlue,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            constraints: const BoxConstraints.tightFor(
                              width: 36,
                              height: 36,
                            ),
                            padding: EdgeInsets.zero,
                            onPressed: pendingQty > 0
                                ? () => ShopManager.instance.setPendingItem(
                                    tableIdInt,
                                    p,
                                    pendingQty - 1,
                                  )
                                : null,
                            icon: const Icon(
                              Icons.remove,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              "$pendingQty",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          IconButton(
                            constraints: const BoxConstraints.tightFor(
                              width: 36,
                              height: 36,
                            ),
                            padding: EdgeInsets.zero,
                            onPressed: () => ShopManager.instance
                                .setPendingItem(tableIdInt, p, pendingQty + 1),
                            icon: const Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ],
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
}
