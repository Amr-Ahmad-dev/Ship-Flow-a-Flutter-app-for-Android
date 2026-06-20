import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/product.dart';
import '../models/prerequisite_submission.dart';
import '../models/seller_dashboard_summary.dart';

// All Firestore writes time out after 15 seconds.
// This prevents the UI from hanging forever when Firestore
// is slow, offline, or returns a permission error.
const _kWriteTimeout = Duration(seconds: 15);
const _kTimeoutMessage =
    'Request timed out. Check your connection and try again.';

/// Reservation request used when reducing stock for a multi-item order.
class InventoryReservation {
  final String productId;
  final int quantity;

  const InventoryReservation({
    required this.productId,
    required this.quantity,
  });
}

/// Firestore adapter for System B collections.
class ABIB {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _sellers =>
      _firestore.collection('system_b_sellers');

  CollectionReference<Map<String, dynamic>> get _products =>
      _firestore.collection('system_b_products');

  CollectionReference<Map<String, dynamic>> get _sales =>
      _firestore.collection('system_b_sales');

  CollectionReference<Map<String, dynamic>> get _submissions =>
      _firestore.collection('system_b_prerequisite_submissions');

  /// Creates or replaces a seller profile document.
  Future<void> writeSeller(String userId, Map<String, dynamic> data) async {
    await _sellers.doc(userId).set(data).timeout(
      _kWriteTimeout,
      onTimeout: () => throw Exception(_kTimeoutMessage),
    );
  }

  /// Returns a seller profile if it exists.
  Future<Map<String, dynamic>?> readSeller(String userId) async {
    final document = await _sellers.doc(userId).get();
    return document.data();
  }

  /// Creates or replaces a product document.
  Future<void> writeProduct(
      String productId, Map<String, dynamic> data) async {
    await _products.doc(productId).set(data).timeout(
      _kWriteTimeout,
      onTimeout: () => throw Exception(_kTimeoutMessage),
    );
  }

  /// Applies a partial update to an existing product.
  Future<void> updateProduct(
      String productId,
      Map<String, dynamic> data,
      ) async {
    await _products.doc(productId).update(data).timeout(
      _kWriteTimeout,
      onTimeout: () => throw Exception(_kTimeoutMessage),
    );
  }

  /// Returns the current product document, if one exists.
  Future<Map<String, dynamic>?> readProduct(String productId) async {
    final document = await _products.doc(productId).get();
    final data = document.data();
    if (data != null) {
      data['productId'] = document.id;
    }
    return data;
  }

  /// Returns every product in the inventory collection.
  Future<List<Map<String, dynamic>>> readAllProducts() async {
    final querySnapshot = await _products.get();
    return querySnapshot.docs.map((document) {
      final data = document.data();
      data['productId'] = document.id;
      return data;
    }).toList();
  }

  /// Returns all products owned by the specified seller.
  Future<List<Map<String, dynamic>>> readProductsForSeller(
      String sellerId,
      ) async {
    final querySnapshot =
    await _products.where('sellerId', isEqualTo: sellerId).get();
    return querySnapshot.docs.map((document) {
      final data = document.data();
      data['productId'] = document.id;
      return data;
    }).toList();
  }

  /// Appends a rating score to the product's ratings array.
  Future<void> addRating(String productId, int score) async {
    await _products.doc(productId).update({
      'ratings': FieldValue.arrayUnion([score]),
    }).timeout(
      _kWriteTimeout,
      onTimeout: () => throw Exception(_kTimeoutMessage),
    );
  }

  /// Stores a newly uploaded prerequisite submission and returns its id.
  Future<String> createSubmission(Map<String, dynamic> data) async {
    final documentReference = await _submissions.add(data).timeout(
      _kWriteTimeout,
      onTimeout: () => throw Exception(_kTimeoutMessage),
    );
    return documentReference.id;
  }

  /// Returns all pending prerequisite submissions for a seller.
  Future<List<Map<String, dynamic>>> readPendingSubmissionsForSeller(
      String sellerId,
      ) async {
    final querySnapshot = await _submissions
        .where('sellerId', isEqualTo: sellerId)
        .where('status', isEqualTo: 'pending')
        .get();

    return querySnapshot.docs
        .map((document) => {
      ...document.data(),
      'submissionId': document.id,
    })
        .toList();
  }

  /// Returns all submissions created by a buyer.
  Future<List<Map<String, dynamic>>> readBuyerSubmissions(
      String buyerId) async {
    final querySnapshot =
    await _submissions.where('buyerId', isEqualTo: buyerId).get();

    return querySnapshot.docs
        .map((document) => {
      ...document.data(),
      'submissionId': document.id,
    })
        .toList();
  }

  /// Returns the latest submission for a buyer/product pair, if one exists.
  Future<Map<String, dynamic>?> readLatestBuyerSubmissionForProduct(
      String buyerId,
      String productId,
      ) async {
    final querySnapshot = await _submissions
        .where('buyerId', isEqualTo: buyerId)
        .where('productId', isEqualTo: productId)
        .get();

    if (querySnapshot.docs.isEmpty) return null;

    final documents = querySnapshot.docs.toList()
      ..sort((l, r) {
        final ld = DateTime.tryParse(l.data()['submittedAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final rd = DateTime.tryParse(r.data()['submittedAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return rd.compareTo(ld);
      });

    return {
      ...documents.first.data(),
      'submissionId': documents.first.id,
    };
  }

  /// Updates the review status or metadata of a stored submission.
  Future<void> updateSubmission(
      String submissionId,
      Map<String, dynamic> data,
      ) async {
    await _submissions
        .doc(submissionId)
        .set(data, SetOptions(merge: true))
        .timeout(
      _kWriteTimeout,
      onTimeout: () => throw Exception(_kTimeoutMessage),
    );
  }

  /// Stores a seller-safe sales record.
  /// MODIFIED: MUST include buyerId for rule compliance.
  Future<void> writeSale(Map<String, dynamic> data) async {
    final payload = {
      ...data,
      'buyerId': data['buyerId'], // Ensure buyerId is explicitly part of the document
    };
    await _sales.add(payload).timeout(
      _kWriteTimeout,
      onTimeout: () => throw Exception(_kTimeoutMessage),
    );
  }

  /// Returns all sales associated with a seller.
  Future<List<Map<String, dynamic>>> readSales(String sellerId) async {
    final querySnapshot =
    await _sales.where('sellerId', isEqualTo: sellerId).get();
    return querySnapshot.docs.map((document) => document.data()).toList();
  }

  /// Reserves stock for every item in an order inside one transaction.
  Future<void> reserveInventory(List<InventoryReservation> reservations) async {
    await _firestore.runTransaction((transaction) async {
      final snapshots = <String, DocumentSnapshot<Map<String, dynamic>>>{};

      for (final r in reservations) {
        final snap = await transaction.get(_products.doc(r.productId));
        snapshots[r.productId] = snap;
        final available = (snap.data()?['quantity'] as num?)?.toInt() ?? 0;
        if (available < r.quantity) {
          throw StateError('Not enough stock for ${r.productId}');
        }
      }

      for (final r in reservations) {
        transaction.update(_products.doc(r.productId), {
          'quantity': FieldValue.increment(-r.quantity),
        });
      }
    }).timeout(
      _kWriteTimeout,
      onTimeout: () => throw Exception(_kTimeoutMessage),
    );
  }

  /// Deletes all System B data, including legacy collections.
  Future<void> wipeAll() async {
    final collectionsToWipe = [
      'system_b_products',
      'system_b_sellers',
      'system_b_sales',
      'system_b_prerequisite_submissions',
      'products',
      'tags',
      'carts',
      'sales',
      'approvals',
    ];

    for (final collectionName in collectionsToWipe) {
      final snapshot = await _firestore.collection(collectionName).get();
      for (final document in snapshot.docs) {
        await document.reference.delete();
      }
    }
  }
}

/// System B owns seller, inventory, sales, and prerequisite-review data.
class SystemB {
  final ABIB _database = ABIB();

  Future<void> createSellerAccount(
      String userId, String name, String email) async {
    await _database.writeSeller(userId, {
      'uid': userId,
      'name': name,
      'email': email,
      'role': 'seller',
    });
  }

  Future<Map<String, dynamic>?> getSellerRegistryEntry(String userId) async {
    return _database.readSeller(userId);
  }

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
    final normalizedTags = tagPath
        .split('/')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    await _database.writeProduct(productId, {
      'productId': productId,
      'sellerId': sellerId,
      'name': name,
      'description': description,
      'price': price,
      'quantity': quantity,
      'tagPath': tagPath,
      'tags': normalizedTags,
      'imageUrl': imageUrl,
      'expiryDate': expiryDate,
      'requiresApproval': requiresApproval,
      'ratings': <int>[],
    });
  }

  Future<void> submitRating(String productId, int score) async {
    await _database.addRating(productId, score);
  }

  Future<bool> verifyStock(String productId, int quantity) async {
    final product = await _database.readProduct(productId);
    final available = (product?['quantity'] as num?)?.toInt() ?? 0;
    return (available >= quantity);
  }

  Future<void> reserveInventoryForOrder(
      List<InventoryReservation> reservations) async {
    await _database.reserveInventory(reservations);
  }

  Future<void> updateExistingStock(
      String productId, int quantityToAdd) async {
    await _database.updateProduct(productId, {
      'quantity': FieldValue.increment(quantityToAdd),
    });
  }

  /// MODIFIED: Added buyerId as a required parameter for rule compliance.
  Future<void> logExternalSale({
    required String buyerId,
    required String sellerId,
    required String orderId,
    required String productId,
    required String productName,
    required int quantity,
    required double totalAmount,
  }) async {
    await _database.writeSale({
      'buyerId': buyerId,
      'sellerId': sellerId,
      'orderId': orderId,
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'totalAmount': totalAmount,
      'soldAt': DateTime.now().toIso8601String(),
    });
  }

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

    final submissionId = await _database.createSubmission(payload);
    return PrerequisiteSubmission.fromJson({
      ...payload,
      'submissionId': submissionId,
    });
  }

  Future<List<PrerequisiteSubmission>> getPendingPrerequisiteSubmissions(
      String sellerId) async {
    final raw = await _database.readPendingSubmissionsForSeller(sellerId);
    return raw.map(PrerequisiteSubmission.fromJson).toList()
      ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
  }

  Future<List<PrerequisiteSubmission>> getBuyerSubmissions(
      String buyerId) async {
    final raw = await _database.readBuyerSubmissions(buyerId);
    return raw.map(PrerequisiteSubmission.fromJson).toList()
      ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
  }

  Future<PrerequisiteSubmission?> getLatestBuyerSubmissionForProduct(
      String buyerId, String productId) async {
    final raw = await _database.readLatestBuyerSubmissionForProduct(
        buyerId, productId);
    if (raw == null) return null;
    return PrerequisiteSubmission.fromJson(raw);
  }

  Future<void> resolvePrerequisiteSubmission({
    required String submissionId,
    required bool isAccepted,
    String? rejectionMessage,
  }) async {
    await _database.updateSubmission(submissionId, {
      'status': isAccepted ? 'accepted' : 'rejected',
      'reviewedAt': DateTime.now().toIso8601String(),
      'rejectionMessage': isAccepted ? null : rejectionMessage?.trim(),
    });
  }

  Future<List<Map<String, dynamic>>> apiProvideAllProducts() async {
    return _database.readAllProducts();
  }

  Future<Map<String, dynamic>?> apiProvideProductDetail(
      String productId) async {
    return _database.readProduct(productId);
  }

  Future<List<Map<String, dynamic>>> apiProvideProductsByTag(
      String tagPath) async {
    final all = await _database.readAllProducts();
    return all.where((p) {
      final path = p['tagPath'] as String? ?? '';
      return path.startsWith(tagPath);
    }).toList();
  }

  Future<List<Product>> getProductsForSeller(String sellerId) async {
    final raw = await _database.readProductsForSeller(sellerId);
    return raw.map(Product.fromJson).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  Future<List<SellerOrderLine>> getSalesForSeller(String sellerId) async {
    final raw = await _database.readSales(sellerId);
    return raw.map(SellerOrderLine.fromJson).toList()
      ..sort((a, b) => b.soldAt.compareTo(a.soldAt));
  }

  Future<void> authorizeInventoryWipe() async {
    await _database.wipeAll();
  }
}