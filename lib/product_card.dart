import 'package:flutter/material.dart';
import 'models.dart';
import 'cart_manager.dart';
import 'product_details_page.dart';
import 'ar_view_page.dart';

class ProductCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isLarge;
  final String heroPrefix;

  const ProductCard({
    super.key, 
    required this.item, 
    this.isLarge = false,
    this.heroPrefix = 'product',
  });

  @override
  Widget build(BuildContext context) {
    final product = Product(
      title: item['title'] ?? 'Product',
      price: item['price'] ?? 'N/A',
      image: item['image'] ?? '',
      tag: item['tag'] ?? 'Popular',
      rating: item['rating'] ?? '4.9',
      discount: item['discount'] ?? '',
      modelUrl: item['model_url'],
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductDetailsPage(
                product: product,
                heroTag: "${heroPrefix}_${item['title']}",
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Section
              AspectRatio(
                aspectRatio: 1.55, 
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      child: Hero(
                        tag: "${heroPrefix}_${item['title']}",
                        child: Image.network(
                          item['image'] ?? '', 
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: const Color(0xFFF1F5F9),
                            child: const Icon(Icons.broken_image, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                    if (item['tag'] != null)
                      Positioned(
                        top: 8, left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(color: const Color(0xFFFF5C00), borderRadius: BorderRadius.circular(4)),
                          child: Text(item['tag'], style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    
                    // 3D / AR Trigger Icon
                    if (product.modelUrl != null && product.modelUrl!.isNotEmpty)
                      Positioned(
                        top: 8, right: 8,
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => ARViewPage(product: product)));
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)],
                            ),
                            child: const Icon(Icons.view_in_ar_rounded, color: Color(0xFFFF5C00), size: 16),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Info Section
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['title'] ?? 'Untitled',
                        style: TextStyle(
                          fontSize: isLarge ? 11 : 10, 
                          fontWeight: FontWeight.w600, 
                          color: Colors.black87,
                          height: 1.1,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item['price'] ?? 'N/A', 
                        style: TextStyle(fontSize: isLarge ? 12 : 11, fontWeight: FontWeight.w900, color: const Color(0xFFFF5C00)),
                      ),
                      const Spacer(),
                      ValueListenableBuilder<List<CartItem>>(
                        valueListenable: ShopManager.instance.items,
                        builder: (context, cartItems, child) {
                          final qty = ShopManager.instance.getItemQuantity(product.title);
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.star, color: Colors.amber, size: 10),
                                  const SizedBox(width: 2),
                                  Text(item['rating'] ?? '4.9', style: const TextStyle(fontSize: 9, color: Color(0xFF64748B))),
                                ],
                              ),
                              if (qty == 0)
                                _buildAddButton(context, product)
                              else
                                _buildQuantityCounter(context, product, qty),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddButton(BuildContext context, Product product) {
    return GestureDetector(
      onTap: () {
        ShopManager.instance.pushToCart(product: product, quantity: 1);
      },
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: const BoxDecoration(color: Color(0xFFFF5C00), shape: BoxShape.circle),
        child: Icon(Icons.add, color: Colors.white, size: isLarge ? 14 : 12),
      ),
    );
  }

  Widget _buildQuantityCounter(BuildContext context, Product product, int qty) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFF5C00).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => ShopManager.instance.updateQuantity(product, qty - 1),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Icon(Icons.remove, size: isLarge ? 14 : 12, color: const Color(0xFFFF5C00)),
            ),
          ),
          Text(
            "$qty",
            style: TextStyle(
              fontSize: isLarge ? 12 : 10,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFFF5C00),
            ),
          ),
          GestureDetector(
            onTap: () => ShopManager.instance.updateQuantity(product, qty + 1),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Icon(Icons.add, size: isLarge ? 14 : 12, color: const Color(0xFFFF5C00)),
            ),
          ),
        ],
      ),
    );
  }
}
