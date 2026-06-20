import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/cart_item.dart';
import 'b.dart';

/// Database adapter for System A.
///
/// This class is intentionally narrow: it only knows how to read and write the
/// buyer-owned collections in Firestore. It does not contain business rules.
class ABIA {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _buyerProfiles =>
      _firestore.collection('system_a_users');

  CollectionReference<Map<String, dynamic>> get _buyerOrders =>
      _firestore.collection('system_a_orders');

  /// Creates or replaces a buyer profile document.
  Future<void> saveBuyer(String userId, Map<String, dynamic> data) async {
    await _buyerProfiles.doc(userId).set(data);
  }

  /// Applies a partial update to an existing buyer profile.
  Future<void> updateBuyer(String userId, Map<String, dynamic> data) async {
    await _buyerProfiles.doc(userId).set(data, SetOptions(merge: true));
  }

  /// Returns a buyer profile if one exists for the given user id.
  Future<Map<String, dynamic>?> fetchBuyer(String userId) async {
    final document = await _buyerProfiles.doc(userId).get();
    return document.data();
  }

  /// Creates or replaces an order document using a stable order id.
  Future<void> createOrder(String orderId, Map<String, dynamic> data) async {
    await _buyerOrders.doc(orderId).set(data);
  }

  /// Returns all orders created by the supplied buyer.
  Future<List<Map<String, dynamic>>> fetchOrders(String userId) async {
    final querySnapshot =
        await _buyerOrders.where('userId', isEqualTo: userId).get();
    return querySnapshot.docs.map((document) => document.data()).toList();
  }

  /// Deletes all buyer and order records, including legacy collections and auth.
  ///
  /// This remains an administrative utility and should never be exposed to
  /// normal users outside controlled development scenarios.
  Future<void> executeRegistryWipe() async {
    final collectionsToWipe = [
      'system_a_users',
      'system_a_orders',
      'users',
      'orders',
    ];

    for (final collectionName in collectionsToWipe) {
      final snapshot = await _firestore.collection(collectionName).get();
      for (final document in snapshot.docs) {
        await document.reference.delete();
      }
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) await user.delete();
    await FirebaseAuth.instance.signOut();
  }
}

/// System A owns buyer profiles, buyer carts, and finalized order records.
class SystemA {
  final ABIA _database = ABIA();
  final SystemB _inventorySystem = SystemB();

  /// Creates the default buyer profile document for a newly registered user.
  Future<void> createBuyerAccount(
    String userId,
    String name,
    String email,
  ) async {
    await _database.saveBuyer(userId, {
      'uid': userId,
      'name': name,
      'email': email,
      'role': 'buyer',
      'emailVerified': false,
      'cart_item_ids': <String>[],
      'cart_items': <Map<String, dynamic>>[],
      'viewed_tags': <String>[],
    });
  }

  /// Persists the current cart shape in the buyer profile.
  ///
  /// We store both the richer `cart_items` payload and the older
  /// `cart_item_ids` list so the upgrade stays backward compatible.
  Future<void> persistCartState(
    String userId,
    List<CartItem> cartItems,
  ) async {
    await _database.updateBuyer(userId, {
      'cart_item_ids':
          cartItems.map((item) => item.product.productId).toList(),
      'cart_items': cartItems.map((item) => item.toJson()).toList(),
    });
  }

  /// Adds or replaces an approved item directly in a buyer cart.
  ///
  /// This is used when a seller accepts a prerequisite submission while the
  /// buyer is offline or using another device.
  Future<void> appendApprovedItemToBuyerCart(
    String buyerId,
    CartItem approvedCartItem,
  ) async {
    final profile = await getRegistryProfile(buyerId);
    final existingItems = _deserializeCartItems(profile?['cart_items']);

    final updatedItems = <CartItem>[];
    var didReplaceExistingItem = false;

    for (final existingItem in existingItems) {
      if (existingItem.product.productId == approvedCartItem.product.productId) {
        updatedItems.add(
          existingItem.copyWith(
            quantity: approvedCartItem.quantity,
            approvedAttachment: approvedCartItem.approvedAttachment,
            product: approvedCartItem.product,
          ),
        );
        didReplaceExistingItem = true;
      } else {
        updatedItems.add(existingItem);
      }
    }

    if (!didReplaceExistingItem) {
      updatedItems.add(approvedCartItem);
    }

    await persistCartState(buyerId, updatedItems);
  }

  /// Creates the final order record in System A.
  Future<Map<String, dynamic>> finalizeOrderRecord({
    required String orderId,
    required String userId,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
  }) async {
    final orderData = {
      'orderId': orderId,
      'userId': userId,
      'items': items,
      'totalAmount': totalAmount,
      'createdAt': DateTime.now().toIso8601String(),
      'arrivalTime':
          DateTime.now().add(const Duration(days: 3)).toIso8601String(),
      'status': 'confirmed',
    };

    await _database.createOrder(orderId, orderData);
    return orderData;
  }

  /// Requests inventory data from System B.
  Future<List<Map<String, dynamic>>> requestInventoryData({
    String? tagPath,
  }) async {
    if (tagPath != null && tagPath.isNotEmpty) {
      return _inventorySystem.apiProvideProductsByTag(tagPath);
    }
    return _inventorySystem.apiProvideAllProducts();
  }

  /// Returns the buyer profile document when it exists.
  Future<Map<String, dynamic>?> getRegistryProfile(String userId) async {
    return _database.fetchBuyer(userId);
  }

  /// Returns the buyer's order history sorted newest-first.
  Future<List<Map<String, dynamic>>> getBuyerLedger(String userId) async {
    final orders = await _database.fetchOrders(userId);
    orders.sort((leftOrder, rightOrder) {
      final leftDate =
          DateTime.tryParse(leftOrder['createdAt'] as String? ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0);
      final rightDate =
          DateTime.tryParse(rightOrder['createdAt'] as String? ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0);
      return rightDate.compareTo(leftDate);
    });
    return orders;
  }

  /// Tracks buyer interests using a capped, de-duplicated list of tag paths.
  Future<void> trackTagInterest(String userId, String tag) async {
    final profile = await getRegistryProfile(userId);
    final existingTags =
        List<String>.from(profile?['viewed_tags'] as List? ?? const []);

    existingTags.remove(tag);
    existingTags.insert(0, tag);

    await _database.updateBuyer(userId, {
      'viewed_tags': existingTags.take(12).toList(),
    });
  }

  /// Marks the buyer email as verified.
  Future<void> verifyUser(String userId, String code) async {
    await _database.updateBuyer(userId, {'emailVerified': true});
  }

  /// Deletes all System A data.
  Future<void> authorizeGlobalWipe() async {
    await _database.executeRegistryWipe();
  }

  /// Rebuilds cart item objects from the stored cart payload.
  List<CartItem> _deserializeCartItems(dynamic rawCartItems) {
    if (rawCartItems is! List) {
      return [];
    }

    return rawCartItems
        .whereType<Map>()
        .map((entry) =>
            CartItem.fromJson(Map<String, dynamic>.from(entry)))
        .toList();
  }
}
