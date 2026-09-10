// Catalogue page — browsable/filterable product list backed by System B's
// inventory, with tag filtering tracked for recommendations.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../models/tag.dart';
import '../services/api_service.dart';
import '../widgets/shopflow_components.dart';

/// Buyer product catalog with tag filters and keyword search.
class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<Product> _products = const [];
  List<AppTag> _tags = const [];
  String? _activeTagId;
  String _searchQuery = '';
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Loads the initial tag list and optional preselected category.
  Future<void> _initialize() async {
    final routeArguments =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final initialTagId = routeArguments?['tagId'] as String?;

    await Future.wait([
      _loadTags(),
      _loadProducts(tagId: initialTagId, updateActiveTag: true),
    ]);
  }

  /// Loads the available tag filter options.
  Future<void> _loadTags() async {
    try {
      final tags = await context.read<ApiService>().getAllTags();
      if (mounted) {
        setState(() => _tags = tags);
      }
    } catch (_) {}
  }

  /// Loads products using the active tag and search query.
  Future<void> _loadProducts({
    String? tagId,
    String? query,
    bool updateActiveTag = false,
  }) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      if (updateActiveTag) {
        _activeTagId = tagId;
      }
      if (query != null) {
        _searchQuery = query;
      }
    });

    try {
      final products = await context.read<ApiService>().getProducts(
            tagPath: _activeTagId,
            query: _searchQuery,
          );
      if (mounted) {
        setState(() => _products = products);
      }
    } on ApiException catch (exception) {
      if (mounted) {
        setState(() => _errorMessage = exception.message);
      }
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
        title: Text(_activeTagId == null ? 'Product Catalog' : _activeTagId!),
        actions: [
          CartBadge(
            count: apiService.cartCount,
            onTap: () => Navigator.pushNamed(context, '/cart'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (value) => _loadProducts(query: value.trim()),
              decoration: InputDecoration(
                hintText: 'Search products, tags, or descriptions',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _searchController.clear();
                          _loadProducts(query: '');
                        },
                      ),
              ),
            ),
          ),
          if (_tags.isNotEmpty)
            SizedBox(
              height: 58,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: const Text('All'),
                      selected: _activeTagId == null,
                      onSelected: (_) =>
                          _loadProducts(tagId: null, updateActiveTag: true),
                    ),
                  ),
                  ..._tags.map((tag) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('${tag.name} (${tag.productCount})'),
                        selected: tag.tagId == _activeTagId,
                        onSelected: (_) {
                          apiService.trackTag(tag.tagId);
                          _loadProducts(
                            tagId: tag.tagId,
                            updateActiveTag: true,
                          );
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _loadProducts(),
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  /// Wraps an [AppEmptyState] in the standard scrollable padded container.
  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: AppSectionCard(
            child: AppEmptyState(icon: icon, title: title, message: message),
          ),
        ),
      ],
    );
  }

  /// Builds the catalog body based on loading, error, and empty states.
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return _buildEmptyState(
        icon: Icons.error_outline,
        title: 'Unable to load products',
        message: _errorMessage!,
      );
    }

    if (_products.isEmpty) {
      return _buildEmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'No products matched your filters',
        message: 'Try a different search term or switch to another category.',
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.72,
      ),
      itemCount: _products.length,
      itemBuilder: (context, index) {
        final product = _products[index];
        return ShopFlowProductCard(
          product: product,
          onTap: () {
            context.read<ApiService>().trackTag(
                  product.tags.isNotEmpty ? product.tags.first : product.tagPath,
                );
            Navigator.pushNamed(
              context,
              '/product-detail',
              arguments: product.productId,
            );
          },
        );
      },
    );
  }
}
