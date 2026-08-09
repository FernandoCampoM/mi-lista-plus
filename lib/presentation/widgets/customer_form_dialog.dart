import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/customer.dart';

class CustomerFormResult {
  const CustomerFormResult({
    required this.name,
    required this.callingCode,
    required this.phoneNumber,
    required this.goal,
    required this.birthday,
    required this.consentGranted,
  });

  final String name;
  final String callingCode;
  final String phoneNumber;
  final String goal;
  final DateTime? birthday;
  final bool consentGranted;
}

Future<CustomerFormResult?> showCustomerFormDialog(
  BuildContext context, {
  Customer? customer,
  String initialName = '',
}) {
  return showDialog<CustomerFormResult>(
    context: context,
    builder: (_) => _CustomerFormDialog(
      customer: customer,
      initialName: initialName,
    ),
  );
}

class _CustomerFormDialog extends StatefulWidget {
  const _CustomerFormDialog({required this.initialName, this.customer});

  final Customer? customer;
  final String initialName;

  @override
  State<_CustomerFormDialog> createState() => _CustomerFormDialogState();
}

class _CustomerFormDialogState extends State<_CustomerFormDialog> {
  late final TextEditingController nameController;
  late final TextEditingController callingCodeController;
  late final TextEditingController phoneController;
  late final TextEditingController goalController;
  DateTime? birthday;
  late bool consentGranted;

  bool get canSave =>
      nameController.text.trim().isNotEmpty &&
      phoneController.text.trim().isNotEmpty &&
      consentGranted;

  @override
  void initState() {
    super.initState();
    final customer = widget.customer;
    nameController = TextEditingController(
      text: customer?.name ?? widget.initialName,
    );
    callingCodeController = TextEditingController(
      text: customer?.callingCode ?? '57',
    );
    phoneController = TextEditingController(text: customer?.phoneNumber ?? '');
    goalController = TextEditingController(text: customer?.goal ?? '');
    birthday = customer?.birthday;
    consentGranted = customer?.hasActiveConsent ?? false;
  }

  @override
  void dispose() {
    nameController.dispose();
    callingCodeController.dispose();
    phoneController.dispose();
    goalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.customer == null ? 'Nuevo cliente' : 'Editar cliente'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              onChanged: (_) => setState(() {}),
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nombre *'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                SizedBox(
                  width: 90,
                  child: TextField(
                    controller: callingCodeController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Indicativo'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: phoneController,
                    onChanged: (_) => setState(() {}),
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Telefono *'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: goalController,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Que quiere mejorar'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.cake_outlined),
              label: Text(
                birthday == null
                    ? 'FECHA DE CUMPLEAÑOS (DD/MM/AAAA)'
                    : DateFormat('dd/MM/yyyy').format(birthday!),
              ),
              onPressed: _selectBirthday,
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: consentGranted,
              title: const Text(
                'Autoriza guardar datos y realizar seguimiento',
                style: TextStyle(fontSize: 13),
              ),
              onChanged: (value) =>
                  setState(() => consentGranted = value ?? false),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCELAR'),
        ),
        ElevatedButton(
          onPressed: canSave ? _submit : null,
          child: const Text('GUARDAR'),
        ),
      ],
    );
  }

  Future<void> _selectBirthday() async {
    final selected = await showDatePicker(
      context: context,
      locale: const Locale('es', 'CO'),
      initialDate: birthday ?? DateTime(1990),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      helpText: 'Fecha de cumpleaños',
      fieldLabelText: 'DD/MM/AAAA',
      fieldHintText: 'DD/MM/AAAA',
    );
    if (selected != null && mounted) setState(() => birthday = selected);
  }

  void _submit() {
    Navigator.pop(
      context,
      CustomerFormResult(
        name: nameController.text.trim(),
        callingCode: callingCodeController.text.trim(),
        phoneNumber: phoneController.text.trim(),
        goal: goalController.text.trim(),
        birthday: birthday,
        consentGranted: consentGranted,
      ),
    );
  }
}
