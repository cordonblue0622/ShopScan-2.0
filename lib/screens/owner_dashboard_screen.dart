import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/auth_provider.dart';
import '../models/product_model.dart';
import '../models/shop_model.dart';
import '../models/shift_model.dart';
import '../models/transaction_model.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../widgets/approval_notification_button.dart';
import 'cashier_dashboard_screen.dart';
import 'inventory_screen.dart';
import 'sales_history_screen.dart';

class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({Key? key}) : super(key: key);

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppColors.lightBg),
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            _OwnerOverviewTab(onTabSelected: _onTabSelected),
            const InventoryScreen(),
            const SalesHistoryScreen(),
            const _OwnerCashiersTab(),
            _OwnerProfileTab(onTabSelected: _onTabSelected),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onTabSelected,
            height: 70,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            backgroundColor: const Color(AppColors.white),
            indicatorColor: const Color(0xFFD9E6FF),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_rounded),
                label: 'Dashboard',
              ),
              NavigationDestination(
                icon: Icon(Icons.inventory_2_rounded),
                label: 'Products',
              ),
              NavigationDestination(
                icon: Icon(Icons.insert_chart_outlined_rounded),
                label: 'Reports',
              ),
              NavigationDestination(
                icon: Icon(Icons.people_alt_outlined),
                label: 'Cashiers',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onTabSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }
}

class _OwnerOverviewTab extends StatelessWidget {
  const _OwnerOverviewTab({required this.onTabSelected});

  final ValueChanged<int> onTabSelected;

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();
    final currentUser = context.watch<AuthProvider>().currentUser;

    return StreamBuilder<List<TransactionModel>>(
      stream: firestoreService.getTransactionsStream(),
      builder: (context, transactionSnapshot) {
        final transactions = transactionSnapshot.data ?? <TransactionModel>[];

        return StreamBuilder<List<ProductModel>>(
          stream: firestoreService.getProductsStream(shopId: currentUser?.shopId),
          builder: (context, productSnapshot) {
            final products = productSnapshot.data ?? <ProductModel>[];
            final summary = _OwnerDashboardSummary.fromData(
              transactions: transactions,
              products: products,
            );
            final ownerName = currentUser?.name;

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTopBar(context, currentUser),
                  const SizedBox(height: 14),
                  _WelcomeBanner(
                    name: ownerName,
                    role: 'Owner',
                    email: currentUser?.email,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Executive Summary',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(AppColors.black),
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Real-time performance overview for today, ${summary.todayLabel}.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(AppColors.greyDark),
                        ),
                  ),
                  const SizedBox(height: 18),
                  _MetricCard(
                    label: 'TOTAL REVENUE',
                    value: summary.totalRevenueLabel,
                    icon: Icons.account_balance_wallet_outlined,
                    accentColor: const Color(AppColors.primary),
                    badgeText: summary.revenueTrend,
                  ),
                  const SizedBox(height: 14),
                  _MetricCard(
                    label: 'MONTHLY REVENUE',
                    value: summary.monthRevenueLabel,
                    icon: Icons.calendar_month_outlined,
                    accentColor: const Color(AppColors.info),
                    badgeText: 'Monthly',
                  ),
                  const SizedBox(height: 14),
                  _MetricCard(
                    label: 'TOTAL PRODUCTS',
                    value: NumberFormat.decimalPattern().format(
                      summary.totalProducts,
                    ),
                    icon: Icons.inventory_2_outlined,
                    accentColor: const Color(AppColors.primaryDark),
                  ),
                  const SizedBox(height: 14),
                  _AlertMetricCard(
                    label: 'LOW STOCK ALERTS',
                    value: '${summary.lowStockCount} ITEMS',
                  ),
                  const SizedBox(height: 18),
                  _ChartCard(summary: summary),
                  const SizedBox(height: 18),
                  _QuickActionsCard(onTabSelected: onTabSelected),
                  const SizedBox(height: 18),
                  _TopProductsCard(
                    products: products,
                    topProducts: summary.topProducts,
                    onViewAll: () => onTabSelected(1),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTopBar(BuildContext context, UserModel? owner) {
    final ownerName = owner?.name.trim().isNotEmpty == true
        ? owner!.name.trim()
        : 'Owner';

    return Row(
      children: [
        Text(
          'ShopScan',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const Spacer(),
        if (owner != null) ...[
          ApprovalNotificationButton(user: owner),
          const SizedBox(width: 6),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5FF),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            ownerName,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: const Color(AppColors.primary),
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ],
    );
  }
}

class _OwnerCashiersTab extends StatefulWidget {
  const _OwnerCashiersTab();

  @override
  State<_OwnerCashiersTab> createState() => _OwnerCashiersTabState();
}

class _OwnerCashiersTabState extends State<_OwnerCashiersTab> {
  final _firestoreService = FirestoreService();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isCreatingStaff = false;
  String? _activeStaffActionId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final owner = context.select<AuthProvider, UserModel?>(
      (provider) => provider.currentUser,
    );
    final ownerName = owner?.name;
    final ownerShopId = owner?.shopId ?? owner?.id;

    return Scaffold(
      backgroundColor: const Color(AppColors.lightBg),
      body: StreamBuilder<List<UserModel>>(
        stream: _firestoreService.getUsersStream(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (userSnapshot.hasError) {
            return _buildLoadError(
                context, 'cashier roster', userSnapshot.error);
          }

          return StreamBuilder<List<ShiftModel>>(
            stream: _firestoreService.getShiftsStream(),
            builder: (context, shiftSnapshot) {
              if (shiftSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (shiftSnapshot.hasError) {
                return _buildLoadError(
                    context, 'shift data', shiftSnapshot.error);
              }

              return StreamBuilder<List<TransactionModel>>(
                stream: _firestoreService.getTransactionsStream(),
                builder: (context, transactionSnapshot) {
                  if (transactionSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (transactionSnapshot.hasError) {
                    return _buildLoadError(
                      context,
                      'cashier performance',
                      transactionSnapshot.error,
                    );
                  }

                  final cashiers = (userSnapshot.data ?? <UserModel>[])
                      .where(
                        (user) =>
                            user.role == UserRole.cashier &&
                            (ownerShopId == null || user.shopId == ownerShopId),
                      )
                      .toList();
                  final shifts = shiftSnapshot.data ?? <ShiftModel>[];
                  final transactions =
                      transactionSnapshot.data ?? <TransactionModel>[];

                  final rosterEntries = cashiers
                      .map(
                        (cashier) => _CashierRosterEntry.fromData(
                          cashier: cashier,
                          shifts: shifts
                              .where((shift) => shift.cashierId == cashier.id)
                              .toList(),
                          transactions: transactions
                              .where((transaction) =>
                                  transaction.cashierId == cashier.id)
                              .toList(),
                        ),
                      )
                      .toList()
                    ..sort((a, b) => a.sortPriority.compareTo(b.sortPriority));

                  final filteredEntries = rosterEntries
                      .where((entry) => entry.matches(_searchQuery))
                      .toList();
                  final summary =
                      _CashierDashboardSummary.fromEntries(rosterEntries);

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                    children: [
                      _buildTopBar(context, owner),
                      const SizedBox(height: 18),
                      Text(
                        'Cashier Management',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: const Color(AppColors.black),
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Monitor performance and manage staff shifts.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: const Color(AppColors.greyDark),
                            ),
                      ),
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.icon(
                          onPressed: owner == null || _isCreatingStaff
                              ? null
                              : () => _showAddStaffSheet(context, owner.id),
                          icon: const Icon(Icons.person_add_alt_1_rounded,
                              size: 18),
                          label: Text(
                            _isCreatingStaff ? 'Saving...' : 'New Staff',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFD9E8FF),
                            foregroundColor: const Color(AppColors.black),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _CashierInsightCard(
                        icon: Icons.groups_rounded,
                        iconTint: const Color(AppColors.primary),
                        iconBackground: const Color(0xFFDDEAFF),
                        label: 'Active Cashiers',
                        value:
                            '${summary.activeCashierCount} / ${summary.totalCashierCount}',
                        badge: summary.newTodayBadge,
                        badgeBackground: const Color(0xFFE7FAEF),
                        badgeColor: const Color(AppColors.success),
                      ),
                      const SizedBox(height: 14),
                      _CashierInsightCard(
                        icon: Icons.access_time_filled_rounded,
                        iconTint: const Color(AppColors.orange),
                        iconBackground: const Color(0xFFFFD9CC),
                        label: 'Average Shift',
                        value: summary.averageShiftLabel,
                      ),
                      const SizedBox(height: 14),
                      _CashierInsightCard(
                        icon: Icons.payments_outlined,
                        iconTint: const Color(AppColors.primaryDark),
                        iconBackground: const Color(0xFFD9E8FF),
                        label: 'Sales per Hour (Avg)',
                        value: summary.salesPerHourLabel,
                        badge: summary.topPerformerBadge,
                        badgeBackground: const Color(0xFFEFF4FF),
                        badgeColor: const Color(AppColors.primary),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F3F5),
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Staff\nRoster',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: TextField(
                                    controller: _searchController,
                                    onChanged: (value) {
                                      setState(() {
                                        _searchQuery =
                                            value.trim().toLowerCase();
                                      });
                                    },
                                    decoration: InputDecoration(
                                      hintText: 'Search cashier...',
                                      prefixIcon:
                                          const Icon(Icons.search_rounded),
                                      filled: true,
                                      fillColor: const Color(AppColors.white),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 14,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide.none,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide.none,
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: const BorderSide(
                                          color: Color(AppColors.primary),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            if (rosterEntries.isEmpty)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 16),
                                child: _EmptyStateCard(
                                  title: 'No staff yet',
                                  subtitle:
                                      'Cashier accounts will appear here after registration.',
                                  icon: Icons.people_outline_rounded,
                                ),
                              )
                            else if (filteredEntries.isEmpty)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 16),
                                child: _EmptyStateCard(
                                  title: 'No matching staff found',
                                  subtitle:
                                      'Try another cashier name, email or ID.',
                                  icon: Icons.search_off_rounded,
                                ),
                              )
                            else
                              ...filteredEntries.map(
                                (entry) => Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: _CashierRosterCard(
                                    entry: entry,
                                    isActionInProgress: _activeStaffActionId ==
                                        entry.cashier.id,
                                    onHistoryTap: () =>
                                        _showHistorySheet(context, entry),
                                    onPerformanceTap: () =>
                                        _showPerformanceSheet(context, entry),
                                    onManageTap: owner == null
                                        ? null
                                        : () => _showCashierActionSheet(
                                              context,
                                              ownerId: owner.id,
                                              entry: entry,
                                            ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, UserModel? owner) {
    final ownerName = owner?.name.trim().isNotEmpty == true
        ? owner!.name.trim()
        : 'Owner';

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(AppColors.white),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.menu_rounded, color: Color(AppColors.black)),
        ),
        const SizedBox(width: 12),
        Text(
          'ShopScan',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const Spacer(),
        if (owner != null) ...[
          ApprovalNotificationButton(user: owner),
          const SizedBox(width: 6),
        ],
        Text(
          ownerName,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: const Color(AppColors.primary),
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFD9E6FF),
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Icon(Icons.person,
              size: 18, color: Color(AppColors.primary)),
        ),
      ],
    );
  }

  Widget _buildLoadError(BuildContext context, String area, Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Failed to load $area: $error',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Future<void> _showAddStaffSheet(BuildContext context, String ownerId) async {
    final authProvider = context.read<AuthProvider>();
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final shiftLabelController = TextEditingController(text: 'Morning');
    TimeOfDay startTime = const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 16, minute: 0);
    bool isSubmitting = false;

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(AppColors.white),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (sheetContext, setSheetState) {
              return SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    18,
                    20,
                    MediaQuery.of(sheetContext).viewInsets.bottom + 20,
                  ),
                  child: SingleChildScrollView(
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add New Staff',
                            style: Theme.of(sheetContext)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Create staff credentials and assign their default shift.',
                            style: Theme.of(sheetContext)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: const Color(AppColors.greyDark),
                                ),
                          ),
                          const SizedBox(height: 18),
                          _buildStaffField(
                            context: sheetContext,
                            controller: nameController,
                            label: 'Full name',
                            hintText: 'Cashier name',
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Enter the staff name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildStaffField(
                            context: sheetContext,
                            controller: emailController,
                            label: 'Login email',
                            hintText: 'cashier@shopscan.com',
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              final email = value?.trim() ?? '';
                              if (email.isEmpty) {
                                return 'Enter an email address';
                              }
                              final isValid =
                                  RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                      .hasMatch(email);
                              if (!isValid) {
                                return 'Enter a valid email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildStaffField(
                            context: sheetContext,
                            controller: passwordController,
                            label: 'Password',
                            hintText: 'Password',
                            obscureText: true,
                            validator: (value) {
                              if (value == null || value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildStaffField(
                            context: sheetContext,
                            controller: shiftLabelController,
                            label: 'Shift label',
                            hintText: 'Morning / Evening',
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Enter a shift label';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _ShiftPickerTile(
                                  label: 'Shift starts',
                                  value: startTime.format(sheetContext),
                                  onTap: () async {
                                    final picked = await showTimePicker(
                                      context: sheetContext,
                                      initialTime: startTime,
                                    );
                                    if (picked != null) {
                                      setSheetState(() {
                                        startTime = picked;
                                      });
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _ShiftPickerTile(
                                  label: 'Shift ends',
                                  value: endTime.format(sheetContext),
                                  onTap: () async {
                                    final picked = await showTimePicker(
                                      context: sheetContext,
                                      initialTime: endTime,
                                    );
                                    if (picked != null) {
                                      setSheetState(() {
                                        endTime = picked;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: isSubmitting
                                  ? null
                                  : () async {
                                      if (!formKey.currentState!.validate()) {
                                        return;
                                      }

                                      final startMinutes = startTime.hour * 60 +
                                          startTime.minute;
                                      final endMinutes =
                                          endTime.hour * 60 + endTime.minute;
                                      if (endMinutes <= startMinutes) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Shift end must be later than the start time.',
                                            ),
                                          ),
                                        );
                                        return;
                                      }

                                      setSheetState(() {
                                        isSubmitting = true;
                                      });
                                      if (mounted) {
                                        setState(() {
                                          _isCreatingStaff = true;
                                        });
                                      }

                                      final staffName =
                                          nameController.text.trim();
                                      final messenger =
                                          ScaffoldMessenger.of(context);

                                      final success = await authProvider
                                          .createCashierForOwner(
                                        ownerId: ownerId,
                                        name: staffName,
                                        email: emailController.text.trim(),
                                        password: passwordController.text,
                                        shiftLabel:
                                            shiftLabelController.text.trim(),
                                        shiftStart: _timeToStorage(startTime),
                                        shiftEnd: _timeToStorage(endTime),
                                      );

                                      if (!mounted) {
                                        return;
                                      }

                                      if (success) {
                                        Navigator.of(sheetContext).pop();
                                        messenger.showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              '✅ $staffName was added to your staff roster.',
                                            ),
                                            backgroundColor:
                                                const Color(0xFF2E7D32),
                                            duration:
                                                const Duration(seconds: 4),
                                          ),
                                        );
                                      } else {
                                        setSheetState(() {
                                          isSubmitting = false;
                                        });
                                        messenger.showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              authProvider.error ??
                                                  'Failed to add staff.',
                                            ),
                                          ),
                                        );
                                      }

                                      if (mounted) {
                                        setState(() {
                                          _isCreatingStaff = false;
                                        });
                                      }
                                    },
                              style: FilledButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                backgroundColor: const Color(AppColors.primary),
                              ),
                              child: Text(
                                isSubmitting
                                    ? 'Creating Staff...'
                                    : 'Create Staff Account',
                              ),
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
      if (mounted) {
        setState(() {
          _isCreatingStaff = false;
        });
      }
      nameController.dispose();
      emailController.dispose();
      passwordController.dispose();
      shiftLabelController.dispose();
    }
  }

  Future<void> _showCashierActionSheet(
    BuildContext context, {
    required String ownerId,
    required _CashierRosterEntry entry,
  }) async {
    final selectedAction = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(AppColors.white),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.cashier.name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  entry.cashier.email,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(AppColors.greyDark),
                      ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.block_rounded,
                      color: Color(AppColors.orange)),
                  title: const Text('Terminate access'),
                  subtitle: const Text(
                    'Keep the cashier record and sales history, but block future logins.',
                  ),
                  onTap: () => Navigator.of(sheetContext).pop('terminate'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_remove_alt_1_rounded,
                      color: Color(AppColors.error)),
                  title: const Text('Remove from roster'),
                  subtitle: const Text(
                    'Remove this cashier from your shop list and clear the assigned shift.',
                  ),
                  onTap: () => Navigator.of(sheetContext).pop('remove'),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || selectedAction == null) {
      return;
    }

    final isTerminate = selectedAction == 'terminate';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(isTerminate ? 'Terminate cashier?' : 'Remove cashier?'),
          content: Text(
            isTerminate
                ? 'This will stop ${entry.cashier.name} from signing in with the created credentials.'
                : 'This will remove ${entry.cashier.name} from your roster and block future logins.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: isTerminate
                    ? const Color(AppColors.orange)
                    : const Color(AppColors.error),
              ),
              child: Text(isTerminate ? 'Terminate' : 'Remove'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _activeStaffActionId = entry.cashier.id;
    });

    final authProvider = context.read<AuthProvider>();
    final success = isTerminate
        ? await authProvider.terminateCashier(
            ownerId: ownerId,
            cashierId: entry.cashier.id,
          )
        : await authProvider.removeCashierFromShop(
            ownerId: ownerId,
            cashierId: entry.cashier.id,
          );

    if (!mounted) {
      return;
    }

    setState(() {
      _activeStaffActionId = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? isTerminate
                  ? '${entry.cashier.name} has been terminated and can no longer sign in.'
                  : '${entry.cashier.name} was removed from your cashier roster.'
              : authProvider.error ?? 'Unable to update cashier access.',
        ),
      ),
    );
  }

  Widget _buildStaffField({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    required String hintText,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            hintText: hintText,
            filled: true,
            fillColor: const Color(0xFFF7F8FB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(AppColors.primary)),
            ),
          ),
        ),
      ],
    );
  }

  String _timeToStorage(TimeOfDay value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  void _showHistorySheet(BuildContext context, _CashierRosterEntry entry) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(AppColors.white),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entry.cashier.name} shift history',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 14),
                if (entry.recentShifts.isEmpty)
                  const _EmptyStateCard(
                    title: 'No shifts yet',
                    subtitle:
                        'Shift history will appear here after staff activity starts.',
                    icon: Icons.history_toggle_off_rounded,
                  )
                else
                  ...entry.recentShifts.map(
                    (shift) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF6F7FA),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('EEEE, MMM d').format(shift.startTime),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_formatTime(shift.startTime)} - ${shift.endTime == null ? 'Active' : _formatTime(shift.endTime!)}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${shift.hoursWorkedFormatted} • ${NumberFormat.currency(symbol: r'$', decimalDigits: 2).format(shift.salesAmount)} sales',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: const Color(AppColors.greyDark),
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPerformanceSheet(BuildContext context, _CashierRosterEntry entry) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(AppColors.white),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entry.cashier.name} performance',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 14),
                _CashierBottomSheetMetric(
                  label: 'Sales this week',
                  value: entry.weekSalesLabel,
                ),
                const SizedBox(height: 10),
                _CashierBottomSheetMetric(
                  label: 'Transactions this week',
                  value: NumberFormat.decimalPattern()
                      .format(entry.weekTransactionCount),
                ),
                const SizedBox(height: 10),
                _CashierBottomSheetMetric(
                  label: 'Average basket',
                  value: entry.averageTicketLabel,
                ),
                const SizedBox(height: 10),
                _CashierBottomSheetMetric(
                  label: 'Sales per hour',
                  value: entry.salesPerHourLabel,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatTime(DateTime value) => DateFormat('HH:mm').format(value);
}

class _CashierInsightCard extends StatelessWidget {
  const _CashierInsightCard({
    required this.icon,
    required this.iconTint,
    required this.iconBackground,
    required this.label,
    required this.value,
    this.badge,
    this.badgeBackground,
    this.badgeColor,
  });

  final IconData icon;
  final Color iconTint;
  final Color iconBackground;
  final String label;
  final String value;
  final String? badge;
  final Color? badgeBackground;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      constraints: const BoxConstraints(minHeight: 132),
      decoration: BoxDecoration(
        color: const Color(AppColors.white),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconTint),
              ),
              const Spacer(),
              if (badge != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: badgeBackground ?? const Color(0xFFF2F4F8),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badge!,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: badgeColor ?? const Color(AppColors.greyDark),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            label,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _CashierRosterCard extends StatelessWidget {
  const _CashierRosterCard({
    required this.entry,
    required this.onHistoryTap,
    required this.onPerformanceTap,
    required this.isActionInProgress,
    this.onManageTap,
  });

  final _CashierRosterEntry entry;
  final VoidCallback onHistoryTap;
  final VoidCallback onPerformanceTap;
  final bool isActionInProgress;
  final VoidCallback? onManageTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(AppColors.white),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _CashierAvatar(entry: entry),
                  Positioned(
                    right: -1,
                    bottom: -1,
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: entry.statusDotColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(AppColors.white),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.cashier.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ID: ${entry.cashierCode}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(AppColors.greyDark),
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: isActionInProgress ? null : onManageTap,
                icon: isActionInProgress
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.more_horiz_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFF2F4F8),
                  foregroundColor: const Color(AppColors.black),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _CashierInfoColumn(
                  label: 'STATUS',
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: entry.statusBackground,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      entry.statusLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: entry.statusTextColor,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CashierInfoColumn(
                  label: 'SHIFT',
                  child: Text(
                    entry.shiftDisplay,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _CashierInfoColumn(
            label: entry.hoursLabel,
            child: Text(
              entry.hoursValue,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: onHistoryTap,
                  child: const Text('History'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: onPerformanceTap,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0B64E8),
                    foregroundColor: const Color(AppColors.white),
                  ),
                  child: const Text('Performance'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CashierAvatar extends StatelessWidget {
  const _CashierAvatar({required this.entry});

  final _CashierRosterEntry entry;

  @override
  Widget build(BuildContext context) {
    final photoUrl = entry.cashier.photoUrl;
    final initials = entry.cashier.name.trim().isEmpty
        ? 'C'
        : entry.cashier.name
            .trim()
            .split(RegExp(r'\s+'))
            .take(2)
            .map((part) => part.isEmpty ? '' : part[0].toUpperCase())
            .join();

    return CircleAvatar(
      radius: 24,
      backgroundColor: const Color(0xFFD9E6FF),
      backgroundImage: photoUrl != null && photoUrl.isNotEmpty
          ? NetworkImage(photoUrl)
          : null,
      child: photoUrl != null && photoUrl.isNotEmpty
          ? null
          : Text(
              initials,
              style: const TextStyle(
                color: Color(AppColors.primary),
                fontWeight: FontWeight.w800,
              ),
            ),
    );
  }
}

class _CashierInfoColumn extends StatelessWidget {
  const _CashierInfoColumn({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: const Color(AppColors.greyDark),
                letterSpacing: 0.8,
              ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _ShiftPickerTile extends StatelessWidget {
  const _ShiftPickerTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FB),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: const Color(AppColors.greyDark),
                  ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                const Icon(Icons.schedule_rounded),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CashierBottomSheetMetric extends StatelessWidget {
  const _CashierBottomSheetMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7FA),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: const Color(AppColors.greyDark),
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _CashierDashboardSummary {
  const _CashierDashboardSummary({
    required this.totalCashierCount,
    required this.activeCashierCount,
    required this.newTodayCount,
    required this.averageShiftHours,
    required this.salesPerHour,
    required this.topPerformerName,
  });

  final int totalCashierCount;
  final int activeCashierCount;
  final int newTodayCount;
  final double averageShiftHours;
  final double salesPerHour;
  final String? topPerformerName;

  String get newTodayBadge =>
      newTodayCount > 0 ? '+$newTodayCount Today' : 'No new staff';

  String get averageShiftLabel {
    final totalMinutes = (averageShiftHours * 60).round();
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    return '${hours}h ${minutes}m';
  }

  String get salesPerHourLabel =>
      NumberFormat.currency(symbol: r'$', decimalDigits: 0)
          .format(salesPerHour);

  String get topPerformerBadge =>
      topPerformerName == null || topPerformerName!.isEmpty
          ? 'Live'
          : '${topPerformerName!.split(' ').first} leads';

  factory _CashierDashboardSummary.fromEntries(
      List<_CashierRosterEntry> entries) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final recentShifts = entries
        .expand((entry) => entry.recentShifts)
        .where((shift) =>
            !shift.startTime.isBefore(today.subtract(const Duration(days: 6))))
        .toList();

    final totalHours = recentShifts.fold<double>(
      0,
      (sum, shift) => sum + shift.hoursWorked.inMinutes / 60,
    );
    final averageShiftHours =
        recentShifts.isEmpty ? 0.0 : totalHours / recentShifts.length;
    final salesPerHour = totalHours <= 0
        ? 0.0
        : entries.fold<double>(0, (sum, entry) => sum + entry.weekSales) /
            totalHours;

    final sortedBySales = [...entries]
      ..sort((a, b) => b.weekSales.compareTo(a.weekSales));

    return _CashierDashboardSummary(
      totalCashierCount: entries.length,
      activeCashierCount: entries.where((entry) => entry.hasActiveShift).length,
      newTodayCount: entries.where((entry) => entry.joinedToday).length,
      averageShiftHours: averageShiftHours,
      salesPerHour: salesPerHour,
      topPerformerName:
          sortedBySales.isEmpty || sortedBySales.first.weekSales == 0
              ? null
              : sortedBySales.first.cashier.name,
    );
  }
}

class _CashierRosterEntry {
  const _CashierRosterEntry({
    required this.cashier,
    required this.statusLabel,
    required this.statusBackground,
    required this.statusTextColor,
    required this.statusDotColor,
    required this.shiftDisplay,
    required this.hoursLabel,
    required this.hoursValue,
    required this.hoursToday,
    required this.hoursWeek,
    required this.weekSales,
    required this.weekTransactionCount,
    required this.averageTicket,
    required this.salesPerHour,
    required this.hasActiveShift,
    required this.joinedToday,
    required this.sortPriority,
    required this.recentShifts,
  });

  final UserModel cashier;
  final String statusLabel;
  final Color statusBackground;
  final Color statusTextColor;
  final Color statusDotColor;
  final String shiftDisplay;
  final String hoursLabel;
  final String hoursValue;
  final double hoursToday;
  final double hoursWeek;
  final double weekSales;
  final int weekTransactionCount;
  final double averageTicket;
  final double salesPerHour;
  final bool hasActiveShift;
  final bool joinedToday;
  final int sortPriority;
  final List<ShiftModel> recentShifts;

  String get cashierCode =>
      '#CS-${cashier.id.replaceAll('-', '').toUpperCase().padRight(4, '0').substring(0, 4)}';

  String get weekSalesLabel =>
      NumberFormat.currency(symbol: r'$', decimalDigits: 2).format(weekSales);

  String get averageTicketLabel =>
      NumberFormat.currency(symbol: r'$', decimalDigits: 2)
          .format(averageTicket);

  String get salesPerHourLabel =>
      NumberFormat.currency(symbol: r'$', decimalDigits: 2)
          .format(salesPerHour);

  bool matches(String query) {
    if (query.isEmpty) {
      return true;
    }
    final value = query.toLowerCase();
    return cashier.name.toLowerCase().contains(value) ||
        cashier.email.toLowerCase().contains(value) ||
        cashierCode.toLowerCase().contains(value) ||
        (cashier.assignedShiftLabel?.toLowerCase().contains(value) ?? false);
  }

  factory _CashierRosterEntry.fromData({
    required UserModel cashier,
    required List<ShiftModel> shifts,
    required List<TransactionModel> transactions,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(const Duration(days: 6));

    shifts.sort((a, b) => b.startTime.compareTo(a.startTime));
    transactions.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final activeShift = shifts.cast<ShiftModel?>().firstWhere(
          (shift) => shift?.isActive == true,
          orElse: () => null,
        );
    final latestShift = shifts.isNotEmpty ? shifts.first : null;
    final latestTransaction =
        transactions.isNotEmpty ? transactions.first : null;
    final joinedToday = _isSameDay(cashier.createdAt, now);

    final hoursToday = shifts
        .where((shift) => _isSameDay(shift.startTime, now))
        .fold<double>(
            0, (sum, shift) => sum + shift.hoursWorked.inMinutes / 60);
    final weekShifts =
        shifts.where((shift) => !shift.startTime.isBefore(weekStart)).toList();
    final hoursWeek = weekShifts.fold<double>(
      0,
      (sum, shift) => sum + shift.hoursWorked.inMinutes / 60,
    );
    final weekTransactions = transactions
        .where((transaction) => !transaction.timestamp.isBefore(weekStart))
        .toList();
    final weekSales = weekTransactions.fold<double>(
        0, (sum, transaction) => sum + transaction.total);
    final weekTransactionCount = weekTransactions.length;
    final averageTicket =
        weekTransactionCount == 0 ? 0.0 : weekSales / weekTransactionCount;
    final salesPerHour = hoursWeek <= 0 ? 0.0 : weekSales / hoursWeek;

    late final String statusLabel;
    late final Color statusBackground;
    late final Color statusTextColor;
    late final Color statusDotColor;
    late final int sortPriority;

    if (!cashier.isActive) {
      statusLabel = 'Inactive';
      statusBackground = const Color(0xFFFFEFEF);
      statusTextColor = const Color(AppColors.error);
      statusDotColor = const Color(AppColors.error);
      sortPriority = 3;
    } else if (activeShift != null) {
      final inactivityWindow = latestTransaction == null
          ? Duration.zero
          : now.difference(latestTransaction.timestamp);
      if (latestTransaction != null &&
          inactivityWindow > const Duration(minutes: 90)) {
        statusLabel = 'On Break';
        statusBackground = const Color(0xFFFFF1DE);
        statusTextColor = const Color(AppColors.orange);
        statusDotColor = const Color(AppColors.warning);
        sortPriority = 1;
      } else {
        statusLabel = 'On Duty';
        statusBackground = const Color(0xFFE7FAEF);
        statusTextColor = const Color(AppColors.success);
        statusDotColor = const Color(AppColors.success);
        sortPriority = 0;
      }
    } else {
      statusLabel = 'Off Duty';
      statusBackground = const Color(0xFFF2F4F8);
      statusTextColor = const Color(AppColors.greyDark);
      statusDotColor = const Color(0xFFB7C0D1);
      sortPriority = 2;
    }

    final shiftReference = activeShift ?? latestShift;
    final assignedShiftDisplay = _assignedShiftDisplay(cashier);
    final shiftDisplay = activeShift != null
        ? '${_shiftName(activeShift.startTime)} (${DateFormat('HH:mm').format(activeShift.startTime)} - ${activeShift.endTime == null ? 'Active' : DateFormat('HH:mm').format(activeShift.endTime!)})'
        : assignedShiftDisplay ??
            (shiftReference == null
                ? 'No shift yet'
                : '${_shiftName(shiftReference.startTime)} (${DateFormat('HH:mm').format(shiftReference.startTime)} - ${shiftReference.endTime == null ? 'Active' : DateFormat('HH:mm').format(shiftReference.endTime!)})');

    return _CashierRosterEntry(
      cashier: cashier,
      statusLabel: statusLabel,
      statusBackground: statusBackground,
      statusTextColor: statusTextColor,
      statusDotColor: statusDotColor,
      shiftDisplay: shiftDisplay,
      hoursLabel: hasActiveShiftLabel(activeShift != null),
      hoursValue: _formatHours(activeShift != null ? hoursToday : hoursWeek),
      hoursToday: hoursToday,
      hoursWeek: hoursWeek,
      weekSales: weekSales,
      weekTransactionCount: weekTransactionCount,
      averageTicket: averageTicket,
      salesPerHour: salesPerHour,
      hasActiveShift: activeShift != null,
      joinedToday: joinedToday,
      sortPriority: sortPriority,
      recentShifts: shifts.take(5).toList(),
    );
  }

  static String hasActiveShiftLabel(bool hasActiveShift) =>
      hasActiveShift ? 'HOURS TODAY' : 'HOURS WEEK';

  static String _shiftName(DateTime startTime) {
    final hour = startTime.hour;
    if (hour < 12) {
      return 'Morning';
    }
    if (hour < 18) {
      return 'Afternoon';
    }
    return 'Evening';
  }

  static String _formatHours(double hours) {
    final totalMinutes = (hours * 60).round();
    final valueHours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    return '${valueHours}h ${minutes}m';
  }

  static String? _assignedShiftDisplay(UserModel cashier) {
    final label = cashier.assignedShiftLabel;
    final start = cashier.assignedShiftStart;
    final end = cashier.assignedShiftEnd;
    if (label == null || label.isEmpty || start == null || end == null) {
      return null;
    }
    return '$label ($start - $end)';
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _OwnerProfileTab extends StatefulWidget {
  const _OwnerProfileTab({required this.onTabSelected});

  final ValueChanged<int> onTabSelected;

  @override
  State<_OwnerProfileTab> createState() => _OwnerProfileTabState();
}

class _OwnerProfileTabState extends State<_OwnerProfileTab> {
  final _firestoreService = FirestoreService();
  bool _isSigningOut = false;

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;
    final notificationsEnabled = user?.notificationsEnabled ?? true;
    final appearanceLabel = user?.appearanceMode ?? 'Light Mode';
    final languageLabel = user?.languagePreference ?? 'English (US)';

    return Scaffold(
      backgroundColor: const Color(AppColors.lightBg),
      body: StreamBuilder<ShopModel?>(
        stream: user == null
            ? const Stream<ShopModel?>.empty()
            : _firestoreService.getShopByOwnerStream(user.id),
        builder: (context, snapshot) {
          final shop = snapshot.data;

          return ListView(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => widget.onTabSelected(0),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  ),
                  Text(
                    'Profile',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const Spacer(),
                  Text(
                    'ShopScan POS',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: const Color(AppColors.greyDark),
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _OwnerAvatar(user: user),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: InkWell(
                        onTap: user == null
                            ? null
                            : () => _showEditProfileSheet(context, user, shop),
                        borderRadius: BorderRadius.circular(999),
                        child: Ink(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(AppColors.primary),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: const Color(AppColors.white),
                              width: 3,
                            ),
                          ),
                          child: const Icon(
                            Icons.edit_rounded,
                            color: Color(AppColors.white),
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                user?.name ?? 'Owner',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Shop Owner',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(AppColors.greyDark),
                    ),
              ),
              const SizedBox(height: 22),
              Center(
                child: FilledButton(
                  onPressed: user == null
                      ? null
                      : () => _showEditProfileSheet(context, user, shop),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(AppColors.primary),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 38, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Edit Profile'),
                ),
              ),
              const SizedBox(height: 32),
              const _ProfileSectionLabel(title: 'Business Details'),
              const SizedBox(height: 14),
              _ProfileCard(
                child: Column(
                  children: [
                    _BusinessDetailRow(
                      icon: Icons.storefront_rounded,
                      iconBackground: const Color(0xFFD9E8FF),
                      label: 'SHOP NAME',
                      value: shop?.name.isNotEmpty == true
                          ? shop!.name
                          : 'No shop name yet',
                    ),
                    const SizedBox(height: 18),
                    _BusinessDetailRow(
                      icon: Icons.location_on_rounded,
                      iconBackground: const Color(0xFFF2F4F8),
                      label: 'LOCATION',
                      value: shop?.address.isNotEmpty == true
                          ? shop!.address
                          : 'No business address yet',
                    ),
                    const SizedBox(height: 18),
                    _BusinessDetailRow(
                      icon: Icons.receipt_long_rounded,
                      iconBackground: const Color(0xFFF2F4F8),
                      label: 'TAX ID',
                      value: _buildTaxId(shop, user),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              const _ProfileSectionLabel(title: 'Account Settings'),
              const SizedBox(height: 14),
              _ProfileCard(
                child: Column(
                  children: [
                    _ProfileActionRow(
                      icon: Icons.person_rounded,
                      title: 'Personal Information',
                      subtitle: _buildPersonalInfoSubtitle(user, shop),
                      onTap: () =>
                          _showPersonalInformationSheet(context, user, shop),
                    ),
                    const SizedBox(height: 18),
                    _ProfileActionRow(
                      icon: Icons.shield_outlined,
                      title: 'Password & Security',
                      subtitle: 'Change password, 2FA',
                      onTap: user == null
                          ? null
                          : () => _handlePasswordSecurity(context, user.email),
                    ),
                    const SizedBox(height: 18),
                    _ProfileActionRow(
                      icon: Icons.payments_outlined,
                      title: 'Payment Methods',
                      subtitle: 'Manage billing and payouts',
                      onTap: () => _showPaymentMethodsSheet(context, shop),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              const _ProfileSectionLabel(title: 'App Settings'),
              const SizedBox(height: 14),
              _ProfileCard(
                child: Column(
                  children: [
                    _SwitchSettingRow(
                      icon: Icons.notifications_rounded,
                      title: 'Notifications',
                      value: notificationsEnabled,
                      onChanged: user == null
                          ? null
                          : (value) => _saveProfileSettings(
                                context,
                                userId: user.id,
                                notificationsEnabled: value,
                              ),
                    ),
                    const SizedBox(height: 20),
                    _ValueSettingRow(
                      icon: Icons.palette_rounded,
                      title: 'Appearance',
                      value: appearanceLabel,
                      onTap: user == null
                          ? null
                          : () => _showAppearanceSheet(context, user.id),
                    ),
                    const SizedBox(height: 20),
                    _ValueSettingRow(
                      icon: Icons.language_rounded,
                      title: 'Language',
                      value: languageLabel,
                      onTap: user == null
                          ? null
                          : () => _showLanguageSheet(context, user.id),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF2FF),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFD9E8FF)),
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  leading: const Icon(Icons.swap_horiz_rounded),
                  title: const Text(
                    'Switch to Cashier Mode',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  trailing: FilledButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CashierDashboardScreen(),
                        ),
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF102A43),
                      foregroundColor: const Color(AppColors.white),
                      minimumSize: const Size(0, 38),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('SWITCH'),
                  ),
                ),
              ),
              _ProfileCard(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  children: [
                    _ProfileActionRow(
                      icon: Icons.help_outline_rounded,
                      title: 'Help & Support',
                      subtitle: 'Contact support and view help resources',
                      onTap: () => _showHelpSupportSheet(context),
                    ),
                    const Divider(height: 28),
                    _ProfileActionRow(
                      icon: Icons.logout_rounded,
                      iconColor: const Color(AppColors.error),
                      title: 'Sign Out',
                      titleColor: const Color(AppColors.error),
                      subtitle: 'Sign out of your owner account',
                      onTap:
                          _isSigningOut ? null : () => _confirmSignOut(context),
                      trailing: _isSigningOut
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _buildTaxId(ShopModel? shop, UserModel? user) {
    final seed = shop?.id ?? user?.shopId ?? user?.id ?? 'SCAN';
    final compact = seed.replaceAll('-', '').toUpperCase();
    final short = compact.length >= 8
        ? compact.substring(0, 8)
        : compact.padRight(8, '0');
    return 'TX-$short';
  }

  String _buildPersonalInfoSubtitle(UserModel? user, ShopModel? shop) {
    final phone = shop?.phone;
    if (phone != null && phone.isNotEmpty) {
      return '${user?.email ?? 'No email'}, $phone';
    }
    return user?.email ?? 'No contact info available';
  }

  Future<void> _showEditProfileSheet(
    BuildContext context,
    UserModel user,
    ShopModel? shop,
  ) async {
    final authProvider = context.read<AuthProvider>();
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: user.name);
    final shopNameController = TextEditingController(text: shop?.name ?? '');
    final addressController = TextEditingController(text: shop?.address ?? '');
    final phoneController = TextEditingController(text: shop?.phone ?? '');
    final imagePicker = ImagePicker();
    Uint8List? selectedPhotoBytes;
    bool isSaving = false;

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(AppColors.white),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (sheetContext, setSheetState) {
              return SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    18,
                    20,
                    MediaQuery.of(sheetContext).viewInsets.bottom + 20,
                  ),
                  child: SingleChildScrollView(
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Edit Profile',
                            style: Theme.of(sheetContext)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 16),
                          _profileInputField(
                            context: sheetContext,
                            controller: nameController,
                            label: 'Owner name',
                            validator: (value) {
                              final input = value?.trim() ?? '';
                              if (input.isEmpty) {
                                return 'Enter your name';
                              }
                              if (input.length < 2) {
                                return 'Name must be at least 2 characters';
                              }
                              if (!RegExp(r"^[a-zA-Z][a-zA-Z\s.'-]*$")
                                  .hasMatch(input)) {
                                return 'Use letters only for the owner name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          _profileInputField(
                            context: sheetContext,
                            controller: shopNameController,
                            label: 'Shop name',
                            hintText: 'Shop name',
                            validator: (value) {
                              final input = value?.trim() ?? '';
                              if (input.isEmpty) {
                                return 'Enter your business name';
                              }
                              if (input.length < 3) {
                                return 'Shop name must be at least 3 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          _profileInputField(
                            context: sheetContext,
                            controller: addressController,
                            label: 'Business address',
                            hintText: 'Business address',
                            validator: (value) {
                              final input = value?.trim() ?? '';
                              if (input.isEmpty) {
                                return 'Enter your business address';
                              }
                              if (input.length < 8) {
                                return 'Address must be at least 8 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          _profileInputField(
                            context: sheetContext,
                            controller: phoneController,
                            label: 'Business phone',
                            hintText: 'Business phone',
                            keyboardType: TextInputType.phone,
                            inputFormatters: const [
                              _PhoneNumberTextFormatter()
                            ],
                            validator: (value) {
                              final input = value?.trim() ?? '';
                              if (input.isEmpty) {
                                return 'Enter your business phone';
                              }
                              final digitsOnly =
                                  input.replaceAll(RegExp(r'\D'), '');
                              if (digitsOnly.length < 7 ||
                                  digitsOnly.length > 15) {
                                return 'Enter a valid phone number';
                              }
                              final invalidCharacters = input.replaceAll(
                                RegExp(r'[0-9+()\-\s]'),
                                '',
                              );
                              if (invalidCharacters.isNotEmpty) {
                                return 'Use only valid phone characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: _OwnerAvatar(
                              user: user,
                              imageBytes: selectedPhotoBytes,
                              radius: 50,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: isSaving
                                  ? null
                                  : () async {
                                      final pickedFile =
                                          await imagePicker.pickImage(
                                        source: ImageSource.gallery,
                                        imageQuality: 85,
                                        maxWidth: 1200,
                                      );
                                      if (pickedFile == null) {
                                        return;
                                      }
                                      final bytes =
                                          await pickedFile.readAsBytes();
                                      setSheetState(() {
                                        selectedPhotoBytes = bytes;
                                      });
                                    },
                              icon: const Icon(Icons.upload_file_rounded),
                              label: const Text('Upload Photo From Device'),
                            ),
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: isSaving
                                  ? null
                                  : () async {
                                      if (!formKey.currentState!.validate()) {
                                        return;
                                      }
                                      setSheetState(() {
                                        isSaving = true;
                                      });
                                      final profileSuccess =
                                          await authProvider.updateProfile(
                                        userId: user.id,
                                        name: nameController.text.trim(),
                                        photoBytes: selectedPhotoBytes,
                                      );

                                      var shopSuccess = false;
                                      if (profileSuccess) {
                                        try {
                                          await _firestoreService
                                              .saveShopForOwner(
                                            ownerId: user.id,
                                            shopId: shop?.id ?? user.shopId,
                                            name:
                                                shopNameController.text.trim(),
                                            address:
                                                addressController.text.trim(),
                                            phone: phoneController.text.trim(),
                                          );
                                          shopSuccess = true;
                                        } catch (e) {
                                          if (!mounted) {
                                            return;
                                          }
                                          setSheetState(() {
                                            isSaving = false;
                                          });
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                                content: Text(e.toString())),
                                          );
                                        }
                                      }

                                      if (!mounted) {
                                        return;
                                      }
                                      if (profileSuccess && shopSuccess) {
                                        Navigator.of(sheetContext).pop();
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content:
                                                  Text('Profile updated.')),
                                        );
                                      } else {
                                        setSheetState(() {
                                          isSaving = false;
                                        });
                                        if (shopSuccess) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                authProvider.error ??
                                                    'Failed to update profile.',
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    },
                              child:
                                  Text(isSaving ? 'Saving...' : 'Save Changes'),
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
      nameController.dispose();
      shopNameController.dispose();
      addressController.dispose();
      phoneController.dispose();
    }
  }

  Future<void> _saveProfileSettings(
    BuildContext context, {
    required String userId,
    bool? notificationsEnabled,
    String? appearanceMode,
    String? languagePreference,
  }) async {
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.updateProfile(
      userId: userId,
      notificationsEnabled: notificationsEnabled,
      appearanceMode: appearanceMode,
      languagePreference: languagePreference,
    );

    if (!mounted || success) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          authProvider.error ?? 'Failed to update account settings.',
        ),
      ),
    );
  }

  Future<void> _showPersonalInformationSheet(
    BuildContext context,
    UserModel? user,
    ShopModel? shop,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(AppColors.white),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Personal Information',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 16),
                _InfoSheetRow(label: 'Name', value: user?.name ?? 'Owner'),
                _InfoSheetRow(
                    label: 'Email', value: user?.email ?? 'No email available'),
                _InfoSheetRow(
                    label: 'Phone',
                    value: shop?.phone.isNotEmpty == true
                        ? shop!.phone
                        : 'No business phone yet'),
                const _InfoSheetRow(label: 'Role', value: 'Shop Owner'),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handlePasswordSecurity(
      BuildContext context, String email) async {
    final authProvider = context.read<AuthProvider>();
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Password & Security'),
              content: Text('Send a password reset email to $email?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Send Reset Link'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed) {
      return;
    }

    final success = await authProvider.resetPassword(email);
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Password reset email sent to $email.'
              : authProvider.error ?? 'Failed to send reset email.',
        ),
      ),
    );
  }

  Future<void> _showPaymentMethodsSheet(
      BuildContext context, ShopModel? shop) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(AppColors.white),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment Methods',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 16),
                _InfoSheetRow(
                    label: 'Billing profile',
                    value: shop?.name.isNotEmpty == true
                        ? shop!.name
                        : 'ShopScan Retail'),
                const _InfoSheetRow(label: 'Cash payments', value: 'Enabled'),
                const _InfoSheetRow(
                    label: 'Card terminal', value: 'Not connected'),
                const _InfoSheetRow(
                    label: 'Payout account', value: 'Not configured'),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showAppearanceSheet(BuildContext context, String userId) async {
    final options = ['Light Mode', 'Dark Mode', 'System Default'];
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(AppColors.white),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: options
                .map(
                  (option) => ListTile(
                    title: Text(option),
                    trailing: option ==
                            (context
                                    .read<AuthProvider>()
                                    .currentUser
                                    ?.appearanceMode ??
                                'Light Mode')
                        ? const Icon(Icons.check_rounded,
                            color: Color(AppColors.primary))
                        : null,
                    onTap: () => Navigator.of(context).pop(option),
                  ),
                )
                .toList(),
          ),
        );
      },
    );

    if (selected != null) {
      await _saveProfileSettings(
        context,
        userId: userId,
        appearanceMode: selected,
      );
    }
  }

  Future<void> _showLanguageSheet(BuildContext context, String userId) async {
    final options = ['English (US)', 'English (UK)', 'Filipino'];
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(AppColors.white),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: options
                .map(
                  (option) => ListTile(
                    title: Text(option),
                    trailing: option ==
                            (context
                                    .read<AuthProvider>()
                                    .currentUser
                                    ?.languagePreference ??
                                'English (US)')
                        ? const Icon(Icons.check_rounded,
                            color: Color(AppColors.primary))
                        : null,
                    onTap: () => Navigator.of(context).pop(option),
                  ),
                )
                .toList(),
          ),
        );
      },
    );

    if (selected != null) {
      await _saveProfileSettings(
        context,
        userId: userId,
        languagePreference: selected,
      );
    }
  }

  Future<void> _showHelpSupportSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(AppColors.white),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return const SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoSheetRow(
                    label: 'Support email', value: 'support@shopscan.app'),
                _InfoSheetRow(label: 'Hotline', value: '+63 900 000 0000'),
                _InfoSheetRow(
                    label: 'Knowledge base',
                    value: 'Inventory, reports, cashier workflows'),
                _InfoSheetRow(label: 'Response time', value: 'Within 24 hours'),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Sign Out'),
              content:
                  const Text('Do you want to sign out of your owner account?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Sign Out'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed) {
      return;
    }

    setState(() {
      _isSigningOut = true;
    });
    await authProvider.signOut();
    if (mounted) {
      setState(() {
        _isSigningOut = false;
      });
    }
  }

  Widget _profileInputField({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    String? hintText,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          decoration: InputDecoration(
            hintText: hintText,
            filled: true,
            fillColor: const Color(0xFFF7F8FB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(AppColors.primary)),
            ),
          ),
        ),
      ],
    );
  }
}

class _PhoneNumberTextFormatter extends TextInputFormatter {
  const _PhoneNumberTextFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final hasLeadingPlus = newValue.text.trimLeft().startsWith('+');
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');

    if (digits.isEmpty) {
      return TextEditingValue(
        text: hasLeadingPlus ? '+' : '',
        selection: TextSelection.collapsed(offset: hasLeadingPlus ? 1 : 0),
      );
    }

    final buffer = StringBuffer();
    var digitIndex = 0;

    if (hasLeadingPlus) {
      buffer.write('+');
      final countryLength = digits.length <= 2 ? digits.length : 2;
      buffer.write(digits.substring(0, countryLength));
      digitIndex = countryLength;
      if (digitIndex < digits.length) {
        buffer.write(' ');
      }
    }

    while (digitIndex < digits.length) {
      final remaining = digits.length - digitIndex;
      final groupLength = remaining > 4 ? 3 : remaining;
      buffer.write(digits.substring(digitIndex, digitIndex + groupLength));
      digitIndex += groupLength;
      if (digitIndex < digits.length) {
        buffer.write('-');
      }
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _OwnerAvatar extends StatelessWidget {
  const _OwnerAvatar({
    required this.user,
    this.imageBytes,
    this.radius = 62,
  });

  final UserModel? user;
  final Uint8List? imageBytes;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final photoUrl = user?.photoUrl;
    final ImageProvider<Object>? profileImage = imageBytes != null
        ? MemoryImage(imageBytes!) as ImageProvider<Object>
        : photoUrl != null && photoUrl.isNotEmpty
            ? NetworkImage(photoUrl) as ImageProvider<Object>
            : null;
    final initials = user?.name.trim().isNotEmpty == true
        ? user!.name
            .trim()
            .split(RegExp(r'\s+'))
            .take(2)
            .map((part) => part[0].toUpperCase())
            .join()
        : 'O';

    return Container(
      width: radius * 2,
      height: radius * 2,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(AppColors.primary), width: 3),
      ),
      child: CircleAvatar(
        backgroundColor: const Color(0xFF0E1B2A),
        radius: radius,
        backgroundImage: profileImage,
        child: imageBytes != null || (photoUrl != null && photoUrl.isNotEmpty)
            ? null
            : Text(
                initials,
                style: const TextStyle(
                  color: Color(AppColors.white),
                  fontWeight: FontWeight.w800,
                  fontSize: 34,
                ),
              ),
      ),
    );
  }
}

class _ProfileSectionLabel extends StatelessWidget {
  const _ProfileSectionLabel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard(
      {required this.child, this.padding = const EdgeInsets.all(20)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(AppColors.white),
        borderRadius: BorderRadius.circular(24),
      ),
      child: child,
    );
  }
}

class _BusinessDetailRow extends StatelessWidget {
  const _BusinessDetailRow({
    required this.icon,
    required this.iconBackground,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconBackground;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: iconBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(AppColors.primary)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: const Color(AppColors.greyDark),
                      letterSpacing: 0.7,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileActionRow extends StatelessWidget {
  const _ProfileActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor = const Color(AppColors.primary),
    this.titleColor,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Color iconColor;
  final Color? titleColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Row(
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(AppColors.greyDark),
                      ),
                ),
              ],
            ),
          ),
          trailing ?? const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

class _SwitchSettingRow extends StatelessWidget {
  const _SwitchSettingRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(AppColors.primary)),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: const Color(AppColors.white),
          activeTrackColor: const Color(AppColors.primary),
        ),
      ],
    );
  }
}

class _ValueSettingRow extends StatelessWidget {
  const _ValueSettingRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Row(
        children: [
          Icon(icon, color: const Color(AppColors.primary)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(AppColors.black),
                ),
          ),
        ],
      ),
    );
  }
}

class _InfoSheetRow extends StatelessWidget {
  const _InfoSheetRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: const Color(AppColors.greyDark),
                ),
          ),
          const SizedBox(height: 4),
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
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accentColor,
    this.badgeText,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accentColor;
  final String? badgeText;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      constraints: const BoxConstraints(minHeight: 146),
      decoration: BoxDecoration(
        color: const Color(AppColors.white),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accentColor),
              ),
              const Spacer(),
              if (badgeText != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FB),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badgeText!,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: badgeText!.contains('+')
                              ? const Color(AppColors.success)
                              : const Color(AppColors.greyDark),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  letterSpacing: 0.6,
                  color: const Color(AppColors.greyDark),
                ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _AlertMetricCard extends StatelessWidget {
  const _AlertMetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      constraints: const BoxConstraints(minHeight: 146),
      decoration: BoxDecoration(
        color: const Color(AppColors.orange),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(AppColors.white).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(AppColors.white),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(AppColors.white).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'ACTION REQUIRED',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: const Color(AppColors.white),
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  letterSpacing: 0.6,
                  color: const Color(AppColors.white),
                ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(AppColors.white),
                ),
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.summary});

  final _OwnerDashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final bars = summary.sixMonthRevenue;
    final hasRevenueData = bars.any((item) => item.amount > 0);
    final peak = hasRevenueData
        ? bars
            .map((item) => item.amount)
            .fold<double>(0, (a, b) => a > b ? a : b)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(AppColors.white),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Revenue Growth',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Monthly analysis for fiscal year ${DateTime.now().year}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(AppColors.greyDark),
                          ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7FB),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text('Last 6 Months'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (!hasRevenueData)
            const _EmptyStateCard(
              title: 'No revenue data yet',
              subtitle:
                  'Revenue bars will appear after transactions are recorded.',
              icon: Icons.show_chart_rounded,
            )
          else
            SizedBox(
              height: 190,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: bars.map((bar) {
                  final isPeak = bar.amount == peak && peak > 0;
                  final normalized = peak == 0 ? 0.0 : bar.amount / peak;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (isPeak)
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(AppColors.black),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Peak',
                                style: TextStyle(
                                  color: Color(AppColors.white),
                                  fontSize: 10,
                                ),
                              ),
                            )
                          else
                            const SizedBox(height: 27),
                          Container(
                            height: 126 * normalized,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: isPeak
                                    ? const [
                                        Color(0xFF0B64E8),
                                        Color(0xFF0052CC)
                                      ]
                                    : const [
                                        Color(0xFFA8CBF5),
                                        Color(0xFF74A9E8)
                                      ],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            bar.label,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: const Color(AppColors.greyDark),
                                ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _QuickActionsCard extends StatelessWidget {
  const _QuickActionsCard({required this.onTabSelected});

  final ValueChanged<int> onTabSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF1F5),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 14),
          _QuickActionTile(
            icon: Icons.add_circle_outline_rounded,
            label: 'Add Product',
            onTap: () => onTabSelected(1),
          ),
          const SizedBox(height: 12),
          _QuickActionTile(
            icon: Icons.description_outlined,
            label: 'View Reports',
            onTap: () => onTabSelected(2),
          ),
          const SizedBox(height: 12),
          _QuickActionTile(
            icon: Icons.badge_outlined,
            label: 'Manage Cashiers',
            onTap: () => onTabSelected(3),
          ),
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(AppColors.white),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFD9E6FF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: const Color(AppColors.primary)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopProductsCard extends StatelessWidget {
  const _TopProductsCard({
    required this.products,
    required this.topProducts,
    required this.onViewAll,
  });

  final List<ProductModel> products;
  final List<_TopProductSummary> topProducts;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final productMap = {for (final product in products) product.id: product};

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
      decoration: BoxDecoration(
        color: const Color(AppColors.white),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top Selling Products',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Performance metrics based on units sold this month',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(AppColors.greyDark),
                ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                flex: 4,
                child: Text(
                  'PRODUCT',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: const Color(AppColors.greyDark),
                      ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'SKU',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: const Color(AppColors.greyDark),
                      ),
                ),
              ),
              Expanded(
                child: Text(
                  'QTY',
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: const Color(AppColors.greyDark),
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (topProducts.isEmpty)
            const _EmptyStateCard(
              title: 'No product sales yet',
              subtitle:
                  'Sales data will appear here after the first transactions.',
              icon: Icons.insights_outlined,
            )
          else
            ...topProducts.map(
              (entry) {
                final product = productMap[entry.productId];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: Row(
                          children: [
                            _ProductThumb(
                              product: product,
                              fallbackName: entry.productName,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                entry.productName,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          entry.sku,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: Color(0xFF9FC8FF),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${entry.quantity}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 6),
          Center(
            child: TextButton(
              onPressed: onViewAll,
              child: const Text('View All Inventory'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductThumb extends StatelessWidget {
  const _ProductThumb({required this.product, required this.fallbackName});

  final ProductModel? product;
  final String fallbackName;

  @override
  Widget build(BuildContext context) {
    if (product?.imageUrl != null && product!.imageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          product!.imageUrl!,
          width: 42,
          height: 42,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallbackAvatar(),
        ),
      );
    }

    return _fallbackAvatar();
  }

  Widget _fallbackAvatar() {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          fallbackName.isEmpty ? 'P' : fallbackName[0].toUpperCase(),
          style: const TextStyle(
            color: Color(AppColors.black),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7FA),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(AppColors.greyDark)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
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
    );
  }
}

class _OwnerDashboardSummary {
  _OwnerDashboardSummary({
    required this.totalRevenue,
    required this.monthRevenue,
    required this.totalProducts,
    required this.lowStockCount,
    required this.topProducts,
    required this.sixMonthRevenue,
    required this.todayLabel,
    required this.revenueTrend,
  });

  final double totalRevenue;
  final double monthRevenue;
  final int totalProducts;
  final int lowStockCount;
  final List<_TopProductSummary> topProducts;
  final List<_RevenueBar> sixMonthRevenue;
  final String todayLabel;
  final String? revenueTrend;

  String get totalRevenueLabel => _currency(totalRevenue);
  String get monthRevenueLabel => _currency(monthRevenue);

  static _OwnerDashboardSummary fromData({
    required List<TransactionModel> transactions,
    required List<ProductModel> products,
  }) {
    final now = DateTime.now();
    final todayTransactions = transactions.where((transaction) {
      final date = transaction.timestamp;
      return date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    }).toList();

    final monthTransactions = transactions.where((transaction) {
      final date = transaction.timestamp;
      return date.year == now.year && date.month == now.month;
    }).toList();

    final previousMonth = DateTime(now.year, now.month - 1, 1);
    final previousMonthTransactions = transactions.where((transaction) {
      final date = transaction.timestamp;
      return date.year == previousMonth.year &&
          date.month == previousMonth.month;
    }).toList();

    final totalRevenue =
        todayTransactions.fold<double>(0, (sum, item) => sum + item.total);
    final monthRevenue =
        monthTransactions.fold<double>(0, (sum, item) => sum + item.total);
    final previousMonthRevenue = previousMonthTransactions.fold<double>(
      0,
      (sum, item) => sum + item.total,
    );

    final String? growth;
    if (previousMonthRevenue > 0) {
      final growthValue =
          ((monthRevenue - previousMonthRevenue) / previousMonthRevenue) * 100;
      growth =
          '${growthValue >= 0 ? '+' : ''}${growthValue.toStringAsFixed(1)}%';
    } else {
      growth = null;
    }

    final salesByProduct = <String, _TopProductSummary>{};
    for (final transaction in monthTransactions) {
      for (final item in transaction.items) {
        final current = salesByProduct[item.productId];
        salesByProduct[item.productId] = _TopProductSummary(
          productId: item.productId,
          productName: item.productName,
          quantity: (current?.quantity ?? 0) + item.quantity,
          revenue: (current?.revenue ?? 0) + item.totalPrice,
          sku: item.sku,
        );
      }
    }

    final topProducts = salesByProduct.values.toList()
      ..sort((a, b) => b.quantity.compareTo(a.quantity));

    final sixMonthRevenue = List.generate(6, (index) {
      final target = DateTime(now.year, now.month - (5 - index), 1);
      final monthlyRevenue = transactions
          .where((transaction) =>
              transaction.timestamp.year == target.year &&
              transaction.timestamp.month == target.month)
          .fold<double>(0, (sum, item) => sum + item.total);

      return _RevenueBar(
        label: DateFormat('MMM').format(target).toUpperCase(),
        amount: monthlyRevenue,
      );
    });

    return _OwnerDashboardSummary(
      totalRevenue: totalRevenue,
      monthRevenue: monthRevenue,
      totalProducts: products.length,
      lowStockCount: products.where((product) => product.isLowStock).length,
      topProducts: topProducts.take(3).toList(),
      sixMonthRevenue: sixMonthRevenue,
      todayLabel: DateFormat('MMM d').format(now),
      revenueTrend: growth,
    );
  }

  static String _currency(double amount) {
    return NumberFormat.currency(symbol: r'$', decimalDigits: 2).format(amount);
  }
}

class _TopProductSummary {
  const _TopProductSummary({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.revenue,
    required this.sku,
  });

  final String productId;
  final String productName;
  final int quantity;
  final double revenue;
  final String sku;
}

class _RevenueBar {
  const _RevenueBar({required this.label, required this.amount});

  final String label;
  final double amount;
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
