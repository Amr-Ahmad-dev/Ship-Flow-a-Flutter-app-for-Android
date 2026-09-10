import 'package:flutter/material.dart';

import '../models/product.dart';
import '../utils/constants.dart';

/// Shared container used to group related content into a clear visual section.
class AppSectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Gradient? gradient;

  const AppSectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null ? AppConstants.kCard : null,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppConstants.kBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F1B2A35),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Compact title widget that keeps section headings visually consistent.
class SectionHeading extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const SectionHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Standard empty state used when a section has no items to display.
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _IconBadge(icon: icon, size: 70, iconSize: 34),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: 18),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Rounded accent-colored icon badge shared by empty states and metric tiles.
class _IconBadge extends StatelessWidget {
  final IconData icon;
  final double size;
  final double iconSize;

  const _IconBadge({required this.icon, this.size = 44, this.iconSize = 24});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppConstants.kAccentSoft,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(icon, size: iconSize, color: AppConstants.kAccent),
    );
  }
}

/// Small metric tile used for dashboard summaries and overview cards.
class AppMetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const AppMetricTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _IconBadge(icon: icon, size: 44, iconSize: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 18,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Visually consistent status pill for approval, review, and order states.
class AppStatusChip extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  const AppStatusChip({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foregroundColor,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

/// Product card used on home and catalog screens.
class ShopFlowProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const ShopFlowProductCard({
    required this.product,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          decoration: BoxDecoration(
            color: AppConstants.kCard,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppConstants.kBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        product.imageUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: AppConstants.kAccentSoft,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.broken_image_outlined,
                            size: 40,
                            color: AppConstants.kAccent,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 12,
                        top: 12,
                        child: AppStatusChip(
                          label: product.requiresApproval ? 'Needs Review' : 'Ready',
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
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      product.tagLabel,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          '${AppConstants.kCurrency}${product.price.toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: AppConstants.kAccent,
                              ),
                        ),
                        const Spacer(),
                        if (product.ratings.isNotEmpty)
                          Row(
                            children: [
                              const Icon(Icons.star_rounded, size: 16, color: AppConstants.kAccent),
                              const SizedBox(width: 2),
                              Text(
                                product.ratingAverage.toStringAsFixed(1),
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// App bar action that shows how many items are currently in the cart.
class CartBadge extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const CartBadge({
    super.key,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.shopping_bag_outlined),
          onPressed: onTap,
        ),
        if (count > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppConstants.kAccent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
