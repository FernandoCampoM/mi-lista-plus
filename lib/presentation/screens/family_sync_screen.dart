import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/errors/friendly_error.dart';
import '../../core/services/cloud_sync_service.dart';
import '../widgets/app_header.dart';
import '../widgets/confirm_action_dialog.dart';

// ── NUEVO: pantalla oculta de sincronización familiar ───────────────────
// Propósito: activar/desactivar en este celular la sincronización con la
//            cuenta del hogar y elegir con qué vendedor trabaja.
// Depende de: CloudSyncService.instance (creado en main.dart).
// No modifica: ninguna otra pantalla. Se abre tocando 7 veces "Datos
//              incluidos" en Respaldo y sincronización.
class FamilySyncScreen extends StatefulWidget {
  const FamilySyncScreen({super.key});

  @override
  State<FamilySyncScreen> createState() => _FamilySyncScreenState();
}

class _FamilySyncScreenState extends State<FamilySyncScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  String seller = CloudSyncService.sellers.keys.first;
  bool busy = false;
  bool obscure = true;
  String? progress;
  // Error real si el servicio no se pudo crear al abrir la pantalla.
  String? startupError;
  bool starting = false;

  @override
  void initState() {
    super.initState();
    if (CloudSyncService.instance == null) _startService();
  }

  Future<void> _startService() async {
    final initializer = CloudSyncService.initializer;
    if (initializer == null) {
      setState(() => startupError =
          'La app todavía se está iniciando. Intenta de nuevo en unos segundos.');
      return;
    }
    setState(() {
      starting = true;
      startupError = null;
    });
    try {
      await initializer();
    } catch (error, stackTrace) {
      developer.log('Sincronización familiar (inicio)', name: 'mi_lista_plus.sync', error: error, stackTrace: stackTrace);
      if (mounted) setState(() => startupError = _signInError(error));
    } finally {
      if (mounted) setState(() => starting = false);
    }
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = CloudSyncService.instance;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          const AppHeader(
            title: 'Sincronización familiar',
            showBack: true,
            showCountrySelector: false,
            titleFontSize: 18,
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: service == null
                  ? _startupView()
                  : ListenableBuilder(
                      listenable: service,
                      builder: (context, _) => service.isActive
                          ? _activeView(service)
                          : _activationForm(service),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _startupView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (starting) ...[
            const CircularProgressIndicator(),
            const SizedBox(height: 14),
            const Text('Preparando la sincronización...'),
          ] else ...[
            Text(
              startupError ?? 'Preparando la sincronización...',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _startService,
              icon: const Icon(Icons.refresh),
              label: const Text('REINTENTAR'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _activationForm(CloudSyncService service) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      children: [
        if (service.needsSignIn)
          const Card(
            color: Color(0xFFFFF4E0),
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'La sesión del hogar se cerró. Escribe de nuevo la contraseña para continuar sincronizando.',
              ),
            ),
          ),
        const Text(
          'Comparte el inventario con los celulares del hogar y guarda tus ventas y clientes en la nube.',
          style: TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: email,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          enabled: !busy,
          decoration: const InputDecoration(
            labelText: 'Correo de la cuenta del hogar',
            prefixIcon: Icon(Icons.home_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: password,
          obscureText: obscure,
          enableSuggestions: false,
          autocorrect: false,
          enabled: !busy,
          decoration: InputDecoration(
            labelText: 'Contraseña del hogar',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              tooltip: obscure ? 'Mostrar contraseña' : 'Ocultar contraseña',
              onPressed: () => setState(() => obscure = !obscure),
              icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Este celular trabaja como:',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: [
            for (final entry in CloudSyncService.sellers.entries)
              ButtonSegment(value: entry.key, label: Text(entry.value)),
          ],
          selected: {seller},
          onSelectionChanged: busy ? null : (value) => setState(() => seller = value.single),
        ),
        const SizedBox(height: 14),
        const Text(
          'Si otro celular del hogar ya está sincronizado, el inventario de este '
          'celular se REEMPLAZA por el de la nube (antes se crea un respaldo '
          'automático). Las ventas y clientes de este celular se suben al '
          'vendedor elegido. El vendedor no se puede cambiar después en esta versión.',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: busy ? null : () => _activate(service),
          icon: busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.cloud_sync_outlined),
          label: Text(busy ? (progress ?? 'ACTIVANDO...') : 'ACTIVAR EN ESTE CELULAR'),
        ),
      ],
    );
  }

  Widget _activeView(CloudSyncService service) {
    final last = service.lastSyncAt;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.cloud_done_outlined, color: AppColors.green),
            title: Text(
              'Activa · ${service.sellerName}',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: Text(
              last == null
                  ? 'Aún sin sincronizar'
                  : 'Última sincronización: ${DateFormat('d MMM, h:mm a', 'es_CO').format(last)}',
            ),
          ),
        ),
        FutureBuilder<int>(
          future: service.pendingCount(),
          builder: (context, snapshot) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              (snapshot.data ?? 0) == 0
                  ? 'No hay cambios pendientes de subir.'
                  : '${snapshot.data} cambios pendientes de subir (se suben al tener internet).',
              style: const TextStyle(color: AppColors.muted),
            ),
          ),
        ),
        FutureBuilder<int>(
          future: service.negativeStockCount(),
          builder: (context, snapshot) => (snapshot.data ?? 0) == 0
              ? const SizedBox.shrink()
              : Card(
                  color: const Color(0xFFFFF4E0),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      '${snapshot.data} producto(s) quedaron con stock negativo '
                      '(se vendió la misma unidad en dos celulares sin internet). '
                      'Revisa y corrige el inventario.',
                    ),
                  ),
                ),
        ),
        if (service.lastError != null)
          Card(
            color: const Color(0xFFFFEDED),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text('Último error: ${service.lastError}'),
            ),
          ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: busy ? null : () => _run(service.syncNow, 'Sincronización completada.'),
          icon: const Icon(Icons.sync),
          label: const Text('SINCRONIZAR AHORA'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: busy ? null : () => _deactivate(service),
          icon: const Icon(Icons.cloud_off_outlined),
          label: const Text('DESACTIVAR EN ESTE CELULAR'),
        ),
      ],
    );
  }

  Future<void> _activate(CloudSyncService service) async {
    if (email.text.trim().isEmpty || password.text.isEmpty) {
      _message('Escribe el correo y la contraseña del hogar.');
      return;
    }
    final confirmed = await confirmAction(
      context,
      title: 'Activar como ${CloudSyncService.sellers[seller]}',
      message: 'Si el hogar ya tiene inventario en la nube, el inventario de '
          'este celular se reemplazará por ese. ¿Continuar?',
      confirmLabel: 'ACTIVAR',
    );
    if (!confirmed || !mounted) return;
    setState(() => busy = true);
    try {
      await service.activate(
        email: email.text,
        password: password.text,
        seller: seller,
        onProgress: (step) {
          if (mounted) setState(() => progress = step);
        },
      );
      password.clear();
      _message('Sincronización activa como ${CloudSyncService.sellers[seller]}.');
    } catch (error, stackTrace) {
      developer.log('Sincronización familiar (activar)', name: 'mi_lista_plus.sync', error: error, stackTrace: stackTrace);
      _message(_signInError(error));
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          progress = null;
        });
      }
    }
  }

  Future<void> _deactivate(CloudSyncService service) async {
    final confirmed = await confirmAction(
      context,
      title: '¿Desactivar en este celular?',
      message: 'Este celular dejará de sincronizar. Sus datos locales y los de '
          'la nube se conservan.',
      confirmLabel: 'DESACTIVAR',
    );
    if (!confirmed) return;
    await _run(service.deactivate, 'Sincronización desactivada en este celular.');
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() => busy = true);
    try {
      await action();
      _message(success);
    } catch (error) {
      _message(friendlyError(error));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String _signInError(Object error) {
    final text = '$error';
    if (text.contains('invalid-credential') ||
        text.contains('wrong-password') ||
        text.contains('user-not-found') ||
        text.contains('invalid-email')) {
      return 'Correo o contraseña del hogar incorrectos.';
    }
    if (text.contains('network-request-failed') || text.contains('unavailable')) {
      return 'Necesitas internet para activar la sincronización.';
    }
    if (text.contains('permission-denied')) {
      return 'Firebase rechazó el acceso. Revisa que las reglas de seguridad estén publicadas.';
    }
    if (text.contains('TimeoutException')) {
      return 'Firebase tardó demasiado en responder. Revisa tu internet y toca REINTENTAR.';
    }
    if (error is StateError || error is ArgumentError) return friendlyError(error);
    // Error no previsto: se muestra completo para poder diagnosticarlo.
    return 'No se pudo completar: $text';
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }
}
