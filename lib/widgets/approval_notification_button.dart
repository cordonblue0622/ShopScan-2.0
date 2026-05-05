import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/constants/app_constants.dart';
import '../models/approval_request_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class ApprovalNotificationButton extends StatelessWidget {
  ApprovalNotificationButton({
    required this.user, Key? key,
  })  : _firestoreService = FirestoreService(),
        _authService = AuthService(),
        super(key: key);

  final UserModel user;
  final FirestoreService _firestoreService;
  final AuthService _authService;

  @override
  Widget build(BuildContext context) {
    final stream = user.role == UserRole.owner
        ? _firestoreService.getApprovalRequestsForApproverStream(user.id)
        : _firestoreService.getApprovalRequestsForRequesterStream(user.id);

    return StreamBuilder<List<ApprovalRequestModel>>(
      stream: stream,
      builder: (context, snapshot) {
        final requests = snapshot.data ?? const <ApprovalRequestModel>[];
        final pendingCount = requests.where((request) => request.isPending).length;

        return IconButton(
          onPressed: () => _showSheet(context, requests),
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_none_rounded),
              if (pendingCount > 0)
                Positioned(
                  top: -3,
                  right: -5,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: const BoxDecoration(
                      color: Color(AppColors.error),
                      borderRadius: BorderRadius.all(Radius.circular(999)),
                    ),
                    constraints: const BoxConstraints(minWidth: 18),
                    child: Text(
                      pendingCount > 9 ? '9+' : '$pendingCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          tooltip: 'Approval requests',
        );
      },
    );
  }

  Future<void> _showSheet(
    BuildContext context,
    List<ApprovalRequestModel> initialRequests,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(AppColors.white),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        final stream = user.role == UserRole.owner
            ? _firestoreService.getApprovalRequestsForApproverStream(user.id)
            : _firestoreService.getApprovalRequestsForRequesterStream(user.id);

        return SafeArea(
          child: StreamBuilder<List<ApprovalRequestModel>>(
            stream: stream,
            initialData: initialRequests,
            builder: (context, snapshot) {
              final requests = snapshot.data ?? const <ApprovalRequestModel>[];
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(AppColors.greyLight),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      user.role == UserRole.owner
                          ? 'Approval Requests'
                          : 'Request Updates',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      user.role == UserRole.owner
                          ? 'Review cashier requests that need your action.'
                          : 'Track requests you have sent for owner approval.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(AppColors.greyDark),
                          ),
                    ),
                    const SizedBox(height: 16),
                    if (requests.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF6F7FA),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Text('No approval notifications yet.'),
                      )
                    else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: requests.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final request = requests[index];
                            return _ApprovalRequestCard(
                              request: request,
                              isOwnerView: user.role == UserRole.owner,
                              onApprove: request.isPending && user.role == UserRole.owner
                                  ? () => _handleDecision(
                                        context,
                                        request: request,
                                        status: ApprovalRequestStatus.approved,
                                      )
                                  : null,
                              onDecline: request.isPending && user.role == UserRole.owner
                                  ? () => _handleDecision(
                                        context,
                                        request: request,
                                        status: ApprovalRequestStatus.declined,
                                      )
                                  : null,
                            );
                          },
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _handleDecision(
    BuildContext context, {
    required ApprovalRequestModel request,
    required ApprovalRequestStatus status,
  }) async {
    try {
      if (status == ApprovalRequestStatus.approved &&
          request.type == 'password_reset') {
        await _authService.resetPassword(request.requesterEmail);
      }

      await _firestoreService.updateApprovalRequestStatus(
        request.id,
        status: status,
        resolvedByName: user.name,
      );

      if (!context.mounted) {
        return;
      }

      final actionLabel = status == ApprovalRequestStatus.approved
          ? 'approved'
          : 'declined';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == ApprovalRequestStatus.approved &&
                    request.type == 'password_reset'
                ? 'Password reset email sent and request approved.'
                : 'Request $actionLabel.',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update request: $error')),
      );
    }
  }
}

class _ApprovalRequestCard extends StatelessWidget {
  const _ApprovalRequestCard({
    required this.request,
    required this.isOwnerView,
    this.onApprove,
    this.onDecline,
  });

  final ApprovalRequestModel request;
  final bool isOwnerView;
  final VoidCallback? onApprove;
  final VoidCallback? onDecline;

  @override
  Widget build(BuildContext context) {
    final createdLabel = DateFormat('MMM d, h:mm a').format(request.createdAt);
    final statusColor = switch (request.status) {
      ApprovalRequestStatus.pending => const Color(AppColors.orange),
      ApprovalRequestStatus.approved => const Color(AppColors.success),
      ApprovalRequestStatus.declined => const Color(AppColors.error),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(AppColors.white),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(AppColors.borderColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  request.typeLabel,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  request.statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isOwnerView
                ? '${request.requesterName} • ${request.requesterEmail}'
                : 'Submitted on $createdLabel',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(AppColors.greyDark),
                ),
          ),
          if (isOwnerView) ...[
            const SizedBox(height: 2),
            Text(
              createdLabel,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(AppColors.greyDark),
                  ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            request.message,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (request.resolvedByName?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Text(
              'Handled by ${request.resolvedByName}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(AppColors.greyDark),
                  ),
            ),
          ],
          if (onApprove != null && onDecline != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDecline,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(AppColors.error),
                      side: const BorderSide(color: Color(AppColors.error)),
                    ),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: onApprove,
                    child: const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
