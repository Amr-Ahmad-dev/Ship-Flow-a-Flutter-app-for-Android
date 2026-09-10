// ApiService — the single façade the UI talks to.
//
// It owns session state (current user, role, cart) and orchestrates the two
// backend subsystems:
//   * System A — buyer domain: accounts, cart, orders, activity tags.
//   * System B — inventory domain: products, stock, prerequisites, seller stats.
// The UI never touches Firestore directly; every read/write flows through here
// so cross-system rules (e.g. stock checks before checkout) stay in one place.
import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/cart_item.dart';
import '../models/order.dart';
import '../models/prerequisite_submission.dart';
import '../models/product.dart';
import '../models/seller_dashboard_summary.dart';
import '../models/tag.dart';
import 'submission_upload_service.dart';
import 'system_a.dart';
import 'system_b.dart';

/// Error wrapper used for readable UI-facing messages.
class ApiException implements Exception {
  final String message;

  ApiException(this.message);

  @override
  String toString() => message;
}

/// Main application orchestrator and the only service the UI talks to.
class ApiService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SystemA _buyerSystem = SystemA();
  final SystemB _inventorySystem = SystemB();
  final SubmissionUploadService _uploads = SubmissionUploadService();
  late final StreamSubscription<User?> _authStateSubscription;

  User? _firebaseUser;
  String? _userId;
  String? _displayName;
  bool _hasBothRoles = false;
  bool _isViewingAsSeller = false;
  bool _isDisposed = false;
  final Map<String, CartItem> _cart = {};

  ApiService() {
    _authStateSubscription =
        _auth.authStateChanges().listen(_handleAuthStateChanged);
  }

  bool get isLoggedIn => _firebaseUser != null;
  bool get isSeller => _isViewingAsSeller;
  bool get hasBothRoles => _hasBothRoles;
  String? get displayName => _displayName;
  String? get userId => _userId;
  Map<String, CartItem> get cart => _cart;
  int get cartCount => _cart.values.fold(0, (sum, item) => sum + item.quantity);
  double get cartTotal =>
      _cart.values.fold(0, (sum, item) => sum + item.subtotal);

  void toggleRole() {
    if (!_hasBothRoles) return;
    _isViewingAsSeller = !_isViewingAsSeller;
    _notify();
  }

  Future<void> init() async {
    if (_auth.currentUser == null) return;
    _firebaseUser = _auth.currentUser;
    _userId = _firebaseUser!.uid;
    await _fetchUserProfile();
    _notify();
  }

  // --- Authentication ------------------------------------------------------

  Future<void> register({
    required String displayName,
    required String email,
    required String password,
    required String role,
  }) async {
    await _runAuth('Registration failed.', () async {
      final credentials = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credentials.user!;
      await user.updateDisplayName(displayName.trim());
      await _buyerSystem.createBuyerAccount(
          user.uid, displayName.trim(), email.trim());
      if (role == 'seller') {
        await _inventorySystem.createSellerAccount(
            user.uid, displayName.trim(), email.trim());
      }
      return user;
    });
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    await _runAuth('Login failed. Please try again.', () async {
      final credentials = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return credentials.user!;
    });
  }

  Future<void> logout() async {
    await _auth.signOut();
    _resetSessionState();
    _notify();
  }

  // --- Catalogue -----------------------------------------------------------

  Future<List<Product>> getProducts({String? tagPath, String? query}) async {
    final raw = await _buyerSystem.requestInventoryData(tagPath: tagPath);

    // Stock already reserved in the local cart is hidden from the listing.
    var products = raw.map(Product.fromJson).map((product) {
      final inCart = _cart[product.productId]?.quantity ?? 0;
      return product.copyWith(quantity: max(0, product.quantity - inCart));
    }).toList();

    final normalizedQuery = query?.trim().toLowerCase() ?? '';
    if (normalizedQuery.isNotEmpty) {
      products = products
          .where((p) =>
              p.name.toLowerCase().contains(normalizedQuery) ||
              p.description.toLowerCase().contains(normalizedQuery) ||
              p.tagLabel.toLowerCase().contains(normalizedQuery))
          .toList();
    }

    return products
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  Future<Product> getProductById(String productId) async {
    final data = await _inventorySystem.apiProvideProductDetail(productId);
    if (data == null) throw ApiException('Product not found.');
    return Product.fromJson(data);
  }

  /// Mostly interest-based recommendations with some discovery mixed in.
  Future<List<Product>> getRecommendations() async {
    if (_userId == null) return [];
    final profile = await _buyerSystem.getRegistryProfile(_userId!);
    final viewedTags =
        List<String>.from(profile?['viewed_tags'] as List? ?? const []);
    final all = (await _inventorySystem.apiProvideAllProducts())
        .map(Product.fromJson)
        .toList();
    if (all.isEmpty) return [];

    final relevant =
        all.where((p) => p.tags.any(viewedTags.contains)).toList();
    final discovery =
        all.where((p) => !p.tags.any(viewedTags.contains)).toList();

    final random = Random();
    final recommendations = <Product>[];
    while (recommendations.length < 10 &&
        (relevant.isNotEmpty || discovery.isNotEmpty)) {
      if (relevant.isNotEmpty && random.nextDouble() < 0.8) {
        recommendations.add(relevant.removeAt(random.nextInt(relevant.length)));
      } else if (discovery.isNotEmpty) {
        recommendations
            .add(discovery.removeAt(random.nextInt(discovery.length)));
      }
    }
    return recommendations;
  }

  Future<List<AppTag>> getAllTags() async {
    final counts = <String, int>{};
    for (final product in await _inventorySystem.apiProvideAllProducts()) {
      final tagPath = product['tagPath'] as String? ?? 'General';
      counts[tagPath] = (counts[tagPath] ?? 0) + 1;
    }
    return counts.entries
        .map((entry) => AppTag(
              tagId: entry.key,
              name: entry.key.split('/').last,
              productCount: entry.value,
            ))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  void trackTag(String tag) {
    if (_userId != null && tag.trim().isNotEmpty) {
      _buyerSystem.trackTagInterest(_userId!, tag.trim());
    }
  }

  // --- Cart and orders -----------------------------------------------------

  Future<void> addToCart(Product product, int quantity) async {
    final userId = _requireUserId();
    final hasStock =
        await _inventorySystem.verifyStock(product.productId, quantity);
    if (!hasStock) throw ApiException('Insufficient stock available.');

    _cart[product.productId] = CartItem(
      product: product,
      quantity: (_cart[product.productId]?.quantity ?? 0) + quantity,
    );
    await _persistCurrentCart(userId);
    _notify();
  }

  Future<void> removeFromCart(String productId) async {
    final userId = _requireUserId();
    _cart.remove(productId);
    await _persistCurrentCart(userId);
    _notify();
  }

  /// Creates an order from the current cart:
  /// validates stock, asks System B to reduce it, then records the order.
  Future<AppOrder> createOrder() async {
    final userId = _requireUserId();
    if (_cart.isEmpty) throw ApiException('Your cart is empty.');

    await _syncCartFromSystemA();
    final items = _cart.values.toList(growable: false);

    for (final item in items) {
      final product =
          await _inventorySystem.apiProvideProductDetail(item.product.productId);
      if (product == null) {
        throw ApiException('Product ${item.product.name} no longer exists.');
      }
      if (((product['quantity'] as num?)?.toInt() ?? 0) < item.quantity) {
        throw ApiException('Insufficient stock for ${item.product.name}.');
      }
    }

    try {
      await _inventorySystem.reserveInventoryForOrder(items
          .map((item) => InventoryReservation(
                productId: item.product.productId,
                quantity: item.quantity,
              ))
          .toList());
    } catch (error) {
      throw ApiException('Reduction failed: $error');
    }

    final orderId = 'ORD_${DateTime.now().millisecondsSinceEpoch}';
    final order = await _buyerSystem.finalizeOrderRecord(
      orderId: orderId,
      userId: userId,
      items: items
          .map((item) => {
                'productId': item.product.productId,
                'productName': item.product.name,
                'imageUrl': item.product.imageUrl,
                'quantity': item.quantity,
                'priceAtPurchase': item.product.price,
              })
          .toList(),
      totalAmount: cartTotal,
    );

    for (final item in items) {
      await _inventorySystem.logExternalSale(
        buyerId: userId,
        sellerId: item.product.sellerId ?? 'unknown_seller',
        orderId: orderId,
        productId: item.product.productId,
        productName: item.product.name,
        quantity: item.quantity,
        totalAmount: item.subtotal,
      );
    }

    _cart.clear();
    await _persistCurrentCart(userId);
    _notify();
    return AppOrder.fromJson(order);
  }

  Future<List<AppOrder>> getOrderHistory() async {
    final orders = await _buyerSystem.getBuyerLedger(_requireUserId());
    return orders.map(AppOrder.fromJson).toList();
  }

  Future<void> addRating(String productId, int score) async {
    final history = await getOrderHistory();
    final hasPurchased = history
        .any((order) => order.items.any((i) => i.productId == productId));
    if (!hasPurchased) {
      throw ApiException('You can only rate products you have purchased.');
    }
    await _inventorySystem.submitRating(productId, score);
    _notify();
  }

  // --- Prerequisite submissions -------------------------------------------

  Future<PrerequisiteSubmission> submitProductPrerequisite(
      Product product) async {
    final userId = _requireUserId();
    final UploadedSubmissionFile file;
    try {
      file = await _uploads.pickAndUploadSubmissionFile(
          buyerId: userId, productId: product.productId);
    } catch (_) {
      throw ApiException('The prerequisite file could not be uploaded.');
    }

    return _inventorySystem.createPrerequisiteSubmission(
      productId: product.productId,
      productName: product.name,
      sellerId: product.sellerId ?? '',
      buyerId: userId,
      fileName: file.fileName,
      fileExtension: file.fileExtension,
      contentType: file.contentType,
      fileSizeInBytes: file.fileSizeInBytes,
      storagePath: file.storagePath,
      downloadUrl: file.downloadUrl,
    );
  }

  Future<List<PrerequisiteSubmission>> getBuyerSubmissions() =>
      _inventorySystem.getBuyerSubmissions(_requireUserId());

  Future<PrerequisiteSubmission?> getLatestBuyerSubmissionForProduct(
          String productId) =>
      _inventorySystem.getLatestBuyerSubmissionForProduct(
          _requireUserId(), productId);

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
    _notify();
  }

  // --- Seller ---------------------------------------------------------------

  Future<SellerDashboardSummary> getSellerDashboardSummary() async {
    final sellerId = _requireUserId();
    final products = await _inventorySystem.getProductsForSeller(sellerId);
    final sales = await _inventorySystem.getSalesForSeller(sellerId);
    final pending =
        await _inventorySystem.getPendingPrerequisiteSubmissions(sellerId);

    final salesByProduct = <String, List<SellerOrderLine>>{};
    for (final sale in sales) {
      salesByProduct.putIfAbsent(sale.productId, () => []).add(sale);
    }

    final performances = products.map((product) {
      final productSales = salesByProduct[product.productId] ?? const [];
      return SellerProductPerformance(
        product: product,
        totalSalesQuantity:
            productSales.fold(0, (sum, sale) => sum + sale.quantityPurchased),
        totalSalesValue:
            productSales.fold(0, (sum, sale) => sum + sale.totalPrice),
        orders: productSales,
      );
    }).toList()
      ..sort((a, b) => b.totalSalesValue.compareTo(a.totalSalesValue));

    return SellerDashboardSummary(
      totalRevenue: performances.fold(0, (sum, p) => sum + p.totalSalesValue),
      totalUnitsSold:
          performances.fold(0, (sum, p) => sum + p.totalSalesQuantity),
      totalOrders: sales.length,
      productPerformances: performances,
      pendingSubmissions: pending,
    );
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
    await _inventorySystem.addProduct(
      sellerId: _requireUserId(),
      name: name.trim(),
      description: desc.trim(),
      price: price,
      quantity: quantity,
      tagPath: tagPath.trim(),
      imageUrl: imageUrl.trim(),
      expiryDate: expiry.trim().isEmpty ? 'No expiry date' : expiry.trim(),
      requiresApproval: approval,
    );
    _notify();
  }

  Future<void> addStock({
    required String productId,
    required int quantityToAdd,
  }) async {
    await _inventorySystem.updateExistingStock(productId, quantityToAdd);
    _notify();
  }

  /// Administrative utility used during development only.
  Future<void> deleteAllData() async {
    await _buyerSystem.authorizeGlobalWipe();
    await _inventorySystem.authorizeInventoryWipe();
    _cart.clear();
    _notify();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _authStateSubscription.cancel();
    super.dispose();
  }

  // --- Internals -----------------------------------------------------------

  Future<void> _runAuth(String fallback, Future<User> Function() action) async {
    try {
      final user = await action();
      _firebaseUser = user;
      _userId = user.uid;
      await _fetchUserProfile();
    } on FirebaseAuthException catch (exception) {
      throw ApiException(exception.message ?? 'Authentication failed.');
    } catch (_) {
      throw ApiException(fallback);
    }
  }

  Future<void> _fetchUserProfile() async {
    if (_userId == null) return;
    final buyer = await _buyerSystem.getRegistryProfile(_userId!);
    final seller = await _inventorySystem.getSellerRegistryEntry(_userId!);

    if (seller != null && buyer == null) {
      // Sellers always get a buyer profile so they can shop too.
      await _buyerSystem.createBuyerAccount(
        _userId!,
        seller['name'] as String? ?? 'Seller',
        _firebaseUser?.email ?? '',
      );
    }

    _hasBothRoles = seller != null;
    _isViewingAsSeller = seller != null;
    _displayName =
        (seller?['name'] ?? buyer?['name']) as String? ?? _displayName;

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
    _notify();
  }

  Future<void> _syncCartFromSystemA() async {
    if (_userId == null) return;
    final profile = await _buyerSystem.getRegistryProfile(_userId!);
    final rawItems = profile?['cart_items'];
    _cart.clear();
    if (rawItems is! List) return;

    for (final raw in rawItems) {
      final entry = Map<String, dynamic>.from(raw as Map);
      final productId = entry['productId'] as String;
      final data = await _inventorySystem.apiProvideProductDetail(productId);
      _cart[productId] = CartItem(
        product: Product.fromJson(data ??
            Map<String, dynamic>.from(entry['productSnapshot'] ?? const {})),
        quantity: (entry['quantity'] as num?)?.toInt() ?? 1,
      );
    }
  }

  Future<void> _persistCurrentCart(String userId) =>
      _buyerSystem.persistCartState(userId, _cart.values.toList());

  void _resetSessionState() {
    _firebaseUser = null;
    _userId = null;
    _displayName = null;
    _hasBothRoles = false;
    _isViewingAsSeller = false;
    _cart.clear();
  }

  String _requireUserId() {
    if (_userId == null) throw ApiException('Please sign in.');
    return _userId!;
  }

  void _notify() {
    if (!_isDisposed) notifyListeners();
  }
}
