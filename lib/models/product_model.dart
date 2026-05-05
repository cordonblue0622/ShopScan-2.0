class ProductModel {
  final String id;
  final String? shopId;
  final String name;
  final String barcode;
  final double price;
  final int stock;
  final String category;
  final String? imageUrl;
  final String? description;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProductModel({
    required this.id,
    required this.name, required this.barcode, required this.price, required this.stock, required this.category, required this.createdAt, required this.updatedAt, this.shopId,
    this.imageUrl,
    this.description,
    this.isActive = true,
  });

  // Convert to JSON
  Map<String, dynamic> toJson() => {
        'id': id,
        'shopId': shopId,
        'name': name,
        'barcode': barcode,
        'price': price,
        'stock': stock,
        'category': category,
        'imageUrl': imageUrl,
        'description': description,
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  // Create from JSON
  factory ProductModel.fromJson(Map<String, dynamic> json, String docId) {
    return ProductModel(
      id: docId,
      shopId: json['shopId'],
      name: json['name'] ?? '',
      barcode: json['barcode'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      stock: json['stock'] ?? 0,
      category: json['category'] ?? '',
      imageUrl: json['imageUrl'],
      description: json['description'],
      isActive: json['isActive'] ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
    );
  }

  // Copy with changes
  ProductModel copyWith({
    String? id,
    String? shopId,
    String? name,
    String? barcode,
    double? price,
    int? stock,
    String? category,
    String? imageUrl,
    String? description,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductModel(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      name: name ?? this.name,
      barcode: barcode ?? this.barcode,
      price: price ?? this.price,
      stock: stock ?? this.stock,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Check if product is low on stock
  bool get isLowStock => stock < 10;

  // Check if product is out of stock
  bool get isOutOfStock => stock == 0;
}
