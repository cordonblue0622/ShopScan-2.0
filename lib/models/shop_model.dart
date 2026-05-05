class ShopModel {
  final String id;
  final String name;
  final String address;
  final String phone;
  final String ownerId;
  final DateTime createdAt;
  final bool isActive;

  ShopModel({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    required this.ownerId,
    required this.createdAt,
    this.isActive = true,
  });

  // Convert to JSON
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'address': address,
    'phone': phone,
    'ownerId': ownerId,
    'createdAt': createdAt.toIso8601String(),
    'isActive': isActive,
  };

  // Create from JSON
  factory ShopModel.fromJson(Map<String, dynamic> json, String docId) {
    return ShopModel(
      id: docId,
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      phone: json['phone'] ?? '',
      ownerId: json['ownerId'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      isActive: json['isActive'] ?? true,
    );
  }

  // Copy with changes
  ShopModel copyWith({
    String? id,
    String? name,
    String? address,
    String? phone,
    String? ownerId,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return ShopModel(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      ownerId: ownerId ?? this.ownerId,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }
}
