import 'dart:developer' as developer;

import 'package:flutter/services.dart';

import 'app_exception.dart';

// ── NUEVO: mensajes de error legibles para el usuario ───────────────────
// Propósito: mostrar solo el texto en español de un error, sin prefijos
//            técnicos como "Bad state:" o "Invalid argument(s):".
// Depende de: AppException y los tipos de error estándar de Dart.
// No modifica: los errores lanzados por la app (solo cómo se muestran).
String friendlyError(Object error) {
  final message = switch (error) {
    AppException(:final message) => message,
    StateError(:final message) => message,
    ArgumentError(:final message) when message is String => message,
    FormatException(:final message) => message,
    PlatformException(:final message) when message != null => message,
    _ => null,
  };
  if (message != null && message.trim().isNotEmpty) return message.trim();
  developer.log('Error sin mensaje amigable', name: 'mi_lista_plus.ui', error: error);
  return 'Ocurrió un error inesperado. Intenta de nuevo.';
}
