import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'models.dart';
import 'cart_manager.dart';
import 'product_details_page.dart';
import 'ar_view_page.dart';
import 'product_voice_assistant_page.dart';
import 'services/tenant_service.dart';
import 'services/api_service.dart';

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
    String displayImage = item['image_url'] ?? item['image'] ?? '';
    
    // --- THE ULTIMATE PATH RESOLVER ---
    if (displayImage.isNotEmpty) {
      // 1. Fix Broken Domain (if SQL removed dots)
      if (displayImage.contains('startupsgotech') && !displayImage.contains('startupsgo.tech')) {
        displayImage = displayImage.replaceFirst('startupsgotech', 'startupsgo.tech');
      }

      // 2. Ensure saas_api is in the path
      if (displayImage.contains('/uploads/') && !displayImage.contains('/saas_api/')) {
        displayImage = displayImage.replaceFirst('/uploads/', '/saas_api/uploads/');
      }
      
      // 3. FIX DOUBLE SAAS_API (Critical for chaumin)
      while (displayImage.contains('/saas_api/saas_api/')) {
        displayImage = displayImage.replaceFirst('/saas_api/saas_api/', '/saas_api/');
      }

      // 4. Fix Middle Dots in filenames (prod_xxx.yyy.jpg -> prod_xxxyyy.jpg)
      if (displayImage.contains('/products/prod_')) {
        String base = displayImage.split('/products/').first;
        String filename = displayImage.split('/products/').last;
        
        // Preservation logic
        String extension = filename.split('.').last;
        String nameWithoutExt = filename.substring(0, filename.lastIndexOf('.'));
        String cleanName = nameWithoutExt.replaceAll('.', '') + "." + extension;
        
        displayImage = "$base/products/$cleanName";
      }

      // 5. Handle relative paths
      if (!displayImage.startsWith('http')) {
        String baseUrl = ApiService.baseUrl; 
        if (baseUrl.endsWith('/')) baseUrl = baseUrl.substring(0, baseUrl.length - 1);
        String cleanPath = displayImage.startsWith('/') ? displayImage.substring(1) : displayImage;
        displayImage = "$baseUrl/$cleanPath";
      }
    }
    
    // Debug print for localhost troubleshooting
    if (kDebugMode && displayImage.isNotEmpty) {
       print("DEBUG: Loading image from -> $displayImage");
    }

    String titleText = (item['title'] != null && item['title'].toString().trim().isNotEmpty) ? item['title'].toString() : 'Coming Soon Item';
    String rawPrice = item['price']?.toString() ?? '';
    String displayPrice = rawPrice.isNotEmpty && rawPrice != '0' && rawPrice != '0.00' ? rawPrice : 'Coming Soon';
    if (!displayPrice.contains('NPR') && displayPrice != 'Coming Soon' && displayPrice != 'N/A') {
      displayPrice = "NPR $displayPrice";
    }

    // Parse variants safely
    List<Map<String, String>> parsedVariants = [];
    if (item['variants'] != null) {
      if (item['variants'] is String && (item['variants'] as String).isNotEmpty) {
        try {
          final List decoded = json.decode(item['variants']);
          parsedVariants = decoded.map((v) => {
            'name': v['name']?.toString() ?? '',
            'price': v['price']?.toString() ?? '',
          }).toList();
        } catch (_) {}
      } else if (item['variants'] is List) {
        parsedVariants = (item['variants'] as List).map((v) => {
          'name': v['name']?.toString() ?? '',
          'price': v['price']?.toString() ?? '',
        }).toList();
      }
    }

    final bool hasVariants = (item['has_variants'] == true || item['has_variants'] == 1 || item['has_variants'] == '1') || parsedVariants.isNotEmpty;
    final String? variantType = item['variant_type']?.toString();
    final String? prepTime = item['prep_time']?.toString();

    final bool itemIsAvailable = item['is_available'] == true || item['is_available'] == 1 || item['is_available'] == '1' || item['is_available'] == null || item['is_available'] == 'true';
    final bool itemIsComingSoon = item['is_coming_soon'] == true || item['is_coming_soon'] == 1 || item['is_coming_soon'] == '1' || item['is_coming_soon'] == 'true';

    final product = Product(
      title: item['title'] ?? 'Product',
      price: displayPrice,
      image: displayImage,
      tag: item['tag'] ?? 'Popular',
      rating: item['rating'] ?? '4.9',
      discount: item['discount'] ?? '',
      slogan: item['slogan'],
      modelUrl: item['model_url'],
      iosModelUrl: item['ios_model_url'],
      hasVariants: hasVariants,
      variantType: variantType,
      variants: parsedVariants,
      prepTime: prepTime,
      isAvailable: itemIsAvailable,
      isComingSoon: itemIsComingSoon,
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
                          displayImage, 
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                    : null,
                                strokeWidth: 2,
                                color: const Color(0xFFFF5C00),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: const Color(0xFFF1F5F9),
                            child: const Icon(Icons.broken_image_rounded, color: Colors.grey, size: 24),
                          ),
                        ),
                      ),
                    ),
                    // Out of Stock Overlay
                    if (!itemIsAvailable)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                          ),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                "OUT OF STOCK",
                                style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Tag Section
                    if (item['tag'] != null)
                      Positioned(
                        bottom: 8, left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(color: const Color(0xFFFF5C00), borderRadius: BorderRadius.circular(4)),
                          child: Text(item['tag'], style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    
                    // 3D / AR Trigger Icon (Premium Feature Check)
                    if (TenantService().currentTenant.value?.isPremiumEnabled ?? false)
                      Positioned(
                        top: 8, left: 8,
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
                            child: Icon(
                              Icons.view_in_ar_rounded, 
                              color: (product.modelUrl != null && product.modelUrl!.isNotEmpty) 
                                  ? const Color(0xFFFF5C00) 
                                  : Colors.grey, 
                              size: 16
                            ),
                          ),
                        ),
                      ),

                    // Voice Assistant Trigger Icon (Premium Feature Check)
                    if (TenantService().currentTenant.value?.isPremiumEnabled ?? false)
                      Positioned(
                        top: 8, right: 8,
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => ProductVoiceAssistantPage(product: product)),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)],
                            ),
                            child: const Icon(Icons.spatial_audio_off_rounded, color: Color(0xFFFF5C00), size: 16),
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
                        titleText,
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
                        displayPrice, 
                        style: TextStyle(fontSize: isLarge ? 12 : 11, fontWeight: FontWeight.w900, color: const Color(0xFFFF5C00)),
                      ),
                      if ((product.slogan != null && product.slogan!.isNotEmpty) || (item['description'] != null && item['description'].toString().isNotEmpty))
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            product.slogan?.isNotEmpty == true ? product.slogan! : item['description'].toString(),
                            style: TextStyle(fontSize: isLarge ? 10 : 9, color: Colors.grey[600], fontWeight: FontWeight.bold, fontStyle: FontStyle.italic),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      const Spacer(),
                      ValueListenableBuilder<List<CartItem>>(
                        valueListenable: ShopManager.instance.items,
                        builder: (context, cartItems, child) {
                          if (itemIsComingSoon) {
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("Coming Soon item! Tap card to view details & give feedback."),
                                        backgroundColor: Colors.purple,
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.purple.shade50,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.purple.shade200),
                                    ),
                                    child: const Icon(Icons.info_outline, color: Colors.purple, size: 14),
                                  ),
                                ),
                              ],
                            );
                          }
                          if (!itemIsAvailable) {
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
                                  child: const Text("UNAVAILABLE", style: TextStyle(color: Colors.grey, fontSize: 8, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            );
                          }
                          final qty = ShopManager.instance.getItemQuantity(product.title);
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
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
