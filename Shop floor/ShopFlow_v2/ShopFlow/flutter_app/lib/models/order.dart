// Order model: an immutable snapshot of a completed purchase, owned by
// System A (buyer side) and mirrored into System B for seller reporting.
import 'prerequisite_submission.dart';

class AppOrder {
  final String id;
  final String userId;
  final List<OrderItemDetail> items;
  final double totalAmount;
  final DateTime createdAt;
  final DateTime arrivalTime;
  final String status;

  AppOrder({
    required this.id,
    required this.userId,
    required this.items,
    required this.totalAmount,
    required this.createdAt,
    required this.arrivalTime,
    this.status = 'pending',
  });

  /// Alias kept for compatibility with older UI code.
  String get orderId => id;

  /// Convenience getter used by the order history UI.
  bool get isConfirmed => status == 'confirmed';

  /// Recreates an order from persisted JSON-like data.
  factory AppOrder.fromJson(Map<String, dynamic> json) => AppOrder(
        id: json['orderId'] as String? ?? json['id'] as String? ?? '',
        userId: json['userId'] as String? ?? '',
        items: (json['items'] as List? ?? [])
            .map((entry) => OrderItemDetail.fromJson(entry as Map<String, dynamic>))
            .toList(),
        totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
        createdAt: json['createdAt'] != null
            ? (json['createdAt'] is String ? DateTime.parse(json['createdAt'].toString()) : DateTime.now())
            : DateTime.now(),
        arrivalTime: json['arrivalTime'] != null
            ? (json['arrivalTime'] is String ? DateTime.parse(json['arrivalTime'].toString()) : DateTime.now())
            : DateTime.now().add(const Duration(days: 3)),
        status: json['status'] as String? ?? 'pending',
      );

  /// Serializes the order for persistence.
  Map<String, dynamic> toJson() => {
        'id': id,
        'orderId': id,
        'userId': userId,
        'items': items.map((i) => i.toJson()).toList(),
        'totalAmount': totalAmount,
        'createdAt': createdAt.toIso8601String(),
        'arrivalTime': arrivalTime.toIso8601String(),
        'status': status,
      };
}

class OrderItemDetail {
  final String productId;
  final String productName;
  final String imageUrl;
  final int quantity;
  final double priceAtPurchase;
  final ApprovedPrerequisiteAttachment? approvedAttachment;

  OrderItemDetail({
    required this.productId,
    required this.productName,
    required this.imageUrl,
    required this.quantity,
    required this.priceAtPurchase,
    this.approvedAttachment,
  });

  /// Calculates the subtotal for the item based on the locked purchase price.
  double get lineTotal => quantity * priceAtPurchase;

  /// Recreates a single order line item from persisted JSON-like data.
  factory OrderItemDetail.fromJson(Map<String, dynamic> json) => OrderItemDetail(
        productId: json['productId'] as String? ?? '',
        productName: json['productName'] as String? ?? 'Product',
        imageUrl: json['imageUrl'] as String? ?? '',
        quantity: (json['quantity'] as num?)?.toInt() ?? 0,
        priceAtPurchase: (json['priceAtPurchase'] as num?)?.toDouble() ?? 0.0,
        approvedAttachment: json['approvedAttachment'] is Map<String, dynamic>
            ? ApprovedPrerequisiteAttachment.fromJson(
                json['approvedAttachment'] as Map<String, dynamic>,
              )
            : null,
      );

  /// Converts the order line into a serializable map.
  Map<String, dynamic> toJson() => {
        'productId': productId,
        'productName': productName,
        'imageUrl': imageUrl,
        'quantity': quantity,
        'priceAtPurchase': priceAtPurchase,
        'approvedAttachment': approvedAttachment?.toJson(),
      };
}
