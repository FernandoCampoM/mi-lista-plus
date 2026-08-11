import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/follow_up_message_templates.dart';
import '../../domain/entities/follow_up.dart';
import '../../domain/entities/follow_up_note.dart';
import '../state/app_scope.dart';
import 'sale_detail_screen.dart';

Future<void> showFollowUpDetail(BuildContext context, String followUpId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _FollowUpDetail(followUpId: followUpId),
  );
}

class _FollowUpDetail extends StatefulWidget {
  const _FollowUpDetail({required this.followUpId});
  final String followUpId;

  @override
  State<_FollowUpDetail> createState() => _FollowUpDetailState();
}

class _FollowUpDetailState extends State<_FollowUpDetail> {
  final note = TextEditingController();
  FollowUpContactMethod contactMethod = FollowUpContactMethod.other;
  bool saving = false;

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final followUp = state.followUpById(widget.followUpId);
    if (followUp == null) {
      return const Padding(
        padding: EdgeInsets.all(30),
        child: Center(child: Text('Este seguimiento ya no existe localmente.')),
      );
    }
    final customer = state.customerById(followUp.customerId);
    if (customer == null) {
      return const Padding(
        padding: EdgeInsets.all(30),
        child: Center(child: Text('El cliente de este seguimiento ya no esta disponible.')),
      );
    }
    final sale = state.saleById(followUp.saleId);
    final recentNotes = state.followUpNotes
        .where((item) => item.customerId == customer.id)
        .take(3)
        .toList();
    final isBirthday = followUp.type == FollowUpType.birthday;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .86,
      minChildSize: .55,
      maxChildSize: .96,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Center(child: Container(width: 44, height: 4, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Text(customer.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          Text('${_label(followUp.type)} · ${DateFormat('dd/MM/yyyy').format(followUp.dueAt)}'),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F3FB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              FollowUpMessageTemplates.message(followUp.type, customer.name),
              style: const TextStyle(fontSize: 15, height: 1.35),
            ),
          ),
          const SizedBox(height: 12),
          if (!isBirthday && sale == null)
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.info_outline, color: AppColors.orange),
              title: Text('La venta historica ya no existe.'),
              subtitle: Text('No se asociara otra venta automaticamente.'),
            ),
          if (sale != null) ...[
            Text(
              'Venta #${sale.number.toString().padLeft(4, '0')} · ${DateFormat('dd/MM/yyyy').format(sale.soldAt)}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(
              sale.deliveredAt == null
                  ? 'Entrega pendiente'
                  : 'Entrega: ${DateFormat('dd/MM/yyyy').format(sale.deliveredAt!)}',
            ),
            const SizedBox(height: 8),
            ...sale.items.map(
              (item) => Text(
                '• ${item.quantity} × ${item.productName}${item.isGift ? ' (obsequio)' : ''}',
              ),
            ),
          ],
          if (recentNotes.isNotEmpty) ...[
            const Divider(height: 28),
            const Text('Ultimas notas', style: TextStyle(fontWeight: FontWeight.w900)),
            ...recentNotes.map((item) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.text),
                  subtitle: Text(DateFormat('dd/MM/yyyy HH:mm').format(item.createdAt)),
                )),
          ],
          const Divider(height: 28),
          TextField(
            controller: note,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Nota del seguimiento'),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<FollowUpContactMethod>(
            value: contactMethod,
            decoration: const InputDecoration(labelText: 'Medio de contacto'),
            items: const [
              DropdownMenuItem(value: FollowUpContactMethod.call, child: Text('Llamada')),
              DropdownMenuItem(value: FollowUpContactMethod.whatsapp, child: Text('WhatsApp')),
              DropdownMenuItem(value: FollowUpContactMethod.other, child: Text('Otro')),
            ],
            onChanged: (value) => setState(() => contactMethod = value ?? contactMethod),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: customer.allowCalls ? () => launchUrl(Uri(scheme: 'tel', path: customer.normalizedPhone)) : null,
                icon: const Icon(Icons.call_outlined),
                label: const Text('LLAMAR'),
              ),
              OutlinedButton.icon(
                onPressed: customer.allowWhatsApp ? () => _whatsApp(customer.normalizedPhone, FollowUpMessageTemplates.message(followUp.type, customer.name)) : null,
                icon: const Icon(Icons.chat_outlined),
                label: const Text('WHATSAPP'),
              ),
              if (sale != null)
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => SaleDetailScreen(saleId: sale.id))),
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('VER VENTA'),
                ),
              FilledButton.icon(
                onPressed: saving || followUp.status != FollowUpStatus.pending ? null : () => _complete(followUp),
                icon: const Icon(Icons.check),
                label: Text(saving ? 'GUARDANDO...' : 'COMPLETAR'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _complete(FollowUp followUp) async {
    setState(() => saving = true);
    try {
      await AppScope.of(context).completeFollowUp(
        followUp,
        notes: note.text,
        contactMethod: contactMethod,
      );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}

String _label(FollowUpType type) => switch (type) {
      FollowUpType.dayOne => 'Seguimiento del dia siguiente',
      FollowUpType.dayThree => 'Seguimiento del tercer dia',
      FollowUpType.dayEight => 'Seguimiento del octavo dia',
      FollowUpType.periodic => 'Seguimiento quincenal',
      FollowUpType.replenishment => 'Reposicion de producto',
      FollowUpType.birthday => 'Cumpleaños',
    };

Future<void> _whatsApp(String number, String message) async {
  final phone = number.replaceAll(RegExp(r'[^0-9]'), '');
  final uri = Uri.https('wa.me', '/$phone', {'text': message});
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    throw StateError('No se pudo abrir WhatsApp.');
  }
}
