enum InventoryMovementType { initialBalance, purchase, sale, saleCancellation, saleEdit, manualAdjustment, import, sync }

class InventoryMovement {
  const InventoryMovement({
    required this.id, required this.productId, required this.countryCode,
    required this.type, required this.quantityDelta, required this.occurredAt,
    required this.deviceId, this.relatedId, this.reason,
    this.syncedAt, this.reversesMovementId,
  });
  final String id;
  final String productId;
  final String countryCode;
  final InventoryMovementType type;
  final int quantityDelta;
  final DateTime occurredAt;
  final String deviceId;
  final String? relatedId;
  final String? reason;
  final DateTime? syncedAt;
  final String? reversesMovementId;
}
