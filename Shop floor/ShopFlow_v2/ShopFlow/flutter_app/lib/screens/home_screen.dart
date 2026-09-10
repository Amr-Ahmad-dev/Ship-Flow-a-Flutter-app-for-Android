// Home page — the post-login landing screen. Renders a buyer storefront or a
// seller overview depending on the signed-in role.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../models/seller_dashboard_summary.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../widgets/shopflow_components.dart';

/// Entry experience after login.
///
/// The screen switches between a buyer-focused landing page and a seller
/// overview based on the active role in [ApiService].
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Product> _recommendedProducts = const [];
  SellerDashboardSummary _sellerSummary = SellerDashboardSummary.empty();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Loads the role-appropriate dashboard data.
  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final apiService = context.read<ApiService>();

    try {
      if (apiService.isSeller) {
        final summary = await apiService.getSellerDashboardSummary();
        if (mounted) {
          setState(() {
            _sellerSummary = summary;
          });
        }
      } else {
        final products = await apiService.getRecommendations();
        if (mounted) {
          setState(() {
            _recommendedProducts = products;
          });
        }
      }
    } catch (_) {
      // Data simply stays empty; the UI shows its empty state.
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final apiService = context.watch<ApiService>();
    return Scaffold(
      appBar: AppBar(
        title: Text(apiService.isSeller ? 'Seller Hub' : 'ShopFlow'),
        automaticallyImplyLeading: false,
        actions: [
          if (apiService.hasBothRoles)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: () async {
                  apiService.toggleRole();
                  await _load();
                },
                icon: Icon(
                  apiService.isSeller ? Icons.shopping_bag_outlined : Icons.storefront_outlined,
                  color: AppConstants.kPrimary,
                ),
                label: Text(
                  apiService.isSeller ? 'Buyer mode' : 'Seller mode',
                ),
              ),
            ),
          if (!apiService.isSeller)
            CartBadge(
              count: apiService.cartCount,
              onTap: () => Navigator.pushNamed(context, '/cart'),
            ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              await apiService.logout();
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF8F4ED), Color(0xFFF0F5F7)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              _HeroHeader(
                displayName: apiService.displayName ?? 'User',
                isSeller: apiService.isSeller,
              ),
              const SizedBox(height: 20),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (apiService.isSeller)
                _SellerHomeContent(summary: _sellerSummary)
              else
                _BuyerHomeContent(recommendedProducts: _recommendedProducts),
            ],
          ),
        ),
      ),
    );
  }
}

/// Decorative introduction panel shown at the top of the home screen.
class _HeroHeader extends StatelessWidget {
  final String displayName;
  final bool isSeller;

  const _HeroHeader({
    required this.displayName,
    required this.isSeller,
  });

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      gradient: const LinearGradient(
        colors: [AppConstants.kPrimary, AppConstants.kPrimaryDark],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              isSeller ? 'Seller workspace' : 'Buyer workspace',
              style: TextStyle(
                color: isSeller ? Colors.white : Colors.green,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Welcome back, $displayName',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            isSeller
                ? 'hiii!.'
                : 'hiii.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.88),
                ),
          ),
        ],
      ),
    );
  }
}

/// Buyer landing content with recommendations and shortcuts.
class _BuyerHomeContent extends StatelessWidget {
  final List<Product> recommendedProducts;

  const _BuyerHomeContent({
    required this.recommendedProducts,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _BuyerQuickActions(),
        const SizedBox(height: 20),
        if (recommendedProducts.isEmpty)
          const AppSectionCard(
            child: AppEmptyState(
              icon: Icons.explore_outlined,
              title: 'No recommendations yet',
              message:
                  'Browse a few categories and ShopFlow will start building a smarter recommendation list.',
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 0.72,
            ),
            itemCount: recommendedProducts.length,
            itemBuilder: (context, index) {
              final product = recommendedProducts[index];
              return ShopFlowProductCard(
                product: product,
                onTap: () => Navigator.pushNamed(
                  context,
                  '/product-detail',
                  arguments: product.productId,
                ),
              );
            },
          ),
      ],
    );
  }
}

/// Seller landing content with summary metrics and a jump-off button.
class _SellerHomeContent extends StatelessWidget {
  final SellerDashboardSummary summary;

  const _SellerHomeContent({
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.35,
          children: [
            AppMetricTile(
              label: 'Revenue',
              value: '${AppConstants.kCurrency}${summary.totalRevenue.toStringAsFixed(2)}',
              icon: Icons.payments_outlined,
            ),
            AppMetricTile(
              label: 'Orders',
              value: '${summary.totalOrders}',
              icon: Icons.receipt_long_outlined,
            ),
            AppMetricTile(
              label: 'Units sold',
              value: '${summary.totalUnitsSold}',
              icon: Icons.inventory_2_outlined,
            ),
            AppMetricTile(
              label: 'Pending reviews',
              value: '${summary.pendingSubmissions.length}',
              icon: Icons.fact_check_outlined,
            ),
          ],
        ),
        const SizedBox(height: 20),
        AppSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (summary.productPerformances.isEmpty)
                const AppEmptyState(
                  icon: Icons.storefront_outlined,
                  title: 'No products yet',
                  message:
                      'Add your first product from the seller dashboard to start seeing sales analytics here.',
                )
              else
                ...summary.productPerformances.take(3).map((performance) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            performance.product.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Text(
                          '${performance.totalSalesQuantity} sold',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${AppConstants.kCurrency}${performance.totalSalesValue.toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: AppConstants.kAccent,
                              ),
                        ),
                      ],
                    ),
                  );
                }),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () =>
                    Navigator.pushNamed(context, '/seller-dashboard'),
                icon: const Icon(Icons.dashboard_customize_outlined),
                label: const Text('Open seller dashboard'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Buyer shortcut section.
class _BuyerQuickActions extends StatelessWidget {
  const _BuyerQuickActions();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionTile(
            icon: Icons.search_rounded,
            title: 'Browse products',
            subtitle: 'Search and filter the catalog.',
            onTap: () => Navigator.pushNamed(context, '/products'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickActionTile(
            icon: Icons.shopping_cart_checkout_rounded,
            title: 'Cart & orders',
            subtitle: 'Check approvals, cart items, and history.',
            onTap: () => Navigator.pushNamed(context, '/cart'),
          ),
        ),
      ],
    );
  }
}

/// Reusable tile used by the buyer quick action row.
class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppConstants.kBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppConstants.kAccentSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: AppConstants.kAccent),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

