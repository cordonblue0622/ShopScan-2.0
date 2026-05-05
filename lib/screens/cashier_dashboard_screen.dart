import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../core/constants/app_constants.dart';
import 'scan_screen.dart';
import 'cart_screen.dart';
import 'sales_history_screen.dart';
import 'inventory_screen.dart';
import 'package:provider/provider.dart';
import '../core/utils/cart_provider.dart';
import '../core/utils/auth_provider.dart';
import '../models/approval_request_model.dart';
import '../models/shift_model.dart';
import '../models/transaction_model.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../widgets/approval_notification_button.dart';

class CashierDashboardScreen extends StatefulWidget {
  const CashierDashboardScreen({Key? key}) : super(key: key);

  @override
  State<CashierDashboardScreen> createState() => _CashierDashboardScreenState();
}

class _CashierDashboardScreenState extends State<CashierDashboardScreen> {
  int _selectedIndex = 0;
  final _firestoreService = FirestoreService();

  // Cache streams so they don't re-subscribe on rebuilds
  Stream<List<ShiftModel>>? _shiftStream;
  String? _shiftStreamCashierId;

  Stream<List<ShiftModel>> _getShiftStream(String cashierId) {
    if (_shiftStream == null || _shiftStreamCashierId != cashierId) {
      _shiftStreamCashierId = cashierId;
      _shiftStream =
          _firestoreService.getShiftsByCashierStream(cashierId);
    }
    return _shiftStream!;
  }

  Stream<List<TransactionModel>>? _txStream;
  String? _txStreamCashierId;

  Stream<List<TransactionModel>> _getTxStream(String cashierId) {
    if (_txStream == null || _txStreamCashierId != cashierId) {
      _txStreamCashierId = cashierId;
      _txStream =
          _firestoreService.getTransactionsByCashierStream(cashierId);
    }
    return _txStream!;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'ShopScan',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        elevation: 0,
        actions: [
          if (currentUser != null) ...[
            ApprovalNotificationButton(user: currentUser),
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5FF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _displayUserLabel(currentUser, fallback: 'Cashier'),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: const Color(AppColors.primary),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: _buildContent(),
      ),
      bottomNavigationBar: _buildCashierNavBar(),
      floatingActionButton: _buildCartFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildHomeScreen();
      case 1:
        return const ScanScreen();
      case 2:
        return const SalesHistoryScreen();
      case 3:
        return const InventoryScreen();
      case 4:
        return _buildProfileScreen();
      default:
        return _buildHomeScreen();
    }
  }

  String _displayUserLabel(UserModel? user, {required String fallback}) {
    final name = user?.name.trim() ?? '';
    return name.isEmpty ? fallback : name;
  }

  Future<void> _requestPasswordResetApproval(UserModel user) async {
    final messenger = ScaffoldMessenger.of(context);
    final shopId = user.shopId;

    if (shopId == null || shopId.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Your shop assignment is missing.')),
      );
      return;
    }

    try {
      final shop = await _firestoreService.getShopById(shopId);
      final approverId = shop?.ownerId ?? '';

      if (approverId.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('No owner approval route is configured yet.')),
        );
        return;
      }

      final hasPending = await _firestoreService.hasPendingApprovalRequest(
        requesterId: user.id,
        type: 'password_reset',
      );

      if (hasPending) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('You already have a pending password reset request.'),
          ),
        );
        return;
      }

      final requesterName = _displayUserLabel(user, fallback: 'Cashier');
      final request = ApprovalRequestModel(
        id: '',
        shopId: shopId,
        requesterId: user.id,
        requesterName: requesterName,
        requesterEmail: user.email,
        requesterRole: user.role,
        approverId: approverId,
        type: 'password_reset',
        message: '$requesterName requested approval to reset their password.',
        status: ApprovalRequestStatus.pending,
        createdAt: DateTime.now(),
      );

      await _firestoreService.createApprovalRequest(request);

      if (!mounted) {
        return;
      }

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Password reset request sent to the shop owner.'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to send request: $error')),
      );
    }
  }

  Widget _buildHomeScreen() {
    final currentUser = context.watch<AuthProvider>().currentUser;
    return Padding(
      padding: const EdgeInsets.all(AppDimens.paddingMedium),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _WelcomeBanner(
              name: currentUser?.name,
              role: 'Cashier',
              email: currentUser?.email,
            ),
            const SizedBox(height: AppDimens.paddingMedium),
            _buildShiftStatus(currentUser?.id),
            const SizedBox(height: AppDimens.paddingXLarge),
            _buildQuickActions(),
            const SizedBox(height: AppDimens.paddingXLarge),
            _buildDailySummary(),
            const SizedBox(height: AppDimens.paddingXLarge),
            _buildRecentLogs(),
          ],
        ),
      ),
    );
  }

  // ─── Shift status ──────────────────────────────────────────────

  Widget _buildShiftStatus(String? cashierId) {
    if (cashierId == null || cashierId.isEmpty) {
      return _buildOfflineShiftCard(null);
    }

    return StreamBuilder<List<ShiftModel>>(
      stream: _getShiftStream(cashierId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(AppDimens.paddingMedium),
            decoration: BoxDecoration(
              color: const Color(AppColors.white),
              borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
              border: Border.all(color: const Color(AppColors.borderColor)),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          // Show offline card instead of error — the index may still be building
          return _buildOfflineShiftCard(cashierId);
        }

        final activeShift =
            (snapshot.data ?? <ShiftModel>[]).cast<ShiftModel?>().firstWhere(
                  (s) => s?.status == ShiftStatus.active,
                  orElse: () => null,
                );

        if (activeShift == null) {
          return _buildOfflineShiftCard(cashierId);
        }

        return _buildOnShiftCard(activeShift);
      },
    );
  }

  Widget _buildOfflineShiftCard(String? cashierId) {
    return _buildShiftCard(
      badgeLabel: 'Offline',
      badgeColor: const Color(AppColors.greyDark),
      badgeBackground: const Color(0xFFF1F3F6),
      title: 'No active shift',
      subtitle: 'You are offline until you start your shift.',
      actionLabel: 'Start Shift',
      actionColor: const Color(AppColors.primary),
      onAction: cashierId != null ? () => _confirmStartShift(cashierId) : null,
    );
  }

  Widget _buildShiftCard({
    required String badgeLabel,
    required Color badgeColor,
    required Color badgeBackground,
    required String title,
    required String subtitle,
    required String actionLabel,
    required Color actionColor,
    VoidCallback? onAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.paddingMedium),
      decoration: BoxDecoration(
        color: const Color(AppColors.white),
        borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
        border: Border.all(color: const Color(AppColors.borderColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimens.paddingSmall,
                        vertical: AppDimens.paddingXSmall,
                      ),
                      decoration: BoxDecoration(
                        color: badgeBackground,
                        borderRadius:
                            BorderRadius.circular(AppDimens.radiusSmall),
                      ),
                      child: Text(
                        badgeLabel,
                        style:
                            Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: badgeColor,
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                    ),
                    const SizedBox(height: AppDimens.paddingSmall),
                    Text(
                      title,
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(AppColors.greyDark),
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.paddingMedium),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: actionColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Shift confirm dialogs ─────────────────────────────────────

  Widget _buildOnShiftCard(ShiftModel activeShift) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.paddingMedium),
      decoration: BoxDecoration(
        color: const Color(AppColors.white),
        borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
        border: Border.all(color: const Color(AppColors.borderColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.paddingSmall,
                  vertical: AppDimens.paddingXSmall,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F8F0),
                  borderRadius: BorderRadius.circular(AppDimens.radiusSmall),
                ),
                child: Text(
                  'On Shift',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: const Color(AppColors.success),
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.paddingSmall),
          _ShiftElapsedTimer(startTime: activeShift.startTime),
          const SizedBox(height: 2),
          Text(
            'Started at ${DateFormat('hh:mm a').format(activeShift.startTime)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(AppColors.greyDark),
                ),
          ),
          const SizedBox(height: AppDimens.paddingMedium),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => _confirmEndShift(activeShift),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(AppColors.error),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('End Shift'),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Shift confirm dialogs (actual) ────────────────────────────

  Future<void> _confirmStartShift(String cashierId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Start Shift'),
        content:
            const Text('Are you sure you want to start your shift now?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Start'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final shift = ShiftModel(
        id: '',
        cashierId: cashierId,
        startTime: DateTime.now(),
        status: ShiftStatus.active,
      );
      await _firestoreService.createShift(shift);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shift started successfully'),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start shift: $e')),
        );
      }
    }
  }

  Future<void> _confirmEndShift(ShiftModel shift) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End Shift'),
        content: const Text(
            'Are you sure you want to end your current shift?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(AppColors.error),
            ),
            child: const Text('End Shift'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _firestoreService.endShift(shift.id, DateTime.now());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shift ended successfully'),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to end shift: $e')),
        );
      }
    }
  }

  // ─── Quick actions ─────────────────────────────────────────────

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                icon: Icons.qr_code_2,
                label: 'Scan Product',
                onTap: () {
                  setState(() {
                    _selectedIndex = 1;
                  });
                },
              ),
            ),
            const SizedBox(width: AppDimens.paddingMedium),
            Expanded(
              child: _buildActionCard(
                icon: Icons.shopping_cart,
                label: 'New Sale',
                color: const Color(AppColors.orange),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const CartScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimens.paddingMedium),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                icon: Icons.inventory_2_outlined,
                label: 'Update Stock',
                onTap: () {
                  setState(() {
                    _selectedIndex = 3;
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppDimens.paddingMedium),
        decoration: BoxDecoration(
          color: color ?? const Color(AppColors.primary),
          borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(AppColors.white), size: 32),
            const SizedBox(height: AppDimens.paddingSmall),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailySummary() {
    final currentUser = context.watch<AuthProvider>().currentUser;
    final cashierId = currentUser?.id;
    if (cashierId == null) {
      return const SizedBox.shrink();
    }

    final todayStart = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Daily Summary',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppDimens.paddingMedium),
        StreamBuilder<List<TransactionModel>>(
          stream:
              _firestoreService.getTransactionsByCashierStream(cashierId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final allTx = snapshot.data ?? [];
            final todayTx = allTx
                .where((tx) => tx.timestamp.isAfter(todayStart))
                .toList();

            final netSales = todayTx.fold<double>(
              0,
              (sum, tx) => sum + tx.total,
            );
            final txCount = todayTx.length;

            return Column(
              children: [
                _buildSummaryItem(
                  'Net Sales',
                  '₱${netSales.toStringAsFixed(2)}',
                ),
                const SizedBox(height: AppDimens.paddingSmall),
                _buildSummaryItem(
                  'Total Transactions',
                  '$txCount',
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildSummaryItem(String label, String value, [String? badge]) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.paddingMedium),
      decoration: BoxDecoration(
        color: const Color(AppColors.white),
        borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
        border: Border.all(color: const Color(AppColors.borderColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: const Color(AppColors.greyDark)),
              ),
              const SizedBox(height: AppDimens.paddingXSmall),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
          if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.paddingSmall,
                vertical: AppDimens.paddingXSmall,
              ),
              decoration: BoxDecoration(
                color: const Color(AppColors.success).withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppDimens.radiusSmall),
              ),
              child: Text(
                badge,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: const Color(AppColors.success),
                    ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRecentLogs() {
    final currentUser = context.watch<AuthProvider>().currentUser;
    final cashierId = currentUser?.id;
    if (cashierId == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Logs',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppDimens.paddingMedium),
        StreamBuilder<List<TransactionModel>>(
          stream:
              _firestoreService.getTransactionsByCashierStream(cashierId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final transactions = snapshot.data ?? [];
            if (transactions.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(AppDimens.paddingMedium),
                decoration: BoxDecoration(
                  color: const Color(AppColors.white),
                  borderRadius:
                      BorderRadius.circular(AppDimens.radiusLarge),
                  border: Border.all(
                      color: const Color(AppColors.borderColor)),
                ),
                child: Center(
                  child: Text(
                    'No transactions yet',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(AppColors.greyDark),
                        ),
                  ),
                ),
              );
            }

            final recent = transactions.take(5).toList();
            return Column(
              children: recent.map((tx) {
                final itemCount =
                    tx.items.fold<int>(0, (sum, i) => sum + i.quantity);
                final time = DateFormat('hh:mm a').format(tx.timestamp);
                return Padding(
                  padding: const EdgeInsets.only(
                      bottom: AppDimens.paddingSmall),
                  child: _buildLogItem(
                    tx.items.isNotEmpty
                        ? tx.items.first.productName
                        : 'Sale',
                    '$time • $itemCount item${itemCount == 1 ? '' : 's'}',
                    '₱${tx.total.toStringAsFixed(2)}',
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLogItem(String title, String subtitle, String amount) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.paddingMedium),
      decoration: BoxDecoration(
        color: const Color(AppColors.white),
        borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
        border: Border.all(color: const Color(AppColors.borderColor)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(AppColors.primary).withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
            ),
            child: const Icon(
              Icons.shopping_bag,
              color: Color(AppColors.primary),
            ),
          ),
          const SizedBox(width: AppDimens.paddingMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodyMedium),
                Text(
                  subtitle,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: const Color(AppColors.greyDark)),
                ),
              ],
            ),
          ),
          Text(amount, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }

  Widget _buildCartFab() {
    return Consumer<CartProvider>(
      builder: (context, cartProvider, _) {
        if (cartProvider.items.isEmpty) {
          return const SizedBox.shrink();
        }

        return FloatingActionButton.extended(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const CartScreen(),
              ),
            );
          },
          icon: const Icon(Icons.shopping_cart),
          label: Text('${cartProvider.items.length}'),
          backgroundColor: const Color(AppColors.primary),
          elevation: 8,
        );
      },
    );
  }

  Widget _buildCashierNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(AppColors.white),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: const Color(AppColors.primary).withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.home_rounded, 'Home', 0),
          _navItem(Icons.qr_code_scanner_rounded, 'Scan', 1),
          _navItem(Icons.receipt_long_rounded, 'Sales', 2),
          _navItem(Icons.inventory_2_rounded, 'Stocks', 3),
          _navItem(Icons.person_rounded, 'Profile', 4),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(AppColors.primary).withOpacity(0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? const Color(AppColors.primary)
                  : const Color(AppColors.greyDark),
              size: 26,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? const Color(AppColors.primary)
                    : const Color(AppColors.greyDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileScreen() {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;
    final shopId = user?.shopId;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimens.paddingMedium),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // ── Avatar + name + role badge ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: const Color(AppColors.white),
              borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
              border: Border.all(color: const Color(AppColors.borderColor)),
            ),
            child: Column(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor:
                          const Color(AppColors.primary).withOpacity(0.1),
                      backgroundImage: user?.photoUrl != null
                          ? NetworkImage(user!.photoUrl!)
                          : null,
                      child: user?.photoUrl == null
                          ? Text(
                              (user?.name ?? 'C')
                                  .substring(0, 1)
                                  .toUpperCase(),
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineLarge
                                  ?.copyWith(
                                    color: const Color(AppColors.primary),
                                    fontWeight: FontWeight.w700,
                                  ),
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.verified,
                            color: Color(AppColors.primary), size: 22),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  user?.name ?? 'Cashier',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F3F6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Cashier',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF5A6170),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Store Information ──
          if (shopId != null && shopId.isNotEmpty)
            _StoreInfoCard(shopId: shopId),

          const SizedBox(height: 16),

          // ── Personal Information ──
          _profileTile(
            icon: Icons.badge_outlined,
            iconColor: const Color(AppColors.primary),
            title: 'Personal Information',
            subtitle: 'View-only profile details',
            onTap: () => _showPersonalInfo(user),
          ),

          const SizedBox(height: 12),

          // ── Security Access ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(AppColors.white),
              borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
              border:
                  Border.all(color: const Color(AppColors.borderColor)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(AppColors.error).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.security_rounded,
                          color: Color(AppColors.error), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Security Access',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Sends a request to the shop owner for security protocols.',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                    color: const Color(AppColors.greyDark)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: user == null
                        ? null
                        : () => _requestPasswordResetApproval(user),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(AppColors.error),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Request Password Reset'),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Preferences header ──
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'PREFERENCES',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(AppColors.greyDark),
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 10),

          Container(
            decoration: BoxDecoration(
              color: const Color(AppColors.white),
              borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
              border:
                  Border.all(color: const Color(AppColors.borderColor)),
            ),
            child: Column(
              children: [
                // Notifications toggle
                ListTile(
                  leading: const Icon(Icons.notifications_rounded,
                      color: Color(AppColors.primary)),
                  title: const Text('Notifications'),
                  trailing: Switch(
                    value: user?.notificationsEnabled ?? true,
                    onChanged: (_) {
                      // Preference toggle placeholder
                    },
                    activeThumbColor: const Color(AppColors.primary),
                  ),
                ),
                const Divider(height: 1),
                // Theme / Appearance
                ListTile(
                  leading: const Icon(Icons.palette_rounded,
                      color: Color(AppColors.primary)),
                  title: const Text('Theme/Appearance'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        user?.appearanceMode ?? 'Light',
                        style: const TextStyle(
                            color: Color(AppColors.greyDark)),
                      ),
                      const Icon(Icons.keyboard_arrow_down,
                          color: Color(AppColors.greyDark)),
                    ],
                  ),
                  onTap: () {},
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Shift History ──
          if (user != null)
            _ShiftHistorySection(cashierId: user.id),

          const SizedBox(height: 24),

          // ── Sign out ──
          GestureDetector(
            onTap: () async {
              await authProvider.signOut();
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout,
                    color: Color(AppColors.error), size: 20),
                SizedBox(width: 8),
                Text(
                  'SIGN OUT',
                  style: TextStyle(
                    color: Color(AppColors.error),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _profileTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(AppColors.white),
          borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
          border: Border.all(color: const Color(AppColors.borderColor)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(AppColors.greyDark))),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: Color(AppColors.greyDark)),
          ],
        ),
      ),
    );
  }

  void _showPersonalInfo(UserModel? user) {
    if (user == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(AppColors.white),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Personal Information',
                style: Theme.of(ctx)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            _infoRow('Full Name', user.name),
            _infoRow('Email', user.email),
            _infoRow('Role', 'Cashier'),
            if (user.assignedShiftLabel != null)
              _infoRow('Shift', user.assignedShiftLabel!),
            if (user.assignedShiftStart != null)
              _infoRow('Shift Hours',
                  '${user.assignedShiftStart} – ${user.assignedShiftEnd ?? ''}'),
            _infoRow(
                'Joined', DateFormat('MMM d, yyyy').format(user.createdAt)),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(AppColors.greyDark),
                )),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Self-contained elapsed timer so it doesn't rebuild parent widget
// ═══════════════════════════════════════════════════════════════════

class _ShiftElapsedTimer extends StatefulWidget {
  final DateTime startTime;
  const _ShiftElapsedTimer({required this.startTime});

  @override
  State<_ShiftElapsedTimer> createState() => _ShiftElapsedTimerState();
}

class _ShiftElapsedTimerState extends State<_ShiftElapsedTimer> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(widget.startTime);
    final h = elapsed.inHours.toString().padLeft(2, '0');
    final m = (elapsed.inMinutes % 60).toString().padLeft(2, '0');
    final s = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return Text(
      '$h:$m:$s',
      style: Theme.of(context)
          .textTheme
          .headlineMedium
          ?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Store info card — fetches shop + owner data via REST on web
// ═══════════════════════════════════════════════════════════════════

class _StoreInfoCard extends StatefulWidget {
  final String shopId;
  const _StoreInfoCard({required this.shopId});

  @override
  State<_StoreInfoCard> createState() => _StoreInfoCardState();
}

class _StoreInfoCardState extends State<_StoreInfoCard> {
  String _storeName = 'Loading...';
  String _location = '';
  String _ownerId = '';
  String _ownerName = '';

  @override
  void initState() {
    super.initState();
    _fetchShopData();
  }

  Future<void> _fetchShopData() async {
    try {
      if (kIsWeb) {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;
        final idToken = await user.getIdToken(true);
        final projectId = Firebase.app().options.projectId;

        // Fetch shop document
        final shopUri = Uri.parse(
          'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/shops/${widget.shopId}',
        );
        final shopRes = await http.get(shopUri, headers: {
          'Authorization': 'Bearer $idToken',
        });
        if (shopRes.statusCode == 200) {
          final decoded = jsonDecode(shopRes.body) as Map<String, dynamic>;
          final fields = decoded['fields'] as Map<String, dynamic>? ?? {};
          final name = fields['name']?['stringValue'] as String? ?? 'Unknown Store';
          final addr = fields['address']?['stringValue'] as String? ?? '';
          final oid = fields['ownerId']?['stringValue'] as String? ?? '';
          if (mounted) {
            setState(() {
              _storeName = name;
              _location = addr.isEmpty ? 'Not set' : addr;
              _ownerId = oid;
            });
          }

          // Fetch owner name
          if (oid.isNotEmpty) {
            final ownerUri = Uri.parse(
              'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/users/$oid',
            );
            final ownerRes = await http.get(ownerUri, headers: {
              'Authorization': 'Bearer $idToken',
            });
            if (ownerRes.statusCode == 200) {
              final ownerDecoded = jsonDecode(ownerRes.body) as Map<String, dynamic>;
              final ownerFields = ownerDecoded['fields'] as Map<String, dynamic>? ?? {};
              final ownerName = ownerFields['name']?['stringValue'] as String? ?? 'Unknown';
              if (mounted) setState(() => _ownerName = ownerName);
            } else {
              if (mounted) setState(() => _ownerName = 'Unavailable');
            }
          }
        }
      } else {
        final doc = await FirebaseFirestore.instance
            .collection('shops')
            .doc(widget.shopId)
            .get();
        if (doc.exists) {
          final data = doc.data() ?? {};
          final oid = data['ownerId'] ?? '';
          if (mounted) {
            setState(() {
              _storeName = data['name'] ?? 'Unknown Store';
              _location = (data['address'] ?? '').toString().isEmpty
                  ? 'Not set'
                  : data['address'];
              _ownerId = oid;
            });
          }
          if (oid.isNotEmpty) {
            final ownerDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(oid)
                .get();
            if (ownerDoc.exists) {
              if (mounted) {
                setState(() => _ownerName = ownerDoc.data()?['name'] ?? 'Unknown');
              }
            }
          }
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _storeName = 'Unavailable';
          _ownerName = 'Unavailable';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(AppColors.white),
        borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
        border: Border.all(color: const Color(AppColors.borderColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.store_rounded,
                  color: Color(AppColors.primary), size: 22),
              const SizedBox(width: 8),
              Text(
                'Store Information',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'STORE NAME',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(AppColors.greyDark),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _storeName,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'LOCATION',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(AppColors.greyDark),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _location,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          // Shop Owner
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SHOP OWNER',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(AppColors.greyDark),
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.admin_panel_settings,
                      size: 18, color: Color(AppColors.orange)),
                  const SizedBox(width: 6),
                  Text(
                    _ownerName.isEmpty ? 'Loading...' : _ownerName,
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Shift History section with date range filter
// ═══════════════════════════════════════════════════════════════════

class _ShiftHistorySection extends StatefulWidget {
  final String cashierId;
  const _ShiftHistorySection({required this.cashierId});

  @override
  State<_ShiftHistorySection> createState() => _ShiftHistorySectionState();
}

class _ShiftHistorySectionState extends State<_ShiftHistorySection> {
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    // Default: last 7 days
    final now = DateTime.now();
    _dateRange = DateTimeRange(
      start: DateTime(now.year, now.month, now.day - 7),
      end: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: const Color(AppColors.primary),
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dateRange = DateTimeRange(
          start: picked.start,
          end: DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d');
    final rangeLabel = _dateRange != null
        ? '${dateFormat.format(_dateRange!.start)} – ${dateFormat.format(_dateRange!.end)}'
        : 'Select dates';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            const Text(
              'SHIFT HISTORY',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(AppColors.greyDark),
                letterSpacing: 1.2,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: _pickDateRange,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5FF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(AppColors.primary).withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        size: 14, color: Color(AppColors.primary)),
                    const SizedBox(width: 6),
                    Text(
                      rangeLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Shift list
        StreamBuilder<List<ShiftModel>>(
          stream: FirestoreService()
              .getShiftsByCashierStream(widget.cashierId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final allShifts = snapshot.data ?? [];
            final filtered = allShifts.where((s) {
              if (_dateRange == null) return true;
              return !s.startTime.isBefore(_dateRange!.start) &&
                  !s.startTime.isAfter(_dateRange!.end);
            }).toList();

            if (filtered.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(AppColors.white),
                  borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
                  border: Border.all(color: const Color(AppColors.borderColor)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.history_rounded,
                        size: 40, color: Colors.grey.shade300),
                    const SizedBox(height: 8),
                    Text(
                      'No shifts found for this period',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            }

            return Container(
              decoration: BoxDecoration(
                color: const Color(AppColors.white),
                borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
                border: Border.all(color: const Color(AppColors.borderColor)),
              ),
              child: Column(
                children: [
                  for (int i = 0; i < filtered.length; i++) ...[
                    _ShiftHistoryTile(shift: filtered[i]),
                    if (i < filtered.length - 1)
                      const Divider(height: 1, indent: 16, endIndent: 16),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ShiftHistoryTile extends StatelessWidget {
  final ShiftModel shift;
  const _ShiftHistoryTile({required this.shift});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');
    final statusColor = switch (shift.status) {
      ShiftStatus.active => const Color(AppColors.success),
      ShiftStatus.completed => const Color(AppColors.primary),
      ShiftStatus.cancelled => const Color(AppColors.error),
    };
    final statusLabel = switch (shift.status) {
      ShiftStatus.active => 'Active',
      ShiftStatus.completed => 'Completed',
      ShiftStatus.cancelled => 'Cancelled',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.schedule_rounded, color: statusColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateFormat.format(shift.startTime),
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '${timeFormat.format(shift.startTime)} – ${shift.endTime != null ? timeFormat.format(shift.endTime!) : 'Ongoing'}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: const Color(AppColors.greyDark)),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                shift.hoursWorkedFormatted,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                      color: const Color(AppColors.greyDark),
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Small widget to fetch and display the owner name (uses REST on web)
// ═══════════════════════════════════════════════════════════════════

class _OwnerNameRow extends StatefulWidget {
  final String ownerId;
  const _OwnerNameRow({required this.ownerId});

  @override
  State<_OwnerNameRow> createState() => _OwnerNameRowState();
}

class _OwnerNameRowState extends State<_OwnerNameRow> {
  String _ownerName = 'Loading...';

  @override
  void initState() {
    super.initState();
    _fetchOwnerName();
  }

  Future<void> _fetchOwnerName() async {
    try {
      if (kIsWeb) {
        // Use REST API on web to avoid Firestore SDK timeout
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          if (mounted) setState(() => _ownerName = 'Unavailable');
          return;
        }
        final idToken = await user.getIdToken(true);
        final projectId = Firebase.app().options.projectId;
        final uri = Uri.parse(
          'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/users/${widget.ownerId}',
        );
        final response = await http.get(uri, headers: {
          'Authorization': 'Bearer $idToken',
        });
        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body) as Map<String, dynamic>;
          final fields = decoded['fields'] as Map<String, dynamic>?;
          final name = fields?['name']?['stringValue'] as String?;
          if (mounted) setState(() => _ownerName = name ?? 'Unknown');
        } else {
          if (mounted) setState(() => _ownerName = 'Unavailable');
        }
      } else {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.ownerId)
            .get();
        if (doc.exists) {
          final data = doc.data() ?? {};
          if (mounted) setState(() => _ownerName = data['name'] ?? 'Unknown');
        } else {
          if (mounted) setState(() => _ownerName = 'Unavailable');
        }
      }
    } catch (_) {
      if (mounted) setState(() => _ownerName = 'Unavailable');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SHOP OWNER',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(AppColors.greyDark),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.admin_panel_settings,
                size: 18, color: Color(AppColors.orange)),
            const SizedBox(width: 6),
            Text(
              _ownerName,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ],
    );
  }
}

class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner({required this.role, this.name, this.email});

  final String? name;
  final String role;
  final String? email;

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final displayName = (name != null && name!.isNotEmpty) ? name! : role;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(AppColors.primary), Color(0xFF1A5BC7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.waving_hand_rounded,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_greeting, $displayName!',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Logged in as $role${email != null ? ' · $email' : ''}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withOpacity(0.8),
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
