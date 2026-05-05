import 'package:flutter/foundation.dart';
import '../../models/transaction_model.dart';

class CartProvider with ChangeNotifier {
  final List<TransactionItemModel> _items = [];
  double _tax = 0;
  double _discount = 0;

  List<TransactionItemModel> get items => _items;
  double get subtotal {
    return _items.fold(0, (sum, item) => sum + item.subtotal);
  }

  double get tax => _tax;
  set tax(double value) {
    _tax = value;
    notifyListeners();
  }

  double get discount => _discount;
  set discount(double value) {
    _discount = value;
    notifyListeners();
  }

  double get total => subtotal + tax - discount;
  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);

  // Add item to cart
  void addItem(TransactionItemModel item) {
    final existingIndex = _items.indexWhere((i) => i.productId == item.productId);

    if (existingIndex >= 0) {
      // Item exists, increase quantity
      final existingItem = _items[existingIndex];
      _items[existingIndex] = TransactionItemModel(
        productId: existingItem.productId,
        productName: existingItem.productName,
        price: existingItem.price,
        quantity: existingItem.quantity + item.quantity,
        sku: existingItem.sku,
        imageUrl: existingItem.imageUrl,
      );
    } else {
      // New item, add to cart
      _items.add(item);
    }

    notifyListeners();
  }

  // Remove item from cart
  void removeItem(String productId) {
    _items.removeWhere((item) => item.productId == productId);
    notifyListeners();
  }

  // Update item quantity
  void updateQuantity(String productId, int quantity) {
    final itemIndex = _items.indexWhere((i) => i.productId == productId);

    if (itemIndex >= 0) {
      if (quantity <= 0) {
        _items.removeAt(itemIndex);
      } else {
        final item = _items[itemIndex];
        _items[itemIndex] = TransactionItemModel(
          productId: item.productId,
          productName: item.productName,
          price: item.price,
          quantity: quantity,
          sku: item.sku,
          imageUrl: item.imageUrl,
        );
      }
      notifyListeners();
    }
  }

  // Clear cart
  void clear() {
    _items.clear();
    _tax = 0;
    _discount = 0;
    notifyListeners();
  }

  // Check if cart is empty
  bool get isEmpty => _items.isEmpty;

  // Get cart as transaction
  TransactionModel toTransaction({
    required String id,
    required String cashierId,
    required String cashierName,
    required String paymentMethod,
    required DateTime timestamp,
  }) {
    return TransactionModel(
      id: id,
      cashierId: cashierId,
      cashierName: cashierName,
      items: _items,
      subtotal: subtotal,
      tax: tax,
      discount: discount,
      total: total,
      status: TransactionStatus.completed,
      timestamp: timestamp,
      paymentMethod: paymentMethod,
    );
  }
}
