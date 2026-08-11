enum FollowUpContactMethod { call, whatsapp, other }

class FollowUpNote {
  const FollowUpNote({
    required this.id,
    required this.customerId,
    required this.text,
    required this.createdAt,
    required this.deviceId,
    this.followUpId,
    this.saleId,
    this.productId,
    this.followUpType,
    this.contactMethod = FollowUpContactMethod.other,
    this.updatedAt,
  });

  final String id;
  final String customerId;
  final String? followUpId;
  final String? saleId;
  final String? productId;
  final String? followUpType;
  final String text;
  final FollowUpContactMethod contactMethod;
  final String deviceId;
  final DateTime createdAt;
  final DateTime? updatedAt;

  FollowUpNote copyWith({String? text, FollowUpContactMethod? contactMethod}) =>
      FollowUpNote(
        id: id,
        customerId: customerId,
        followUpId: followUpId,
        saleId: saleId,
        productId: productId,
        followUpType: followUpType,
        text: text ?? this.text,
        contactMethod: contactMethod ?? this.contactMethod,
        deviceId: deviceId,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'customerId': customerId,
        'followUpId': followUpId,
        'saleId': saleId,
        'productId': productId,
        'followUpType': followUpType,
        'text': text,
        'contactMethod': contactMethod.name,
        'deviceId': deviceId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory FollowUpNote.fromJson(Map<String, dynamic> json) => FollowUpNote(
        id: json['id'] as String,
        customerId: json['customerId'] as String,
        followUpId: json['followUpId'] as String?,
        saleId: json['saleId'] as String?,
        productId: json['productId'] as String?,
        followUpType: json['followUpType'] as String?,
        text: json['text'] as String? ?? '',
        contactMethod: FollowUpContactMethod.values.firstWhere(
          (item) => item.name == json['contactMethod'],
          orElse: () => FollowUpContactMethod.other,
        ),
        deviceId: json['deviceId'] as String? ?? 'unknown',
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: json['updatedAt'] == null
            ? null
            : DateTime.tryParse(json['updatedAt'] as String),
      );
}
