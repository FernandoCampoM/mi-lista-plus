import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/currency_formatter.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/follow_up_note.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/sale.dart';
import '../state/app_scope.dart';
import '../widgets/app_header.dart';
import '../widgets/product_avatar.dart';
import 'follow_up_detail_sheet.dart';
import 'sale_detail_screen.dart';

class CustomerProfileScreen extends StatelessWidget {
  const CustomerProfileScreen({required this.customerId, super.key});

  final String customerId;

  @override
  Widget build(BuildContext context) {
    final customer = AppScope.of(context).customerById(customerId);
    if (customer == null) {
      return const Scaffold(body: Center(child: Text('Cliente no disponible.')));
    }
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: Column(
          children: [
            AppHeader(
              title: customer.name,
              showBack: true,
              titleFontSize: 18,
              showCountrySelector: false,
            ),
            const Material(
              color: Colors.white,
              child: TabBar(
                tabs: [
                  Tab(text: 'Historial de compras'),
                  Tab(text: 'Notas de seguimiento'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _PurchaseHistory(customer: customer),
                  _NotesHistory(customer: customer),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PurchaseHistory extends StatelessWidget {
  const _PurchaseHistory({required this.customer});
  final Customer customer;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final sales = state.sales.where((item) => item.customerId == customer.id).toList()
      ..sort((a, b) => b.soldAt.compareTo(a.soldAt));
    final commercial = sales.where((item) => item.isCompleted).toList();
    final formatter = CurrencyFormatter(state.selectedCountry!);
    final total = commercial.fold<double>(0, (sum, item) => sum + item.effectiveReceivedAmount);
    final points = commercial.fold<int>(0, (sum, item) => sum + item.totalPoints);
    final frequency = _averageFrequency(commercial);
    final topProducts = _topProducts(commercial, state.products);
    final purchasedProductRevenue = commercial
        .expand((sale) => sale.items)
        .where((item) => !item.isGift)
        .fold<double>(0, (sum, item) => sum + item.totalSale);

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Summary(label: 'Total comprado', value: formatter.money(total)),
            _Summary(label: 'Compras', value: '${commercial.length}'),
            _Summary(label: 'Puntos', value: '$points'),
            _Summary(
              label: 'Última compra',
              value: commercial.isEmpty ? '-' : DateFormat('dd/MM/yyyy').format(commercial.first.soldAt),
            ),
            _Summary(label: 'Frecuencia promedio', value: frequency == null ? '-' : 'Cada $frequency días'),
          ],
        ),
        if (topProducts.isNotEmpty) ...[
          const SizedBox(height: 14),
          _CustomerTopThreeProductsCard(
            products: topProducts,
            totalPurchased: purchasedProductRevenue,
            formatter: formatter,
          ),
        ],
        const SizedBox(height: 18),
        const Text(
          'Historial de ventas',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        if (sales.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(30), child: Text('No hay compras asociadas.')))
        else
          ...sales.map(
            (sale) => _CustomerSaleCard(
              sale: sale,
              number: state.saleNumberOf(sale),
              formatter: formatter,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => SaleDetailScreen(saleId: sale.id)),
              ),
            ),
          ),
      ],
    );
  }

  static int? _averageFrequency(List<Sale> source) {
    if (source.length < 2) return null;
    final ordered = source.toList()..sort((a, b) => a.soldAt.compareTo(b.soldAt));
    var days = 0;
    for (var i = 1; i < ordered.length; i++) {
      days += ordered[i].soldAt.difference(ordered[i - 1].soldAt).inDays.abs();
    }
    return (days / (ordered.length - 1)).round();
  }

  static List<_CustomerTopProduct> _topProducts(List<Sale> sales, List<Product> catalog) {
    final aggregates = <String, _CustomerTopProductAccumulator>{};
    for (final item in sales.expand((sale) => sale.items).where((item) => !item.isGift)) {
      final key = item.productId.isNotEmpty ? item.productId : item.productName;
      final aggregate = aggregates.putIfAbsent(
        key,
        () => _CustomerTopProductAccumulator(item: item),
      );
      aggregate
        ..units += item.quantity
        ..points += item.totalPoints
        ..revenue += item.totalSale;
    }
    final result = aggregates.values.map((aggregate) {
      Product? current;
      for (final product in catalog) {
        if (product.id == aggregate.item.productId) {
          current = product;
          break;
        }
      }
      final product = current ?? Product(
        id: aggregate.item.productId,
        countryCode: '',
        name: aggregate.item.productName,
        code: aggregate.item.productCode,
        category: aggregate.item.category ?? ProductCategory.nutrition,
        suggestedPrice: aggregate.item.suggestedUnitPrice,
        points: aggregate.item.pointsPerUnit,
        imageUrl: aggregate.item.imageUrl,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      );
      return _CustomerTopProduct(
        product: product,
        productName: aggregate.item.productName,
        units: aggregate.units,
        points: aggregate.points,
        revenue: aggregate.revenue,
      );
    }).toList()
      ..sort((a, b) {
        final byUnits = b.units.compareTo(a.units);
        if (byUnits != 0) return byUnits;
        final byRevenue = b.revenue.compareTo(a.revenue);
        if (byRevenue != 0) return byRevenue;
        return a.productName.toLowerCase().compareTo(b.productName.toLowerCase());
      });
    return result.take(3).toList();
  }
}

class _CustomerTopProductAccumulator {
  _CustomerTopProductAccumulator({required this.item});
  final SaleItem item;
  int units = 0;
  int points = 0;
  double revenue = 0;
}

class _CustomerTopProduct {
  const _CustomerTopProduct({
    required this.product,
    required this.productName,
    required this.units,
    required this.points,
    required this.revenue,
  });

  final Product product;
  final String productName;
  final int units;
  final int points;
  final double revenue;
}

class _CustomerTopThreeProductsCard extends StatelessWidget {
  const _CustomerTopThreeProductsCard({
    required this.products,
    required this.totalPurchased,
    required this.formatter,
  });

  final List<_CustomerTopProduct> products;
  final double totalPurchased;
  final CurrencyFormatter formatter;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top 3 Productos Más Comprados',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          ...products.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final rankColor = switch (index) {
              0 => const Color(0xFFFFB400),
              1 => const Color(0xFFB8BBC6),
              _ => const Color(0xFFD97A45),
            };
            final percent = totalPurchased <= 0 ? 0 : item.revenue / totalPurchased * 100;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: rankColor,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  ProductAvatar(product: item.product, size: 42),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.productName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                        ),
                        Text(
                          '${item.units} unidades · ${item.points} pts',
                          style: const TextStyle(fontSize: 9.5, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatter.money(item.revenue),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                      ),
                      Text(
                        '${percent.round()}% del total',
                        style: const TextStyle(fontSize: 9, color: AppColors.muted),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _CustomerSaleCard extends StatelessWidget {
  const _CustomerSaleCard({
    required this.sale,
    required this.number,
    required this.formatter,
    required this.onTap,
  });

  final Sale sale;
  final int number;
  final CurrencyFormatter formatter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      decoration: _cardDecoration(),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: AppColors.purple,
                child: Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Venta #${number.toString().padLeft(4, '0')}',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      DateFormat('dd/MM/yyyy hh:mm a', 'es_CO').format(sale.soldAt),
                      style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
                    ),
                    Text(
                      '${sale.totalUnits} unidades · ${sale.totalPoints} pts',
                      style: const TextStyle(fontSize: 10.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sale.isDelivered
                          ? 'Entregada ${DateFormat('dd/MM/yyyy').format(sale.deliveredAt!)}'
                          : 'Entrega pendiente',
                      style: const TextStyle(fontSize: 9.5, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _SaleStatusBadge(status: sale.status),
                  const SizedBox(height: 4),
                  Text(
                    formatter.money(sale.effectiveReceivedAmount),
                    style: const TextStyle(
                      color: AppColors.purple,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'Ganancia ${formatter.money(sale.totalProfit)}',
                    style: const TextStyle(fontSize: 9.5),
                  ),
                ],
              ),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _SaleStatusBadge extends StatelessWidget {
  const _SaleStatusBadge({required this.status});
  final SaleStatus status;

  @override
  Widget build(BuildContext context) {
    final completed = status == SaleStatus.completed;
    final color = completed ? const Color(0xFF238A53) : AppColors.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(12)),
      child: Text(
        completed ? 'Completada' : 'Cancelada',
        style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _NotesHistory extends StatefulWidget {
  const _NotesHistory({required this.customer});
  final Customer customer;

  @override
  State<_NotesHistory> createState() => _NotesHistoryState();
}

class _NotesHistoryState extends State<_NotesHistory> {
  final search = TextEditingController();
  String filter = 'all';

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    var notes = state.followUpNotes.where((item) => item.customerId == widget.customer.id).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final query = search.text.trim().toLowerCase();
    if (query.isNotEmpty) notes = notes.where((item) => item.text.toLowerCase().contains(query)).toList();
    notes = switch (filter) {
      'manual' => notes.where((item) => item.followUpId == null).toList(),
      'sale' => notes.where((item) => item.saleId != null).toList(),
      'product' => notes.where((item) => item.productId != null).toList(),
      'recent' => notes.where((item) => item.createdAt.isAfter(DateTime.now().subtract(const Duration(days: 30)))).toList(),
      _ => notes,
    };

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        TextField(
          controller: search,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            labelText: 'Buscar en notas',
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: {
              'all': 'Todas',
              'recent': 'Últimos 30 días',
              'manual': 'Manuales',
              'sale': 'Con venta',
              'product': 'Con producto',
            }.entries.map((entry) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(entry.value),
                    selected: filter == entry.key,
                    onSelected: (_) => setState(() => filter = entry.key),
                  ),
                )).toList(),
          ),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: () => _editNote(context),
          icon: const Icon(Icons.note_add_outlined),
          label: const Text('AGREGAR NOTA MANUAL'),
        ),
        const SizedBox(height: 12),
        if (notes.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(30), child: Text('No hay notas para este filtro.')))
        else
          ...notes.map((note) => _FollowUpNoteCard(
                note: note,
                sale: state.saleById(note.saleId),
                onTap: () {
                  if (note.followUpId != null) {
                    showFollowUpDetail(context, note.followUpId!);
                  } else if (note.saleId != null && state.saleById(note.saleId) != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(builder: (_) => SaleDetailScreen(saleId: note.saleId!)),
                    );
                  }
                },
                onEdit: () => _editNote(context, note: note),
              )),
      ],
    );
  }

  Future<void> _editNote(BuildContext context, {FollowUpNote? note}) async {
    final controller = TextEditingController(text: note?.text ?? '');
    var method = note?.contactMethod ?? FollowUpContactMethod.other;
    final save = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: Text(note == null ? 'Nueva nota' : 'Editar nota'),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: controller, maxLines: 4, decoration: const InputDecoration(labelText: 'Nota')),
                const SizedBox(height: 10),
                DropdownButtonFormField<FollowUpContactMethod>(
                  value: method,
                  decoration: const InputDecoration(labelText: 'Medio de contacto'),
                  items: FollowUpContactMethod.values
                      .map((item) => DropdownMenuItem(value: item, child: Text(_contactLabel(item))))
                      .toList(),
                  onChanged: (value) => setDialogState(() => method = value ?? method),
                ),
              ]),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('CANCELAR')),
                FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('GUARDAR')),
              ],
            ),
          ),
        ) ??
        false;
    if (!save || !context.mounted) return;
    if (controller.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Escribe una nota antes de guardar.')));
      return;
    }
    if (note == null) {
      await AppScope.of(context).addManualNote(
        customerId: widget.customer.id,
        text: controller.text,
        contactMethod: method,
      );
    } else {
      await AppScope.of(context).updateFollowUpNote(note, text: controller.text, contactMethod: method);
    }
  }
}

class _FollowUpNoteCard extends StatelessWidget {
  const _FollowUpNoteCard({
    required this.note,
    required this.sale,
    required this.onTap,
    required this.onEdit,
  });

  final FollowUpNote note;
  final Sale? sale;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final icon = switch (note.contactMethod) {
      FollowUpContactMethod.call => Icons.call_outlined,
      FollowUpContactMethod.whatsapp => Icons.chat_outlined,
      FollowUpContactMethod.other => Icons.sticky_note_2_outlined,
    };
    final color = switch (note.contactMethod) {
      FollowUpContactMethod.call => const Color(0xFF397CE8),
      FollowUpContactMethod.whatsapp => const Color(0xFF16845D),
      FollowUpContactMethod.other => AppColors.purple,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: _cardDecoration(),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: color.withOpacity(.11), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _followUpTypeLabel(note.followUpType),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                          ),
                        ),
                        Text(
                          DateFormat('dd/MM/yyyy').format(note.createdAt),
                          style: const TextStyle(fontSize: 10, color: AppColors.muted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(note.text, style: const TextStyle(fontSize: 13, height: 1.35)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 5,
                      children: [
                        _MetaChip(icon: icon, label: _contactLabel(note.contactMethod), color: color),
                        if (sale != null)
                          _MetaChip(
                            icon: Icons.receipt_long_outlined,
                            label: 'Venta #${sale!.number.toString().padLeft(4, '0')}',
                            color: AppColors.purple,
                          ),
                        if (note.productId != null)
                          _MetaChip(
                            icon: Icons.inventory_2_outlined,
                            label: _productLabel(sale, note.productId!),
                            color: AppColors.orange,
                          ),
                      ],
                    ),
                    if (note.updatedAt != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Editada ${DateFormat('dd/MM/yyyy HH:mm').format(note.updatedAt!)}',
                        style: const TextStyle(fontSize: 9.5, color: AppColors.muted),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Editar nota',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 19),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(color: color.withOpacity(.09), borderRadius: BorderRadius.circular(10)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 190),
              child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9.5, color: color, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
}

class _Summary extends StatelessWidget {
  const _Summary({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        width: 150,
        constraints: const BoxConstraints(minHeight: 74),
        padding: const EdgeInsets.all(10),
        decoration: _cardDecoration(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ]),
      );
}

BoxDecoration _cardDecoration() => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.line),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(.025), blurRadius: 7, offset: const Offset(0, 2)),
      ],
    );

String _contactLabel(FollowUpContactMethod method) => switch (method) {
      FollowUpContactMethod.call => 'Llamada',
      FollowUpContactMethod.whatsapp => 'WhatsApp',
      FollowUpContactMethod.other => 'Otro',
    };

String _followUpTypeLabel(String? type) => switch (type) {
      'dayOne' => 'Seguimiento del día siguiente',
      'dayThree' => 'Seguimiento del tercer día',
      'dayEight' => 'Seguimiento del octavo día',
      'periodic' => 'Seguimiento quincenal',
      'replenishment' => 'Reposición de producto',
      'birthday' => 'Cumpleaños',
      _ => 'Nota manual',
    };

String _productLabel(Sale? sale, String productId) => sale?.items
        .where((item) => item.productId == productId)
        .map((item) => item.productName)
        .firstOrNull ??
    productId;
