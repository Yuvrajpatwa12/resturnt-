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

  late int tableIdInt;

  @override
  void initState() {
    super.initState();
    tableIdInt = ShopManager.parseTableId(widget.tableId);
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
      ]),
      builder: (context, _) {
        final filteredProducts = _getFilteredProducts();
        final categories = _getCategories();

        return ValueListenableBuilder<Map<int, String>>(
          valueListenable: ShopManager.instance.tableStatuses,
          builder: (context, statuses, _) {
            final bool isOccupied = statuses[tableIdInt] == "Dining";

            return ValueListenableBuilder<Map<int, List<CartItem>>>(
              valueListenable: ShopManager.instance.tableOrders,
              builder: (context, allOrders, child) {
                final tableOrders = allOrders[tableIdInt] ?? [];

                return ValueListenableBuilder<Map<int, Map<String, CartItem>>>(
                  valueListenable: ShopManager.instance.pendingTableOrders,
                  builder: (context, allPending, child) {
                    final tablePending = allPending[tableIdInt] ?? {};
                    int cartCount = 0;
                    double cartTotal = 0.0;

                    tablePending.forEach((_, item) {
                      cartCount += item.quantity;
                      double price =
                          double.tryParse(
                            item.product.price.replaceAll(
                              RegExp(r'[^0-9.]'),
                              '',
                            ),
                          ) ??
                          0;
                      cartTotal += price * item.quantity;
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
                          IconButton(
                            onPressed: () {},
                            icon: const Icon(Icons.search, size: 20),
                          ),
                        ],
                      ),
                      body: Column(
                        children: [
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
                          // Items Grid
                          Expanded(
                            child: filteredProducts.isEmpty
                                ? const Center(
                                    child: Text(
                                      "No restaurant products are available.",
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  )
                                : GridView.builder(
                                    padding: const EdgeInsets.all(12),
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 3,
                                          crossAxisSpacing: 10,
                                          mainAxisSpacing: 10,
                                          childAspectRatio: 0.65,
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
                                          Text(
                                            "Total: NPR ${cartTotal.toStringAsFixed(0)}",
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 11,
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
                    InkWell(
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
                        size: 16,
                        color: Colors.grey,
                      ),
                    ),
                    Container(
                      height: 24,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: WaiterProTheme.royalBlue,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          InkWell(
                            onTap: () {
                              if (pendingQty > 0)
                                ShopManager.instance.setPendingItem(
                                  tableIdInt,
                                  p,
                                  pendingQty - 1,
                                );
                            },
                            child: const Icon(
                              Icons.remove,
                              color: Colors.white,
                              size: 14,
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
                          InkWell(
                            onTap: () => ShopManager.instance.setPendingItem(
                              tableIdInt,
                              p,
                              pendingQty + 1,
                            ),
                            child: const Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 14,
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
