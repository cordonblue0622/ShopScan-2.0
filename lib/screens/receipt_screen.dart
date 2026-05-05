import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_constants.dart';
import '../../models/transaction_model.dart';

class ReceiptScreen extends StatefulWidget {
  const ReceiptScreen({required this.transaction, Key? key}) : super(key: key);

  final TransactionModel transaction;

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  bool _isPrinting = false;
  bool _isSharing = false;

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F7FB),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSuccessHeader(context),
                      const SizedBox(height: 18),
                      _buildReceiptCard(context),
                      const SizedBox(height: 18),
                      _buildPaymentCard(context),
                    ],
                  ),
                ),
              ),
              _buildBottomActions(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(AppColors.primary),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: const Color(AppColors.primary).withOpacity(0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: const Color(AppColors.white).withOpacity(0.16),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Color(AppColors.white),
              size: 34,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            AppStrings.paymentSuccessful,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: const Color(AppColors.white),
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Receipt ${widget.transaction.id} is ready for the customer.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: const Color(AppColors.white).withOpacity(0.9),
                ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildHeaderPill(
                context,
                Icons.schedule_rounded,
                DateFormat('MMM d, y • h:mm a')
                    .format(widget.transaction.timestamp),
              ),
              _buildHeaderPill(
                context,
                _paymentIcon(widget.transaction.paymentMethod),
                widget.transaction.paymentMethod,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderPill(BuildContext context, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(AppColors.white).withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(AppColors.white)),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: const Color(AppColors.white),
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptCard(BuildContext context) {
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
          Row(
            children: [
              Expanded(
                child: Text(
                  AppStrings.receipt,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              Text(
                '${widget.transaction.itemCount} item${widget.transaction.itemCount == 1 ? '' : 's'}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(AppColors.greyDark),
                    ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...widget.transaction.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
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
                        const SizedBox(height: 4),
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
          _buildSummaryRow(context, AppStrings.subtotal,
              _currency(widget.transaction.subtotal)),
          const SizedBox(height: 10),
          _buildSummaryRow(
            context,
            AppStrings.discount,
            '-${_currency(widget.transaction.discount)}',
            valueColor: const Color(AppColors.orange),
            caption: widget.transaction.discountPercent > 0
                ? '${_formatDiscountPercent(widget.transaction.discountPercent)} off applied'
                : null,
          ),
          const SizedBox(height: 10),
          _buildSummaryRow(
            context,
            AppStrings.total,
            _currency(widget.transaction.total),
            valueColor: const Color(AppColors.primary),
            emphasize: true,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(BuildContext context) {
    final amountReceived =
        widget.transaction.amountReceived ?? widget.transaction.total;
    final changeAmount = widget.transaction.changeAmount ?? 0;

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
            'Payment Details',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 16),
          _buildSummaryRow(
              context, 'Payment method', widget.transaction.paymentMethod),
          const SizedBox(height: 10),
          _buildSummaryRow(
              context, 'Amount received', _currency(amountReceived)),
          const SizedBox(height: 10),
          _buildSummaryRow(
            context,
            'Change',
            _currency(changeAmount),
            valueColor: const Color(AppColors.success),
          ),
          const SizedBox(height: 10),
          _buildSummaryRow(context, 'Cashier', widget.transaction.cashierName),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    BuildContext context,
    String label,
    String value, {
    Color? valueColor,
    String? caption,
    bool emphasize = false,
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
                      fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
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
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: valueColor ?? const Color(0xFF111827),
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(
        color: Color(0xFFF6F7FB),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isPrinting ? null : _printReceipt,
                  icon: _isPrinting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.print_outlined),
                  label: const Text(AppStrings.printReceipt),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSharing ? null : _shareReceipt,
                  icon: _isSharing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.ios_share_rounded),
                  label: const Text(AppStrings.shareExport),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: _finishCheckout,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                AppStrings.done,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _printReceipt() async {
    setState(() {
      _isPrinting = true;
    });

    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) {
      return;
    }

    setState(() {
      _isPrinting = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Receipt sent to printer.'),
        backgroundColor: Color(AppColors.success),
      ),
    );
  }

  Future<void> _shareReceipt() async {
    setState(() {
      _isSharing = true;
    });

    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) {
      return;
    }

    setState(() {
      _isSharing = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share/export is ready for integration.')),
    );
  }

  void _finishCheckout() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  String _currency(double amount) => '\$${amount.toStringAsFixed(2)}';

  String _formatDiscountPercent(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
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
