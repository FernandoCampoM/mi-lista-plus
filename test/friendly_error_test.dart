// ── NUEVO: pruebas de friendlyError ─────────────────────────────────────
// Propósito: verificar que se quitan los prefijos técnicos de los errores.
// Depende de: friendlyError y AppException.
// No modifica: pruebas existentes.
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_lista_plus/core/errors/app_exception.dart';
import 'package:mi_lista_plus/core/errors/friendly_error.dart';

void main() {
  test('quita los prefijos técnicos de los errores conocidos', () {
    expect(friendlyError(StateError('Sin stock.')), 'Sin stock.');
    expect(
      friendlyError(ArgumentError.value(-1, 'x', 'No puede ser negativo.')),
      'No puede ser negativo.',
    );
    expect(friendlyError(AppException('Sin conexión.')), 'Sin conexión.');
    expect(
      friendlyError(const FormatException('Archivo inválido.')),
      'Archivo inválido.',
    );
  });

  test('un error desconocido muestra un mensaje genérico', () {
    expect(
      friendlyError(Exception('detalle interno')),
      'Ocurrió un error inesperado. Intenta de nuevo.',
    );
  });
}
