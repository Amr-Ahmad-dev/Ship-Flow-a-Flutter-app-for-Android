// System B — inventory / seller subsystem.
//
// Owns products, stock levels, prerequisite definitions and submissions, and
// the aggregated seller dashboard figures. It never reads buyer profiles.
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/product.dart';
import '../models/prerequisite_submission.dart';
import '../models/seller_dashboard_summary.dart';

/// All Firestore writes time out so the UI never hangs on a slow connection.
const _kTimeout = Duration(seconds: 15);

Future<T> _guard<T>(Future<T> future) => future.timeout(
      _kTimeout,
      onTimeout: () => throw Exception(
          'Request timed out. Check your connection and try again.'),
    );

/// Reservation request used when reducing stock for a multi-item order.
class InventoryReservation {
  final String productId;
  final int quantity;

  const InventoryReservation({required this.productId, required this.quantity});
}

/// System B owns seller, inventory, sales, and prerequisite-review data.
///
/// The `api*` methods form the interface System A is allowed to call.
class SystemB {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _sellers =>
      _firestore.collection('system_b_sellers');

  CollectionReference<Map<String, dynamic>> get _products =>
      _firestore.collection('system_b_products');

  CollectionReference<Map<String, dynamic>> get _sales =>
      _firestore.collection('system_b_sales');

  CollectionReference<Map<String, dynamic>> get _submissions =>
      _firestore.collection('system_b_prerequisite_submissions');

  // --- Sellers -------------------------------------------------------------

  Future<void> createSellerAccount(
      String userId, String name, String email) async {
    await _guard(_sellers.doc(userId).set({
      'uid': userId,
      'name': name,
      'email': email,
      'role': 'seller',
    }));
  }

  Future<Map<String, dynamic>?> getSellerRegistryEntry(String userId) async =>
      (await _sellers.doc(userId).get()).data();

  // --- Inventory -----------------------------------------------------------

  Future<void> addProduct({
    required String sellerId,
    required String name,
    required String description,
    required double price,
    required int quantity,
    required String tagPath,
    required String imageUrl,
    required String expiryDate,
    required bool requiresApproval,
  }) async {
    final productId = 'P_${DateTime.now().millisecondsSinceEpoch}';
    await _guard(_products.doc(productId).set({
      'productId': productId,
      'sellerId': sellerId,
      'name': name,
      'description': description,
      'price': price,
      'quantity': quantity,
      'tagPath': tagPath,
      'tags': _splitTagPath(tagPath),
      'imageUrl': imageUrl,
      'expiryDate': expiryDate,
      'requiresApproval': requiresApproval,
      'ratings': <int>[],
    }));
  }

  Future<void> updateExistingStock(String productId, int quantityToAdd) async {
    await _guard(_products
        .doc(productId)
        .update({'quantity': FieldValue.increment(quantityToAdd)}));
  }

  Future<void> submitRating(String productId, int score) async {
    await _guard(_products.doc(productId).update({
      'ratings': FieldValue.arrayUnion([score]),
    }));
  }

  Future<bool> verifyStock(String productId, int quantity) async {
    final product = await apiProvideProductDetail(productId);
    return ((product?['quantity'] as num?)?.toInt() ?? 0) >= quantity;
  }

  /// Reserves stock for every item in an order inside one transaction.
  Future<void> reserveInventoryForOrder(
      List<InventoryReservation> reservations) async {
    await _guard(_firestore.runTransaction((transaction) async {
      for (final r in reservations) {
        final snapshot = await transaction.get(_products.doc(r.productId));
        final available = (snapshot.data()?['quantity'] as num?)?.toInt() ?? 0;
        if (available < r.quantity) {
          throw StateError('Not enough stock for ${r.productId}');
        }
      }
      for (final r in reservations) {
        transaction.update(_products.doc(r.productId), {
          'quantity': FieldValue.increment(-r.quantity),
        });
      }
    }));
  }

  // --- Interface exposed to System A --------------------------------------

  Future<List<Map<String, dynamic>>> apiProvideAllProducts() async =>
      (await _products.get()).docs.map(_withId).toList();

  Future<Map<String, dynamic>?> apiProvideProductDetail(
      String productId) async {
    final document = await _products.doc(productId).get();
    return document.exists ? _withId(document) : null;
  }

  Future<List<Map<String, dynamic>>> apiProvideProductsByTag(
      String tagPath) async {
    final all = await apiProvideAllProducts();
    return all
        .where((p) => (p['tagPath'] as String? ?? '').startsWith(tagPath))
        .toList();
  }

  // --- Sales ---------------------------------------------------------------

  /// Stores a seller-safe sales record. `buyerId` is required by the rules.
  Future<void> logExternalSale({
    required String buyerId,
    required String sellerId,
    required String orderId,
    required String productId,
    required String productName,
    required int quantity,
    required double totalAmount,
  }) async {
    await _guard(_sales.add({
      'buyerId': buyerId,
      'sellerId': sellerId,
      'orderId': orderId,
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'totalAmount': totalAmount,
      'soldAt': DateTime.now().toIso8601String(),
    }));
  }

  Future<List<SellerOrderLine>> getSalesForSeller(String sellerId) async {
    final snapshot = await _sales.where('sellerId', isEqualTo: sellerId).get();
    return snapshot.docs.map((d) => SellerOrderLine.fromJson(d.data())).toList()
      ..sort((a, b) => b.soldAt.compareTo(a.soldAt));
  }

  Future<List<Product>> getProductsForSeller(String sellerId) async {
    final snapshot =
        await _products.where('sellerId', isEqualTo: sellerId).get();
    return snapshot.docs.map((d) => Product.fromJson(_withId(d))).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  // --- Prerequisite submissions -------------------------------------------

  Future<PrerequisiteSubmission> createPrerequisiteSubmission({
    required String productId,
    required String productName,
    required String sellerId,
    required String buyerId,
    required String fileName,
    required String fileExtension,
    required String contentType,
    required int fileSizeInBytes,
    required String storagePath,
    required String downloadUrl,
  }) async {
    final payload = {
      'productId': productId,
      'productName': productName,
      'sellerId': sellerId,
      'buyerId': buyerId,
      'status': 'pending',
      'fileName': fileName,
      'fileExtension': fileExtension,
      'contentType': contentType,
      'fileSizeInBytes': fileSizeInBytes,
      'storagePath': storagePath,
      'downloadUrl': downloadUrl,
      'submittedAt': DateTime.now().toIso8601String(),
      'reviewedAt': null,
      'rejectionMessage': null,
    };
    final reference = await _guard(_submissions.add(payload));
    return PrerequisiteSubmission.fromJson({
      ...payload,
      'submissionId': reference.id,
    });
  }

  Future<List<PrerequisiteSubmission>> getPendingPrerequisiteSubmissions(
          String sellerId) =>
      _querySubmissions(_submissions
          .where('sellerId', isEqualTo: sellerId)
          .where('status', isEqualTo: 'pending'));

  Future<List<PrerequisiteSubmission>> getBuyerSubmissions(String buyerId) =>
      _querySubmissions(_submissions.where('buyerId', isEqualTo: buyerId));

  Future<PrerequisiteSubmission?> getLatestBuyerSubmissionForProduct(
      String buyerId, String productId) async {
    final submissions = await _querySubmissions(_submissions
        .where('buyerId', isEqualTo: buyerId)
        .where('productId', isEqualTo: productId));
    return submissions.isEmpty ? null : submissions.first;
  }

  Future<void> resolvePrerequisiteSubmission({
    required String submissionId,
    required bool isAccepted,
    String? rejectionMessage,
  }) async {
    await _guard(_submissions.doc(submissionId).set({
      'status': isAccepted ? 'accepted' : 'rejected',
      'reviewedAt': DateTime.now().toIso8601String(),
      'rejectionMessage': isAccepted ? null : rejectionMessage?.trim(),
    }, SetOptions(merge: true)));
  }

  /// Administrative utility: deletes all System B data.
  Future<void> authorizeInventoryWipe() async {
    for (final collection in [
      'system_b_products',
      'system_b_sellers',
      'system_b_sales',
      'system_b_prerequisite_submissions',
    ]) {
      final snapshot = await _firestore.collection(collection).get();
      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }
    }
  }

  // --- Helpers -------------------------------------------------------------

  Future<List<PrerequisiteSubmission>> _querySubmissions(Query query) async {
    final snapshot = await query.get();
    return snapshot.docs
        .map((d) => PrerequisiteSubmission.fromJson({
              ...d.data() as Map<String, dynamic>,
              'submissionId': d.id,
            }))
        .toList()
      ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
  }

  static Map<String, dynamic> _withId(
      DocumentSnapshot<Map<String, dynamic>> document) {
    return {...?document.data(), 'productId': document.id};
  }

  static List<String> _splitTagPath(String tagPath) => tagPath
      .split('/')
      .map((segment) => segment.trim())
      .where((segment) => segment.isNotEmpty)
      .toList();
}
