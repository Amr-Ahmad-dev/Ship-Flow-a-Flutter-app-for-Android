import 'product.dart';
import 'prerequisite_submission.dart';

/// Aggregated seller-facing snapshot used by the seller dashboard screen.
class SellerDashboardSummary {
  final double totalRevenue;
  final int totalUnitsSold;
  final int totalOrders;
  final List<SellerProductPerformance> productPerformances;
  final List<PrerequisiteSubmission> pendingSubmissions;

  const SellerDashboardSummary({
    required this.totalRevenue,
    required this.totalUnitsSold,
    required this.totalOrders,
    required this.productPerformances,
    required this.pendingSubmissions,
  });

  /// Provides an empty summary for loading and fallback states.
  factory SellerDashboardSummary.empty() {
    return const SellerDashboardSummary(
      totalRevenue: 0,
      totalUnitsSold: 0,
      totalOrders: 0,
      productPerformances: [],
      pendingSubmissions: [],
    );
  }
}

/// Product-level performance breakdown for the seller dashboard.
class SellerProductPerformance {
  final Product product;
  final int totalSalesQuantity;
  final double totalSalesValue;
  final List<SellerOrderLine> orders;

  const SellerProductPerformance({
    required this.product,
    required this.totalSalesQuantity,
    required this.totalSalesValue,
    required this.orders,
  });
}

/// Minimal seller-safe order line information.
///
/// Customer identity is intentionally omitted so the dashboard stays compliant
/// with the requirement to hide buyer information from sellers.
class SellerOrderLine {
  final String orderId;
  final String productId;
  final int quantityPurchased;
  final double totalPrice;
  final DateTime soldAt;

  const SellerOrderLine({
    required this.orderId,
    required this.productId,
    required this.quantityPurchased,
    required this.totalPrice,
    required this.soldAt,
  });

  /// Recreates a seller order line from stored JSON-like data.
  factory SellerOrderLine.fromJson(Map<String, dynamic> json) {
    return SellerOrderLine(
      orderId: json['orderId'] as String? ?? '',
      productId: json['productId'] as String? ?? '',
      quantityPurchased: (json['quantity'] as num?)?.toInt() ?? 0,
      totalPrice: (json['totalAmount'] as num?)?.toDouble() ?? 0,
      soldAt: DateTime.tryParse(json['soldAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
