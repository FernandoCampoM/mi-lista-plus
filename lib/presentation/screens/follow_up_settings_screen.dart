import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/text_search.dart';
import '../../core/services/app_ad_service.dart';
import '../../domain/entities/product.dart';
import '../state/app_scope.dart';
import '../widgets/adaptive_banner_ad.dart';
import '../widgets/app_header.dart';

class FollowUpSettingsScreen extends StatefulWidget {
  const FollowUpSettingsScreen({super.key});

  @override
  State<FollowUpSettingsScreen> createState() =>
      _FollowUpSettingsScreenState();
}

class _FollowUpSettingsScreenState extends State<FollowUpSettingsScreen> {
  final searchController = TextEditingController();
  int? hour;
  String query = '';
  bool loadedHour = false;
  bool? notificationsAllowed;
  int? pendingNotifications;
  String manufacturer = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (loadedHour) return;
    loadedHour = true;
    AppScope.of(context).reminderHour.then((value) {
      if (mounted) setState(() => hour = value);
    });
    _loadDiagnostics();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final normalized = normalizeSearchText(query);
    final products = state.products.where((product) {
      return searchMatchesProduct(query: normalized, name: product.name, code: product.code);
    }).toList()
      ..sort((a, b) {
        final byCategory = a.category.index.compareTo(b.category.index);
        return byCategory != 0
            ? byCategory
            : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          const AppHeader(
            title: 'Configurar seguimiento',
            showBack: true,
            showCountrySelector: false,
            titleFontSize: 18,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
            child: DropdownButtonFormField<int>(
              value: hour,
              decoration: const InputDecoration(
                labelText: 'Hora de recordatorios',
              ),
              items: List.generate(
                24,
                (value) => DropdownMenuItem(
                  value: value,
                  child: Text('${value.toString().padLeft(2, '0')}:00'),
                ),
              ),
              onChanged: (value) async {
                if (value == null) return;
                await state.setReminderHour(value);
                if (mounted) setState(() => hour = value);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _editMonthlyPointsGoal(state.monthlyPointsGoal),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppColors.line),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.track_changes_outlined, color: AppColors.purple),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Meta mensual de puntos', style: TextStyle(fontWeight: FontWeight.w900)),
                          const SizedBox(height: 3),
                          Text('${state.monthlyPointsGoal} puntos', style: const TextStyle(color: AppColors.muted)),
                        ],
                      ),
                    ),
                    const Icon(Icons.edit_outlined, size: 20),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(8)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Diagnostico de notificaciones', style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(notificationsAllowed == null
                    ? 'Comprobando permiso...'
                    : notificationsAllowed!
                        ? 'Notificaciones permitidas'
                        : 'Notificaciones bloqueadas',
                    style: TextStyle(color: notificationsAllowed == true ? AppColors.green : AppColors.orange)),
                Text('Programadas: ${pendingNotifications ?? '-'}'),
                if (manufacturer.contains('xiaomi') || manufacturer.contains('redmi'))
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('Xiaomi/Redmi puede restringir alarmas en segundo plano. Permite inicio automatico y excluye Mi Lista + del ahorro de bateria.', style: TextStyle(color: AppColors.orange)),
                  ),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  OutlinedButton.icon(onPressed: _sendTest, icon: const Icon(Icons.notifications_active_outlined), label: const Text('ENVIAR NOTIFICACION DE PRUEBA')),
                  TextButton.icon(onPressed: _openSettings, icon: const Icon(Icons.settings_outlined), label: const Text('ABRIR AJUSTES')),
                  IconButton(tooltip: 'Actualizar diagnostico', onPressed: _loadDiagnostics, icon: const Icon(Icons.refresh)),
                ]),
              ]),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Días que debe durar cada unidad al cliente',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
            child: TextField(
              controller: searchController,
              onChanged: (value) => setState(() {
                query = value;
              }),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Buscar por nombre o código...',
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpiar búsqueda',
                        onPressed: () {
                          searchController.clear();
                          setState(() => query = '');
                        },
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: products.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.fromLTRB(18, 24, 18, 32),
                      children: const [
                        Center(child: Text('No se encontraron productos.')),
                        AdaptiveBannerAd(
                          placement: BannerPlacement.settings,
                          margin: EdgeInsets.only(top: 24, bottom: 4),
                          maxHeight: 72,
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 32),
                      itemCount: products.length + 1,
                      itemBuilder: (context, index) {
                        if (index == products.length) {
                          return const AdaptiveBannerAd(
                            placement: BannerPlacement.settings,
                            margin: EdgeInsets.only(top: 8, bottom: 4),
                            maxHeight: 72,
                          );
                        }
                        final product = products[index];
                        return FutureBuilder<int?>(
                          future: state.productFollowUpDurationDays(product),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState !=
                                ConnectionState.done) {
                              return _ProductDurationTile.loading(
                                product: product,
                              );
                            }
                            final days = snapshot.data;
                            return _ProductDurationTile(
                              product: product,
                              days: days,
                              onToggle: (enabled) => _toggle(
                                product,
                                enabled,
                                days,
                              ),
                              onEdit: () => _edit(product, days),
                            );
                          },
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  int _defaultDays(Product product) => switch (product.category) {
        ProductCategory.nutrition => 10,
        ProductCategory.beauty => 180,
        ProductCategory.kit => 10,
      };

  Future<void> _editMonthlyPointsGoal(int currentGoal) async {
    var draft = '$currentGoal';
    final value = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Meta mensual de puntos'),
        content: TextFormField(
          initialValue: draft,
          autofocus: true,
          keyboardType: TextInputType.number,
          onChanged: (text) => draft = text,
          decoration: const InputDecoration(
            labelText: 'Meta de puntos',
            helperText: 'La meta predeterminada es 2500 puntos.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('CANCELAR'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = int.tryParse(draft.trim());
              if (parsed == null || parsed < 1) return;
              Navigator.pop(dialogContext, parsed);
            },
            child: const Text('GUARDAR'),
          ),
        ],
      ),
    );
    if (value != null && mounted) {
      await AppScope.of(context).setMonthlyPointsGoal(value);
    }
  }

  Future<void> _loadDiagnostics() async {
    final service = AppScope.of(context).notificationService;
    if (service == null) return;
    await service.initialize(requestPermission: false);
    final allowed = await service.notificationsAllowed();
    final count = await service.pendingCount();
    final maker = await service.manufacturer();
    if (mounted) setState(() {
      notificationsAllowed = allowed;
      pendingNotifications = count;
      manufacturer = maker;
    });
  }

  Future<void> _sendTest() async {
    final service = AppScope.of(context).notificationService;
    if (service == null) return;
    if (!await service.requestPermissions()) {
      await _loadDiagnostics();
      return;
    }
    await service.sendTestNotification();
    await _loadDiagnostics();
  }

  Future<void> _openSettings() async {
    await AppScope.of(context).notificationService?.openNotificationSettings();
    await _loadDiagnostics();
  }

  Future<void> _toggle(
    Product product,
    bool enabled,
    int? currentDays,
  ) async {
    await AppScope.of(context).setProductFollowUpDuration(
      product,
      enabled: enabled,
      days: currentDays ?? _defaultDays(product),
    );
    if (mounted) setState(() {});
  }

  Future<void> _edit(Product product, int? current) async {
    final controller = TextEditingController(
      text: '${current ?? _defaultDays(product)}',
    );
    var enabled = current != null;
    final result = await showDialog<({bool enabled, int days})>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(product.name, maxLines: 3),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: enabled,
                title: const Text('Seguimiento activo'),
                onChanged: (value) =>
                    setDialogState(() => enabled = value),
              ),
              TextField(
                controller: controller,
                enabled: enabled,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Días que debe durar cada unidad',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('CANCELAR'),
            ),
            ElevatedButton(
              onPressed: () {
                final days = int.tryParse(controller.text.trim());
                if (days == null || days < 1) return;
                Navigator.pop(
                  dialogContext,
                  (enabled: enabled, days: days),
                );
              },
              child: const Text('GUARDAR'),
            ),
          ],
        ),
      ),
    );
    final value = result;
    Future<void>.delayed(
      const Duration(milliseconds: 400),
      controller.dispose,
    );
    if (value == null || !mounted) return;
    await AppScope.of(context).setProductFollowUpDuration(
      product,
      enabled: value.enabled,
      days: value.days,
    );
    if (mounted) setState(() {});
  }
}

class _ProductDurationTile extends StatelessWidget {
  const _ProductDurationTile({
    required this.product,
    required this.days,
    required this.onToggle,
    required this.onEdit,
  }) : loading = false;

  const _ProductDurationTile.loading({required this.product})
      : days = null,
        onToggle = null,
        onEdit = null,
        loading = true;

  final Product product;
  final int? days;
  final ValueChanged<bool>? onToggle;
  final VoidCallback? onEdit;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 4,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (product.code.isNotEmpty)
                  Text(
                    'Código ${product.code}',
                    style: const TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
                Text(
                  loading
                      ? 'Cargando configuración...'
                      : days == null
                          ? 'Seguimiento desactivado'
                          : 'Seguimiento activo · $days días por unidad',
                  style: TextStyle(
                    fontSize: 11,
                    color: days == null && !loading
                        ? AppColors.muted
                        : AppColors.green,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (loading)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else ...[
            Switch(value: days != null, onChanged: onToggle),
            IconButton(
              tooltip: 'Editar duración',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
          ],
        ],
      ),
    );
  }
}
