enum FollowUpType { dayOne, dayThree, dayEight, periodic, replenishment, birthday }
enum FollowUpStatus { pending, completed, paused, cancelled }

class FollowUp {
  const FollowUp({
    required this.id,
    required this.customerId,
    required this.type,
    required this.dueAt,
    required this.createdAt,
    this.saleId,
    this.productId,
    this.status = FollowUpStatus.pending,
    this.completedAt,
    this.notes = '',
  });

  final String id;
  final String customerId;
  final String? saleId;
  final String? productId;
  final FollowUpType type;
  final FollowUpStatus status;
  final DateTime dueAt;
  final DateTime? completedAt;
  final String notes;
  final DateTime createdAt;

  bool get isOverdue => status == FollowUpStatus.pending && dueAt.isBefore(DateTime.now());

  FollowUp copyWith({FollowUpStatus? status, DateTime? dueAt, DateTime? completedAt, String? notes}) => FollowUp(
        id: id, customerId: customerId, saleId: saleId, productId: productId,
        type: type, status: status ?? this.status, dueAt: dueAt ?? this.dueAt,
        completedAt: completedAt ?? this.completedAt, notes: notes ?? this.notes,
        createdAt: createdAt,
      );

  Map<String, Object?> toJson() => {
        'id': id, 'customerId': customerId, 'saleId': saleId,
        'productId': productId, 'type': type.name, 'status': status.name,
        'dueAt': dueAt.toIso8601String(), 'completedAt': completedAt?.toIso8601String(),
        'notes': notes, 'createdAt': createdAt.toIso8601String(),
      };

  factory FollowUp.fromJson(Map<String, dynamic> json) => FollowUp(
        id: json['id'] as String, customerId: json['customerId'] as String,
        saleId: json['saleId'] as String?, productId: json['productId'] as String?,
        type: FollowUpType.values.firstWhere((item) => item.name == json['type']),
        status: FollowUpStatus.values.firstWhere((item) => item.name == json['status'], orElse: () => FollowUpStatus.pending),
        dueAt: DateTime.parse(json['dueAt'] as String),
        completedAt: json['completedAt'] == null ? null : DateTime.tryParse(json['completedAt'] as String),
        notes: json['notes'] as String? ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
