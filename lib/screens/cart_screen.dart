import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/auth_provider.dart';
import '../../core/utils/cart_provider.dart';
import '../../models/transaction_model.dart';
import '../../models/user_model.dart';
import 'checkout_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({Key? key}) : super(key: key);

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  static const List<_PaymentOption> _paymentOptions = [
    _PaymentOption('Cash', Icons.payments_rounded),
    _PaymentOption('Card', Icons.credit_card_rounded),
    _PaymentOption('E-Wallet', Icons.account_balance_wallet_rounded),
  ];

  final _discountController = TextEditingController(text: '0');

  bool _isProcessing = false;
  double _discountPercent = 0;
  String _selectedPaymentMethod = _paymentOptions.first.label;
  late final String _draftTransactionId;

  @override
  void initState() {
    super.initState();
    _draftTransactionId = _generateTransactionId();
  }

  @override
  void dispose() {
    _discountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        child: Consumer<CartProvider>(
          builder: (context, cartProvider, _) {
            final subtotal = cartProvider.subtotal;
            final discountAmount = _calculateDiscountAmount(subtotal);
            final total = math.max(0.0, subtotal - discountAmount);

            if (cartProvider.isEmpty) {
              return _buildEmptyState(context);
            }

            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTopBar(context, currentUser),
                        const SizedBox(height: 24),
                        _buildHeader(context),
                        const SizedBox(height: 24),
                        ...cartProvider.items.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child:
                                _buildCartItemCard(context, item, cartProvider),
                          ),
                        ),
                        _buildAddOrScanButton(context),
                        const SizedBox(height: 20),
                        _buildSummaryCard(
                          context,
                          cartProvider,
                          subtotal: subtotal,
                          discountAmount: discountAmount,
                          total: total,
                        ),
                        const SizedBox(height: 18),
                        _buildPaymentMethodCard(context),
                        const SizedBox(height: 20),
                        _buildQuickActions(context),
                      ],
                    ),
                  ),
                ),
                _buildBottomActions(context, cartProvider, total),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                color: Color(0xFFEAF1FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shopping_bag_outlined,
                size: 42,
                color: Color(AppColors.primary),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Current transaction is empty',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Scan or search for products to start a new checkout.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(AppColors.greyDark),
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('Back to scanner'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, UserModel? currentUser) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          splashRadius: 20,
        ),
        Text(
          'ShopScan',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const Spacer(),
        if (currentUser != null)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _roleLabel(currentUser.role).toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: const Color(AppColors.greyDark),
                        letterSpacing: 1.2,
                      ),
                ),
                Text(
                  _displayUserName(currentUser),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: const Color(AppColors.primary),
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        CircleAvatar(
          radius: 24,
          backgroundColor: const Color(0xFFE2ECFF),
          child: Text(
            _userInitials(currentUser?.name),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(AppColors.primary),
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final now = DateTime.now();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 420;
        final sessionBadge = Container(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 14 : 16,
            vertical: isCompact ? 10 : 14,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFCDE2FF),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            isCompact ? 'ACTIVE SESSION' : 'ACTIVE\nSESSION',
            textAlign: isCompact ? TextAlign.center : TextAlign.start,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  letterSpacing: 1.3,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF182436),
                ),
          ),
        );

        final details = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isCompact ? 'Current Transaction' : 'Current\nTransaction',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    height: 1.04,
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              'Transaction ID: #$_draftTransactionId',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF2F3747),
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              DateFormat('MMM d, h:mm a').format(now),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(AppColors.greyDark),
                  ),
            ),
          ],
        );

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              details,
              const SizedBox(height: 16),
              sessionBadge,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: details),
            const SizedBox(width: 16),
            sessionBadge,
          ],
        );
      },
    );
  }

  Widget _buildCartItemCard(
    BuildContext context,
    TransactionItemModel item,
    CartProvider cartProvider,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 430;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(AppColors.white),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: isCompact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildProductImage(item),
                        const SizedBox(width: 14),
                        Expanded(child: _buildItemDetails(context, item)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(child: _buildLineTotalPill(context, item)),
                        const SizedBox(width: 12),
                        _buildQuantityControl(context, item, cartProvider),
                      ],
                    ),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildProductImage(item),
                    const SizedBox(width: 18),
                    Expanded(child: _buildItemDetails(context, item)),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildQuantityControl(context, item, cartProvider),
                        const SizedBox(height: 12),
                        _buildLineTotalPill(context, item),
                      ],
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildItemDetails(BuildContext context, TransactionItemModel item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.productName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'SKU: ${item.sku}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(AppColors.greyDark),
                letterSpacing: 0.6,
              ),
        ),
        const SizedBox(height: 10),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: 10,
          runSpacing: 6,
          children: [
            Text(
              _currency(item.price),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: const Color(AppColors.primary),
                    fontWeight: FontWeight.w700,
                  ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                'per unit',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(AppColors.greyDark),
                    ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLineTotalPill(BuildContext context, TransactionItemModel item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8FF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Line total',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(AppColors.greyDark),
                ),
          ),
          const SizedBox(height: 2),
          Text(
            _currency(item.subtotal),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF111827),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductImage(TransactionItemModel item) {
    final imageUrl = item.imageUrl?.trim();

    return Container(
      width: 82,
      height: 82,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F7),
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl != null && imageUrl.isNotEmpty
          ? Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildProductImageFallback(),
            )
          : _buildProductImageFallback(),
    );
  }

  Widget _buildProductImageFallback() {
    return const Center(
      child: Icon(
        Icons.inventory_2_rounded,
        size: 34,
        color: Color(0xFF8A94A6),
      ),
    );
  }

  Widget _buildQuantityControl(
    BuildContext context,
    TransactionItemModel item,
    CartProvider cartProvider,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7FB),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _QuantityButton(
            icon: Icons.remove,
            onTap: () =>
                cartProvider.updateQuantity(item.productId, item.quantity - 1),
          ),
          SizedBox(
            width: 54,
            child: Text(
              item.quantity.toString().padLeft(2, '0'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          _QuantityButton(
            icon: Icons.add,
            onTap: () =>
                cartProvider.updateQuantity(item.productId, item.quantity + 1),
          ),
        ],
      ),
    );
  }

  Widget _buildAddOrScanButton(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => Navigator.of(context).maybePop(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFBFCBE1),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.add_circle,
              color: Color(0xFF536176),
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              'Add or Scan Another Product',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF1E2430),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    CartProvider cartProvider, {
    required double subtotal,
    required double discountAmount,
    required double total,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(AppColors.white),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Transaction Summary',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 18),
          _buildSummaryRow(
            context,
            'Subtotal (${cartProvider.itemCount} items)',
            _currency(subtotal),
          ),
          const SizedBox(height: 14),
          _buildDiscountInputRow(context),
          const SizedBox(height: 14),
          _buildSummaryRow(
            context,
            'Store Discount',
            '-${_currency(discountAmount)}',
            valueColor: const Color(AppColors.orange),
            caption: _discountPercent > 0
                ? '${_formatDiscountPercent(_discountPercent)} off'
                : 'No discount applied',
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
            decoration: BoxDecoration(
              color: const Color(AppColors.white),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
              border: const Border(
                left: BorderSide(
                  color: Color(AppColors.primary),
                  width: 6,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TOTAL AMOUNT PAYABLE',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        letterSpacing: 1.1,
                        color: const Color(0xFF4B5667),
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  _currency(total),
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontSize: 42,
                        fontWeight: FontWeight.w700,
                        color: const Color(AppColors.primary),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscountInputRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Discount Percentage',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                'Use percentage-based discount instead of tax.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(AppColors.greyDark),
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Container(
          width: 116,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F4FA),
            borderRadius: BorderRadius.circular(16),
          ),
          child: TextField(
            controller: _discountController,
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: const InputDecoration(
              border: InputBorder.none,
              suffixText: '%',
            ),
            onChanged: _handleDiscountChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(
    BuildContext context,
    String label,
    String value, {
    Color? valueColor,
    String? caption,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFF374151),
                    ),
              ),
              if (caption != null) ...[
                const SizedBox(height: 2),
                Text(
                  caption,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(AppColors.greyDark),
                      ),
                ),
              ],
            ],
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: valueColor ?? const Color(0xFF111827),
              ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(AppColors.white),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Method',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Select how the customer is paying for this transaction.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(AppColors.greyDark),
                ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _paymentOptions
                .map((option) => _buildPaymentChip(context, option))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentChip(BuildContext context, _PaymentOption option) {
    final isSelected = _selectedPaymentMethod == option.label;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        setState(() {
          _selectedPaymentMethod = option.label;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE8F1FF) : const Color(0xFFF5F7FB),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(AppColors.primary)
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              option.icon,
              color: isSelected
                  ? const Color(AppColors.primary)
                  : const Color(0xFF526173),
            ),
            const SizedBox(width: 10),
            Text(
              option.label,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF182230),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Park transaction is coming soon.')),
          );
        },
        icon: const Icon(Icons.inventory_2_outlined),
        label: const Text('Park Transaction'),
      ),
    );
  }

  Widget _buildBottomActions(
    BuildContext context,
    CartProvider cartProvider,
    double total,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(
        color: Color(0xFFF6F7FB),
      ),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: _isProcessing
                ? null
                : () => _confirmCancel(context, cartProvider),
            icon:
                const Icon(Icons.close_rounded, color: Color(AppColors.error)),
            label: const Text(
              AppStrings.cancel,
              style: TextStyle(color: Color(AppColors.error)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: SizedBox(
              height: 64,
              child: ElevatedButton(
                onPressed: _isProcessing
                    ? null
                    : () => _processCheckout(cartProvider, total),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: _isProcessing
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            AppStrings.checkout,
                            style: TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w700),
                          ),
                          SizedBox(width: 10),
                          Icon(Icons.arrow_forward_rounded),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmCancel(
      BuildContext context, CartProvider cartProvider) async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cancel current transaction?'),
          content: const Text(
            'This will remove all scanned items from the cart.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Keep Editing'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Clear Cart'),
            ),
          ],
        );
      },
    );

    if (shouldClear == true) {
      cartProvider.clear();
      if (mounted) {
        Navigator.of(context).maybePop();
      }
    }
  }

  Future<void> _processCheckout(CartProvider cartProvider, double total) async {
    if (_isProcessing || cartProvider.isEmpty) {
      return;
    }

    final currentUser = context.read<AuthProvider>().currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('You must be signed in to complete checkout.')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    final subtotal = cartProvider.subtotal;
    final discountAmount = _calculateDiscountAmount(subtotal);
    final transaction = TransactionModel(
      id: _draftTransactionId,
      shopId: currentUser.shopId,
      cashierId: currentUser.id,
      cashierName: _displayUserName(currentUser),
      items: cartProvider.items.map((item) => item.copyWith()).toList(),
      subtotal: subtotal,
      tax: 0,
      discount: discountAmount,
      discountPercent: _discountPercent,
      total: total,
      status: TransactionStatus.pending,
      timestamp: DateTime.now(),
      paymentMethod: _selectedPaymentMethod,
    );

    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CheckoutScreen(transaction: transaction),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _handleDiscountChanged(String value) {
    final parsed = double.tryParse(value) ?? 0;
    final clamped = parsed.clamp(0, 100).toDouble();

    if (clamped != parsed) {
      final normalized = _formatControllerValue(clamped);
      _discountController.value = TextEditingValue(
        text: normalized,
        selection: TextSelection.collapsed(offset: normalized.length),
      );
    }

    setState(() {
      _discountPercent = clamped;
    });
  }

  double _calculateDiscountAmount(double subtotal) {
    return subtotal * (_discountPercent / 100);
  }

  String _formatControllerValue(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }

  String _formatDiscountPercent(double value) {
    if (value == value.roundToDouble()) {
      return '${value.toStringAsFixed(0)}%';
    }
    return '${value.toStringAsFixed(1)}%';
  }

  String _currency(double amount) => '\$${amount.toStringAsFixed(2)}';

  String _generateTransactionId() {
    final stamp = DateTime.now().millisecondsSinceEpoch.toString();
    final suffix = stamp.substring(math.max(0, stamp.length - 7));
    return 'SHP-$suffix';
  }

  String _displayUserName(UserModel? user) {
    final name = user?.name.trim() ?? '';
    if (name.isNotEmpty) {
      return name;
    }
    return 'Cashier';
  }

  String _roleLabel(UserRole role) {
    return role.toString().split('.').last;
  }

  String _userInitials(String? name) {
    final cleaned = (name ?? '').trim();
    if (cleaned.isEmpty) {
      return 'SS';
    }
    final parts = cleaned.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first
          .substring(0, math.min(2, parts.first.length))
          .toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

class _PaymentOption {
  const _PaymentOption(this.label, this.icon);

  final String label;
  final IconData icon;
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: const Color(AppColors.white),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, size: 18, color: const Color(0xFF313949)),
      ),
    );
  }
}
