import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/order.dart';
import '../models/product.dart';
import '../models/prerequisite_submission.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../widgets/shopflow_components.dart';

/// Detailed product page for buyers.
class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  Product? _product;
  PrerequisiteSubmission? _latestSubmission;
  bool _hasPurchasedProduct = false;
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  /// Loads the product, latest submission status, and rating eligibility.
  Future<void> _load() async {
    final productId = ModalRoute.of(context)?.settings.arguments as String?;
    if (productId == null) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    setState(() => _isLoading = true);
    final apiService = context.read<ApiService>();

    try {
      final product = await apiService.getProductById(productId);
      final orderHistory = await apiService.getOrderHistory();
      final latestSubmission = product.requiresApproval
          ? await apiService.getLatestBuyerSubmissionForProduct(productId)
          : null;

      if (mounted) {
        setState(() {
          _product = product;
          _latestSubmission = latestSubmission;
          _hasPurchasedProduct = _buyerHasPurchasedProduct(orderHistory, productId);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _product = null);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Handles either a direct add-to-cart flow or a prerequisite upload flow.
  Future<void> _handlePrimaryAction() async {
    final product = _product;
    if (product == null) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final apiService = context.read<ApiService>();
      if (product.requiresApproval) {
        final submission = await apiService.submitProductPrerequisite(product);
        await _load();

        if (!mounted) {
          return;
        }

        final message = submission.isAccepted
            ? 'This file was already approved and the product has been added to your cart.'
            : 'Your prerequisite file has been uploaded and sent to the seller for review.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      } else {
        await apiService.addToCart(product, 1);
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product added to your cart.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  /// Opens a simple dialog for the product rating flow.
  Future<void> _showRatingPicker() async {
    if (_product == null) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Rate this product'),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(5, (index) {
              return IconButton(
                icon: const Icon(Icons.star_border_rounded),
                onPressed: () async {
                  try {
                    await context
                        .read<ApiService>()
                        .addRating(_product!.productId, index + 1);
                    if (!mounted) {
                      return;
                    }
                    Navigator.pop(dialogContext);
                    await _load();
                  } catch (error) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(error.toString())),
                      );
                    }
                  }
                },
              );
            }),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_product == null) {
      return const Scaffold(
        body: Center(child: Text('The requested product could not be found.')),
      );
    }

    final product = _product!;

    return Scaffold(
      appBar: AppBar(title: Text(product.name)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Stack(
                children: [
                  Image.network(
                    product.imageUrl,
                    width: double.infinity,
                    height: 320,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 320,
                      color: AppConstants.kAccentSoft,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.inventory_2_outlined,
                        size: 56,
                        color: AppConstants.kAccent,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    top: 16,
                    child: AppStatusChip(
                      label: product.requiresApproval ? 'Needs seller review' : 'Ready to buy',
                      backgroundColor: product.requiresApproval
                          ? const Color(0xFFFEEFD3)
                          : const Color(0xFFE1F3E7),
                      foregroundColor: product.requiresApproval
                          ? const Color(0xFF9A6500)
                          : const Color(0xFF1F6A43),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            AppSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '${AppConstants.kCurrency}${product.price.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AppConstants.kAccent,
                            ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'Stock: ${product.quantity}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(label: Text(product.tagLabel)),
                      Chip(label: Text('Expiry: ${product.expiryDate}')),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    product.description,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  if (product.ratings.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, color: AppConstants.kAccent),
                        const SizedBox(width: 6),
                        Text(
                          '${product.ratingAverage.toStringAsFixed(1)} from ${product.ratings.length} ratings',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (product.requiresApproval) ...[
              const SizedBox(height: 18),
              _SubmissionStatusCard(submission: _latestSubmission),
            ],
            const SizedBox(height: 18),
            AppSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeading(
                    title: product.requiresApproval ? 'Prerequisite flow' : 'Purchase',
                    subtitle: product.requiresApproval
                        ? 'Upload a prerequisite file first. The seller can approve or reject it, and accepted files are attached to your cart item.'
                        : 'Add this product directly to your cart.',
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    onPressed: _isSubmitting || _latestSubmission?.isPending == true
                        ? null
                        : _handlePrimaryAction,
                    icon: Icon(
                      product.requiresApproval
                          ? Icons.upload_file_rounded
                          : Icons.add_shopping_cart_rounded,
                    ),
                    label: Text(
                      product.requiresApproval
                          ? _primaryButtonLabelForSubmission()
                          : 'Add to cart',
                    ),
                  ),
                  if (_latestSubmission?.isAccepted == true) ...[
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => Navigator.pushNamed(context, '/cart'),
                      child: const Text('Open cart'),
                    ),
                  ],
                ],
              ),
            ),
            if (_hasPurchasedProduct) ...[
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: _showRatingPicker,
                icon: const Icon(Icons.star_outline_rounded),
                label: const Text('Rate this product'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Returns `true` if any previous order contained the current product.
  bool _buyerHasPurchasedProduct(List<AppOrder> orders, String productId) {
    return orders.any(
      (order) => order.items.any((item) => item.productId == productId),
    );
  }

  /// Chooses the best primary button label based on submission state.
  String _primaryButtonLabelForSubmission() {
    final latestSubmission = _latestSubmission;
    if (latestSubmission == null) {
      return 'Upload prerequisite file';
    }
    if (latestSubmission.isRejected) {
      return 'Upload replacement file';
    }
    if (latestSubmission.isAccepted) {
      return 'Sync approved item to cart';
    }
    return 'Waiting for seller review';
  }
}

/// Shows the latest buyer-side submission review result.
class _SubmissionStatusCard extends StatelessWidget {
  final PrerequisiteSubmission? submission;

  const _SubmissionStatusCard({
    required this.submission,
  });

  @override
  Widget build(BuildContext context) {
    if (submission == null) {
      return const AppSectionCard(
        child: AppEmptyState(
          icon: Icons.upload_file_outlined,
          title: 'No prerequisite file uploaded yet',
          message:
              'Upload the required file and wait for the seller review before this product can enter your cart.',
        ),
      );
    }

    final submittedLabel =
        DateFormat('MMM d, yyyy • h:mm a').format(submission!.submittedAt);

    return AppSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SectionHeading(
                  title: 'Latest submission',
                  subtitle: 'Submitted on $submittedLabel',
                ),
              ),
              AppStatusChip(
                label: submission!.statusLabel,
                backgroundColor: submission!.isAccepted
                    ? const Color(0xFFE1F3E7)
                    : submission!.isRejected
                        ? const Color(0xFFF8DEDC)
                        : const Color(0xFFFEEFD3),
                foregroundColor: submission!.isAccepted
                    ? const Color(0xFF1F6A43)
                    : submission!.isRejected
                        ? AppConstants.kDanger
                        : const Color(0xFF9A6500),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'File: ${submission!.fileName}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Type: ${submission!.fileExtension.toUpperCase()} • ${submission!.fileSizeInBytes} bytes',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (submission!.isRejected &&
              (submission!.rejectionMessage?.trim().isNotEmpty ?? false)) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFBEAE8),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                'Seller note: ${submission!.rejectionMessage}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppConstants.kDanger,
                    ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
