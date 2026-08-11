import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/follow_up_message_templates.dart';
import '../../core/services/app_ad_service.dart';
import '../../core/services/currency_formatter.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/follow_up.dart';
import '../../domain/entities/sale.dart';
import '../state/app_scope.dart';
import '../widgets/adaptive_banner_ad.dart';
import '../widgets/app_header.dart';
import '../widgets/customer_form_dialog.dart';
import 'data_transfer_screen.dart';
import 'customer_profile_screen.dart';
import 'follow_up_detail_sheet.dart';

class CustomersScreen extends StatelessWidget {
  const CustomersScreen({this.initialIndex = 0, super.key});
  final int initialIndex;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: initialIndex,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: Column(children: [
          AppHeader(
            title: 'Clientes y seguimiento', showBack: true, titleFontSize: 18,
            actions: [IconButton(
              tooltip: 'Respaldo y sincronizacion', color: Colors.white,
              onPressed: () async {
                await AppScope.adsOf(context).recordImportantAction(
                  ImportantAdAction.backupOpened,
                );
                if (!context.mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const DataTransferScreen()),
                );
              },
              icon: const Icon(Icons.sync_alt),
            )],
          ),
          const Material(
            color: Colors.white,
            child: TabBar(tabs: [
              Tab(icon: Icon(Icons.people_outline), text: 'Clientes'),
              Tab(icon: Icon(Icons.notifications_active_outlined), text: 'Hoy'),
              Tab(icon: Icon(Icons.local_shipping_outlined), text: 'Entregas'),
            ]),
          ),
          const AdaptiveBannerAd(
            placement: BannerPlacement.customers,
            margin: EdgeInsets.fromLTRB(18, 8, 18, 4),
            maxHeight: 64,
          ),
          const Expanded(child: TabBarView(children: [
            _CustomerList(), _FollowUpList(), _PendingDeliveries(),
          ])),
        ]),
      ),
    );
  }
}

class _CustomerList extends StatelessWidget {
  const _CustomerList();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final active = state.customers.where((item) => !item.isArchived).toList();
    final formatter = CurrencyFormatter(state.selectedCountry!);
    final ranked = active.toList()..sort((a, b) => _spent(state.sales, b.id).compareTo(_spent(state.sales, a.id)));
    final recurrent = active.toList()..sort((a, b) => _purchases(state.sales, b.id).compareTo(_purchases(state.sales, a.id)));
    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
        Row(children: [
          Expanded(child: _Metric(label: 'Clientes activos', value: '${active.length}')),
          const SizedBox(width: 8),
          Expanded(child: _Metric(
            label: 'Mayor comprador',
            value: ranked.isEmpty ? '-' : ranked.first.name,
            subtitle: ranked.isEmpty ? null : formatter.money(_spent(state.sales, ranked.first.id)),
          )),
        ]),
        const SizedBox(height: 8),
        _Metric(
          label: 'Cliente mas recurrente',
          value: recurrent.isEmpty ? '-' : recurrent.first.name,
          subtitle: recurrent.isEmpty ? null : '${_purchases(state.sales, recurrent.first.id)} compras',
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => _openCustomerEditor(context),
          icon: const Icon(Icons.person_add_alt_1), label: const Text('AGREGAR CLIENTE'),
        ),
        const SizedBox(height: 16),
        if (active.isEmpty)
          const Padding(padding: EdgeInsets.all(28), child: Center(child: Text('Aun no hay clientes registrados.')))
        else
          ...ranked.map((customer) {
            final purchases = state.sales.where((sale) => sale.customerId == customer.id && sale.isCompleted).length;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(child: Text(customer.name.trim().isEmpty ? '?' : customer.name.trim()[0].toUpperCase())),
                title: Text(customer.name, maxLines: 2, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('${customer.normalizedPhone}\n$purchases compras · ${formatter.money(_spent(state.sales, customer.id))}'),
                isThreeLine: true,
                trailing: PopupMenuButton<String>(
                  onSelected: (action) => _customerAction(context, customer, action),
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Editar cliente')),
                    PopupMenuItem(
                      value: 'pause',
                      enabled: customer.hasActiveConsent,
                      child: Text(
                        !customer.hasActiveConsent
                            ? 'Seguimiento requiere consentimiento'
                            : customer.followUpEnabled
                                ? 'Pausar seguimiento'
                                : 'Reactivar seguimiento',
                      ),
                    ),
                    const PopupMenuItem(value: 'archive', child: Text('Archivar cliente')),
                    PopupMenuItem(
                      value: 'consent',
                      child: Text(
                        customer.hasActiveConsent
                            ? 'Revocar consentimiento'
                            : 'Reactivar consentimiento',
                      ),
                    ),
                  ],
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => CustomerProfileScreen(customerId: customer.id),
                  ),
                ),
              ),
            );
          }),
        if (state.customers.any((item) => item.isArchived)) ...[
          const SizedBox(height: 18),
          const Text('Clientes archivados', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          ...state.customers.where((item) => item.isArchived).map((customer) => Card(
                child: ListTile(
                  leading: const Icon(Icons.archive_outlined, color: AppColors.muted),
                  title: Text(customer.name),
                  subtitle: const Text('Historial conservado'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(builder: (_) => CustomerProfileScreen(customerId: customer.id)),
                  ),
                ),
              )),
        ],
        ],
      ),
    );
  }

  static double _spent(List<Sale> sales, String id) => sales
      .where((sale) => sale.customerId == id && sale.isCompleted)
      .fold(0, (sum, sale) => sum + sale.effectiveReceivedAmount);

  static int _purchases(List<Sale> sales, String id) =>
      sales.where((sale) => sale.customerId == id && sale.isCompleted).length;

  Future<void> _customerAction(BuildContext context, Customer customer, String action) async {
    final state = AppScope.of(context);
    if (action == 'edit') {
      await _openCustomerEditor(context, customer: customer);
    } else if (action == 'archive') {
      await state.archiveCustomer(customer);
    } else if (action == 'consent') {
      if (customer.hasActiveConsent) {
        await state.revokeCustomerConsent(customer);
      } else {
        final resume = await _askConsentReactivation(context);
        if (resume != null) {
          await state.reactivateCustomerConsent(
            customer,
            resumeFollowUp: resume,
          );
        }
      }
    } else if (customer.followUpEnabled) {
      final reason = TextEditingController();
      final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
        title: const Text('Pausar seguimiento'),
        content: TextField(controller: reason, decoration: const InputDecoration(labelText: 'Motivo opcional')),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('CANCELAR')), ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('PAUSAR'))],
      )) ?? false;
      if (confirmed) await state.pauseCustomerFollowUp(customer, reason: reason.text);
      Future<void>.delayed(
        const Duration(milliseconds: 400),
        reason.dispose,
      );
    } else {
      await state.resumeCustomerFollowUp(customer, fromToday: true);
    }
  }

  Future<bool?> _askConsentReactivation(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reactivar consentimiento'),
        content: const Text(
          'Se habilitarán nuevamente llamadas y WhatsApp. '
          '¿También deseas reactivar el seguimiento pendiente?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('CANCELAR'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('SOLO CONSENTIMIENTO'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('REACTIVAR TODO'),
          ),
        ],
      ),
    );
  }

  void _showCustomer(BuildContext context, Customer customer) {
    final state = AppScope.of(context);
    final customerSales = state.sales.where((sale) => sale.customerId == customer.id).toList();
    final customerFollowUps = state.followUps.where((item) => item.customerId == customer.id).toList();
    showModalBottomSheet<void>(
      context: context, isScrollControlled: true,
      builder: (_) => SafeArea(child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(customer.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          Text(customer.normalizedPhone),
          if (customer.goal.isNotEmpty) Text('Quiere mejorar: ${customer.goal}'),
          const SizedBox(height: 12),
          Text('${customerSales.length} compras · ${customerFollowUps.where((item) => item.status == FollowUpStatus.completed).length} seguimientos completados'),
          Text(customer.followUpEnabled ? 'Seguimiento activo' : 'Seguimiento pausado', style: TextStyle(color: customer.followUpEnabled ? AppColors.green : AppColors.orange, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Row(children: [
            if (customer.allowCalls) Expanded(child: OutlinedButton.icon(onPressed: () => launchUrl(Uri(scheme: 'tel', path: customer.normalizedPhone)), icon: const Icon(Icons.call_outlined), label: const Text('LLAMAR'))),
            if (customer.allowCalls && customer.allowWhatsApp) const SizedBox(width: 8),
            if (customer.allowWhatsApp) Expanded(child: OutlinedButton.icon(onPressed: () => _openWhatsApp(customer, FollowUpMessageTemplates.message(FollowUpType.periodic, customer.name)), icon: const Icon(Icons.chat_outlined), label: const Text('WHATSAPP'))),
          ]),
        ]),
      )),
    );
  }
}

class _FollowUpList extends StatefulWidget {
  const _FollowUpList();

  @override
  State<_FollowUpList> createState() => _FollowUpListState();
}

class _FollowUpListState extends State<_FollowUpList> {
  bool showUpcoming = false;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final pending = state.followUps.where((item) {
      final customer = state.customerById(item.customerId);
      return item.status == FollowUpStatus.pending &&
          customer != null &&
          !customer.isArchived &&
          customer.followUpEnabled;
    }).toList()
      ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
    final overdue = pending.where((item) => _date(item.dueAt).isBefore(today)).toList();
    final dueToday = pending.where((item) => _date(item.dueAt) == today).toList();
    final upcoming = pending.where((item) => _date(item.dueAt).isAfter(today)).toList();
    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('HOY'), icon: Icon(Icons.today_outlined)),
            ButtonSegment(value: true, label: Text('PROXIMOS'), icon: Icon(Icons.event_outlined)),
          ],
          selected: {showUpcoming},
          onSelectionChanged: (value) => setState(() => showUpcoming = value.first),
        ),
        const SizedBox(height: 16),
        if (!showUpcoming) ...[
          _FollowUpSection(title: 'Vencidos', items: overdue, danger: true),
          const SizedBox(height: 14),
          _FollowUpSection(title: 'Para hoy', items: dueToday),
          if (overdue.isEmpty && dueToday.isEmpty)
            const Padding(padding: EdgeInsets.all(28), child: Center(child: Text('No hay seguimientos para hoy.'))),
        ] else ...[
          _FollowUpSection(title: 'Proximos', items: upcoming),
          if (upcoming.isEmpty)
            const Padding(padding: EdgeInsets.all(28), child: Center(child: Text('No hay seguimientos proximos.'))),
        ],
        const AdaptiveBannerAd(
          placement: BannerPlacement.followups,
          margin: EdgeInsets.only(top: 8, bottom: 4),
          maxHeight: 72,
        ),
        ],
      ),
    );
  }
}

class _FollowUpSection extends StatelessWidget {
  const _FollowUpSection({required this.title, required this.items, this.danger = false});
  final String title;
  final List<FollowUp> items;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final state = AppScope.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('$title (${items.length})', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: danger ? AppColors.danger : null)),
      const SizedBox(height: 8),
      ...items.map((item) {
        final customer = state.customerById(item.customerId)!;
        final format = item.dueAt.year == DateTime.now().year ? 'dd/MM' : 'dd/MM/yyyy';
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            onTap: () => showFollowUpDetail(context, item.id),
            title: Text(customer.name, style: const TextStyle(fontWeight: FontWeight.w900)),
            subtitle: Text(FollowUpMessageTemplates.shortLabel(item.type)),
            trailing: Text(DateFormat(format).format(item.dueAt), style: TextStyle(color: danger ? AppColors.danger : AppColors.muted, fontWeight: FontWeight.w800)),
          ),
        );
      }),
    ]);
  }
}

DateTime _date(DateTime value) => DateTime(value.year, value.month, value.day);

class _PendingDeliveries extends StatelessWidget {
  const _PendingDeliveries();
  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final pending = state.sales.where((sale) => sale.isCompleted && !sale.isDelivered).toList();
    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Text(
            'Por confirmar entrega',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          if (pending.isEmpty)
            const Padding(
              padding: EdgeInsets.all(28),
              child: Center(
                child: Text('No hay pedidos pendientes de entrega.'),
              ),
            ),
          ...pending.map(
            (sale) => Card(
              child: ListTile(
                leading: const Icon(Icons.inventory_2_outlined),
                title: Text(
                  sale.customerName,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  'Venta #${sale.number.toString().padLeft(4, '0')} · '
                  '${DateFormat('dd/MM/yyyy').format(sale.soldAt)}',
                ),
                trailing: FilledButton(
                  onPressed: sale.customerId == null
                      ? null
                      : () async {
                          await state.confirmDelivery(sale);
                          if (context.mounted) {
                            await AppScope.adsOf(context).recordImportantAction(
                              ImportantAdAction.deliveryConfirmed,
                            );
                          }
                        },
                  child: const Text('CONFIRMAR'),
                ),
              ),
            ),
          ),
          const AdaptiveBannerAd(
            placement: BannerPlacement.deliveries,
            margin: EdgeInsets.only(top: 8, bottom: 4),
            maxHeight: 72,
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.subtitle});
  final String label; final String value; final String? subtitle;
  @override Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 86), padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(8)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 11, color: AppColors.muted)), Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)), if (subtitle != null) Text(subtitle!, style: const TextStyle(fontSize: 11))]),
  );
}

Future<void> _openCustomerEditor(BuildContext context, {Customer? customer}) async {
  final form = await showCustomerFormDialog(context, customer: customer);
  if (form == null || !context.mounted) return;
  try {
    final state = AppScope.of(context);
    if (customer == null) {
      await state.createCustomer(
        name: form.name,
        callingCode: form.callingCode,
        phoneNumber: form.phoneNumber,
        goal: form.goal,
        birthday: form.birthday,
        consentGranted: form.consentGranted,
      );
      if (context.mounted) {
        await AppScope.adsOf(context).recordImportantAction(
          ImportantAdAction.customerCreated,
        );
      }
    } else {
      await state.updateCustomerProfile(
        customer: customer,
        name: form.name,
        callingCode: form.callingCode,
        phoneNumber: form.phoneNumber,
        goal: form.goal,
        birthday: form.birthday,
        consentGranted: form.consentGranted,
      );
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          customer == null
              ? 'Cliente guardado correctamente.'
              : 'Cliente actualizado correctamente.',
        ),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('No se pudo guardar el cliente: $error')),
    );
  }
}



Future<void> _openWhatsApp(Customer customer, String message) async {
  final phone = customer.normalizedPhone.replaceAll(RegExp(r'[^0-9]'), '');
  final uri = Uri.https('wa.me', '/$phone', {'text': message});
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    throw StateError('No se pudo abrir WhatsApp.');
  }
}
