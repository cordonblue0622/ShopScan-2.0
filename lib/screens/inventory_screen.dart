import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/auth_provider.dart';
import '../../models/product_model.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({Key? key}) : super(key: key);

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _firestoreService = FirestoreService();
  final _searchController = TextEditingController();
  String _filterType = 'All';
  String? _updatingProductId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthProvider>().currentUser;
    final canAdjustInventory = currentUser != null;
    final bottomSafeArea = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: const Color(AppColors.lightBg),
      body: SafeArea(
        child: StreamBuilder<List<ProductModel>>(
          stream: _firestoreService.getProductsStream(shopId: currentUser?.shopId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Failed to load inventory: ${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final allProducts = snapshot.data ?? <ProductModel>[];
            final filteredProducts = _applyFilters(allProducts);
            final ownerName = currentUser?.name;
            final summary = _InventorySummary.fromProducts(allProducts);

            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    children: [
                      _buildTopBar(context, ownerName),
                      const SizedBox(height: 18),
                      Text(
                        'Products',
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        canAdjustInventory
                            ? 'Review stock levels and adjust inventory counts.'
                            : 'Manage your inventory and stock levels',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: const Color(AppColors.greyDark),
                            ),
                      ),
                      const SizedBox(height: 18),
                      _buildSearchField(),
                      const SizedBox(height: 12),
                      _buildFilterBar(),
                      const SizedBox(height: 18),
                      _buildSummaryGrid(context, summary),
                      const SizedBox(height: 18),
                      if (filteredProducts.isEmpty)
                        const _InventoryEmptyState()
                      else
                        ...filteredProducts.map(
                          (product) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _InventoryProductCard(
                              product: product,
                              canAdjustInventory: canAdjustInventory,
                              isUpdating: _updatingProductId == product.id,
                              onAdjustStock: canAdjustInventory
                                  ? () => _showAdjustStockSheet(product)
                                  : null,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // ── Bottom: Add Product button + Summary ──
                Container(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 6 + bottomSafeArea),
                  color: const Color(AppColors.lightBg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (currentUser?.role == UserRole.owner) ...[
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () => _showAddProductSheet(currentUser),
                            icon: const Icon(Icons.add_rounded, size: 20),
                            label: const Text('Add Product',
                                style: TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w600)),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(AppColors.primary),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      _InventorySummaryPanel(summary: summary),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<ProductModel> _applyFilters(List<ProductModel> products) {
    var filtered = [...products];

    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered.where((product) {
        return product.name.toLowerCase().contains(query) ||
            product.category.toLowerCase().contains(query) ||
            product.barcode.toLowerCase().contains(query);
      }).toList();
    }

    filtered = filtered.where((product) {
      switch (_filterType) {
        case 'Low Stock':
          return product.isLowStock && !product.isOutOfStock;
        case 'Out of Stock':
          return product.isOutOfStock;
        default:
          return true;
      }
    }).toList();

    filtered.sort((a, b) {
      if (a.isOutOfStock != b.isOutOfStock) {
        return a.isOutOfStock ? -1 : 1;
      }
      if (a.isLowStock != b.isLowStock) {
        return a.isLowStock ? -1 : 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return filtered;
  }

  Widget _buildTopBar(BuildContext context, String? ownerName) {
    return Row(
      children: [
        Text(
          'ShopScan',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5FF),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            ownerName == null || ownerName.isEmpty ? 'Owner' : ownerName,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: const Color(AppColors.primary),
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: 'Search product name or SKU...',
        prefixIcon: const Icon(Icons.search_rounded),
        filled: true,
        fillColor: const Color(AppColors.white),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(AppColors.primary)),
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(AppColors.white),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          _buildFilterButton('All'),
          const SizedBox(width: 8),
          _buildFilterButton('Low Stock'),
          const SizedBox(width: 8),
          _buildFilterButton('Out of Stock'),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String label) {
    final isSelected = _filterType == label;

    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _filterType = label;
          });
        },
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color:
                isSelected ? const Color(0xFFE8F1FF) : const Color(0xFFF6F7FA),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (label == 'All')
                const Icon(Icons.grid_view_rounded, size: 16)
              else if (label == 'Low Stock')
                const Icon(Icons.warning_amber_rounded, size: 16)
              else
                const Icon(Icons.remove_shopping_cart_outlined, size: 16),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected
                        ? const Color(AppColors.primary)
                        : const Color(AppColors.black),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryGrid(BuildContext context, _InventorySummary summary) {
    return GridView.count(
      crossAxisCount: 2,
      childAspectRatio: 1.38,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      children: [
        _InventoryStatCard(
          label: 'TOTAL ITEMS',
          value: NumberFormat.decimalPattern().format(summary.totalItems),
        ),
        _InventoryStatCard(
          label: 'OUT OF STOCK',
          value: NumberFormat.decimalPattern().format(summary.outOfStockCount),
          valueColor: const Color(AppColors.error),
        ),
        _InventoryStatCard(
          label: 'LOW STOCK',
          value: NumberFormat.decimalPattern().format(summary.lowStockCount),
          valueColor: const Color(AppColors.orange),
        ),
        _InventoryStatCard(
          label: 'INVENTORY VALUE',
          value: summary.totalValueLabel,
          valueColor: const Color(AppColors.primary),
        ),
      ],
    );
  }

  Future<void> _showAdjustStockSheet(ProductModel product) async {
    final quantityController = TextEditingController(
      text: product.stock.toString(),
    );
    var proposedStock = product.stock;
    var isSaving = false;

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(AppColors.white),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (sheetContext, setSheetState) {
              return SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    20,
                    20,
                    20 + MediaQuery.of(sheetContext).viewInsets.bottom,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Update Inventory',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        product.name,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: const Color(AppColors.greyDark),
                            ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: quantityController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Current stock',
                          hintText: 'Enter quantity on hand',
                          filled: true,
                          fillColor: const Color(0xFFF7F9FC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(
                              color: Color(AppColors.primary),
                            ),
                          ),
                        ),
                        onChanged: (value) {
                          final parsed = int.tryParse(value);
                          if (parsed != null && parsed >= 0) {
                            proposedStock = parsed;
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                final nextValue =
                                    proposedStock <= 0 ? 0 : proposedStock - 1;
                                setSheetState(() {
                                  proposedStock = nextValue;
                                  quantityController.text =
                                      nextValue.toString();
                                });
                              },
                              icon: const Icon(Icons.remove_rounded),
                              label: const Text('Minus 1'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () {
                                final nextValue = proposedStock + 1;
                                setSheetState(() {
                                  proposedStock = nextValue;
                                  quantityController.text =
                                      nextValue.toString();
                                });
                              },
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Plus 1'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  final parsed = int.tryParse(
                                      quantityController.text.trim());
                                  if (parsed == null || parsed < 0) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Enter a valid stock quantity.'),
                                        backgroundColor: Color(AppColors.error),
                                      ),
                                    );
                                    return;
                                  }

                                  setSheetState(() {
                                    isSaving = true;
                                  });
                                  setState(() {
                                    _updatingProductId = product.id;
                                  });

                                  try {
                                    final shopId = context
                                        .read<AuthProvider>()
                                        .currentUser
                                        ?.shopId;
                                    await _firestoreService.updateProductStock(
                                      product.id,
                                      parsed,
                                      shopId: shopId,
                                    );

                                    if (!mounted) {
                                      return;
                                    }

                                    Navigator.of(sheetContext).pop();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '${product.name} stock updated to $parsed.',
                                        ),
                                      ),
                                    );
                                  } catch (e) {
                                    if (!mounted) {
                                      return;
                                    }

                                    setSheetState(() {
                                      isSaving = false;
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content:
                                            Text('Failed to update stock: $e'),
                                        backgroundColor:
                                            const Color(AppColors.error),
                                      ),
                                    );
                                  } finally {
                                    if (mounted) {
                                      setState(() {
                                        _updatingProductId = null;
                                      });
                                    }
                                  }
                                },
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child:
                              Text(isSaving ? 'Saving...' : 'Save Inventory'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      quantityController.dispose();
    }
  }

  Future<void> _showAddProductSheet(UserModel? currentUser) async {
    final nameCtrl = TextEditingController();
    final barcodeCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final stockCtrl = TextEditingController(text: '0');
    final categoryCtrl = TextEditingController();
    final descriptionCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var isSaving = false;

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(AppColors.white),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (sheetContext, setSheetState) {
              return SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    20,
                    20,
                    20 + MediaQuery.of(sheetContext).viewInsets.bottom,
                  ),
                  child: Form(
                    key: formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Add New Product',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                              IconButton(
                                onPressed: () =>
                                    Navigator.of(sheetContext).pop(),
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _AddProductField(
                            controller: nameCtrl,
                            label: 'Product Name',
                            hint: 'e.g. Organic Milk 1L',
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Name is required'
                                : null,
                          ),
                          const SizedBox(height: 14),
                          _AddProductField(
                            controller: barcodeCtrl,
                            label: 'Barcode / SKU',
                            hint: 'Scan or type barcode',
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Barcode is required'
                                : null,
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _AddProductField(
                                  controller: priceCtrl,
                                  label: 'Price',
                                  hint: '0.00',
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'Required';
                                    }
                                    final parsed = double.tryParse(v.trim());
                                    if (parsed == null || parsed < 0) {
                                      return 'Invalid';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _AddProductField(
                                  controller: stockCtrl,
                                  label: 'Stock Qty',
                                  hint: '0',
                                  keyboardType: TextInputType.number,
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'Required';
                                    }
                                    final parsed = int.tryParse(v.trim());
                                    if (parsed == null || parsed < 0) {
                                      return 'Invalid';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _AddProductField(
                            controller: categoryCtrl,
                            label: 'Category',
                            hint: 'e.g. Dairy, Electronics',
                          ),
                          const SizedBox(height: 14),
                          _AddProductField(
                            controller: descriptionCtrl,
                            label: 'Description (optional)',
                            hint: 'Brief product description',
                            maxLines: 2,
                          ),
                          const SizedBox(height: 22),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: isSaving
                                  ? null
                                  : () async {
                                      if (!formKey.currentState!.validate()) {
                                        return;
                                      }

                                      setSheetState(() => isSaving = true);

                                      final now = DateTime.now();
                                      final product = ProductModel(
                                        id: '',
                                        shopId: currentUser?.shopId,
                                        name: nameCtrl.text.trim(),
                                        barcode: barcodeCtrl.text.trim(),
                                        price:
                                            double.parse(priceCtrl.text.trim()),
                                        stock: int.parse(stockCtrl.text.trim()),
                                        category: categoryCtrl.text.trim(),
                                        description:
                                            descriptionCtrl.text.trim().isEmpty
                                                ? null
                                                : descriptionCtrl.text.trim(),
                                        createdAt: now,
                                        updatedAt: now,
                                      );

                                      try {
                                        await _firestoreService
                                            .createProduct(product);

                                        if (!mounted) return;
                                        Navigator.of(sheetContext).pop();
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              '${product.name} added to inventory.',
                                            ),
                                          ),
                                        );
                                      } catch (e) {
                                        if (!mounted) return;
                                        setSheetState(() => isSaving = false);
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                'Failed to add product: $e'),
                                            backgroundColor:
                                                const Color(AppColors.error),
                                          ),
                                        );
                                      }
                                    },
                              style: FilledButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                backgroundColor: const Color(AppColors.primary),
                              ),
                              child:
                                  Text(isSaving ? 'Adding...' : 'Add Product'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      nameCtrl.dispose();
      barcodeCtrl.dispose();
      priceCtrl.dispose();
      stockCtrl.dispose();
      categoryCtrl.dispose();
      descriptionCtrl.dispose();
    }
  }
}

class _InventoryProductCard extends StatelessWidget {
  const _InventoryProductCard({
    required this.product,
    required this.canAdjustInventory,
    required this.isUpdating,
    this.onAdjustStock,
  });

  final ProductModel product;
  final bool canAdjustInventory;
  final bool isUpdating;
  final VoidCallback? onAdjustStock;

  @override
  Widget build(BuildContext context) {
    final stockLabel = product.isOutOfStock
        ? 'Out of Stock'
        : product.isLowStock
            ? '${product.stock} units left'
            : '${product.stock} units';
    final stockColor = product.isOutOfStock
        ? const Color(AppColors.error)
        : product.isLowStock
            ? const Color(AppColors.orange)
            : const Color(AppColors.success);
    final badgeBackground = stockColor.withValues(alpha: 0.12);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(AppColors.white),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: product.isLowStock || product.isOutOfStock
              ? stockColor.withValues(alpha: 0.25)
              : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProductImage(product: product),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      product.category.isEmpty
                          ? 'Uncategorized'
                          : product.category,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(AppColors.greyDark),
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'SKU: ${product.barcode}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: const Color(0xFF9AA7BD),
                            letterSpacing: 0.2,
                          ),
                    ),
                  ],
                ),
              ),
              if (product.isLowStock || product.isOutOfStock)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: badgeBackground,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    product.isOutOfStock ? 'OUT OF STOCK' : 'LOW STOCK',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: stockColor,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '${product.stock}',
                            style: Theme.of(context)
                                .textTheme
                                .displayMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: const Color(AppColors.black),
                                ),
                          ),
                          TextSpan(
                            text: product.stock == 1 ? ' Unit' : ' Units',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: const Color(AppColors.greyDark),
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stockLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: stockColor,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    NumberFormat.currency(symbol: r'$', decimalDigits: 2)
                        .format(product.price),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: const Color(AppColors.primary),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Updated ${DateFormat('MMM d').format(product.updatedAt)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(AppColors.greyDark),
                        ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 1,
                  color: const Color(0xFFF0F2F7),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: stockColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          if (canAdjustInventory) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isUpdating ? null : onAdjustStock,
                icon: isUpdating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.inventory_2_outlined),
                label: Text(isUpdating ? 'Updating...' : 'Adjust Inventory'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.product});

  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4F9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          product.name.isEmpty ? 'P' : product.name[0].toUpperCase(),
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(AppColors.primary),
          ),
        ),
      ),
    );

    if (product.imageUrl == null || product.imageUrl!.isEmpty) {
      return fallback;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.network(
        product.imageUrl!,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }
}

class _InventoryStatCard extends StatelessWidget {
  const _InventoryStatCard({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(AppColors.white),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: const Color(AppColors.greyDark),
                  letterSpacing: 0.7,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: valueColor ?? const Color(AppColors.black),
                ),
          ),
        ],
      ),
    );
  }
}

class _InventorySummaryPanel extends StatelessWidget {
  const _InventorySummaryPanel({required this.summary});

  final _InventorySummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: const BoxDecoration(
        color: Color(AppColors.primary),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Inventory Summary',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: const Color(AppColors.white),
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SummaryMetric(
                  label: 'TOTAL ITEMS',
                  value:
                      NumberFormat.decimalPattern().format(summary.totalItems),
                ),
              ),
              Expanded(
                child: _SummaryMetric(
                  label: 'CRITICAL LOW',
                  value: NumberFormat.decimalPattern()
                      .format(summary.lowStockCount),
                ),
              ),
              Expanded(
                child: _SummaryMetric(
                  label: 'OUT OF STOCK',
                  value: NumberFormat.decimalPattern()
                      .format(summary.outOfStockCount),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: const Color(AppColors.white),
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: const Color(AppColors.white).withValues(alpha: 0.82),
                letterSpacing: 0.8,
                fontSize: 11,
              ),
        ),
      ],
    );
  }
}

class _InventoryEmptyState extends StatelessWidget {
  const _InventoryEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(AppColors.white),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5FF),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: Color(AppColors.primary),
              size: 32,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No products found',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Try a different search or filter, or add products to Firestore to populate this list.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(AppColors.greyDark),
                ),
          ),
        ],
      ),
    );
  }
}

class _InventorySummary {
  const _InventorySummary({
    required this.totalItems,
    required this.totalValue,
    required this.lowStockCount,
    required this.outOfStockCount,
    required this.latestUpdate,
  });

  final int totalItems;
  final double totalValue;
  final int lowStockCount;
  final int outOfStockCount;
  final DateTime? latestUpdate;

  String get totalValueLabel {
    if (totalValue >= 1000000) {
      return '\$${(totalValue / 1000000).toStringAsFixed(1)}M';
    }
    if (totalValue >= 1000) {
      return '\$${(totalValue / 1000).toStringAsFixed(1)}k';
    }
    return NumberFormat.currency(symbol: r'$', decimalDigits: 0)
        .format(totalValue);
  }

  String get lastUpdatedLabel {
    if (latestUpdate == null) {
      return 'No update history yet';
    }
    return 'Last updated ${DateFormat('MMM d, h:mm a').format(latestUpdate!)}';
  }

  factory _InventorySummary.fromProducts(List<ProductModel> products) {
    final totalItems =
        products.fold<int>(0, (sum, product) => sum + product.stock);
    final totalValue = products.fold<double>(
      0,
      (sum, product) => sum + (product.price * product.stock),
    );
    final latestUpdate = products.isEmpty
        ? null
        : products.map((product) => product.updatedAt).reduce(
              (current, next) => current.isAfter(next) ? current : next,
            );

    return _InventorySummary(
      totalItems: totalItems,
      totalValue: totalValue,
      lowStockCount: products.where((product) => product.isLowStock).length,
      outOfStockCount: products.where((product) => product.isOutOfStock).length,
      latestUpdate: latestUpdate,
    );
  }
}

class _AddProductField extends StatelessWidget {
  const _AddProductField({
    required this.controller,
    required this.label,
    required this.hint,
    this.validator,
    this.keyboardType,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF7F9FC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(AppColors.primary)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(AppColors.error)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(AppColors.error)),
        ),
      ),
    );
  }
}
