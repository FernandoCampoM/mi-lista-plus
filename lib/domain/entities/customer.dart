enum ConsentScope { phone, birthday, goals, notes }

class Customer {
  const Customer({
    required this.id,
    required this.name,
    required this.callingCode,
    required this.phoneNumber,
    required this.createdAt,
    required this.updatedAt,
    this.goal = '',
    this.birthday,
    this.consentAt,
    this.consentVersion = '1',
    this.consentScopes = const {},
    this.consentRevokedAt,
    this.allowCalls = true,
    this.allowWhatsApp = true,
    this.followUpEnabled = true,
    this.followUpPausedUntil,
    this.followUpPauseReason,
    this.birthdayRemindersEnabled = true,
    this.archivedAt,
  });

  final String id;
  final String name;
  final String callingCode;
  final String phoneNumber;
  final String goal;
  final DateTime? birthday;
  final DateTime? consentAt;
  final String consentVersion;
  final Set<ConsentScope> consentScopes;
  final DateTime? consentRevokedAt;
  final bool allowCalls;
  final bool allowWhatsApp;
  final bool followUpEnabled;
  final DateTime? followUpPausedUntil;
  final String? followUpPauseReason;
  final bool birthdayRemindersEnabled;
  final DateTime? archivedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get normalizedPhone {
    final code = callingCode.replaceAll(RegExp(r'[^0-9]'), '');
    final number = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    return '+$code$number';
  }

  bool get isArchived => archivedAt != null;
  bool get hasActiveConsent => consentAt != null && consentRevokedAt == null;

  Customer copyWith({
    String? name,
    String? callingCode,
    String? phoneNumber,
    String? goal,
    DateTime? birthday,
    bool clearBirthday = false,
    DateTime? consentAt,
    Set<ConsentScope>? consentScopes,
    DateTime? consentRevokedAt,
    bool clearConsentRevocation = false,
    bool? allowCalls,
    bool? allowWhatsApp,
    bool? followUpEnabled,
    DateTime? followUpPausedUntil,
    bool clearPausedUntil = false,
    String? followUpPauseReason,
    bool? birthdayRemindersEnabled,
    DateTime? archivedAt,
    bool clearArchivedAt = false,
  }) => Customer(
        id: id,
        name: name ?? this.name,
        callingCode: callingCode ?? this.callingCode,
        phoneNumber: phoneNumber ?? this.phoneNumber,
        goal: goal ?? this.goal,
        birthday: clearBirthday ? null : birthday ?? this.birthday,
        consentAt: consentAt ?? this.consentAt,
        consentVersion: consentVersion,
        consentScopes: consentScopes ?? this.consentScopes,
        consentRevokedAt: clearConsentRevocation
            ? null
            : consentRevokedAt ?? this.consentRevokedAt,
        allowCalls: allowCalls ?? this.allowCalls,
        allowWhatsApp: allowWhatsApp ?? this.allowWhatsApp,
        followUpEnabled: followUpEnabled ?? this.followUpEnabled,
        followUpPausedUntil: clearPausedUntil
            ? null
            : followUpPausedUntil ?? this.followUpPausedUntil,
        followUpPauseReason: followUpPauseReason ?? this.followUpPauseReason,
        birthdayRemindersEnabled:
            birthdayRemindersEnabled ?? this.birthdayRemindersEnabled,
        archivedAt: clearArchivedAt ? null : archivedAt ?? this.archivedAt,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'callingCode': callingCode,
        'phoneNumber': phoneNumber,
        'goal': goal,
        'birthday': birthday?.toIso8601String(),
        'consentAt': consentAt?.toIso8601String(),
        'consentVersion': consentVersion,
        'consentScopes': consentScopes.map((item) => item.name).toList(),
        'consentRevokedAt': consentRevokedAt?.toIso8601String(),
        'allowCalls': allowCalls,
        'allowWhatsApp': allowWhatsApp,
        'followUpEnabled': followUpEnabled,
        'followUpPausedUntil': followUpPausedUntil?.toIso8601String(),
        'followUpPauseReason': followUpPauseReason,
        'birthdayRemindersEnabled': birthdayRemindersEnabled,
        'archivedAt': archivedAt?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
        id: json['id'] as String,
        name: json['name'] as String,
        callingCode: json['callingCode'] as String? ?? '57',
        phoneNumber: json['phoneNumber'] as String? ?? '',
        goal: json['goal'] as String? ?? '',
        birthday: _date(json['birthday']),
        consentAt: _date(json['consentAt']),
        consentVersion: json['consentVersion'] as String? ?? '1',
        consentScopes: ((json['consentScopes'] as List?) ?? const [])
            .map((value) => ConsentScope.values.firstWhere(
                  (item) => item.name == value,
                  orElse: () => ConsentScope.phone,
                ))
            .toSet(),
        consentRevokedAt: _date(json['consentRevokedAt']),
        allowCalls: json['allowCalls'] as bool? ?? true,
        allowWhatsApp: json['allowWhatsApp'] as bool? ?? true,
        followUpEnabled: json['followUpEnabled'] as bool? ?? true,
        followUpPausedUntil: _date(json['followUpPausedUntil']),
        followUpPauseReason: json['followUpPauseReason'] as String?,
        birthdayRemindersEnabled:
            json['birthdayRemindersEnabled'] as bool? ?? true,
        archivedAt: _date(json['archivedAt']),
        createdAt: _date(json['createdAt']) ?? DateTime.now(),
        updatedAt: _date(json['updatedAt']) ?? DateTime.now(),
      );

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}
