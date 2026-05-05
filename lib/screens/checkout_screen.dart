import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/cart_provider.dart';
import '../../models/transaction_model.dart';
import '../../services/firestore_service.dart';
import 'receipt_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({required this.transaction, Key? key}) : super(key: key);

  final TransactionModel transaction;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _firestoreService = FirestoreService();
  final _amountReceivedController = TextEditingController();

  bool _isSubmitting = false;

  bool get _isCashPayment =>
      widget.transaction.paymentMethod.toLowerCase() == 'cash';

  double get _amountReceived =>
      double.tryParse(_amountReceivedController.text.trim()) ?? 0;

  double get _changeAmount => _isCashPayment
      ? math.max(0, _amountReceived - widget.transaction.total)
      : 0;

  double get _remainingAmount => _isCashPayment
      ? math.max(0, widget.transaction.total - _amountReceived)
      : 0;

  @override
  void initState() {
    super.initState();
    if (!_isCashPayment) {
      _amountReceivedController.text =
          _formatInputValue(widget.transaction.total);
    }
  }

  @override
  void dispose() {
    _amountReceivedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTopBar(context),
                    const SizedBox(height: 24),
                    _buildHeroCard(context),
                    const SizedBox(height: 18),
                    _buildPaymentEntryCard(context),
                    const SizedBox(height: 18),
                    _buildItemsPreviewCard(context),
                  ],
                ),
              ),
            ),
            _buildBottomBar(context),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed:
              _isSubmitting ? null : () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          splashRadius: 20,
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Checkout',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                'Receive payment before printing the receipt.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(AppColors.greyDark),
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(AppColors.white),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F1FF),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _paymentIcon(widget.transaction.paymentMethod),
                  size: 18,
                  color: const Color(AppColors.primary),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.transaction.paymentMethod,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: const Color(AppColors.primary),
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Amount Due',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: const Color(AppColors.greyDark),
                  letterSpacing: 0.8,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            _currency(widget.transaction.total),
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(AppColors.primary),
                ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildInfoPill(context, 'Transaction', widget.transaction.id),
              _buildInfoPill(
                context,
                'Items',
                '${widget.transaction.itemCount} item${widget.transaction.itemCount == 1 ? '' : 's'}',
              ),
              _buildInfoPill(
                context,
                'Discount',
                widget.transaction.discount > 0
                    ? '-${_currency(widget.transaction.discount)}'
                    : 'None',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPill(BuildContext context, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FB),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(AppColors.greyDark),
                ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentEntryCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(AppColors.white),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isCashPayment ? 'Cash Received' : 'Payment Confirmation',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            _isCashPayment
                ? 'Enter how much the cashier received from the customer.'
                : 'This payment method does not require manual change computation.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(AppColors.greyDark),
                ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7FB),
              borderRadius: BorderRadius.circular(20),
            ),
            child: TextField(
              controller: _amountReceivedController,
              readOnly: !_isCashPayment,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: InputDecoration(
                border: InputBorder.none,
                labelText:
                    _isCashPayment ? 'Amount received' : 'Amount charged',
                prefixText: '\$',
                helperText: _isCashPayment
                    ? 'Receipt can be completed once the amount covers the total.'
                    : 'Recorded automatically using the transaction total.',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _buildAmountStatusCard(
                  context,
                  label: _isCashPayment ? 'Change' : 'Change',
                  value: _currency(_changeAmount),
                  accent: const Color(AppColors.success),
                  background: const Color(0xFFE7F8EF),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAmountStatusCard(
                  context,
                  label: _isCashPayment ? 'Remaining' : 'Status',
                  value: _isCashPayment ? _currency(_remainingAmount) : 'Ready',
                  accent: _isCashPayment && _remainingAmount > 0
                      ? const Color(AppColors.orange)
                      : const Color(AppColors.primary),
                  background: _isCashPayment && _remainingAmount > 0
                      ? const Color(0xFFFFF1E8)
                      : const Color(0xFFE8F1FF),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAmountStatusCard(
    BuildContext context, {
    required String label,
    required String value,
    required Color accent,
    required Color background,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF4B5667),
                ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsPreviewCard(BuildContext context) {
    final items = widget.transaction.items;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(AppColors.white),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Transaction Preview',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 14),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.productName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${item.quantity} x ${_currency(item.price)}',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: const Color(AppColors.greyDark),
                                  ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _currency(item.totalPrice),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 28),
          _buildTotalRow(
              context, 'Subtotal', _currency(widget.transaction.subtotal)),
          const SizedBox(height: 10),
          _buildTotalRow(
            context,
            'Discount',
            '-${_currency(widget.transaction.discount)}',
            valueColor: const Color(AppColors.orange),
          ),
          const SizedBox(height: 10),
          _buildTotalRow(
            context,
            'Total payable',
            _currency(widget.transaction.total),
            valueColor: const Color(AppColors.primary),
            emphasize: true,
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(
    BuildContext context,
    String label,
    String value, {
    Color? valueColor,
    bool emphasize = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFF374151),
                  fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
                ),
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: valueColor ?? const Color(0xFF111827),
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final canSubmit = !_isSubmitting &&
        (!_isCashPayment || _amountReceived >= widget.transaction.total);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(
        color: Color(0xFFF6F7FB),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 64,
        child: ElevatedButton(
          onPressed: canSubmit ? _completePayment : null,
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Confirm Payment',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(width: 10),
                    Icon(Icons.receipt_long_rounded),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _completePayment() async {
    FocusScope.of(context).unfocus();

    if (_isCashPayment && _amountReceived < widget.transaction.total) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Amount received must be equal to or greater than the total.'),
          backgroundColor: Color(AppColors.error),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final completedTransaction = widget.transaction.copyWith(
      status: TransactionStatus.completed,
      timestamp: DateTime.now(),
      amountReceived:
          _isCashPayment ? _amountReceived : widget.transaction.total,
      changeAmount: _isCashPayment ? _changeAmount : 0,
    );

    try {
      await _firestoreService.createTransaction(completedTransaction);

      for (final item in completedTransaction.items) {
        final product = await _firestoreService.getProductById(
          item.productId,
          shopId: completedTransaction.shopId,
        );
        if (product != null) {
          await _firestoreService.updateProductStock(
            item.productId,
            product.stock - item.quantity,
            shopId: completedTransaction.shopId,
          );
        }
      }

      context.read<CartProvider>().clear();

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ReceiptScreen(transaction: completedTransaction),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to complete checkout: $error'),
          backgroundColor: const Color(AppColors.error),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  String _currency(double amount) => '\$${amount.toStringAsFixed(2)}';

  String _formatInputValue(double amount) {
    if (amount == amount.roundToDouble()) {
      return amount.toStringAsFixed(0);
    }
    return amount.toStringAsFixed(2);
  }

  IconData _paymentIcon(String paymentMethod) {
    final normalized = paymentMethod.toLowerCase();
    if (normalized.contains('card')) {
      return Icons.credit_card_rounded;
    }
    if (normalized.contains('wallet')) {
      return Icons.account_balance_wallet_rounded;
    }
    return Icons.payments_rounded;
  }
}
