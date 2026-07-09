import 'dart:typed_data';

import 'package:flutter/material.dart' hide Simulation;
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/entities/country.dart';
import '../../domain/entities/simulation.dart';
import '../../presentation/widgets/product_avatar.dart';
import '../constants/app_colors.dart';
import 'currency_formatter.dart';

class ShareSimulationService {
  ShareSimulationService._();

  static Future<void> shareAsText({
    required Simulation simulation,
    required Country country,
  }) async {
    final text = buildShareText(simulation: simulation, country: country);
    await Share.share(text);
  }

  static Future<void> shareAsImage({
    required BuildContext context,
    required Simulation simulation,
    required Country country,
  }) async {
    final bytes = await _buildImageBytes(
      context: context,
      simulation: simulation,
      country: country,
    );

    await Share.shareXFiles(
      [
        XFile.fromData(
          bytes,
          mimeType: 'image/png',
          name: 'simulacion_${simulation.id}.png',
        ),
      ],
      text: 'Simulación #${simulation.id}',
    );
  }

  static String buildShareText({
    required Simulation simulation,
    required Country country,
  }) {
    final formatter = CurrencyFormatter(country);
    final customerName = simulation.customerName.trim().isEmpty
        ? 'Nacional'
        : simulation.customerName.trim();
    final buffer = StringBuffer()
      ..writeln('📋 #${simulation.id}')
      ..writeln('📦 $customerName')
      ..writeln('🌎 ${simulation.countryCode}')
      ..writeln('─────────────────')
      ..writeln('🛒 Productos:');

    for (final item in simulation.items) {
      buffer
        ..writeln('  • ${item.quantity}x ${item.product.name}')
        ..writeln(
          '     ${formatter.money(item.subtotal(simulation.discountPercent))}  |  ${item.totalPoints} pts',
        );
    }

    buffer
      ..writeln('─────────────────')
      ..writeln('⭐ Puntos: ${simulation.totalPoints} pts')
      ..writeln('💰 Total: ${formatter.money(simulation.totalAmount)}')
      ..writeln('─────────────────');

    return buffer.toString();
  }

  static Future<Uint8List> _buildImageBytes({
    required BuildContext context,
    required Simulation simulation,
    required Country country,
  }) {
    final width = MediaQuery.sizeOf(context).width.clamp(360.0, 520.0).toDouble();
    final pixelRatio = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 3.0).toDouble();

    return ScreenshotController().captureFromWidget(
      Material(
        color: Colors.transparent,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: _SimulationShareImage(
            simulation: simulation,
            country: country,
            width: width,
          ),
        ),
      ),
      pixelRatio: pixelRatio,
      delay: const Duration(milliseconds: 700),
    );
  }
}

class _SimulationShareImage extends StatelessWidget {
  const _SimulationShareImage({
    required this.simulation,
    required this.country,
    required this.width,
  });

  final Simulation simulation;
  final Country country;
  final double width;

  @override
  Widget build(BuildContext context) {
    final formatter = CurrencyFormatter(country);
    final discountLabel = simulation.discountPercent == 0
        ? 'Precio sugerido'
        : 'Descuento de ${simulation.discountPercent}%';
    final customerName = simulation.customerName.trim().isEmpty
        ? 'Nacional'
        : simulation.customerName.trim();

    return Container(
      width: width,
      color: const Color(0xFF070707),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ShareCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Id: ${simulation.id}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text('País: ${simulation.countryCode}', style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 4),
                Text(discountLabel, style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 4),
                Text('Cliente: $customerName', style: const TextStyle(fontSize: 18)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Mi pedido',
            style: TextStyle(
              color: AppColors.deepPurple,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          _ShareCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < simulation.items.length; i++) ...[
                  _ShareProductRow(
                    itemIndex: i,
                    simulation: simulation,
                    formatter: formatter,
                  ),
                  if (i != simulation.items.length - 1)
                    const Divider(height: 1, color: Color(0xFFE0E0E0)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          _ShareCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Resumen de la simulación',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                Text(
                  _formatDate(simulation.createdAt),
                  style: const TextStyle(fontSize: 17),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Puntos totales:',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text(
                      '${simulation.totalPoints}',
                      style: const TextStyle(fontSize: 20, color: AppColors.muted),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Precio total:',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text(
                      formatter.money(simulation.totalAmount),
                      style: const TextStyle(fontSize: 20, color: AppColors.muted),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '${value.day}/${value.month}/${value.year} $hour:$minute';
  }
}

class _ShareProductRow extends StatelessWidget {
  const _ShareProductRow({
    required this.itemIndex,
    required this.simulation,
    required this.formatter,
  });

  final int itemIndex;
  final Simulation simulation;
  final CurrencyFormatter formatter;

  @override
  Widget build(BuildContext context) {
    final item = simulation.items[itemIndex];

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ProductAvatar(product: item.product, size: 64),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                _ShareRow(label: 'Cantidad', value: '${item.quantity}'),
                _ShareRow(label: 'Puntos:', value: '${item.totalPoints}'),
                _ShareRow(
                  label: 'Precio:',
                  value: formatter.money(item.subtotal(simulation.discountPercent)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareRow extends StatelessWidget {
  const _ShareRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 17))),
          Text(
            value,
            style: const TextStyle(fontSize: 18, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _ShareCard extends StatelessWidget {
  const _ShareCard({required this.child, this.padding = const EdgeInsets.all(18)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }
}
