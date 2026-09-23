import 'package:flutter/material.dart';
import 'models.dart';
import 'product_details_page.dart';
import 'services/api_service.dart';

class MySearchDelegate extends SearchDelegate {
  final List<Map<String, dynamic>> products;
  MySearchDelegate(this.products);

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

  Widget _buildProductImage(String? rawImagePath, {double width = 50, double height = 50}) {
    final imagePath = _resolveImageUrl(rawImagePath ?? '');

    if (imagePath.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: width,
          height: height,
          color: const Color(0xFFFFF0E5),
          child: const Icon(Icons.fastfood, color: Colors.orange, size: 20),
        ),
      );
    }
    if (imagePath.startsWith('assets/')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.asset(
          imagePath,
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            width: width,
            height: height,
            color: const Color(0xFFFFF0E5),
            child: const Icon(Icons.fastfood, color: Colors.orange, size: 20),
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        imagePath,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: width,
          height: height,
          color: const Color(0xFFFFF0E5),
          child: const Icon(Icons.fastfood, color: Colors.orange, size: 20),
        ),
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () => query = '',
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final results = products.where((p) => p['title'].toString().toLowerCase().contains(query.toLowerCase())).toList();
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final item = results[index];
        final String rawImg = item['image_url'] ?? item['image'] ?? '';
        final String imgUrl = _resolveImageUrl(rawImg);
        final String priceStr = item['price'] != null ? "NPR ${item['price']}" : "";

        return ListTile(
          leading: Hero(
            tag: "search_${item['title']}",
            child: _buildProductImage(rawImg, width: 50, height: 50),
          ),
          title: Text(item['title'] ?? ''),
          subtitle: Text(priceStr),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProductDetailsPage(
                  product: Product(
                    title: item['title'] ?? '',
                    price: priceStr.isNotEmpty ? priceStr : (item['price']?.toString() ?? '0'),
                    image: imgUrl,
                    tag: item['tag'] ?? 'Popular',
                    rating: item['rating']?.toString() ?? '4.9',
                    discount: item['discount'] ?? '',
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final suggestions = products.where((p) => p['title'].toString().toLowerCase().contains(query.toLowerCase())).toList();
    return ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final item = suggestions[index];
        final String rawImg = item['image_url'] ?? item['image'] ?? '';
        final String imgUrl = _resolveImageUrl(rawImg);
        final String priceStr = item['price'] != null ? "NPR ${item['price']}" : "";

        return ListTile(
          leading: _buildProductImage(rawImg, width: 40, height: 40),
          title: Text(item['title'] ?? '', style: const TextStyle(fontSize: 14)),
          subtitle: priceStr.isNotEmpty ? Text(priceStr, style: const TextStyle(fontSize: 11, color: Colors.grey)) : null,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProductDetailsPage(
                  product: Product(
                    title: item['title'] ?? '',
                    price: priceStr.isNotEmpty ? priceStr : (item['price']?.toString() ?? '0'),
                    image: imgUrl,
                    tag: item['tag'] ?? 'Popular',
                    rating: item['rating']?.toString() ?? '4.9',
                    discount: item['discount'] ?? '',
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
