enum ShiftStatus { active, completed, cancelled }

class ShiftModel {
  final String id;
  final String cashierId;
  final DateTime startTime;
  final DateTime? endTime;
  final ShiftStatus status;
  final double salesAmount;
  final int transactionCount;

  ShiftModel({
    required this.id,
    required this.cashierId,
    required this.startTime,
    required this.status, this.endTime,
    this.salesAmount = 0,
    this.transactionCount = 0,
  });

  // Calculate hours worked
  Duration get hoursWorked {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  String get hoursWorkedFormatted {
    final duration = hoursWorked;
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    return '${hours}h ${minutes}m';
  }

  bool get isActive => status == ShiftStatus.active;

  // Convert to JSON
  Map<String, dynamic> toJson() => {
    'id': id,
    'cashierId': cashierId,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime?.toIso8601String(),
    'status': status.toString().split('.').last,
    'salesAmount': salesAmount,
    'transactionCount': transactionCount,
  };

  // Create from JSON
  factory ShiftModel.fromJson(Map<String, dynamic> json, String docId) {
    return ShiftModel(
      id: docId,
      cashierId: json['cashierId'] ?? '',
      startTime: json['startTime'] != null
          ? DateTime.parse(json['startTime'])
          : DateTime.now(),
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
      status: _parseStatus(json['status']),
      salesAmount: (json['salesAmount'] ?? 0).toDouble(),
      transactionCount: json['transactionCount'] ?? 0,
    );
  }

  static ShiftStatus _parseStatus(String? status) {
    switch (status) {
      case 'completed':
        return ShiftStatus.completed;
      case 'cancelled':
        return ShiftStatus.cancelled;
      default:
        return ShiftStatus.active;
    }
  }

  // Copy with changes
  ShiftModel copyWith({
    String? id,
    String? cashierId,
    DateTime? startTime,
    DateTime? endTime,
    ShiftStatus? status,
    double? salesAmount,
    int? transactionCount,
  }) {
    return ShiftModel(
      id: id ?? this.id,
      cashierId: cashierId ?? this.cashierId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      salesAmount: salesAmount ?? this.salesAmount,
      transactionCount: transactionCount ?? this.transactionCount,
    );
  }
}
