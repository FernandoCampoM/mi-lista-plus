import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_lista_plus/presentation/widgets/primary_button.dart';

void main() {
  testWidgets('PrimaryButton muestra la etiqueta y ejecuta la accion', (
    tester,
  ) async {
    var pressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrimaryButton(
            label: 'CONFIRMAR',
            onPressed: () => pressed = true,
          ),
        ),
      ),
    );

    expect(find.text('CONFIRMAR'), findsOneWidget);
    await tester.tap(find.text('CONFIRMAR'));
    expect(pressed, isTrue);
  });
}
