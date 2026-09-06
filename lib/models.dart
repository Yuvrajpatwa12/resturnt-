class Product {
  final String title;
  final String price;
  final String image;
  final String tag;
  final String rating;
  final String discount;
  final String? description;
  final String? modelUrl;

  Product({
    required this.title,
    required this.price,
    required this.image,
    required this.tag,
    required this.rating,
    this.discount = '',
    this.description,
    this.modelUrl,
  });
}
