import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../models/transaction_model.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';

class OwnerAnalyticsDashboard extends StatefulWidget {
  const OwnerAnalyticsDashboard({Key? key}) : super(key: key);

  @override
  State<OwnerAnalyticsDashboard> createState() =>
      _OwnerAnalyticsDashboardState();
}

class _OwnerAnalyticsDashboardState extends State<OwnerAnalyticsDashboard> {
  final _firestoreService = FirestoreService();
  String _selectedPeriod = 'Today';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Owner Dashboard',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildPeriodSelector(context),
              _buildKeyMetrics(context),
              _buildTopProductsSection(context),
              _buildCashierPerformanceSection(context),
              const SizedBox(height: AppDimens.paddingLarge),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodSelector(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppDimens.paddingMedium),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: ['Today', 'This Week', 'This Month', 'All Time']
              .map((period) => Padding(
                    padding: const EdgeInsets.only(right: AppDimens.paddingSmall),
                    child: FilterChip(
                      label: Text(period),
                      selected: _selectedPeriod == period,
                      onSelected: (_) {
                        setState(() {
                          _selectedPeriod = period;
                        });
                      },
                      backgroundColor: _selectedPeriod == period
                          ? const Color(AppColors.primary)
                          : const Color(AppColors.grey),
                      labelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _selectedPeriod == period
                                ? const Color(AppColors.white)
                                : const Color(AppColors.black),
                          ),
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildKeyMetrics(BuildContext context) {
    return StreamBuilder<List<TransactionModel>>(
      stream: _firestoreService.getTransactionsStream(),
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        var transactions = snapshot.data ?? [];
        transactions = _filterByPeriod(transactions);

        final totalSales =
            transactions.fold<double>(0, (sum, t) => sum + t.total);
        final totalTransactions = transactions.length;
        final totalItems =
            transactions.fold<int>(0, (sum, t) => sum + t.items.length);
        final avgTransactionValue = totalTransactions > 0
            ? totalSales / totalTransactions
            : 0;

        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.paddingMedium,
            vertical: AppDimens.paddingSmall,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      context,
                      'TOTAL SALES',
                      '\$${totalSales.toStringAsFixed(2)}',
                      Icons.trending_up,
                    ),
                  ),
                  const SizedBox(width: AppDimens.paddingMedium),
                  Expanded(
                    child: _buildMetricCard(
                      context,
                      'TRANSACTIONS',
                      '$totalTransactions',
                      Icons.receipt,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.paddingMedium),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      context,
                      'ITEMS SOLD',
                      '$totalItems',
                      Icons.inventory_2,
                    ),
                  ),
                  const SizedBox(width: AppDimens.paddingMedium),
                  Expanded(
                    child: _buildMetricCard(
                      context,
                      'AVG VALUE',
                      '\$${avgTransactionValue.toStringAsFixed(2)}',
                      Icons.assessment,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricCard(BuildContext context, String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.paddingMedium),
      decoration: BoxDecoration(
        color: const Color(AppColors.white),
        border: Border.all(color: const Color(AppColors.borderColor)),
        borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 24,
            color: const Color(AppColors.primary),
          ),
          const SizedBox(height: AppDimens.paddingSmall),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: const Color(AppColors.greyDark),
                ),
          ),
          const SizedBox(height: AppDimens.paddingXSmall),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(AppColors.primary),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopProductsSection(BuildContext context) {
    return StreamBuilder<List<TransactionModel>>(
      stream: _firestoreService.getTransactionsStream(),
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        var transactions = snapshot.data ?? [];
        transactions = _filterByPeriod(transactions);

        // Calculate top products
        final productSales = <String, Map<String, dynamic>>{};
        for (var transaction in transactions) {
          for (var item in transaction.items) {
            if (productSales.containsKey(item.productName)) {
              productSales[item.productName]!['quantity'] += item.quantity;
              productSales[item.productName]!['revenue'] += item.totalPrice;
            } else {
              productSales[item.productName] = {
                'quantity': item.quantity,
                'revenue': item.totalPrice,
              };
            }
          }
        }

        final topProducts = productSales.entries.toList()
          ..sort((a, b) =>
              (b.value['revenue'] as num).compareTo(a.value['revenue'] as num));

        return Padding(
          padding: const EdgeInsets.all(AppDimens.paddingMedium),
          child: Container(
            padding: const EdgeInsets.all(AppDimens.paddingMedium),
            decoration: BoxDecoration(
              color: const Color(AppColors.white),
              border: Border.all(color: const Color(AppColors.borderColor)),
              borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Top 5 Products',
                  style: Theme.of(ctx)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppDimens.paddingMedium),
                ...topProducts.take(5).toList().asMap().entries.map((entry) {
                  final index = entry.key;
                  final product = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppDimens.paddingSmall),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            color: Color(AppColors.primary),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                                style: Theme.of(ctx)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: const Color(AppColors.white),
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppDimens.paddingMedium),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.key,
                                style: Theme.of(ctx).textTheme.bodySmall,
                              ),
                              Text(
                                '${product.value['quantity']} units',
                                style: Theme.of(ctx)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: const Color(AppColors.greyDark),
                                    ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '\$${(product.value['revenue'] as num).toStringAsFixed(2)}',
                          style: Theme.of(ctx)
                              .textTheme
                              .bodySmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCashierPerformanceSection(BuildContext context) {
    return StreamBuilder<List<TransactionModel>>(
      stream: _firestoreService.getTransactionsStream(),
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        var transactions = snapshot.data ?? [];
        transactions = _filterByPeriod(transactions);

        // Calculate cashier performance
        final cashierStats = <String, Map<String, dynamic>>{};
        for (var transaction in transactions) {
          if (cashierStats.containsKey(transaction.cashierName)) {
            cashierStats[transaction.cashierName]!['transactions'] += 1;
            cashierStats[transaction.cashierName]!['sales'] +=
                transaction.total;
          } else {
            cashierStats[transaction.cashierName] = {
              'transactions': 1,
              'sales': transaction.total,
            };
          }
        }

        final topCashiers = cashierStats.entries.toList()
          ..sort((a, b) =>
              (b.value['sales'] as num).compareTo(a.value['sales'] as num));

        return Padding(
          padding: const EdgeInsets.all(AppDimens.paddingMedium),
          child: Container(
            padding: const EdgeInsets.all(AppDimens.paddingMedium),
            decoration: BoxDecoration(
              color: const Color(AppColors.white),
              border: Border.all(color: const Color(AppColors.borderColor)),
              borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Cashier Performance',
                      style: Theme.of(ctx)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    TextButton(
                      onPressed: () => _showCashierDetails(context),
                      child: Text(
                        'Manage →',
                        style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                              color: const Color(AppColors.primary),
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimens.paddingMedium),
                cashierStats.isEmpty
                    ? Center(
                        child: Text(
                          'No cashier data available',
                          style:
                              Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                    color: const Color(AppColors.greyDark),
                                  ),
                        ),
                      )
                    : Column(
                        children: topCashiers
                            .take(5)
                            .map((entry) => Padding(
                                  padding: const EdgeInsets.only(
                                      bottom: AppDimens.paddingSmall),
                                  child: _buildCashierPerformanceCard(
                                    ctx,
                                    entry.key,
                                    entry.value['transactions'] as int,
                                    entry.value['sales'] as double,
                                  ),
                                ))
                            .toList(),
                      ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCashierPerformanceCard(
    BuildContext context,
    String name,
    int transactions,
    double sales,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.paddingSmall),
      decoration: BoxDecoration(
        color: const Color(AppColors.grey),
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(AppColors.primary),
            child: Text(
              name.substring(0, 1).toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: const Color(AppColors.white),
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          const SizedBox(width: AppDimens.paddingMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  '$transactions transactions',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: const Color(AppColors.greyDark),
                      ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${sales.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(AppColors.primary),
                    ),
              ),
              Text(
                'Total Sales',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: const Color(AppColors.greyDark),
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCashierDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppDimens.radiusLarge),
          topRight: Radius.circular(AppDimens.radiusLarge),
        ),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.paddingMedium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(AppColors.greyLight),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppDimens.paddingMedium),
                Text(
                  'Manage Cashiers',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppDimens.paddingMedium),
                StreamBuilder<List<UserModel>>(
                  stream: _firestoreService.getUsersStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final cashiers = snapshot.data
                            ?.where((u) => u.role == UserRole.cashier)
                            .toList() ??
                        [];

                    if (cashiers.isEmpty) {
                      return const Center(
                        child: Text('No cashiers found'),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: cashiers.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppDimens.paddingSmall),
                      itemBuilder: (context, index) {
                        final cashier = cashiers[index];
                        return Container(
                          padding: const EdgeInsets.all(AppDimens.paddingSmall),
                          decoration: BoxDecoration(
                            color: const Color(AppColors.grey),
                            borderRadius: BorderRadius.circular(
                                AppDimens.radiusMedium),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: const Color(AppColors.primary),
                                child: Text(
                                  cashier.name.substring(0, 1).toUpperCase(),
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: const Color(AppColors.white),
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ),
                              const SizedBox(width: AppDimens.paddingMedium),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      cashier.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    Text(
                                      cashier.email,
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
                              PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'deactivate') {
                                    // Handle deactivation
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      SnackBar(
                                          content: Text(
                                              '${cashier.name} deactivated')),
                                    );
                                  }
                                },
                                itemBuilder: (BuildContext context) => [
                                  const PopupMenuItem(
                                    value: 'view',
                                    child: Text('View Details'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'deactivate',
                                    child: Text(
                                      'Deactivate',
                                      style: TextStyle(
                                        color: Color(AppColors.error),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<TransactionModel> _filterByPeriod(List<TransactionModel> transactions) {
    final now = DateTime.now();

    switch (_selectedPeriod) {
      case 'Today':
        return transactions.where((t) {
          return t.dateTime.year == now.year &&
              t.dateTime.month == now.month &&
              t.dateTime.day == now.day;
        }).toList();
      case 'This Week':
        final weekAgo = now.subtract(Duration(days: now.weekday - 1));
        return transactions.where((t) => t.dateTime.isAfter(weekAgo)).toList();
      case 'This Month':
        return transactions.where((t) {
          return t.dateTime.year == now.year &&
              t.dateTime.month == now.month;
        }).toList();
      default:
        return transactions;
    }
  }
}
