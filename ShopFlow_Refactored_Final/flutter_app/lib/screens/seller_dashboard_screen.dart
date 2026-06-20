import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/prerequisite_submission.dart';
import '../models/seller_dashboard_summary.dart';
import '../services/service.dart';
import '../utils/constants.dart';
import '../widgets/shopflow_components.dart';

/// Seller-focused operations screen.
class SellerDashboardScreen extends StatefulWidget {
  const SellerDashboardScreen({super.key});

  @override
  State<SellerDashboardScreen> createState() => _SellerDashboardScreenState();
}

class _SellerDashboardScreenState extends State<SellerDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _tagPathController = TextEditingController();
  final TextEditingController _imageController = TextEditingController();
  final TextEditingController _expiryController = TextEditingController();

  SellerDashboardSummary _summary = SellerDashboardSummary.empty();
  bool _isLoading = true;
  bool _isSubmittingProduct = false;
  bool _requiresApproval = false;

  bool Function()? _validateProductForm;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadSummary();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _tagPathController.dispose();
    _imageController.dispose();
    _expiryController.dispose();
    super.dispose();
  }

  Future<void> _loadSummary() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final summary = await context.read<ApiService>().getSellerDashboardSummary();
      if (!mounted) return;
      setState(() => _summary = summary);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitProduct() async {
    if (_validateProductForm == null || !_validateProductForm!()) {
      return;
    }

    final parsedPrice = double.tryParse(_priceController.text.trim());
    final parsedQuantity = int.tryParse(_quantityController.text.trim());

    if (parsedPrice == null || parsedQuantity == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Price and quantity must be valid numbers.')),
      );
      return;
    }

    setState(() => _isSubmittingProduct = true);

    try {
      await context.read<ApiService>().addProduct(
            name: _nameController.text.trim(),
            desc: _descriptionController.text.trim(),
            price: parsedPrice,
            quantity: parsedQuantity,
            tagPath: _tagPathController.text.trim(),
            imageUrl: _imageController.text.trim(),
            expiry: _expiryController.text.trim(),
            approval: _requiresApproval,
          );

      if (!mounted) return;
      _nameController.clear();
      _descriptionController.clear();
      _priceController.clear();
      _quantityController.clear();
      _tagPathController.clear();
      _imageController.clear();
      _expiryController.clear();
      setState(() => _requiresApproval = false);

      await _loadSummary();
      if (!mounted) return;
      _tabController.animateTo(1);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product created successfully.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (!mounted) return;
      setState(() => _isSubmittingProduct = false);
    }
  }

  Future<void> _showAddStockDialog(String productId) async {
    final amountToAdd = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _AddStockDialog(),
    );

    if (amountToAdd == null || amountToAdd <= 0) return;

    if (!mounted) return;
    try {
      await context.read<ApiService>().addStock(
            productId: productId,
            quantityToAdd: amountToAdd,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stock update requested. Refresh the page to see the new value.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update stock: $error')),
      );
    }
  }

  Future<void> _reviewSubmission({
    required PrerequisiteSubmission submission,
    required bool isAccepted,
  }) async {
    String? rejectionMessage;

    if (!isAccepted) {
      rejectionMessage = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const _RejectionDialog(),
      );
      if (rejectionMessage == null) return;
    }

    if (!mounted) return;
    try {
      await context.read<ApiService>().reviewPrerequisiteSubmission(
            submission: submission,
            isAccepted: isAccepted,
            rejectionMessage: rejectionMessage,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review submitted. Refresh to see changes.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _openSubmissionFile(String downloadUrl) async {
    final fileUri = Uri.tryParse(downloadUrl);
    if (fileUri == null) return;

    final launched = await launchUrl(fileUri, mode: LaunchMode.externalApplication);

    if (!launched && mounted) {
      await Clipboard.setData(ClipboardData(text: downloadUrl));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link copied to clipboard.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seller Dashboard'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Catalog'),
            Tab(text: 'Add Product'),
            Tab(text: 'Submissions'),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              _OverviewTab(summary: _summary),
              _CatalogTab(summary: _summary, onAddStock: _showAddStockDialog),
              _AddProductTab(
                onRegisterValidator: (fn) => _validateProductForm = fn,
                nameController: _nameController,
                descriptionController: _descriptionController,
                priceController: _priceController,
                quantityController: _quantityController,
                tagPathController: _tagPathController,
                imageController: _imageController,
                expiryController: _expiryController,
                requiresApproval: _requiresApproval,
                isSubmittingProduct: _isSubmittingProduct,
                onRequiresApprovalChanged: (v) => setState(() => _requiresApproval = v),
                onSubmit: _submitProduct,
              ),
              _SubmissionTab(
                submissions: _summary.pendingSubmissions,
                onOpenFile: _openSubmissionFile,
                onReview: _reviewSubmission,
              ),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

class _AddStockDialog extends StatefulWidget {
  const _AddStockDialog();

  @override
  State<_AddStockDialog> createState() => _AddStockDialogState();
}

class _AddStockDialogState extends State<_AddStockDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add stock'),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Quantity to add'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, int.tryParse(_controller.text.trim())),
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

class _RejectionDialog extends StatefulWidget {
  const _RejectionDialog();

  @override
  State<_RejectionDialog> createState() => _RejectionDialogState();
}

class _RejectionDialogState extends State<_RejectionDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reject submission'),
      content: TextField(
        controller: _controller,
        maxLines: 3,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Reason shown to the buyer',
          hintText: 'Explain what needs to be fixed',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('Reject'),
        ),
      ],
    );
  }
}

class _OverviewTab extends StatelessWidget {
  final SellerDashboardSummary summary;
  const _OverviewTab({required this.summary});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
      ],
    );
  }
}

class _CatalogTab extends StatelessWidget {
  final SellerDashboardSummary summary;
  final Future<void> Function(String productId) onAddStock;

  const _CatalogTab({required this.summary, required this.onAddStock});

  @override
  Widget build(BuildContext context) {
    if (summary.productPerformances.isEmpty) {
      return const AppEmptyState(
        icon: Icons.storefront,
        title: 'No products yet',
        message: 'Your product catalog is currently empty.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: summary.productPerformances.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final performance = summary.productPerformances[index];
        return AppSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(performance.product.name, style: Theme.of(context).textTheme.titleLarge),
                        Text('Stock: ${performance.product.quantity}'),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () => onAddStock(performance.product.productId),
                    child: const Text('Add stock'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AddProductTab extends StatefulWidget {
  final void Function(bool Function() validate) onRegisterValidator;
  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final TextEditingController priceController;
  final TextEditingController quantityController;
  final TextEditingController tagPathController;
  final TextEditingController imageController;
  final TextEditingController expiryController;
  final bool requiresApproval;
  final bool isSubmittingProduct;
  final ValueChanged<bool> onRequiresApprovalChanged;
  final Future<void> Function() onSubmit;

  const _AddProductTab({
    required this.onRegisterValidator,
    required this.nameController,
    required this.descriptionController,
    required this.priceController,
    required this.quantityController,
    required this.tagPathController,
    required this.imageController,
    required this.expiryController,
    required this.requiresApproval,
    required this.isSubmittingProduct,
    required this.onRequiresApprovalChanged,
    required this.onSubmit,
  });

  @override
  State<_AddProductTab> createState() => _AddProductTabState();
}

class _AddProductTabState extends State<_AddProductTab> with AutomaticKeepAliveClientMixin {
  final _formKey = GlobalKey<FormState>();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _register();
  }

  @override
  void didUpdateWidget(_AddProductTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onRegisterValidator != oldWidget.onRegisterValidator) {
      _register();
    }
  }

  void _register() {
    widget.onRegisterValidator(() => _formKey.currentState?.validate() ?? false);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AppSectionCard(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeading(
                  title: 'Create product',
                  subtitle: 'Fill in the details to add a new product to your catalog.',
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: widget.nameController,
                  decoration: const InputDecoration(labelText: 'Product name'),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: widget.descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Description'),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: widget.priceController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Price'),
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: widget.quantityController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Quantity'),
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: widget.tagPathController,
                  decoration: const InputDecoration(labelText: 'Tag Path'),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: widget.imageController,
                  decoration: const InputDecoration(labelText: 'Image URL'),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: widget.expiryController,
                  decoration: const InputDecoration(labelText: 'Expiry (Optional)'),
                ),
                const SizedBox(height: 14),
                SwitchListTile(
                  title: const Text('Require Prerequisite'),
                  subtitle: const Text('Buyer must upload a file for review before purchasing.'),
                  value: widget.requiresApproval,
                  onChanged: widget.onRequiresApprovalChanged,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: widget.isSubmittingProduct ? null : widget.onSubmit,
                    child: const Text('Create Product'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SubmissionTab extends StatelessWidget {
  final List<PrerequisiteSubmission> submissions;
  final Future<void> Function(String url) onOpenFile;
  final Future<void> Function({required PrerequisiteSubmission submission, required bool isAccepted}) onReview;

  const _SubmissionTab({required this.submissions, required this.onOpenFile, required this.onReview});

  @override
  Widget build(BuildContext context) {
    if (submissions.isEmpty) {
      return const AppEmptyState(
        icon: Icons.fact_check,
        title: 'No submissions',
        message: 'There are no pending prerequisite submissions to review.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: submissions.length,
      itemBuilder: (context, index) {
        final sub = submissions[index];
        return AppSectionCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(sub.productName, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text('File: ${sub.fileName}', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => onOpenFile(sub.downloadUrl),
                      child: const Text('View File'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.check_circle, color: Colors.green, size: 32),
                    onPressed: () => onReview(submission: sub, isAccepted: true),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.red, size: 32),
                    onPressed: () => onReview(submission: sub, isAccepted: false),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
