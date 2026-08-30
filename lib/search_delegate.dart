import 'package:flutter/material.dart';
import 'models.dart';
import 'product_details_page.dart';

class MySearchDelegate extends SearchDelegate {
  final List<Map<String, dynamic>> products;
  MySearchDelegate(this.products);

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
    final results = products.where((p) => p['title'].toLowerCase().contains(query.toLowerCase())).toList();
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final item = results[index];
        return ListTile(
          leading: Hero(tag: "search_${item['title']}", child: Image.network(item['image'], width: 50, height: 50, fit: BoxFit.cover)),
          title: Text(item['title']),
          subtitle: Text(item['price']),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProductDetailsPage(
                  product: Product(
                    title: item['title'],
                    price: item['price'],
                    image: item['image'],
                    tag: item['tag'] ?? 'Popular',
                    rating: item['rating'] ?? '4.9',
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
    final suggestions = products.where((p) => p['title'].toLowerCase().contains(query.toLowerCase())).toList();
    return ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final item = suggestions[index];
        return ListTile(
          leading: Image.network(item['image'], width: 40, height: 40, fit: BoxFit.cover),
          title: Text(item['title'], style: const TextStyle(fontSize: 14)),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProductDetailsPage(
                  product: Product(
                    title: item['title'],
                    price: item['price'],
                    image: item['image'],
                    tag: item['tag'] ?? 'Popular',
                    rating: item['rating'] ?? '4.9',
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
