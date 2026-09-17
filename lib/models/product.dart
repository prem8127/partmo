class Product {
  const Product({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.mrp,
    required this.rating,
    required this.stock,
    required this.imageIcon,
    required this.badge,
    required this.description,
    required this.compatibility,
    required this.specs,
    this.imageUrls = const [],
  });

  final String id;
  final String name;
  final String category;
  final double price;
  final double mrp;
  final double rating;
  final int stock;
  final String imageIcon;
  final String badge;
  final String description;
  final List<String> compatibility;
  final Map<String, String> specs;

  /// All uploaded images (first = primary). Falls back to [imageIcon] if empty.
  final List<String> imageUrls;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'price': price,
        'mrp': mrp,
        'rating': rating,
        'stock': stock,
        'imageIcon': imageIcon,
        'badge': badge,
        'description': description,
        'compatibility': compatibility,
        'specs': specs,
        'imageUrls': imageUrls,
      };

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        category: json['category'] as String? ?? '',
        price: (json['price'] as num?)?.toDouble() ?? 0,
        mrp: (json['mrp'] as num?)?.toDouble() ?? 0,
        rating: (json['rating'] as num?)?.toDouble() ?? 0,
        stock: (json['stock'] as num?)?.toInt() ?? 0,
        imageIcon: json['imageIcon'] as String? ?? '',
        badge: json['badge'] as String? ?? '',
        description: json['description'] as String? ?? '',
        compatibility: (json['compatibility'] as List?)
                ?.map((item) => item.toString())
                .toList() ??
            const [],
        specs: (json['specs'] as Map?)?.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            ) ??
            const {},
        imageUrls: (json['imageUrls'] as List?)
                ?.map((item) => item.toString())
                .toList() ??
            const [],
      );

  /// All displayable image URLs, guaranteed non-empty if imageIcon is a URL.
  List<String> get allImages {
    if (imageUrls.isNotEmpty) return imageUrls;
    if (imageIcon.startsWith('http')) return [imageIcon];
    return [];
  }
}
