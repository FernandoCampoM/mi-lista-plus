import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/currency_formatter.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/follow_up_note.dart';
import '../../domain/entities/sale.dart';
import '../state/app_scope.dart';
import '../widgets/app_header.dart';
import 'sale_detail_screen.dart';
import 'follow_up_detail_sheet.dart';

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
    final topProducts = _topProducts(commercial);
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
              label: 'Ultima compra',
              value: commercial.isEmpty ? '-' : DateFormat('dd/MM/yyyy').format(commercial.first.soldAt),
            ),
            _Summary(label: 'Frecuencia promedio', value: frequency == null ? '-' : 'Cada $frequency dias'),
          ],
        ),
        if (topProducts.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text('Mas comprados: ${topProducts.join(' · ')}'),
        ],
        const SizedBox(height: 18),
        if (sales.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(30), child: Text('No hay compras asociadas.'))),
        ...sales.map((sale) => Card(
              child: ListTile(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => SaleDetailScreen(saleId: sale.id)),
                ),
                leading: Icon(
                  sale.isCompleted ? Icons.receipt_long_outlined : Icons.cancel_outlined,
                  color: sale.isCompleted ? AppColors.green : AppColors.danger,
                ),
                title: Text('Venta #${sale.number.toString().padLeft(4, '0')} · ${DateFormat('dd/MM/yyyy').format(sale.soldAt)}'),
                subtitle: Text([
                  sale.isCompleted ? 'Completada' : 'Cancelada (no suma a totales)',
                  sale.isDelivered
                      ? 'Entregada ${DateFormat('dd/MM/yyyy').format(sale.deliveredAt!)}'
                      : 'Entrega pendiente',
                  sale.items.map((item) => '${item.quantity} × ${item.productName}${item.isGift ? ' (obsequio)' : ''}').join(', '),
                  'Pagado ${formatter.money(sale.effectiveReceivedAmount)} · ${sale.totalPoints} pts · Ganancia ${formatter.money(sale.totalProfit)}',
                ].join('\n')),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right),
              ),
            )),
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

  static List<String> _topProducts(List<Sale> sales) {
    final counts = <String, int>{};
    for (final item in sales.expand((sale) => sale.items).where((item) => !item.isGift)) {
      counts.update(item.productName, (value) => value + item.quantity, ifAbsent: () => item.quantity);
    }
    final entries = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(3).map((item) => '${item.key} (${item.value})').toList();
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
    var notes = state.followUpNotes.where((item) => item.customerId == widget.customer.id).toList();
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
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'Buscar en notas'),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          children: {
            'all': 'Todas',
            'recent': 'Ultimos 30 dias',
            'manual': 'Manuales',
            'sale': 'Con venta',
            'product': 'Con producto',
          }.entries.map((entry) => ChoiceChip(
                label: Text(entry.value),
                selected: filter == entry.key,
                onSelected: (_) => setState(() => filter = entry.key),
              )).toList(),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: () => _editNote(context),
          icon: const Icon(Icons.note_add_outlined),
          label: const Text('AGREGAR NOTA MANUAL'),
        ),
        if (notes.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(30), child: Text('No hay notas para este filtro.'))),
        ...notes.map((note) => Card(
              child: ListTile(
                onTap: () {
                  if (note.followUpId != null) {
                    showFollowUpDetail(context, note.followUpId!);
                  } else if (note.saleId != null && state.saleById(note.saleId) != null) {
                    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => SaleDetailScreen(saleId: note.saleId!)));
                  }
                },
                title: Text(note.text),
                subtitle: Text([
                  DateFormat('dd/MM/yyyy HH:mm').format(note.createdAt),
                  _followUpTypeLabel(note.followUpType),
                  'Medio: ${_contactLabel(note.contactMethod)} · Dispositivo: ${note.deviceId}',
                  if (note.saleId != null)
                    'Venta #${state.saleById(note.saleId)?.number.toString().padLeft(4, '0') ?? note.saleId}',
                  if (note.productId != null)
                    'Producto: ${_productLabel(state.saleById(note.saleId), note.productId!)}',
                  if (note.updatedAt != null) 'Editada ${DateFormat('dd/MM/yyyy HH:mm').format(note.updatedAt!)}',
                ].join('\n')),
                isThreeLine: true,
                trailing: IconButton(
                  tooltip: 'Editar nota',
                  onPressed: () => _editNote(context, note: note),
                  icon: const Icon(Icons.edit_outlined),
                ),
              ),
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
                  items: FollowUpContactMethod.values.map((item) => DropdownMenuItem(value: item, child: Text(_contactLabel(item)))).toList(),
                  onChanged: (value) => setDialogState(() => method = value ?? method),
                ),
              ]),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('CANCELAR')),
                FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('GUARDAR')),
              ],
            ),
          ),
        ) ?? false;
    if (!save || !context.mounted) return;
    if (controller.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Escribe una nota antes de guardar.')));
      return;
    }
    if (note == null) {
      await AppScope.of(context).addManualNote(customerId: widget.customer.id, text: controller.text, contactMethod: method);
    } else {
      await AppScope.of(context).updateFollowUpNote(note, text: controller.text, contactMethod: method);
    }
  }
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
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(8)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ]),
      );
}

String _contactLabel(FollowUpContactMethod method) => switch (method) {
      FollowUpContactMethod.call => 'Llamada',
      FollowUpContactMethod.whatsapp => 'WhatsApp',
      FollowUpContactMethod.other => 'Otro',
    };

String _followUpTypeLabel(String? type) => switch (type) {
      'dayOne' => 'Seguimiento del dia siguiente',
      'dayThree' => 'Seguimiento del tercer dia',
      'dayEight' => 'Seguimiento del octavo dia',
      'periodic' => 'Seguimiento quincenal',
      'replenishment' => 'Reposicion de producto',
      'birthday' => 'Cumpleaños',
      _ => 'Nota manual',
    };

String _productLabel(Sale? sale, String productId) => sale?.items
        .where((item) => item.productId == productId)
        .map((item) => item.productName)
        .firstOrNull ??
    productId;
