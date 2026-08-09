import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (loadedHour) return;
    loadedHour = true;
    AppScope.of(context).reminderHour.then((value) {
      if (mounted) setState(() => hour = value);
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final normalized = query.trim().toLowerCase();
    final products = state.products.where((product) {
      return normalized.isEmpty ||
          product.name.toLowerCase().contains(normalized) ||
          product.code.toLowerCase().contains(normalized);
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
