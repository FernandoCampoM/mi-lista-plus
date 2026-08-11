import '../../domain/entities/customer.dart';

class SaleCustomerOption {
  const SaleCustomerOption({
    required this.id,
    required this.name,
    required this.statusLabel,
    required this.isEligible,
  });

  factory SaleCustomerOption.fromCustomer(Customer customer) {
    final eligible = !customer.isArchived && customer.hasActiveConsent;
    final status = customer.isArchived
        ? 'Cliente archivado'
        : !customer.hasActiveConsent
            ? 'Sin consentimiento'
            : !customer.followUpEnabled
                ? 'Consentimiento activo · seguimiento pausado'
                : 'Consentimiento y seguimiento activos';
    return SaleCustomerOption(
      id: customer.id,
      name: customer.name,
      statusLabel: status,
      isEligible: eligible,
    );
  }

  factory SaleCustomerOption.historical({
    required String id,
    required String name,
  }) => SaleCustomerOption(
        id: id,
        name: name.trim().isEmpty ? 'Cliente histórico' : name,
        statusLabel: 'Cliente histórico no disponible localmente',
        isEligible: false,
      );

  final String id;
  final String name;
  final String statusLabel;
  final bool isEligible;
}

List<SaleCustomerOption> buildSaleCustomerOptions({
  required List<Customer> customers,
  required String? selectedCustomerId,
  required bool preserveHistoricalCustomer,
  required String historicalCustomerName,
}) {
  final byId = <String, SaleCustomerOption>{};
  for (final customer in customers) {
    if (customer.isArchived || !customer.hasActiveConsent) continue;
    byId[customer.id] = SaleCustomerOption.fromCustomer(customer);
  }

  if (preserveHistoricalCustomer && selectedCustomerId != null) {
    final matches = customers.where((item) => item.id == selectedCustomerId);
    final customer = matches.firstOrNull;
    byId[selectedCustomerId] = customer == null
        ? SaleCustomerOption.historical(
            id: selectedCustomerId,
            name: historicalCustomerName,
          )
        : SaleCustomerOption.fromCustomer(customer);
  }

  final options = byId.values.toList()
    ..sort((a, b) {
      if (a.id == selectedCustomerId) return -1;
      if (b.id == selectedCustomerId) return 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  return options;
}
