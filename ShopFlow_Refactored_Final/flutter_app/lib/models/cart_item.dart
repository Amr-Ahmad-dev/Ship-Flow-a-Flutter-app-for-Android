import 'product.dart';
import 'prerequisite_submission.dart';

/// Buyer cart entry used by the UI and persisted buyer profile.
class CartItem {
  final Product product;
  final int quantity;
  final ApprovedPrerequisiteAttachment? approvedAttachment;

  const CartItem({
    required this.product,
    required this.quantity,
    this.approvedAttachment,
  });

  /// Calculates the line subtotal displayed in the cart UI.
  double get subtotal => product.price * quantity;

  /// Indicates whether this item includes an approved prerequisite file.
  bool get hasApprovedAttachment => approvedAttachment != null;

  /// Recreates a cart entry from persisted profile data.
  factory CartItem.fromJson(
    Map<String, dynamic> json, {
    Product? fallbackProduct,
  }) {
    return CartItem(
      product: fallbackProduct ?? Product.fromJson(json['productSnapshot'] as Map<String, dynamic>? ?? json),
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      approvedAttachment: json['approvedAttachment'] is Map<String, dynamic>
          ? ApprovedPrerequisiteAttachment.fromJson(
              json['approvedAttachment'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  /// Converts the cart entry into a Firestore-friendly map.
  Map<String, dynamic> toJson() {
    return {
      'productId': product.productId,
      'quantity': quantity,
      'productSnapshot': product.toJson(),
      'approvedAttachment': approvedAttachment?.toJson(),
    };
  }

  /// Creates a modified copy so cart updates stay predictable and readable.
  CartItem copyWith({
    Product? product,
    int? quantity,
    ApprovedPrerequisiteAttachment? approvedAttachment,
    bool clearApprovedAttachment = false,
  }) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      approvedAttachment: clearApprovedAttachment
          ? null
          : approvedAttachment ?? this.approvedAttachment,
    );
  }
}
