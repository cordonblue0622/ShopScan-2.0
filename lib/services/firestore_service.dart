import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/approval_request_model.dart';
import '../models/product_model.dart';
import '../models/shop_model.dart';
import '../models/transaction_model.dart';
import '../models/shift_model.dart';
import '../models/user_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<String> _barcodeLookupCandidates(String barcode) {
    final trimmed = barcode.trim();
    if (trimmed.isEmpty) {
      return const <String>[];
    }

    final compact = trimmed.replaceAll(RegExp(r'\s+'), '');
    final digitsOnly = compact.replaceAll(RegExp(r'[^0-9]'), '');

    final candidates = <String>{trimmed, compact};

    if (digitsOnly.isNotEmpty) {
      candidates.add(digitsOnly);

      if (digitsOnly.length == 12) {
        candidates.add('0$digitsOnly');
      }

      if (digitsOnly.length == 13 && digitsOnly.startsWith('0')) {
        candidates.add(digitsOnly.substring(1));
      }
    }

    return candidates.where((candidate) => candidate.isNotEmpty).toList();
  }

  bool _hasShopScope(String? shopId) {
    return shopId != null && shopId.isNotEmpty;
  }

  bool _matchesExactShopScope(String? recordShopId, String? requestedShopId) {
    if (!_hasShopScope(requestedShopId)) {
      return false;
    }
    return recordShopId != null && recordShopId == requestedShopId;
  }

  bool _matchesShopScope(String? recordShopId, String? requestedShopId) {
    if (requestedShopId == null || requestedShopId.isEmpty) {
      return true;
    }
    return recordShopId == null || recordShopId == requestedShopId;
  }

  // ==================== PRODUCTS ====================

  // Get all products
  Stream<List<ProductModel>> getProductsStream({String? shopId}) {
    if (!_hasShopScope(shopId)) {
      return Stream.value(const <ProductModel>[]);
    }

    return _firestore
        .collection('products')
        .where('shopId', isEqualTo: shopId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ProductModel.fromJson(doc.data(), doc.id))
              .where((product) => product.isActive)
              .toList(),
        );
  }

  // Get product by ID
  Future<ProductModel?> getProductById(String productId, {String? shopId}) async {
    if (!_hasShopScope(shopId)) {
      return null;
    }

    try {
      final doc = await _firestore.collection('products').doc(productId).get();
      if (doc.exists) {
        final product = ProductModel.fromJson(doc.data()!, doc.id);
        if (product.isActive &&
            _matchesExactShopScope(product.shopId, shopId)) {
          return product;
        }
      }
      return null;
    } catch (e) {
      throw Exception('Failed to fetch product: $e');
    }
  }

  // Get product by barcode
  Future<ProductModel?> getProductByBarcode(String barcode,
      {String? shopId}) async {
    if (!_hasShopScope(shopId)) {
      return null;
    }

    try {
      final candidates = _barcodeLookupCandidates(barcode);
      if (candidates.isEmpty) {
        return null;
      }

      for (final field in const <String>['barcode', 'sku']) {
        final query = candidates.length == 1
            ? await _firestore
                .collection('products')
                .where(field, isEqualTo: candidates.first)
                .get()
            : await _firestore
                .collection('products')
                .where(field, whereIn: candidates)
                .get();

        if (query.docs.isEmpty) {
          continue;
        }

        final products = query.docs
            .map((doc) => ProductModel.fromJson(doc.data(), doc.id))
            .where((product) =>
                product.isActive &&
                _matchesExactShopScope(product.shopId, shopId))
            .toList();

        if (products.isNotEmpty) {
          return products.first;
        }
      }

      return null;
    } catch (e) {
      throw Exception('Failed to fetch product by barcode: $e');
    }
  }

  // Create product
  Future<String> createProduct(ProductModel product) async {
    if (!_hasShopScope(product.shopId)) {
      throw Exception('Products must be assigned to a shop.');
    }

    try {
      final docRef =
          await _firestore.collection('products').add(product.toJson());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create product: $e');
    }
  }

  // Update product
  Future<void> updateProduct(String productId, ProductModel product) async {
    if (!_hasShopScope(product.shopId)) {
      throw Exception('Products must stay assigned to a shop.');
    }

    final existing = await getProductById(productId, shopId: product.shopId);
    if (existing == null) {
      throw Exception('Product not found for this shop.');
    }

    try {
      await _firestore
          .collection('products')
          .doc(productId)
          .update(product.toJson());
    } catch (e) {
      throw Exception('Failed to update product: $e');
    }
  }

  // Update product stock
  Future<void> updateProductStock(String productId, int newStock,
      {String? shopId}) async {
    final existing = await getProductById(productId, shopId: shopId);
    if (existing == null) {
      throw Exception('Product not found for this shop.');
    }

    try {
      await _firestore.collection('products').doc(productId).update({
        'stock': newStock,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to update stock: $e');
    }
  }

  // Delete product (soft delete)
  Future<void> deleteProduct(String productId, {String? shopId}) async {
    final existing = await getProductById(productId, shopId: shopId);
    if (existing == null) {
      throw Exception('Product not found for this shop.');
    }

    try {
      await _firestore.collection('products').doc(productId).update({
        'isActive': false,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to delete product: $e');
    }
  }

  // Search products
  Future<List<ProductModel>> searchProducts(String query,
      {String? shopId}) async {
    if (!_hasShopScope(shopId)) {
      return [];
    }

    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return [];
    }

    try {
      final snapshot = await _firestore
          .collection('products')
          .where('shopId', isEqualTo: shopId)
          .get();

      final products = snapshot.docs
          .map((doc) => ProductModel.fromJson(doc.data(), doc.id))
          .where((product) => product.isActive)
          .toList();

      return products
          .where((product) =>
              product.name.toLowerCase().contains(normalizedQuery) ||
              product.category.toLowerCase().contains(normalizedQuery) ||
              product.barcode.toLowerCase().contains(normalizedQuery))
          .toList();
    } catch (e) {
      throw Exception('Failed to search products: $e');
    }
  }

  // Create transaction
  Future<String> createTransaction(TransactionModel transaction) async {
    try {
      final docId = transaction.id.trim().isNotEmpty
          ? transaction.id
          : _firestore.collection('transactions').doc().id;
      final payload = transaction.copyWith(id: docId).toJson();

      await _firestore.collection('transactions').doc(docId).set(payload);
      return docId;
    } catch (e) {
      throw Exception('Failed to create transaction: $e');
    }
  }

  // Get transaction by ID
  Future<TransactionModel?> getTransactionById(String transactionId) async {
    try {
      final doc =
          await _firestore.collection('transactions').doc(transactionId).get();

      if (doc.exists && doc.data() != null) {
        return TransactionModel.fromJson(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to fetch transaction: $e');
    }
  }

  // Get transactions by cashier
  Stream<List<TransactionModel>> getTransactionsByCashierStream(
    String cashierId, {
    String? shopId,
  }) {
    return _firestore
        .collection('transactions')
        .where('cashierId', isEqualTo: cashierId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => TransactionModel.fromJson(doc.data(), doc.id))
              .where((transaction) =>
                  _matchesShopScope(transaction.shopId, shopId))
              .toList(),
        );
  }

  // Get transactions by date range
  Future<List<TransactionModel>> getTransactionsByDateRange(
      DateTime startDate, DateTime endDate) async {
    try {
      final query = await _firestore
          .collection('transactions')
          .where('timestamp', isGreaterThanOrEqualTo: startDate)
          .where('timestamp', isLessThanOrEqualTo: endDate)
          .orderBy('timestamp', descending: true)
          .get();

      return query.docs
          .map((doc) => TransactionModel.fromJson(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch transactions: $e');
    }
  }

  // Update transaction
  Future<void> updateTransaction(
      String transactionId, TransactionModel transaction) async {
    try {
      await _firestore
          .collection('transactions')
          .doc(transactionId)
          .update(transaction.toJson());
    } catch (e) {
      throw Exception('Failed to update transaction: $e');
    }
  }

  // ==================== SHIFTS ====================

  // Create shift
  Future<String> createShift(ShiftModel shift) async {
    try {
      final docRef = await _firestore.collection('shifts').add(shift.toJson());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create shift: $e');
    }
  }

  // Get active shift for cashier
  Future<ShiftModel?> getActiveShiftForCashier(String cashierId) async {
    try {
      final query = await _firestore
          .collection('shifts')
          .where('cashierId', isEqualTo: cashierId)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return ShiftModel.fromJson(query.docs[0].data(), query.docs[0].id);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to fetch active shift: $e');
    }
  }

  // Get shift by ID
  Future<ShiftModel?> getShiftById(String shiftId) async {
    try {
      final doc = await _firestore.collection('shifts').doc(shiftId).get();
      if (doc.exists) {
        return ShiftModel.fromJson(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to fetch shift: $e');
    }
  }

  // Get shifts by cashier
  Stream<List<ShiftModel>> getShiftsByCashierStream(String cashierId) {
    return _firestore
        .collection('shifts')
        .where('cashierId', isEqualTo: cashierId)
        .orderBy('startTime', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ShiftModel.fromJson(doc.data(), doc.id))
              .toList(),
        );
  }

  // Update shift
  Future<void> updateShift(String shiftId, ShiftModel shift) async {
    try {
      await _firestore.collection('shifts').doc(shiftId).update(shift.toJson());
    } catch (e) {
      throw Exception('Failed to update shift: $e');
    }
  }

  // End shift
  Future<void> endShift(String shiftId, DateTime endTime) async {
    try {
      await _firestore.collection('shifts').doc(shiftId).update({
        'endTime': endTime.toIso8601String(),
        'status': 'completed',
      });
    } catch (e) {
      throw Exception('Failed to end shift: $e');
    }
  }

  // Get all shifts
  Stream<List<ShiftModel>> getAllShiftsStream() {
    return _firestore
        .collection('shifts')
        .orderBy('startTime', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ShiftModel.fromJson(doc.data(), doc.id))
              .toList(),
        );
  }

  // Get shifts stream (alias for getAllShiftsStream)
  Stream<List<ShiftModel>> getShiftsStream() {
    return getAllShiftsStream();
  }

  // Save shift (create or update)
  Future<void> saveShift(ShiftModel shift) async {
    try {
      if (shift.id.isEmpty || shift.id == DateTime.now().toString()) {
        // Create new shift
        await _firestore.collection('shifts').add(shift.toJson());
      } else {
        // Update existing shift
        await _firestore
            .collection('shifts')
            .doc(shift.id)
            .update(shift.toJson());
      }
    } catch (e) {
      throw Exception('Failed to save shift: $e');
    }
  }

  // ==================== TRANSACTIONS ====================

  // Get all transactions stream
  Stream<List<TransactionModel>> getTransactionsStream({String? shopId}) {
    return _firestore
        .collection('transactions')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => TransactionModel.fromJson(doc.data(), doc.id))
              .where((transaction) =>
                  _matchesShopScope(transaction.shopId, shopId))
              .toList(),
        );
  }

  // ==================== USERS ====================

  // Get all users stream
  Stream<List<UserModel>> getUsersStream() {
    return _firestore.collection('users').snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => UserModel.fromJson(doc.data(), doc.id))
              .toList(),
        );
  }

  // Get user by ID
  Future<UserModel?> getUserById(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return UserModel.fromJson(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to fetch user: $e');
    }
  }

  // Create user
  Future<String> createUser(UserModel user) async {
    try {
      final docRef = await _firestore.collection('users').add(user.toJson());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create user: $e');
    }
  }

  // Update user
  Future<void> updateUser(String userId, UserModel user) async {
    try {
      await _firestore.collection('users').doc(userId).update(user.toJson());
    } catch (e) {
      throw Exception('Failed to update user: $e');
    }
  }

  // ==================== SHOPS ====================

  Stream<ShopModel?> getShopByOwnerStream(String ownerId) {
    return _firestore
        .collection('shops')
        .where('ownerId', isEqualTo: ownerId)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) {
        return null;
      }
      final doc = snapshot.docs.first;
      return ShopModel.fromJson(doc.data(), doc.id);
    });
  }

  Stream<ShopModel?> getShopByIdStream(String shopId) {
    return _firestore.collection('shops').doc(shopId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) {
        return null;
      }
      return ShopModel.fromJson(doc.data()!, doc.id);
    });
  }

  Future<void> saveShopForOwner({
    required String ownerId,
    required String name, required String address, required String phone, String? shopId,
  }) async {
    try {
      String targetShopId = shopId ?? '';
      DateTime createdAt = DateTime.now();

      if (targetShopId.isEmpty) {
        final query = await _firestore
            .collection('shops')
            .where('ownerId', isEqualTo: ownerId)
            .limit(1)
            .get();

        if (query.docs.isNotEmpty) {
          final doc = query.docs.first;
          targetShopId = doc.id;
          createdAt = ShopModel.fromJson(doc.data(), doc.id).createdAt;
        } else {
          targetShopId = ownerId;
        }
      } else {
        final doc =
            await _firestore.collection('shops').doc(targetShopId).get();
        if (doc.exists) {
          createdAt = ShopModel.fromJson(doc.data()!, doc.id).createdAt;
        }
      }

      final shop = ShopModel(
        id: targetShopId,
        name: name,
        address: address,
        phone: phone,
        ownerId: ownerId,
        createdAt: createdAt,
      );

      await _firestore
          .collection('shops')
          .doc(targetShopId)
          .set(shop.toJson(), SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to save shop: $e');
    }
  }

  Future<ShopModel?> getShopById(String shopId) async {
    try {
      final doc = await _firestore.collection('shops').doc(shopId).get();
      if (!doc.exists || doc.data() == null) {
        return null;
      }
      return ShopModel.fromJson(doc.data()!, doc.id);
    } catch (e) {
      throw Exception('Failed to fetch shop: $e');
    }
  }

  // ==================== APPROVAL REQUESTS ====================

  Stream<List<ApprovalRequestModel>> getApprovalRequestsForApproverStream(
    String approverId,
  ) {
    return _firestore
        .collection('approval_requests')
        .where('approverId', isEqualTo: approverId)
        .snapshots()
        .map((snapshot) {
      final requests = snapshot.docs
          .map((doc) => ApprovalRequestModel.fromJson(doc.data(), doc.id))
          .toList();
      requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return requests;
    });
  }

  Stream<List<ApprovalRequestModel>> getApprovalRequestsForRequesterStream(
    String requesterId,
  ) {
    return _firestore
        .collection('approval_requests')
        .where('requesterId', isEqualTo: requesterId)
        .snapshots()
        .map((snapshot) {
      final requests = snapshot.docs
          .map((doc) => ApprovalRequestModel.fromJson(doc.data(), doc.id))
          .toList();
      requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return requests;
    });
  }

  Future<bool> hasPendingApprovalRequest({
    required String requesterId,
    required String type,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('approval_requests')
          .where('requesterId', isEqualTo: requesterId)
          .get();

      return snapshot.docs
          .map((doc) => ApprovalRequestModel.fromJson(doc.data(), doc.id))
          .any((request) => request.type == type && request.isPending);
    } catch (e) {
      throw Exception('Failed to check pending requests: $e');
    }
  }

  Future<String> createApprovalRequest(ApprovalRequestModel request) async {
    try {
      final docRef = await _firestore
          .collection('approval_requests')
          .add(request.toJson());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create approval request: $e');
    }
  }

  Future<void> updateApprovalRequestStatus(
    String requestId, {
    required ApprovalRequestStatus status,
    String? resolvedByName,
  }) async {
    try {
      await _firestore.collection('approval_requests').doc(requestId).update({
        'status': status.name,
        'resolvedAt': DateTime.now().toIso8601String(),
        'resolvedByName': resolvedByName,
      });
    } catch (e) {
      throw Exception('Failed to update approval request: $e');
    }
  }
}
