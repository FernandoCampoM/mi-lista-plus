import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_lista_plus/domain/entities/customer.dart';
import 'package:mi_lista_plus/presentation/widgets/customer_form_dialog.dart';

void main() {
  testWidgets('cancelar cierra el formulario sin excepciones', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showCustomerFormDialog(context),
            child: const Text('ABRIR'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('ABRIR'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CANCELAR'));
    await tester.pumpAndSettle();

    expect(find.text('Nuevo cliente'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('muestra cumpleaños con formato dd/mm/yyyy', (tester) async {
    final customer = Customer(
      id: 'c1',
      name: 'Ana',
      callingCode: '57',
      phoneNumber: '3001234567',
      birthday: DateTime(1990, 7, 5),
      consentAt: DateTime(2026),
      consentScopes: const {ConsentScope.phone},
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showCustomerFormDialog(
              context,
              customer: customer,
            ),
            child: const Text('ABRIR'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('ABRIR'));
    await tester.pumpAndSettle();

    expect(find.text('05/07/1990'), findsOneWidget);
  });
}
