import '../utils/size_pricing.dart';

class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final double rating;
  final String category;
  final bool isAvailable;
  final bool isArchived;

  int priceForSize(String size) => SizePricing.price(price, size);

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.rating,
    required this.category,
    this.isAvailable = true,
    this.isArchived = false,
  });

  Map<String, dynamic> toMap() {
    if (!price.isFinite || price <= 0 || price != price.roundToDouble()) {
      throw ArgumentError.value(
        price,
        'price',
        'Positive whole VND price required',
      );
    }
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price.toInt(),
      'imageUrl': imageUrl,
      'imageURL': imageUrl, // Include both for compatibility
      'rating': rating,
      'category': category,
      'isAvailable': isAvailable,
      'isArchived': isArchived,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map, String documentId) {
    return Product(
      id: documentId,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      imageUrl: map['imageUrl'] ?? map['imageURL'] ?? '',
      rating: (map['rating'] ?? 0).toDouble(),
      category: map['category'] ?? map['type'] ?? '', // Backward compatibility
      isAvailable: map['isAvailable'] ?? true,
      isArchived: map['isArchived'] == true,
    );
  }
}
