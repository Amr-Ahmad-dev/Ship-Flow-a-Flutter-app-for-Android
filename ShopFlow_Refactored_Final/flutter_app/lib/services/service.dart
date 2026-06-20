import 'dart:math';
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/cart_item.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../models/prerequisite_submission.dart';
import '../models/seller_dashboard_summary.dart';
import '../models/tag.dart';
import 'a.dart';
import 'b.dart';
import 'submission_upload_service.dart';

/// Error wrapper used for readable UI-facing messages.
class ApiException implements Exception {
  final String message;

  ApiException(this.message);

  @override
  String toString() => message;
}

/// Tracks which subsystems a user belongs to and which mode the UI can show.
enum UserSystemStatus { none, buyerOnly, sellerOnly, both }

/// Main application orchestrator.
class ApiService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SystemA _buyerSystem = SystemA();
  final SystemB _inventorySystem = SystemB();
  final SubmissionUploadService _submissionUploadService =
      SubmissionUploadService();
  late final StreamSubscription<User?> _authStateSubscription;

  User? _firebaseUser;
  String? _userId;
  String? _displayName;
  UserSystemStatus _status = UserSystemStatus.none;
  bool _isViewingAsSeller = false;
  String? _systemErrorMessage;
  final Map<String, CartItem> _cart = {};
  bool _isDisposed = false;

  ApiService() {
    _authStateSubscription = _auth.authStateChanges().listen(_handleAuthStateChanged);
  }

  bool get isAuthenticated => _firebaseUser != null;
  bool get isLoggedIn => _firebaseUser != null;
  bool get isSeller => _isViewingAsSeller;
  bool get hasBothRoles => _status == UserSystemStatus.both;
  String? get systemErrorMessage => _systemErrorMessage;
  String? get displayName => _displayName;
  String? get userId => _userId;
  Map<String, CartItem> get cart => _cart;
  int get cartCount => _cart.values.fold(0, (sum, item) => sum + item.quantity);
  double get cartTotal => _cart.values.fold(0, (sum, item) => sum + item.subtotal);

  void toggleRole() {
    if (!hasBothRoles) return;
    _isViewingAsSeller = !_isViewingAsSeller;
    _safeNotifyListeners();
  }

  Future<void> init() async {
    if (_auth.currentUser == null) return;
    _firebaseUser = _auth.currentUser;
    _userId = _auth.currentUser!.uid;
    await _fetchUserProfile();
    _safeNotifyListeners();
  }

  Future<void> register({
    required String displayName,
    required String email,
    required String password,
    required String role,
  }) async {
    try {
      final credentials = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      await credentials.user?.updateDisplayName(displayName.trim());
      await _buyerSystem.createBuyerAccount(
        credentials.user!.uid,
        displayName.trim(),
        email.trim(),
      );

      if (role == 'seller') {
        await _inventorySystem.createSellerAccount(
          credentials.user!.uid,
          displayName.trim(),
          email.trim(),
        );
      }

      _firebaseUser = credentials.user;
      _userId = credentials.user!.uid;
      await _fetchUserProfile();
    } on FirebaseAuthException catch (exception) {
      throw ApiException(_readableAuthError(exception));
    } catch (error) {
      throw ApiException('Registration failed: $error');
    }
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    try {
      final credentials = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      _firebaseUser = credentials.user;
      _userId = credentials.user!.uid;
      await _fetchUserProfile();
    } on FirebaseAuthException catch (exception) {
      throw ApiException(_readableAuthError(exception));
    } catch (_) {
      throw ApiException('Login failed. Please try again.');
    }
  }

  Future<List<Product>> getProducts({String? tagPath, String? query}) async {
    final rawProducts = await _buyerSystem.requestInventoryData(tagPath: tagPath);
    var products = rawProducts.map(Product.fromJson).toList();

    products = products.map((product) {
      final quantityAlreadyInCart = _cart[product.productId]?.quantity ?? 0;
      final visibleQuantity = max(0, product.quantity - quantityAlreadyInCart);
      return product.copyWith(quantity: visibleQuantity);
    }).toList();

    if (query != null && query.trim().isNotEmpty) {
      final normalizedQuery = query.trim().toLowerCase();
      products = products.where((product) {
        return product.name.toLowerCase().contains(normalizedQuery) ||
            product.description.toLowerCase().contains(normalizedQuery) ||
            product.tagLabel.toLowerCase().contains(normalizedQuery);
      }).toList();
    }

    products.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return products;
  }

  Future<List<Product>> getRecommendations() async {
    if (_userId == null) return [];
    final buyerProfile = await _buyerSystem.getRegistryProfile(_userId!);
    final buyerTags = List<String>.from(buyerProfile?['viewed_tags'] as List? ?? const []);
    final allProducts = (await _inventorySystem.apiProvideAllProducts()).map(Product.fromJson).toList();

    if (allProducts.isEmpty) return [];

    final relevantProducts = allProducts.where((p) => p.tags.any((t) => buyerTags.contains(t))).toList();
    final discoveryProducts = allProducts.where((p) => !p.tags.any((t) => buyerTags.contains(t))).toList();

    final random = Random();
    final recommendations = <Product>[];

    while (recommendations.length < 10 && (relevantProducts.isNotEmpty || discoveryProducts.isNotEmpty)) {
      if (relevantProducts.isNotEmpty && random.nextDouble() < 0.8) {
        recommendations.add(relevantProducts.removeAt(random.nextInt(relevantProducts.length)));
      } else if (discoveryProducts.isNotEmpty) {
        recommendations.add(discoveryProducts.removeAt(random.nextInt(discoveryProducts.length)));
      }
    }
    return recommendations;
  }

  /// Creates an order from the current cart.
  Future<AppOrder> createOrder() async {
    final currentUserId = _requireAuthenticatedUserId();
    if (_cart.isEmpty) throw ApiException('Your cart is empty.');

    await _syncCartFromSystemA();
    final cartItems = _cart.values.toList(growable: false);

    for (final cartItem in cartItems) {
      // 1. Check if product exists in System B
      final productData = await _inventorySystem.apiProvideProductDetail(cartItem.product.productId);
      if (productData == null) {
        throw ApiException('Product ${cartItem.product.name} no longer exists.');
      }

      // 2. Check if stock is sufficient
      final availableStock = (productData['quantity'] as num?)?.toInt() ?? 0;
      if (availableStock < cartItem.quantity) {
        throw ApiException('Insufficient stock for ${cartItem.product.name}.');
      }
    }

    // 3. Hand-off to System B: Reduce stock for all items
    final reservations = cartItems.map((item) => InventoryReservation(
      productId: item.product.productId,
      quantity: item.quantity,
    )).toList();

    try {
      // System B executes the actual database reduction logic
      await _inventorySystem.reserveInventoryForOrder(reservations);
    } catch (error) {
      throw ApiException('Reduction failed: $error');
    }

    // 4. Finalize the order record in System A
    final orderId = 'ORD_${DateTime.now().millisecondsSinceEpoch}';
    final order = await _buyerSystem.finalizeOrderRecord(
      orderId: orderId,
      userId: currentUserId,
      items: cartItems.map(_buildOrderItemPayload).toList(),
      totalAmount: cartTotal,
    );

    for (final cartItem in cartItems) {
      // MODIFIED: Pass buyerId (currentUserId) for rule compliance
      await _inventorySystem.logExternalSale(
        buyerId: currentUserId,
        sellerId: cartItem.product.sellerId ?? 'unknown_seller',
        orderId: orderId,
        productId: cartItem.product.productId,
        productName: cartItem.product.name,
        quantity: cartItem.quantity,
        totalAmount: cartItem.subtotal,
      );
    }

    _cart.clear();
    await _persistCurrentCart();
    _safeNotifyListeners();
    return AppOrder.fromJson(order);
  }

  Future<Product> getProductById(String productId) async {
    final productData = await _inventorySystem.apiProvideProductDetail(productId);
    if (productData == null) throw ApiException('Product not found.');
    return Product.fromJson(productData);
  }

  Future<void> addToCart(Product product, int quantity) async {
    final currentUserId = _requireAuthenticatedUserId();

    final hasEnoughStock = await _inventorySystem.verifyStock(product.productId, quantity);
    if (!hasEnoughStock) throw ApiException('Insufficient stock available.');

    _cart[product.productId] = CartItem(
      product: product,
      quantity: (_cart[product.productId]?.quantity ?? 0) + quantity,
    );

    await _persistCurrentCart(userIdOverride: currentUserId);
    _safeNotifyListeners();
  }

  Future<void> removeFromCart(String productId) async {
    _requireAuthenticatedUserId();
    _cart.remove(productId);
    await _persistCurrentCart();
    _safeNotifyListeners();
  }

  Future<List<AppOrder>> getOrderHistory() async {
    final currentUserId = _requireAuthenticatedUserId();
    final rawOrders = await _buyerSystem.getBuyerLedger(currentUserId);
    return rawOrders.map(AppOrder.fromJson).toList();
  }

  Future<List<AppTag>> getAllTags() async {
    final allProducts = await _inventorySystem.apiProvideAllProducts();
    final counts = <String, int>{};

    for (final product in allProducts) {
      final tagPath = product['tagPath'] as String? ?? 'General';
      counts[tagPath] = (counts[tagPath] ?? 0) + 1;
    }

    return counts.entries.map((e) => AppTag(
      tagId: e.key,
      name: e.key.split('/').last,
      childCount: 0,
      productCount: e.value,
    )).toList()..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  Future<void> addRating(String productId, int score) async {
    final orderHistory = await getOrderHistory();
    final hasPurchased = orderHistory.any((o) => o.items.any((i) => i.productId == productId));
    if (!hasPurchased) throw ApiException('You can only rate products you have purchased.');
    await _inventorySystem.submitRating(productId, score);
    _safeNotifyListeners();
  }

  Future<PrerequisiteSubmission> submitProductPrerequisite(Product product) async {
    final currentUserId = _requireAuthenticatedUserId();
    final uploadedFile = await _pickAndUploadSubmissionFile(buyerId: currentUserId, productId: product.productId);

    return await _inventorySystem.createPrerequisiteSubmission(
      productId: product.productId,
      productName: product.name,
      sellerId: product.sellerId ?? '',
      buyerId: currentUserId,
      fileName: uploadedFile.fileName,
      fileExtension: uploadedFile.fileExtension,
      contentType: uploadedFile.contentType,
      fileSizeInBytes: uploadedFile.fileSizeInBytes,
      storagePath: uploadedFile.storagePath,
      downloadUrl: uploadedFile.downloadUrl,
    );
  }

  Future<List<PrerequisiteSubmission>> getBuyerSubmissions() async {
    final currentUserId = _requireAuthenticatedUserId();
    return _inventorySystem.getBuyerSubmissions(currentUserId);
  }

  Future<PrerequisiteSubmission?> getLatestBuyerSubmissionForProduct(String productId) async {
    final currentUserId = _requireAuthenticatedUserId();
    return _inventorySystem.getLatestBuyerSubmissionForProduct(currentUserId, productId);
  }

  Future<SellerDashboardSummary> getSellerDashboardSummary() async {
    final currentUserId = _requireAuthenticatedUserId();
    final results = await Future.wait([
      _inventorySystem.getProductsForSeller(currentUserId),
      _inventorySystem.getSalesForSeller(currentUserId),
      _inventorySystem.getPendingPrerequisiteSubmissions(currentUserId),
    ]);

    final products = results[0] as List<Product>;
    final sales = results[1] as List<SellerOrderLine>;
    final pendingSubmissions = results[2] as List<PrerequisiteSubmission>;

    final salesByProduct = <String, List<SellerOrderLine>>{};
    for (final sale in sales) {
      salesByProduct.putIfAbsent(sale.productId, () => []).add(sale);
    }

    final performances = products.map((product) {
      final productSales = salesByProduct[product.productId] ?? const [];
      return SellerProductPerformance(
        product: product,
        totalSalesQuantity: productSales.fold(0, (sum, sale) => sum + sale.quantityPurchased),
        totalSalesValue: productSales.fold(0, (sum, sale) => sum + sale.totalPrice),
        orders: productSales,
      );
    }).toList()..sort((a, b) => b.totalSalesValue.compareTo(a.totalSalesValue));

    return SellerDashboardSummary(
      totalRevenue: performances.fold(0, (sum, p) => sum + p.totalSalesValue),
      totalUnitsSold: performances.fold(0, (sum, p) => sum + p.totalSalesQuantity),
      totalOrders: sales.length,
      productPerformances: performances,
      pendingSubmissions: pendingSubmissions,
    );
  }

  Future<void> reviewPrerequisiteSubmission({
    required PrerequisiteSubmission submission,
    required bool isAccepted,
    String? rejectionMessage,
  }) async {
    await _inventorySystem.resolvePrerequisiteSubmission(
      submissionId: submission.submissionId,
      isAccepted: isAccepted,
      rejectionMessage: rejectionMessage,
    );
    _safeNotifyListeners();
  }

  Future<void> addProduct({
    required String name,
    required String desc,
    required double price,
    required int quantity,
    required String tagPath,
    required String imageUrl,
    required String expiry,
    required bool approval,
  }) async {
    final currentUserId = _requireAuthenticatedUserId();
    await _inventorySystem.addProduct(
      sellerId: currentUserId,
      name: name.trim(),
      description: desc.trim(),
      price: price,
      quantity: quantity,
      tagPath: tagPath.trim(),
      imageUrl: imageUrl.trim(),
      expiryDate: expiry.trim().isEmpty ? 'No expiry date' : expiry.trim(),
      requiresApproval: false,
    );
    _safeNotifyListeners();
  }

  Future<void> addStock({required String productId, required int quantityToAdd}) async {
    await _inventorySystem.updateExistingStock(productId, quantityToAdd);
    _safeNotifyListeners();
  }

  Future<void> deleteAllData() async {
    await _buyerSystem.authorizeGlobalWipe();
    await _inventorySystem.authorizeInventoryWipe();
    _cart.clear();
    _safeNotifyListeners();
  }

  Future<void> logout() async {
    await _auth.signOut();
    _resetSessionState();
    _safeNotifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _authStateSubscription.cancel();
    super.dispose();
  }

  void trackActivity(String type, {String? entityId, String? tag}) {
    if (_userId != null && tag != null && tag.trim().isNotEmpty) {
      _buyerSystem.trackTagInterest(_userId!, tag.trim());
    }
  }

  Future<void> verifyEmail({required String userId, required String code}) async {
    await _buyerSystem.verifyUser(userId, code);
  }

  Future<Map<String, dynamic>> resendCode({required String userId}) async {
    return {'verificationCode': '123456'};
  }

  Future<void> _fetchUserProfile() async {
    if (_userId == null) return;
    final buyerProfile = await _buyerSystem.getRegistryProfile(_userId!);
    final sellerProfile = await _inventorySystem.getSellerRegistryEntry(_userId!);

    if (buyerProfile != null && sellerProfile != null) {
      _status = UserSystemStatus.both;
      _isViewingAsSeller = true;
      _displayName = sellerProfile['name'] as String? ?? buyerProfile['name'] as String?;
    } else if (buyerProfile != null) {
      _status = UserSystemStatus.buyerOnly;
      _isViewingAsSeller = false;
      _displayName = buyerProfile['name'] as String?;
    } else if (sellerProfile != null) {
      await _buyerSystem.createBuyerAccount(_userId!, sellerProfile['name'] ?? 'Seller', _firebaseUser?.email ?? '');
      _status = UserSystemStatus.both;
      _isViewingAsSeller = true;
      _displayName = sellerProfile['name'] as String?;
    }
    await _syncCartFromSystemA();
  }

  Future<void> _handleAuthStateChanged(User? user) async {
    if (_isDisposed) return;
    _firebaseUser = user;
    if (user == null) {
      _resetSessionState();
    } else {
      _userId = user.uid;
      await _fetchUserProfile();
    }
    _safeNotifyListeners();
  }

  Future<void> _syncCartFromSystemA() async {
    if (_userId == null) return;
    final profile = await _buyerSystem.getRegistryProfile(_userId!);
    final rawItems = profile?['cart_items'];
    final rebuiltCart = <String, CartItem>{};

    if (rawItems is List && rawItems.isNotEmpty) {
      for (final raw in rawItems) {
        final entry = Map<String, dynamic>.from(raw);
        final productId = entry['productId'] as String;
        final productData = await _inventorySystem.apiProvideProductDetail(productId);
        final product = productData != null ? Product.fromJson(productData) : Product.fromJson(Map<String, dynamic>.from(entry['productSnapshot'] ?? {}));
        rebuiltCart[productId] = CartItem(product: product, quantity: entry['quantity']);
      }
    }
    _cart..clear()..addAll(rebuiltCart);
  }

  Future<void> _persistCurrentCart({String? userIdOverride}) async {
    final targetUserId = userIdOverride ?? _userId;
    if (targetUserId == null) return;
    await _buyerSystem.persistCartState(targetUserId, _cart.values.toList());
  }

  Map<String, dynamic> _buildOrderItemPayload(CartItem item) {
    return {
      'productId': item.product.productId,
      'productName': item.product.name,
      'imageUrl': item.product.imageUrl,
      'quantity': item.quantity,
      'priceAtPurchase': item.product.price,
    };
  }

  void _resetSessionState() {
    _firebaseUser = null; _userId = null; _displayName = null;
    _status = UserSystemStatus.none; _isViewingAsSeller = false;
    _cart.clear();
  }

  String _requireAuthenticatedUserId() {
    if (_userId == null) throw ApiException('Please sign in.');
    return _userId!;
  }

  String _readableAuthError(FirebaseAuthException e) => e.message ?? 'Authentication failed.';

  void _safeNotifyListeners() { if (!_isDisposed) notifyListeners(); }

  Future<UploadedSubmissionFile> _pickAndUploadSubmissionFile({required String buyerId, required String productId}) async {
    try {
      return await _submissionUploadService.pickAndUploadSubmissionFile(buyerId: buyerId, productId: productId);
    } catch (_) {
      throw ApiException('The prerequisite file could not be uploaded.');
    }
  }
}
