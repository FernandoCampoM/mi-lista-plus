enum SaleStatus { completed, cancelled }

class SaleItem {
  const SaleItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.suggestedUnitPrice,
    required this.costUnitPrice,
    required this.pointsPerUnit,
    required this.discountPercent,
    required this.isGift,
    this.productCode = '',
    this.imageUrl = '',
  });

  final String productId;
  final String productName;
  final String productCode;
  final String imageUrl;
  final int quantity;
  final double suggestedUnitPrice;
  final double costUnitPrice;
  final int pointsPerUnit;
  final int discountPercent;
  final bool isGift;

  double get totalSuggested => suggestedUnitPrice * quantity;
  double get totalSale => isGift ? 0 : totalSuggested;
  double get totalCost => costUnitPrice * quantity;
  double get totalProfit => totalSale - totalCost;
  int get totalPoints => pointsPerUnit * quantity;
}

class Sale {
  const Sale({
    required this.id,
    required this.countryCode,
    required this.customerName,
    required this.soldAt,
    required this.items,
    this.number = 0,
    this.status = SaleStatus.completed,
    this.receivedAmount,
  });

  final String id;
  final int number;
  final String countryCode;
  final String customerName;
  final DateTime soldAt;
  final SaleStatus status;
  final double? receivedAmount;
  final List<SaleItem> items;

  bool get isCompleted => status == SaleStatus.completed;
  double get totalSuggested =>
      items.fold(0, (total, item) => total + item.totalSuggested);
  double get totalSale =>
      items.fold(0, (total, item) => total + item.totalSale);
  double get totalCost =>
      items.fold(0, (total, item) => total + item.totalCost);
  double get effectiveReceivedAmount => receivedAmount ?? totalSale;
  double get receivedAdjustment => effectiveReceivedAmount - totalSale;
  double get discountAmount => totalSuggested - totalCost;
  double get totalProfit => effectiveReceivedAmount - totalCost;
  int get totalPoints =>
      items.fold(0, (total, item) => total + item.totalPoints);
  int get totalUnits =>
      items.fold(0, (total, item) => total + item.quantity);

  Sale copyWith({
    int? number,
    String? customerName,
    DateTime? soldAt,
    SaleStatus? status,
    double? receivedAmount,
    List<SaleItem>? items,
  }) {
    return Sale(
      id: id,
      number: number ?? this.number,
      countryCode: countryCode,
      customerName: customerName ?? this.customerName,
      soldAt: soldAt ?? this.soldAt,
      status: status ?? this.status,
      receivedAmount: receivedAmount ?? this.receivedAmount,
      items: items ?? this.items,
    );
  }
}
