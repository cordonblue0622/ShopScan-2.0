import 'user_model.dart';

enum ApprovalRequestStatus { pending, approved, declined }

class ApprovalRequestModel {
  final String id;
  final String shopId;
  final String requesterId;
  final String requesterName;
  final String requesterEmail;
  final UserRole requesterRole;
  final String approverId;
  final String type;
  final String message;
  final ApprovalRequestStatus status;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final String? resolvedByName;

  const ApprovalRequestModel({
    required this.id,
    required this.shopId,
    required this.requesterId,
    required this.requesterName,
    required this.requesterEmail,
    required this.requesterRole,
    required this.approverId,
    required this.type,
    required this.message,
    required this.status,
    required this.createdAt,
    this.resolvedAt,
    this.resolvedByName,
  });

  bool get isPending => status == ApprovalRequestStatus.pending;

  String get statusLabel {
    switch (status) {
      case ApprovalRequestStatus.pending:
        return 'Pending';
      case ApprovalRequestStatus.approved:
        return 'Approved';
      case ApprovalRequestStatus.declined:
        return 'Declined';
    }
  }

  String get typeLabel {
    switch (type) {
      case 'password_reset':
        return 'Password Reset';
      default:
        return 'Approval Request';
    }
  }

  Map<String, dynamic> toJson() => {
        'shopId': shopId,
        'requesterId': requesterId,
        'requesterName': requesterName,
        'requesterEmail': requesterEmail,
        'requesterRole': requesterRole.name,
        'approverId': approverId,
        'type': type,
        'message': message,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'resolvedAt': resolvedAt?.toIso8601String(),
        'resolvedByName': resolvedByName,
      };

  factory ApprovalRequestModel.fromJson(Map<String, dynamic> json, String docId) {
    return ApprovalRequestModel(
      id: docId,
      shopId: (json['shopId'] ?? '').toString(),
      requesterId: (json['requesterId'] ?? '').toString(),
      requesterName: (json['requesterName'] ?? '').toString(),
      requesterEmail: (json['requesterEmail'] ?? '').toString(),
      requesterRole: (json['requesterRole'] ?? 'cashier') == 'owner'
          ? UserRole.owner
          : UserRole.cashier,
      approverId: (json['approverId'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      status: _statusFromString((json['status'] ?? 'pending').toString()),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
          : DateTime.now(),
      resolvedAt: json['resolvedAt'] != null &&
              json['resolvedAt'].toString().isNotEmpty
          ? DateTime.parse(json['resolvedAt'].toString())
          : null,
      resolvedByName: json['resolvedByName']?.toString(),
    );
  }

  ApprovalRequestModel copyWith({
    String? id,
    String? shopId,
    String? requesterId,
    String? requesterName,
    String? requesterEmail,
    UserRole? requesterRole,
    String? approverId,
    String? type,
    String? message,
    ApprovalRequestStatus? status,
    DateTime? createdAt,
    DateTime? resolvedAt,
    String? resolvedByName,
  }) {
    return ApprovalRequestModel(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      requesterId: requesterId ?? this.requesterId,
      requesterName: requesterName ?? this.requesterName,
      requesterEmail: requesterEmail ?? this.requesterEmail,
      requesterRole: requesterRole ?? this.requesterRole,
      approverId: approverId ?? this.approverId,
      type: type ?? this.type,
      message: message ?? this.message,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      resolvedByName: resolvedByName ?? this.resolvedByName,
    );
  }

  static ApprovalRequestStatus _statusFromString(String value) {
    switch (value) {
      case 'approved':
        return ApprovalRequestStatus.approved;
      case 'declined':
        return ApprovalRequestStatus.declined;
      default:
        return ApprovalRequestStatus.pending;
    }
  }
}
