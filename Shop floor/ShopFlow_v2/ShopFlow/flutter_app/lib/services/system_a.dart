// System A — buyer subsystem.
//
// Owns authentication, user profiles, carts, orders and tag activity. It calls
// into System B only where a purchase must decrement inventory.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/cart_item.dart';
import 'system_b.dart';

/// System A owns buyer profiles, buyer carts, and finalized order records.
///
/// It never writes inventory data directly: every inventory read goes through
/// the [SystemB] interface.
class SystemA {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SystemB _inventory = SystemB();

  CollectionReference<Map<String, dynamic>> get _buyers =>
      _firestore.collection('system_a_users');

  CollectionReference<Map<String, dynamic>> get _orders =>
      _firestore.collection('system_a_orders');

  Future<void> createBuyerAccount(
      String userId, String name, String email) async {
    await _buyers.doc(userId).set({
      'uid': userId,
      'name': name,
      'email': email,
      'role': 'buyer',
      'cart_items': <Map<String, dynamic>>[],
      'viewed_tags': <String>[],
    });
  }

  Future<Map<String, dynamic>?> getRegistryProfile(String userId) async =>
      (await _buyers.doc(userId).get()).data();

  Future<void> persistCartState(String userId, List<CartItem> items) async {
    await _buyers.doc(userId).set(
      {'cart_items': items.map((item) => item.toJson()).toList()},
      SetOptions(merge: true),
    );
  }

  /// Creates the final order record in System A.
  Future<Map<String, dynamic>> finalizeOrderRecord({
    required String orderId,
    required String userId,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
  }) async {
    final now = DateTime.now();
    final order = {
      'orderId': orderId,
      'userId': userId,
      'items': items,
      'totalAmount': totalAmount,
      'createdAt': now.toIso8601String(),
      'arrivalTime': now.add(const Duration(days: 3)).toIso8601String(),
      'status': 'confirmed',
    };
    await _orders.doc(orderId).set(order);
    return order;
  }

  /// Returns the buyer's order history sorted newest-first.
  Future<List<Map<String, dynamic>>> getBuyerLedger(String userId) async {
    final snapshot = await _orders.where('userId', isEqualTo: userId).get();
    return snapshot.docs.map((doc) => doc.data()).toList()
      ..sort((l, r) => _date(r['createdAt']).compareTo(_date(l['createdAt'])));
  }

  /// Requests inventory data from System B through its interface.
  Future<List<Map<String, dynamic>>> requestInventoryData({
    String? tagPath,
  }) async {
    if (tagPath != null && tagPath.isNotEmpty) {
      return _inventory.apiProvideProductsByTag(tagPath);
    }
    return _inventory.apiProvideAllProducts();
  }

  /// Tracks buyer interests using a capped, de-duplicated list of tag paths.
  Future<void> trackTagInterest(String userId, String tag) async {
    final profile = await getRegistryProfile(userId);
    final tags = List<String>.from(profile?['viewed_tags'] as List? ?? const [])
      ..remove(tag)
      ..insert(0, tag);
    await _buyers.doc(userId).set(
      {'viewed_tags': tags.take(12).toList()},
      SetOptions(merge: true),
    );
  }

  /// Administrative utility: deletes all System A data and the current account.
  Future<void> authorizeGlobalWipe() async {
    for (final collection in ['system_a_users', 'system_a_orders']) {
      final snapshot = await _firestore.collection(collection).get();
      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) await user.delete();
    await FirebaseAuth.instance.signOut();
  }

  static DateTime _date(dynamic raw) =>
      DateTime.tryParse(raw as String? ?? '') ??
      DateTime.fromMillisecondsSinceEpoch(0);
}
