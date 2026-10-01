import 'package:flutter/material.dart';
import 'dart:math';
import 'cart_manager.dart';
import 'models.dart';
import 'app_data.dart';
import 'product_card.dart';
import 'ar_view_page.dart';
import 'services/tenant_service.dart';
import 'services/api_service.dart';

class ProductDetailsPage extends StatefulWidget {
  final Product product;
  final String? heroTag;

  const ProductDetailsPage({super.key, required this.product, this.heroTag});

  @override
  State<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends State<ProductDetailsPage> {
  int quantity = 1;
  bool isFavorite = false;
  String selectedSize = "Medium";
  String currentDisplayPrice = "";
  List<Map<String, dynamic>> _moreItems = [];

  @override
  void initState() {
    super.initState();
    _initMoreItems();
    _initSelectedSizeAndPrice();
  }

  void _initSelectedSizeAndPrice() {
    if (widget.product.hasVariants && widget.product.variants.isNotEmpty) {
      final defaultVariant = widget.product.variants.first;
      selectedSize = defaultVariant['name'] ?? 'Medium';
      String vPrice = defaultVariant['price'] ?? '';
      if (vPrice.isNotEmpty) {
        currentDisplayPrice = vPrice.startsWith('NPR') ? vPrice : "NPR $vPrice";
      } else {
        currentDisplayPrice = widget.product.price;
      }
    } else {
      currentDisplayPrice = widget.product.price;
    }
  }

  void _onSizeSelected(String sizeName) {
    setState(() {
      selectedSize = sizeName;
      if (widget.product.hasVariants && widget.product.variants.isNotEmpty) {
        final match = widget.product.variants.firstWhere(
          (v) => (v['name'] ?? '').toLowerCase() == sizeName.toLowerCase(),
          orElse: () => {'name': sizeName, 'price': widget.product.price},
        );
        String vPrice = match['price'] ?? '';
        if (vPrice.isNotEmpty) {
          currentDisplayPrice = vPrice.startsWith('NPR') ? vPrice : "NPR $vPrice";
        }
      }
    });
  }

  void _initMoreItems() {
    final List<Map<String, dynamic>> rawDbProducts = List<Map<String, dynamic>>.from(
      TenantService().products.value,
    ).where((p) {
      final avail = p['is_available'];
      if (avail == false || avail == 0 || avail == '0' || avail == 'false') return false;
      return true;
    }).toList();

    if (rawDbProducts.isEmpty) {
      _moreItems = [];
      return;
    }

    final currentTitle = widget.product.title.trim().toLowerCase();
    final currentCategory = widget.product.tag.trim().toLowerCase();

    // 1. Separate uploaded items in same category vs other categories (excluding current product)
    final sameCat = <Map<String, dynamic>>[];
    final otherCat = <Map<String, dynamic>>[];

    for (var p in rawDbProducts) {
      final pTitle = (p['title'] ?? '').toString().trim().toLowerCase();
      if (pTitle == currentTitle) continue; // Exclude current product being viewed

      final pTag = (p['tag'] ?? p['category'] ?? p['category_name'] ?? '').toString().trim().toLowerCase();
      final isSameCat = (pTag.isNotEmpty && pTag == currentCategory) ||
                        (currentCategory.isNotEmpty && pTag.contains(currentCategory)) ||
                        (currentCategory.isNotEmpty && currentCategory.contains(pTag));

      if (isSameCat) {
        sameCat.add(p);
      } else {
        otherCat.add(p);
      }
    }

    // Shuffle both lists randomly
    sameCat.shuffle(Random());
    otherCat.shuffle(Random());

    final selected = <Map<String, dynamic>>[];

    // 2. First take up to 4 items from the SAME category
    for (var p in sameCat) {
      if (selected.length < 4) {
        selected.add(p);
      }
    }

    // 3. If we still need more items to reach 4, fill from OTHER categories (uploaded products only)
    for (var p in otherCat) {
      if (selected.length < 4) {
        selected.add(p);
      }
    }

    _moreItems = selected;
  }

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

  Widget _buildProductImage(String imagePath) {
    final resolvedPath = _resolveImageUrl(imagePath);

    if (resolvedPath.isEmpty) {
      return Container(
        height: 220,
        width: 220,
        decoration: BoxDecoration(
          color: const Color(0xFFFFF0E5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: Icon(Icons.fastfood_rounded, color: Color(0xFFFF5C00), size: 64),
        ),
      );
    }

    if (resolvedPath.startsWith('assets/')) {
      return Image.asset(
        resolvedPath,
        height: 220,
        width: 220,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Container(
          height: 220,
          width: 220,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF0E5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Center(
            child: Icon(Icons.fastfood_rounded, color: Color(0xFFFF5C00), size: 64),
          ),
        ),
      );
    }

    return Image.network(
      resolvedPath,
      height: 220,
      width: 220,
      fit: BoxFit.contain,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return SizedBox(
          height: 220,
          width: 220,
          child: Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                  : null,
              color: const Color(0xFFFF5C00),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) => Container(
        height: 220,
        width: 220,
        decoration: BoxDecoration(
          color: const Color(0xFFFFF0E5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: Icon(Icons.fastfood_rounded, color: Color(0xFFFF5C00), size: 64),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: CircleAvatar(
            backgroundColor: Colors.grey.withValues(alpha: 0.1),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: const Text(
          "Details",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  isFavorite = !isFavorite;
                });
              },
              child: CircleAvatar(
                backgroundColor: Colors.grey.withValues(alpha: 0.1),
                child: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: isFavorite ? Colors.red : Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image Card - Made larger and more immersive
            Container(
              width: double.infinity,
              height: 300,
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: Stack(
                children: [
                  Center(
                    child: Hero(
                      tag: widget.heroTag ?? widget.product.title,
                      child: _buildProductImage(widget.product.image),
                    ),
                  ),
                  Positioned(
                    top: 20, right: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5C00),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        widget.product.tag,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  if (TenantService().currentTenant.value?.isPremiumEnabled ?? false)
                    Positioned(
                      top: 20, left: 20,
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => ARViewPage(product: widget.product)),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: Icon(
                            Icons.view_in_ar_rounded, 
                            color: (widget.product.modelUrl != null && widget.product.modelUrl!.isNotEmpty)
                                ? const Color(0xFFFF5C00)
                                : Colors.grey,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          widget.product.title,
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black, height: 1.2),
                        ),
                      ),
                      if (!widget.product.isComingSoon)
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              _buildQtyBtn(Icons.remove, () {
                                if (quantity > 1) setState(() => quantity--);
                              }),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text("$quantity", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                              _buildQtyBtn(Icons.add, () => setState(() => quantity++), isAdd: true),
                            ],
                          ),
                        ),
                    ],
                  ),
                  
                  if (widget.product.isComingSoon)
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.purple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.upcoming_outlined, color: Colors.purple),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "Upcoming Menu Item • Coming Soon! Not available for ordering yet. Give us your feedback below!",
                              style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  const SizedBox(height: 12),
                  
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined, color: Colors.grey, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        (widget.product.prepTime != null && widget.product.prepTime!.isNotEmpty)
                            ? widget.product.prepTime!
                            : "15-20 min",
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  
                  // Selection Section
                  _buildSizeSection(),

                  const SizedBox(height: 24),
                  
                  const Text("Description", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    widget.product.description ?? "Experience the authentic taste of ChiyaBreak with our premium ${widget.product.title}. Prepared with fresh ingredients and served hot just for you.",
                    style: TextStyle(color: Colors.grey[600], height: 1.6, fontSize: 14),
                  ),

                  const SizedBox(height: 32),
                  
                  const Text("More from our Menu", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  
                  // Dynamic 4 items from uploaded products (Category matched / Randomized)
                  SizedBox(
                    height: 190,
                    child: _moreItems.isEmpty
                        ? const Center(child: Text("No items available", style: TextStyle(color: Colors.grey)))
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _moreItems.length,
                            itemBuilder: (context, index) {
                              final item = _moreItems[index];
                              return Padding(
                                padding: const EdgeInsets.only(right: 16),
                                child: SizedBox(
                                  width: 130,
                                  child: ProductCard(
                                    item: item, 
                                    heroPrefix: 'detail_more_${widget.product.title}_$index',
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Price", style: TextStyle(color: Colors.grey, fontSize: 12)),
                Text(
                  currentDisplayPrice.isNotEmpty ? currentDisplayPrice : widget.product.price,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFFFF5C00)),
                ),
              ],
            ),
            const SizedBox(width: 24),
            Expanded(
              child: widget.product.isComingSoon
                  ? ElevatedButton.icon(
                      onPressed: () => _showFeedbackDialog(context),
                      icon: const Icon(Icons.rate_review_outlined),
                      label: const Text("GIVE FEEDBACK / VOTE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                    )
                  : ElevatedButton(
                onPressed: widget.product.isAvailable
                    ? () {
                        final String cartTitle = widget.product.hasVariants && widget.product.variants.isNotEmpty
                            ? "${widget.product.title} ($selectedSize)"
                            : widget.product.title;

                        final cartProduct = Product(
                          title: cartTitle,
                          price: currentDisplayPrice.isNotEmpty ? currentDisplayPrice : widget.product.price,
                          image: widget.product.image,
                          tag: widget.product.tag,
                          rating: widget.product.rating,
                          discount: widget.product.discount,
                          description: widget.product.description,
                          slogan: widget.product.slogan,
                          modelUrl: widget.product.modelUrl,
                          iosModelUrl: widget.product.iosModelUrl,
                        );

                        ShopManager.instance.pushToCart(product: cartProduct, quantity: quantity);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("$cartTitle added to cart!"),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: const Color(0xFFFF5C00),
                          ),
                        );
                        Navigator.pop(context);
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.product.isAvailable ? const Color(0xFFFF5C00) : Colors.grey.shade400,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: Text(
                  widget.product.isAvailable ? "ADD TO CART" : "CURRENTLY OUT OF STOCK",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQtyBtn(IconData icon, VoidCallback onTap, {bool isAdd = false}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isAdd ? const Color(0xFFFF5C00) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [if(!isAdd) BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)],
        ),
        child: Icon(icon, size: 18, color: isAdd ? Colors.white : Colors.black),
      ),
    );
  }

  Widget _buildSizeSection() {
    List<Map<String, String>> options = [];
    String sectionTitle = "Select Size";

    if (widget.product.hasVariants && widget.product.variants.isNotEmpty) {
      options = widget.product.variants;
      if (widget.product.variantType == 'portions') {
        sectionTitle = "Select Portion";
      } else if (widget.product.variantType == 'volume') {
        sectionTitle = "Select Volume";
      } else if (widget.product.variantType == 'custom') {
        sectionTitle = "Select Option";
      }
    } else {
      options = [
        {'name': 'Small', 'price': widget.product.price},
        {'name': 'Medium', 'price': widget.product.price},
        {'name': 'Large', 'price': widget.product.price},
      ];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(sectionTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: options.map((opt) {
            final name = opt['name'] ?? '';
            final price = opt['price'] ?? '';
            final isSelected = selectedSize.toLowerCase() == name.toLowerCase();

            String displayLabel = name;
            if (price.isNotEmpty && price != widget.product.price) {
              displayLabel = "$name (NPR ${price.replaceAll('NPR ', '')})";
            }

            return GestureDetector(
              onTap: () => _onSizeSelected(name),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFFF5C00) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isSelected ? const Color(0xFFFF5C00) : Colors.grey[300]!),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFFFF5C00).withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          )
                        ]
                      : [],
                ),
                child: Text(
                  displayLabel,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[800],
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSizeChip(String size) {
    bool isSelected = selectedSize == size;
    return GestureDetector(
      onTap: () => setState(() => selectedSize = size),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF5C00).withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? const Color(0xFFFF5C00) : Colors.grey[200]!),
        ),
        child: Text(
          size,
          style: TextStyle(
            color: isSelected ? const Color(0xFFFF5C00) : Colors.grey[600],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  void _showFeedbackDialog(BuildContext context) {
    final feedbackCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Feedback for ${widget.product.title}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("We'd love to hear your thoughts on this upcoming dish! Would you like to see it on our menu soon?"),
            const SizedBox(height: 16),
            TextField(
              controller: feedbackCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "Enter your review or suggestions...",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Thank you for your feedback on this coming product!"), backgroundColor: Colors.purple),
              );
            },
            child: const Text("Submit Feedback"),
          ),
        ],
      ),
    );
  }
}
