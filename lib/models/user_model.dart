enum UserRole { owner, cashier }

class UserModel {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String? shopId;
  final String? photoUrl;
  final bool notificationsEnabled;
  final String appearanceMode;
  final String languagePreference;
  final String? assignedShiftLabel;
  final String? assignedShiftStart;
  final String? assignedShiftEnd;
  final DateTime createdAt;
  final bool isActive;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.createdAt,
    this.shopId,
    this.photoUrl,
    this.notificationsEnabled = true,
    this.appearanceMode = 'Light Mode',
    this.languagePreference = 'English (US)',
    this.assignedShiftLabel,
    this.assignedShiftStart,
    this.assignedShiftEnd,
    this.isActive = true,
  });

  // Convert to JSON
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role.toString().split('.').last,
        'shopId': shopId,
        'photoUrl': photoUrl,
        'notificationsEnabled': notificationsEnabled,
        'appearanceMode': appearanceMode,
        'languagePreference': languagePreference,
        'assignedShiftLabel': assignedShiftLabel,
        'assignedShiftStart': assignedShiftStart,
        'assignedShiftEnd': assignedShiftEnd,
        'createdAt': createdAt.toIso8601String(),
        'isActive': isActive,
      };

  // Create from JSON
  factory UserModel.fromJson(Map<String, dynamic> json, String docId) {
    return UserModel(
      id: docId,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] == 'owner' ? UserRole.owner : UserRole.cashier,
      shopId: json['shopId'],
      photoUrl: json['photoUrl'],
      notificationsEnabled: json['notificationsEnabled'] ?? true,
      appearanceMode: json['appearanceMode'] ?? 'Light Mode',
      languagePreference: json['languagePreference'] ?? 'English (US)',
      assignedShiftLabel: json['assignedShiftLabel'],
      assignedShiftStart: json['assignedShiftStart'],
      assignedShiftEnd: json['assignedShiftEnd'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      isActive: json['isActive'] ?? true,
    );
  }

  // Copy with changes
  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    UserRole? role,
    String? shopId,
    String? photoUrl,
    bool? notificationsEnabled,
    String? appearanceMode,
    String? languagePreference,
    String? assignedShiftLabel,
    String? assignedShiftStart,
    String? assignedShiftEnd,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      shopId: shopId ?? this.shopId,
      photoUrl: photoUrl ?? this.photoUrl,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      appearanceMode: appearanceMode ?? this.appearanceMode,
      languagePreference: languagePreference ?? this.languagePreference,
      assignedShiftLabel: assignedShiftLabel ?? this.assignedShiftLabel,
      assignedShiftStart: assignedShiftStart ?? this.assignedShiftStart,
      assignedShiftEnd: assignedShiftEnd ?? this.assignedShiftEnd,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }
}
