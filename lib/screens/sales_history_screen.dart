import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/auth_provider.dart';
import '../../models/transaction_model.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({Key? key}) : super(key: key);

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  final _firestoreService = FirestoreService();
  static const double _summaryStripHeight = 106;

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthProvider>().currentUser;
    final isOwner = currentUser?.role == UserRole.owner;
    final transactionStream = currentUser == null
        ? const Stream<List<TransactionModel>>.empty()
        : isOwner
            ? _firestoreService.getTransactionsStream(
                shopId: currentUser.shopId)
            : _firestoreService.getTransactionsByCashierStream(
                currentUser.id,
                shopId: currentUser.shopId,
              );
    final bottomSafeArea = MediaQuery.paddingOf(context).bottom;
    final listBottomPadding = _summaryStripHeight + bottomSafeArea + 28;

    return Scaffold(
      backgroundColor: const Color(AppColors.lightBg),
      body: SafeArea(
        child: StreamBuilder<List<TransactionModel>>(
          stream: transactionStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Failed to load reports: ${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final transactions = snapshot.data ?? <TransactionModel>[];
            final summary = _ReportsSummary.fromTransactions(transactions);
            return Stack(
              children: [
                ListView(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, listBottomPadding),
                  children: [
                    Text(
                      isOwner ? 'Reports & Analytics' : 'Sales History',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isOwner
                          ? 'Performance overview for ${summary.periodLabel}'
                          : 'Your completed sales for ${summary.periodLabel}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(AppColors.greyDark),
                          ),
                    ),
                    const SizedBox(height: 18),
                    _RevenueChartCard(summary: summary),
                    const SizedBox(height: 18),
                    _TodaySalesCard(summary: summary),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _MiniMetricCard(
                            icon: Icons.shopping_bag_outlined,
                            iconColor: const Color(AppColors.orange),
                            iconBackground: const Color(0xFFFFE6DA),
                            label: 'AVG ORDER VALUE',
                            value: summary.avgOrderValueLabel,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MiniMetricCard(
                            icon: Icons.shopping_cart_checkout_rounded,
                            iconColor: const Color(AppColors.primary),
                            iconBackground: const Color(0xFFDDEAFF),
                            label: 'ITEMS SOLD',
                            value: NumberFormat.decimalPattern().format(
                              summary.totalItemsSold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _TopSellingProductsCard(summary: summary),
                    const SizedBox(height: 18),
                    _DailyBreakdownCard(summary: summary),
                  ],
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 6 + bottomSafeArea,
                  child: _ReportsSummaryStrip(summary: summary),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RevenueChartCard extends StatelessWidget {
  const _RevenueChartCard({required this.summary});

  final _ReportsSummary summary;

  @override
  Widget build(BuildContext context) {
    final bars = summary.monthlyBars;
    final maxAmount = bars.isEmpty
        ? 0.0
        : bars
            .map((bar) => bar.amount)
            .fold<double>(0, (a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(AppColors.white),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TOTAL MONTHLY REVENUE',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: const Color(AppColors.greyDark),
                  letterSpacing: 0.7,
                ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  summary.totalMonthlyRevenueLabel,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: const Color(AppColors.primary),
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F7FA),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text('Revenue'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (bars.isEmpty || maxAmount == 0)
            const _EmptyAnalyticsCard(
              title: 'No monthly sales yet',
              subtitle:
                  'Revenue bars will appear after completed transactions are recorded this month.',
              icon: Icons.bar_chart_rounded,
            )
          else
            SizedBox(
              height: 236,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: bars.map((bar) {
                  final normalized =
                      maxAmount == 0 ? 0.0 : bar.amount / maxAmount;
                  final isPeak = summary.peakDayLabel == bar.label;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        children: [
                          SizedBox(
                            height: 28,
                            child: isPeak
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
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
                                : const SizedBox.shrink(),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: FractionallySizedBox(
                                widthFactor: 0.78,
                                heightFactor: normalized.clamp(0.08, 1.0),
                                alignment: Alignment.bottomCenter,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: isPeak
                                        ? const Color(AppColors.primary)
                                        : const Color(0xFFEAF1FF),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 16,
                            child: Text(
                              bar.label,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: const Color(AppColors.greyDark),
                                  ),
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

class _TodaySalesCard extends StatelessWidget {
  const _TodaySalesCard({required this.summary});

  final _ReportsSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(AppColors.primary),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(AppColors.primary).withValues(alpha: 0.22),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
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
                  color: const Color(AppColors.white).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.trending_up_rounded,
                  color: Color(AppColors.white),
                ),
              ),
              const Spacer(),
              if (summary.todayGrowthLabel != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(AppColors.white).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${summary.todayGrowthLabel} TODAY',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: const Color(AppColors.white),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'TODAY\'S SALES',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: const Color(AppColors.white).withValues(alpha: 0.9),
                  letterSpacing: 0.7,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            summary.todaySalesLabel,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: const Color(AppColors.white),
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(
                Icons.access_time_filled_rounded,
                size: 14,
                color: const Color(AppColors.white).withValues(alpha: 0.78),
              ),
              const SizedBox(width: 6),
              Text(
                summary.lastUpdateLabel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color:
                          const Color(AppColors.white).withValues(alpha: 0.84),
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniMetricCard extends StatelessWidget {
  const _MiniMetricCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(AppColors.white),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: const Color(AppColors.greyDark),
                        letterSpacing: 0.5,
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
      ),
    );
  }
}

class _TopSellingProductsCard extends StatelessWidget {
  const _TopSellingProductsCard({required this.summary});

  final _ReportsSummary summary;

  @override
  Widget build(BuildContext context) {
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
                child: Text(
                  'Top Selling Products',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              Text(
                'This Month',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(AppColors.primary),
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (summary.topProducts.isEmpty)
            const _EmptyAnalyticsCard(
              title: 'No top products yet',
              subtitle:
                  'Top selling products will appear here after sales are recorded.',
              icon: Icons.inventory_2_outlined,
            )
          else
            ...summary.topProducts.map(
              (product) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F4F9),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          product.name.isEmpty
                              ? 'P'
                              : product.name[0].toUpperCase(),
                          style: const TextStyle(
                            color: Color(AppColors.primary),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${product.quantity} sold',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
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
                          product.revenueLabel,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'REVENUE',
                          style:
                              Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: const Color(AppColors.greyDark),
                                    letterSpacing: 0.7,
                                  ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DailyBreakdownCard extends StatelessWidget {
  const _DailyBreakdownCard({required this.summary});

  final _ReportsSummary summary;

  @override
  Widget build(BuildContext context) {
    final peakValue = summary.dailyBreakdown.isEmpty
        ? 0.0
        : summary.dailyBreakdown
            .map((entry) => entry.total)
            .fold<double>(0, (a, b) => a > b ? a : b);

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
                child: Text(
                  'Daily Breakdown',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              const Icon(Icons.more_horiz_rounded),
            ],
          ),
          const SizedBox(height: 14),
          if (summary.dailyBreakdown.isEmpty)
            const _EmptyAnalyticsCard(
              title: 'No daily breakdown yet',
              subtitle:
                  'Daily revenue rows will appear when there are transactions.',
              icon: Icons.calendar_view_week_outlined,
            )
          else
            ...summary.dailyBreakdown.map(
              (entry) {
                final progress = peakValue == 0 ? 0.0 : entry.total / peakValue;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F8FB),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                entry.label,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                            Text(
                              entry.totalLabel,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: const Color(AppColors.primary),
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            minHeight: 5,
                            value: progress,
                            backgroundColor: const Color(0xFFE1E6EF),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(AppColors.primary),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _ReportsSummaryStrip extends StatelessWidget {
  const _ReportsSummaryStrip({required this.summary});

  final _ReportsSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(
        minHeight: _SalesHistoryScreenState._summaryStripHeight,
      ),
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
      child: Row(
        children: [
          Expanded(
            child: _StripMetric(
              label: 'TOTAL SALES',
              value: summary.totalSalesLabel,
            ),
          ),
          Container(
            width: 1,
            height: 62,
            color: const Color(AppColors.white).withValues(alpha: 0.32),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 18),
              child: _StripMetric(
                label: 'TRANSACTIONS',
                value: NumberFormat.decimalPattern().format(
                  summary.totalTransactions,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StripMetric extends StatelessWidget {
  const _StripMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: const Color(AppColors.white).withValues(alpha: 0.85),
                letterSpacing: 0.8,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: const Color(AppColors.white),
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

class _EmptyAnalyticsCard extends StatelessWidget {
  const _EmptyAnalyticsCard({
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
        color: const Color(0xFFF7F8FB),
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

class _ReportsSummary {
  const _ReportsSummary({
    required this.periodLabel,
    required this.totalMonthlyRevenue,
    required this.todaySales,
    required this.totalSales,
    required this.totalTransactions,
    required this.avgOrderValue,
    required this.totalItemsSold,
    required this.monthlyBars,
    required this.topProducts,
    required this.dailyBreakdown,
    required this.lastUpdate,
    required this.todayGrowthLabel,
    required this.peakDayLabel,
  });

  final String periodLabel;
  final double totalMonthlyRevenue;
  final double todaySales;
  final double totalSales;
  final int totalTransactions;
  final double avgOrderValue;
  final int totalItemsSold;
  final List<_RevenuePoint> monthlyBars;
  final List<_TopProductReport> topProducts;
  final List<_DailySalesEntry> dailyBreakdown;
  final DateTime? lastUpdate;
  final String? todayGrowthLabel;
  final String? peakDayLabel;

  String get totalMonthlyRevenueLabel => _currency(totalMonthlyRevenue);
  String get todaySalesLabel => _currency(todaySales);
  String get totalSalesLabel => _currency(totalSales);
  String get avgOrderValueLabel => _currency(avgOrderValue);

  String get lastUpdateLabel {
    if (lastUpdate == null) {
      return 'Updated just now';
    }
    return 'Updated ${DateFormat('MMM d, h:mm a').format(lastUpdate!)}';
  }

  factory _ReportsSummary.fromTransactions(
      List<TransactionModel> transactions) {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    final monthTransactions = transactions.where((transaction) {
      final date = transaction.timestamp;
      return date.year == now.year && date.month == now.month;
    }).toList();

    final todayTransactions = monthTransactions.where((transaction) {
      final date = transaction.timestamp;
      return date.day == now.day;
    }).toList();

    final yesterdayTransactions = monthTransactions.where((transaction) {
      final date = transaction.timestamp;
      return date.year == yesterday.year &&
          date.month == yesterday.month &&
          date.day == yesterday.day;
    }).toList();

    final totalMonthlyRevenue =
        monthTransactions.fold<double>(0, (sum, item) => sum + item.total);
    final totalSales =
        transactions.fold<double>(0, (sum, item) => sum + item.total);
    final todaySales =
        todayTransactions.fold<double>(0, (sum, item) => sum + item.total);
    final yesterdaySales =
        yesterdayTransactions.fold<double>(0, (sum, item) => sum + item.total);
    final double avgOrderValue =
        transactions.isEmpty ? 0.0 : totalSales / transactions.length;
    final totalItemsSold =
        transactions.fold<int>(0, (sum, item) => sum + item.itemCount);

    final Map<String, _TopProductReport> productTotals = {};
    for (final transaction in monthTransactions) {
      for (final item in transaction.items) {
        final current = productTotals[item.productId];
        productTotals[item.productId] = _TopProductReport(
          name: item.productName,
          quantity: (current?.quantity ?? 0) + item.quantity,
          revenue: (current?.revenue ?? 0) + item.totalPrice,
        );
      }
    }

    final topProducts = productTotals.values.toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));

    final dailyTotals = <DateTime, double>{};
    for (final transaction in monthTransactions) {
      final day = DateTime(
        transaction.timestamp.year,
        transaction.timestamp.month,
        transaction.timestamp.day,
      );
      dailyTotals[day] = (dailyTotals[day] ?? 0) + transaction.total;
    }

    final sortedDays = dailyTotals.keys.toList()
      ..sort((a, b) => a.compareTo(b));
    final monthlyBars = sortedDays.map((day) {
      return _RevenuePoint(
        label: DateFormat('MMM dd').format(day).toUpperCase(),
        amount: dailyTotals[day] ?? 0,
      );
    }).toList();

    final dailyBreakdown = sortedDays.reversed.take(4).map((day) {
      final total = dailyTotals[day] ?? 0;
      return _DailySalesEntry(
        label: DateFormat('EEEE, MMM d').format(day),
        total: total,
      );
    }).toList();

    String? growthLabel;
    if (yesterdaySales > 0) {
      final growth = ((todaySales - yesterdaySales) / yesterdaySales) * 100;
      growthLabel = '${growth >= 0 ? '+' : ''}${growth.toStringAsFixed(1)}%';
    }

    String? peakDayLabel;
    if (monthlyBars.isNotEmpty) {
      final peakPoint =
          monthlyBars.reduce((a, b) => a.amount >= b.amount ? a : b);
      if (peakPoint.amount > 0) {
        peakDayLabel = peakPoint.label;
      }
    }

    final latestTimestamp = transactions.isEmpty
        ? null
        : transactions.map((transaction) => transaction.timestamp).reduce(
              (current, next) => current.isAfter(next) ? current : next,
            );

    return _ReportsSummary(
      periodLabel: DateFormat('MMMM yyyy').format(now),
      totalMonthlyRevenue: totalMonthlyRevenue,
      todaySales: todaySales,
      totalSales: totalSales,
      totalTransactions: transactions.length,
      avgOrderValue: avgOrderValue,
      totalItemsSold: totalItemsSold,
      monthlyBars: monthlyBars,
      topProducts: topProducts.take(3).toList(),
      dailyBreakdown: dailyBreakdown,
      lastUpdate: latestTimestamp,
      todayGrowthLabel: growthLabel,
      peakDayLabel: peakDayLabel,
    );
  }

  static String _currency(double amount) {
    return NumberFormat.currency(symbol: r'$', decimalDigits: 2).format(amount);
  }
}

class _RevenuePoint {
  const _RevenuePoint({required this.label, required this.amount});

  final String label;
  final double amount;
}

class _TopProductReport {
  const _TopProductReport({
    required this.name,
    required this.quantity,
    required this.revenue,
  });

  final String name;
  final int quantity;
  final double revenue;

  String get revenueLabel =>
      NumberFormat.currency(symbol: r'$', decimalDigits: 2).format(revenue);
}

class _DailySalesEntry {
  const _DailySalesEntry({required this.label, required this.total});

  final String label;
  final double total;

  String get totalLabel =>
      NumberFormat.currency(symbol: r'$', decimalDigits: 0).format(total);
}
