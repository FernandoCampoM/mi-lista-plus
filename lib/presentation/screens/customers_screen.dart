import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
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
              onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const DataTransferScreen())),
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
                onTap: () => _showCustomer(context, customer),
              ),
            );
          }),
        const AdaptiveBannerAd(
          placement: BannerPlacement.customers,
          margin: EdgeInsets.only(top: 8, bottom: 4),
          maxHeight: 72,
        ),
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
            if (customer.allowWhatsApp) Expanded(child: OutlinedButton.icon(onPressed: () => _openWhatsApp(customer, 'Hola ${customer.name}, ¿como te has sentido?'), icon: const Icon(Icons.chat_outlined), label: const Text('WHATSAPP'))),
          ]),
        ]),
      )),
    );
  }
}

class _FollowUpList extends StatelessWidget {
  const _FollowUpList();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final pending = state.followUps.where((item) => item.status == FollowUpStatus.pending).toList();
    final now = DateTime.now();
    pending.sort((a, b) => a.dueAt.compareTo(b.dueAt));
    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
        Text('${pending.where((item) => item.dueAt.isBefore(now)).length} vencidos · ${pending.length} pendientes', style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        if (pending.isEmpty) const Padding(padding: EdgeInsets.all(28), child: Center(child: Text('No hay seguimientos pendientes.'))),
        ...pending.map((item) {
          final customer = state.customers.where((entry) => entry.id == item.customerId).firstOrNull;
          if (customer == null || customer.isArchived || !customer.followUpEnabled) return const SizedBox.shrink();
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(customer.name, style: const TextStyle(fontWeight: FontWeight.w900))),
                  Text(DateFormat('dd/MM').format(item.dueAt), style: TextStyle(color: item.isOverdue ? AppColors.danger : AppColors.muted, fontWeight: FontWeight.w800)),
                ]),
                Text(_followUpLabel(item.type)),
                const SizedBox(height: 8),
                Row(children: [
                  IconButton.filledTonal(tooltip: 'Llamar', onPressed: customer.allowCalls ? () => launchUrl(Uri(scheme: 'tel', path: customer.normalizedPhone)) : null, icon: const Icon(Icons.call_outlined)),
                  const SizedBox(width: 6),
                  IconButton.filledTonal(tooltip: 'WhatsApp', onPressed: customer.allowWhatsApp ? () => _openWhatsApp(customer, _message(customer, item.type)) : null, icon: const Icon(Icons.chat_outlined)),
                  const Spacer(),
                  FilledButton.icon(onPressed: () => _complete(context, item), icon: const Icon(Icons.check), label: const Text('COMPLETAR')),
                ]),
              ]),
            ),
          );
        }),
        const AdaptiveBannerAd(
          placement: BannerPlacement.followups,
          margin: EdgeInsets.only(top: 8, bottom: 4),
          maxHeight: 72,
        ),
        ],
      ),
    );
  }

  Future<void> _complete(BuildContext context, FollowUp item) async {
    final notes = TextEditingController();
    final save = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('Completar seguimiento'),
      content: TextField(controller: notes, maxLines: 4, decoration: const InputDecoration(labelText: 'Notas del cliente')),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('CANCELAR')), ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('GUARDAR'))],
    )) ?? false;
    if (save && context.mounted) {
      await AppScope.of(context).completeFollowUp(item, notes: notes.text);
      if (context.mounted) {
        await AppScope.adsOf(context).recordImportantAction(
          ImportantAdAction.followUpCompleted,
        );
      }
    }
    Future<void>.delayed(
      const Duration(milliseconds: 400),
      notes.dispose,
    );
  }
}

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

String _followUpLabel(FollowUpType type) => switch (type) {
  FollowUpType.dayOne => 'Confirmar que inicio el producto',
  FollowUpType.dayThree => 'Preguntar como se ha sentido',
  FollowUpType.dayEight => 'Revisar su experiencia con el producto',
  FollowUpType.periodic => 'Seguimiento quincenal',
  FollowUpType.replenishment => 'El producto puede estar por terminarse',
  FollowUpType.birthday => 'Cumpleanos',
};

String _message(Customer customer, FollowUpType type) => switch (type) {
  FollowUpType.dayOne => 'Hola ${customer.name}, ¿ya comenzaste a usar tus productos?',
  FollowUpType.dayThree => 'Hola ${customer.name}, ¿como te has sentido? ¿Has presentado alguna molestia o reaccion?',
  FollowUpType.dayEight => 'Hola ${customer.name}, ¿como ha sido tu experiencia con el producto? ¿Has notado algun cambio?',
  FollowUpType.replenishment => 'Hola ${customer.name}, ¿como vas con tu producto? Es posible que este por terminarse.',
  FollowUpType.birthday => '🎉 Feliz cumpleaños, ${customer.name} 🎂 Que tengas un dia maravilloso ✨',
  FollowUpType.periodic => 'Hola ${customer.name}, ¿como te has sentido desde nuestro ultimo seguimiento?',
};

Future<void> _openWhatsApp(Customer customer, String message) async {
  final phone = customer.normalizedPhone.replaceAll(RegExp(r'[^0-9]'), '');
  final uri = Uri.https('wa.me', '/$phone', {'text': message});
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    throw StateError('No se pudo abrir WhatsApp.');
  }
}
