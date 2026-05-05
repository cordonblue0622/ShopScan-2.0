import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/auth_provider.dart';
import '../../models/shift_model.dart';
import '../../services/firestore_service.dart';

class ShiftManagementScreen extends StatefulWidget {
  final String? cashierId;

  const ShiftManagementScreen({
    Key? key,
    this.cashierId,
  }) : super(key: key);

  @override
  State<ShiftManagementScreen> createState() => _ShiftManagementScreenState();
}

class _ShiftManagementScreenState extends State<ShiftManagementScreen> {
  final _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthProvider>().currentUser;
    final cashierId = widget.cashierId ?? currentUser?.id;

    if (cashierId == null || cashierId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Shift Management',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          elevation: 0,
        ),
        body: const SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(AppDimens.paddingMedium),
              child: Text(
                'Unable to load shifts because no cashier account is signed in.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Shift Management',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildActiveShiftSection(cashierId),
            const SizedBox(height: AppDimens.paddingMedium),
            Expanded(
              child: _buildShiftHistorySection(cashierId),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveShiftSection(String cashierId) {
    return StreamBuilder<List<ShiftModel>>(
      stream: _firestoreService.getShiftsByCashierStream(cashierId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final shifts = snapshot.data ?? [];
        final activeShift = shifts.cast<ShiftModel?>().firstWhere(
              (shift) => shift?.status == ShiftStatus.active,
              orElse: () => null,
            );

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
                      'Active Shift',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimens.paddingSmall,
                        vertical: AppDimens.paddingXSmall,
                      ),
                      decoration: BoxDecoration(
                        color: activeShift != null
                            ? const Color(AppColors.success).withOpacity(0.1)
                            : const Color(AppColors.greyLight),
                        borderRadius:
                            BorderRadius.circular(AppDimens.radiusSmall),
                      ),
                      child: Text(
                        activeShift != null ? 'ACTIVE' : 'NO ACTIVE SHIFT',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: activeShift != null
                                  ? const Color(AppColors.success)
                                  : const Color(AppColors.greyDark),
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimens.paddingMedium),
                if (activeShift != null)
                  _buildActiveShiftDetails(context, activeShift)
                else
                  _buildNoActiveShift(context),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActiveShiftDetails(BuildContext context, ShiftModel shift) {
    final elapsedTime = DateTime.now().difference(shift.startTime);
    final hours = elapsedTime.inHours;
    final minutes = (elapsedTime.inMinutes % 60);

    return Column(
      children: [
        _buildShiftInfoRow(
          'Shift Start',
          DateFormat('MMM dd, yyyy • hh:mm a').format(shift.startTime),
        ),
        const SizedBox(height: AppDimens.paddingSmall),
        _buildShiftInfoRow(
          'Duration',
          '$hours hours $minutes minutes',
          highlight: true,
        ),
        const SizedBox(height: AppDimens.paddingMedium),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _endShift(context, shift),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(AppColors.error),
              foregroundColor: const Color(AppColors.white),
              padding: const EdgeInsets.all(AppDimens.paddingMedium),
            ),
            icon: const Icon(Icons.logout),
            label: const Text('End Shift'),
          ),
        ),
      ],
    );
  }

  Widget _buildNoActiveShift(BuildContext context) {
    return Column(
      children: [
        const Icon(
          Icons.schedule_outlined,
          size: 48,
          color: Color(AppColors.greyLight),
        ),
        const SizedBox(height: AppDimens.paddingMedium),
        Text(
          'No active shift',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: const Color(AppColors.greyDark)),
        ),
        const SizedBox(height: AppDimens.paddingMedium),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _startShift(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(AppColors.success),
              foregroundColor: const Color(AppColors.white),
              padding: const EdgeInsets.all(AppDimens.paddingMedium),
            ),
            icon: const Icon(Icons.login),
            label: const Text('Start Shift'),
          ),
        ),
      ],
    );
  }

  Widget _buildShiftHistorySection(String cashierId) {
    return StreamBuilder<List<ShiftModel>>(
      stream: _firestoreService.getShiftsByCashierStream(cashierId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final shifts = snapshot.data ?? [];
        final completedShifts = shifts
            .where((s) => s.status == ShiftStatus.completed)
            .toList()
          ..sort((a, b) => b.startTime.compareTo(a.startTime));

        if (completedShifts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.history_outlined,
                  size: 64,
                  color: Color(AppColors.greyLight),
                ),
                const SizedBox(height: AppDimens.paddingMedium),
                Text(
                  'No completed shifts',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.paddingMedium,
                vertical: AppDimens.paddingSmall,
              ),
              child: Text(
                'Shift History',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.paddingMedium,
                ),
                itemCount: completedShifts.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppDimens.paddingSmall),
                itemBuilder: (context, index) {
                  return _buildShiftCard(context, completedShifts[index]);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildShiftCard(BuildContext context, ShiftModel shift) {
    return InkWell(
      onTap: () => _showShiftDetails(context, shift),
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
                  DateFormat('MMM dd, yyyy').format(shift.startTime),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  '${shift.hoursWorked} hrs',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: const Color(AppColors.primary),
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.paddingXSmall),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Start: ${DateFormat('hh:mm a').format(shift.startTime)}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: const Color(AppColors.greyDark),
                          ),
                    ),
                    if (shift.endTime != null)
                      Text(
                        'End: ${DateFormat('hh:mm a').format(shift.endTime!)}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: const Color(AppColors.greyDark),
                            ),
                      ),
                  ],
                ),
                const Icon(Icons.chevron_right,
                    color: Color(AppColors.greyDark)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showShiftDetails(BuildContext context, ShiftModel shift) {
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
                  'Shift Duration',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppDimens.paddingMedium),
                _buildShiftSummaryRow(
                  'Date',
                  DateFormat('MMM dd, yyyy').format(shift.startTime),
                ),
                _buildShiftSummaryRow(
                  'Start Time',
                  DateFormat('hh:mm a').format(shift.startTime),
                ),
                if (shift.endTime != null)
                  _buildShiftSummaryRow(
                    'End Time',
                    DateFormat('hh:mm a').format(shift.endTime!),
                  ),
                const SizedBox(height: AppDimens.paddingSmall),
                Container(
                  padding: const EdgeInsets.all(AppDimens.paddingSmall),
                  decoration: BoxDecoration(
                    color: const Color(AppColors.primary).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppDimens.radiusSmall),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'DURATION',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        '${shift.hoursWorked} hours',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: const Color(AppColors.primary),
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimens.paddingMedium),
                Text(
                  'Status',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: AppDimens.paddingXSmall),
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
                    shift.status.toString().split('.').last.toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: const Color(AppColors.success),
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _startShift(BuildContext context) {
    final cashierId =
        widget.cashierId ?? context.read<AuthProvider>().currentUser?.id;
    if (cashierId == null || cashierId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to start shift without a signed-in cashier.'),
          backgroundColor: Color(AppColors.error),
        ),
      );
      return;
    }

    final shift = ShiftModel(
      id: DateTime.now().toString(),
      cashierId: cashierId,
      startTime: DateTime.now(),
      status: ShiftStatus.active,
    );

    _firestoreService.saveShift(shift).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Shift started'),
          backgroundColor: Color(AppColors.success),
        ),
      );
    }).catchError((e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error starting shift: $e'),
          backgroundColor: const Color(AppColors.error),
        ),
      );
    });
  }

  void _endShift(BuildContext context, ShiftModel shift) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Shift'),
        content: const Text('Are you sure you want to end this shift?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              final endedShift = shift.copyWith(
                endTime: DateTime.now(),
                status: ShiftStatus.completed,
              );

              _firestoreService.saveShift(endedShift).then((_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Shift ended'),
                    backgroundColor: Color(AppColors.success),
                  ),
                );
              }).catchError((e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error ending shift: $e'),
                    backgroundColor: const Color(AppColors.error),
                  ),
                );
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(AppColors.error),
            ),
            child: const Text('End Shift'),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftInfoRow(String label, String value,
      {bool highlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(AppColors.greyDark),
              ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: highlight ? const Color(AppColors.primary) : null,
              ),
        ),
      ],
    );
  }

  Widget _buildShiftSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.paddingSmall),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(AppColors.greyDark),
                ),
          ),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
