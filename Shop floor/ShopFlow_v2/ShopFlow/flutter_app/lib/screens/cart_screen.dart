// Cart page — reviews the buyer's cart, collects any prerequisite submissions
// required by a product, and places the order through [ApiService].
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/order.dart';
import '../models/prerequisite_submission.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../widgets/shopflow_components.dart';

/// Combined buyer workspace for cart items, submission updates, and order history.
class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<AppOrder> _orders = const [];
  List<PrerequisiteSubmission> _submissions = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Loads order history and submission updates together.
  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        context.read<ApiService>().getOrderHistory(),
        context.read<ApiService>().getBuyerSubmissions(),
      ]);
      if (mounted) {
        setState(() {
          _orders = results[0] as List<AppOrder>;
          _submissions = results[1] as List<PrerequisiteSubmission>;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Runs checkout and then refreshes the dependent buyer data.
  Future<void> _checkout() async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final createdOrder = await context.read<ApiService>().createOrder();
      if (!mounted) return;

      Navigator.pop(context);

      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Order created'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Your order has been confirmed.'),
              const SizedBox(height: 12),
              Text('Order ID: ${createdOrder.orderId}'),
              Text(
                'Amount: ${AppConstants.kCurrency}${createdOrder.totalAmount.toStringAsFixed(2)}',
              ),
              Text(
                'Estimated arrival: ${DateFormat('MMM d, yyyy').format(createdOrder.arrivalTime)}',
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      );

      await _load();
      _tabController.animateTo(2);
    } catch (error) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final apiService = context.watch<ApiService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cart & Orders'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Cart'),
            Tab(text: 'Files'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _CartTab(apiService: apiService, onCheckout: _checkout),
                _SubmissionUpdatesTab(
                  submissions: _submissions,
                  onRefresh: _load,
                ),
                _OrderHistoryTab(orders: _orders, onRefresh: _load),
              ],
            ),
    );
  }
}

/// Small text row helper reused across the submission/order tabs.
Text _bodyText(BuildContext context, String text,
    {Color? color, TextStyle? style}) {
  final base = style ?? Theme.of(context).textTheme.bodyMedium;
  return Text(text, style: base?.copyWith(color: color));
}

/// Attachment banner reused wherever an approved file needs to be surfaced.
class _AttachedFileBanner extends StatelessWidget {
  final String fileName;
  final bool boxed;

  const _AttachedFileBanner({required this.fileName, this.boxed = false});

  @override
  Widget build(BuildContext context) {
    final text = _bodyText(
      context,
      'Attached file: $fileName',
      color: AppConstants.kSuccess,
    );
    if (!boxed) return text;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF5EC),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(Icons.attach_file_rounded, color: AppConstants.kSuccess),
          const SizedBox(width: 10),
          Expanded(child: text),
        ],
      ),
    );
  }
}

/// Active cart tab for checkout and removal flows.
class _CartTab extends StatelessWidget {
  final ApiService apiService;
  final Future<void> Function() onCheckout;

  const _CartTab({required this.apiService, required this.onCheckout});

  @override
  Widget build(BuildContext context) {
    final cartItems = apiService.cart.values.toList(growable: false);

    if (cartItems.isEmpty) {
      return const AppEmptyState(
        icon: Icons.shopping_cart_outlined,
        title: 'Your cart is empty',
        message:
            'Items appear here after you add a ready product or after a seller approves a prerequisite submission.',
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: cartItems.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final cartItem = cartItems[index];
              return AppSectionCard(
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.network(
                            cartItem.product.imageUrl,
                            width: 78,
                            height: 78,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 78,
                              height: 78,
                              color: AppConstants.kAccentSoft,
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.inventory_2_outlined,
                                color: AppConstants.kAccent,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cartItem.product.name,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 6),
                              _bodyText(
                                context,
                                '${AppConstants.kCurrency}${cartItem.product.price.toStringAsFixed(2)} x ${cartItem.quantity}',
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Line total: ${AppConstants.kCurrency}${cartItem.subtotal.toStringAsFixed(2)}',
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded),
                          onPressed: () => apiService
                              .removeFromCart(cartItem.product.productId),
                        ),
                      ],
                    ),
                    if (cartItem.hasApprovedAttachment) ...[
                      const SizedBox(height: 14),
                      _AttachedFileBanner(
                        fileName: cartItem.approvedAttachment!.fileName,
                        boxed: true,
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: AppSectionCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        'Cart total',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Spacer(),
                      Text(
                        '${AppConstants.kCurrency}${apiService.cartTotal.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AppConstants.kAccent,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onCheckout,
                      child: const Text('Checkout'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Buyer-facing view of prerequisite file review outcomes.
class _SubmissionUpdatesTab extends StatelessWidget {
  final List<PrerequisiteSubmission> submissions;
  final Future<void> Function() onRefresh;

  const _SubmissionUpdatesTab({
    required this.submissions,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (submissions.isEmpty) {
      return _RefreshableEmptyList(
        onRefresh: onRefresh,
        icon: Icons.fact_check_outlined,
        title: 'No uploaded files yet',
        message:
            'Once you upload a prerequisite file for a restricted product, its review result will appear here.',
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: submissions.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final submission = submissions[index];
          final submittedAt = DateFormat('MMM d, yyyy • h:mm a')
              .format(submission.submittedAt);

          return AppSectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        submission.productName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    AppStatusChip(
                      label: submission.statusLabel,
                      backgroundColor: submission.isAccepted
                          ? const Color(0xFFE1F3E7)
                          : submission.isRejected
                              ? const Color(0xFFF8DEDC)
                              : const Color(0xFFFEEFD3),
                      foregroundColor: submission.isAccepted
                          ? const Color(0xFF1F6A43)
                          : submission.isRejected
                              ? AppConstants.kDanger
                              : const Color(0xFF9A6500),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'File: ${submission.fileName}',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 6),
                _bodyText(context, 'Submitted: $submittedAt'),
                if (submission.isRejected &&
                    (submission.rejectionMessage?.trim().isNotEmpty ??
                        false)) ...[
                  const SizedBox(height: 12),
                  _bodyText(
                    context,
                    'Seller note: ${submission.rejectionMessage}',
                    color: AppConstants.kDanger,
                  ),
                ],
                if (submission.isAccepted) ...[
                  const SizedBox(height: 12),
                  _bodyText(
                    context,
                    'This approved file is now attached to the buyer-side cart item and future order record.',
                    color: AppConstants.kSuccess,
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Buyer order history tab.
class _OrderHistoryTab extends StatelessWidget {
  final List<AppOrder> orders;
  final Future<void> Function() onRefresh;

  const _OrderHistoryTab({required this.orders, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return _RefreshableEmptyList(
        onRefresh: onRefresh,
        icon: Icons.receipt_long_outlined,
        title: 'No orders yet',
        message: 'Your completed purchases will appear here.',
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final order = orders[index];
          return AppSectionCard(
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(top: 8),
              title: Text(
                'Order ${order.orderId}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              subtitle: Text(
                '${DateFormat('MMM d, yyyy').format(order.createdAt)} • ${AppConstants.kCurrency}${order.totalAmount.toStringAsFixed(2)}',
              ),
              children: order.items.map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productName,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 4),
                      _bodyText(
                        context,
                        'Quantity: ${item.quantity} • Total: ${AppConstants.kCurrency}${item.lineTotal.toStringAsFixed(2)}',
                      ),
                      if (item.approvedAttachment != null) ...[
                        const SizedBox(height: 4),
                        _AttachedFileBanner(
                          fileName: item.approvedAttachment!.fileName,
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}

/// Shared pull-to-refresh empty state used by the submission and order tabs.
class _RefreshableEmptyList extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final IconData icon;
  final String title;
  final String message;

  const _RefreshableEmptyList({
    required this.onRefresh,
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        children: [
          AppEmptyState(icon: icon, title: title, message: message),
        ],
      ),
    );
  }
}
