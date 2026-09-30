import 'package:flutter/material.dart';

import '../../core/services/app_ad_service.dart';
import 'app_state.dart';

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({
    required AppState state,
    required this.adService,
    required super.child,
    super.key,
  }) : super(notifier: state);

  final AppAdService adService;

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope no esta disponible en el arbol.');
    return scope!.notifier!;
  }

  static AppAdService adsOf(BuildContext context) {
    // El servicio de anuncios nunca cambia de instancia y avisa sus propios
    // cambios; por eso no se suscribe el widget a cada cambio de AppState.
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope no esta disponible en el arbol.');
    return scope!.adService;
  }
}
