enum TransactionStatus { pending, completed, cancelled, refunded }

class TransactionItemModel {
  final String productId;
  final String productName;
  final double price;
  final int quantity;
  final String sku;
  final String? imageUrl;

  TransactionItemModel({
    required this.productId,
    required this.productName,
    required this.price,
    required this.quantity,
    required this.sku,
    this.imageUrl,
  });

  double get subtotal => price * quantity;
  double get totalPrice => price * quantity;
  double get unitPrice => price;

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'productName': productName,
        'price': price,
        'quantity': quantity,
        'sku': sku,
        'imageUrl': imageUrl,
      };

  factory TransactionItemModel.fromJson(Map<String, dynamic> json) {
    return TransactionItemModel(
      productId: json['productId'] ?? '',
      productName: json['productName'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      quantity: json['quantity'] ?? 0,
      sku: json['sku'] ?? '',
      imageUrl: json['imageUrl'],
    );
  }

  TransactionItemModel copyWith({
    String? productId,
    String? productName,
    double? price,
    int? quantity,
    String? sku,
    String? imageUrl,
  }) {
    return TransactionItemModel(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      sku: sku ?? this.sku,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}

class TransactionModel {
  final String id;
  final String? shopId;
  final String cashierId;
  final String cashierName;
  final List<TransactionItemModel> items;
  final double subtotal;
  final double tax;
  final double discount;
  final double discountPercent;
  final double total;
  final TransactionStatus status;
  final DateTime timestamp;
  final String paymentMethod;
  final double? amountReceived;
  final double? changeAmount;
  final String? notes;

  TransactionModel({
    required this.id,
    required this.cashierId,
    required this.cashierName,
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.discount,
    required this.total,
    required this.status,
    required this.timestamp,
    required this.paymentMethod,
    this.shopId,
    this.discountPercent = 0,
    this.amountReceived,
    this.changeAmount,
    this.notes,
  });

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);
  DateTime get dateTime => timestamp;

  // Convert to JSON
  Map<String, dynamic> toJson() => {
        'id': id,
        'shopId': shopId,
        'cashierId': cashierId,
        'cashierName': cashierName,
        'items': items.map((item) => item.toJson()).toList(),
        'subtotal': subtotal,
        'tax': tax,
        'discount': discount,
        'discountPercent': discountPercent,
        'total': total,
        'status': status.toString().split('.').last,
        'timestamp': timestamp.toIso8601String(),
        'paymentMethod': paymentMethod,
        'amountReceived': amountReceived,
        'changeAmount': changeAmount,
        'notes': notes,
      };

  // Create from JSON
  factory TransactionModel.fromJson(Map<String, dynamic> json, String docId) {
    return TransactionModel(
      id: (json['id'] as String?)?.trim().isNotEmpty == true
          ? json['id'] as String
          : docId,
      shopId: json['shopId'],
      cashierId: json['cashierId'] ?? '',
      cashierName: json['cashierName'] ?? 'Unknown',
      items: (json['items'] as List?)
              ?.map((item) => TransactionItemModel.fromJson(item))
              .toList() ??
          [],
      subtotal: (json['subtotal'] ?? 0).toDouble(),
      tax: (json['tax'] ?? 0).toDouble(),
      discount: (json['discount'] ?? 0).toDouble(),
      discountPercent: (json['discountPercent'] ?? 0).toDouble(),
      total: (json['total'] ?? 0).toDouble(),
      status: _parseStatus(json['status']),
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      paymentMethod: json['paymentMethod'] ?? 'Cash',
      amountReceived: (json['amountReceived'] as num?)?.toDouble(),
      changeAmount: (json['changeAmount'] as num?)?.toDouble(),
      notes: json['notes'],
    );
  }

  static TransactionStatus _parseStatus(String? status) {
    switch (status) {
      case 'completed':
        return TransactionStatus.completed;
      case 'cancelled':
        return TransactionStatus.cancelled;
      case 'refunded':
        return TransactionStatus.refunded;
      default:
        return TransactionStatus.pending;
    }
  }

  // Copy with changes
  TransactionModel copyWith({
    String? id,
    String? shopId,
    String? cashierId,
    String? cashierName,
    List<TransactionItemModel>? items,
    double? subtotal,
    double? tax,
    double? discount,
    double? discountPercent,
    double? total,
    TransactionStatus? status,
    DateTime? timestamp,
    String? paymentMethod,
    double? amountReceived,
    double? changeAmount,
    String? notes,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      cashierId: cashierId ?? this.cashierId,
      cashierName: cashierName ?? this.cashierName,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      tax: tax ?? this.tax,
      discount: discount ?? this.discount,
      discountPercent: discountPercent ?? this.discountPercent,
      total: total ?? this.total,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      amountReceived: amountReceived ?? this.amountReceived,
      changeAmount: changeAmount ?? this.changeAmount,
      notes: notes ?? this.notes,
    );
  }
}
