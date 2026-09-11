class Product {
  final String title;
  final String price;
  final String image;
  final String tag;
  final String rating;
  final String discount;
  final String? description;
  final String? slogan; // Added
  final String? modelUrl;
  final String? iosModelUrl;

  Product({
    required this.title,
    required this.price,
    required this.image,
    required this.tag,
    required this.rating,
    this.discount = '',
    this.description,
    this.slogan,
    this.modelUrl,
    this.iosModelUrl,
  });
}
