import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart' hide Simulation;
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/entities/cart_item.dart';
import '../../domain/entities/country.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/simulation.dart';
import '../constants/app_colors.dart';
import 'currency_formatter.dart';
import 'product_image_cache_service.dart';

class ShareSimulationService {
  ShareSimulationService._();

  static Future<void> shareAsText({
    required Simulation simulation,
    required Country country,
  }) async {
    final text = buildShareText(simulation: simulation, country: country);
    await Share.share(text);
  }

  static Future<XFile> buildImageFile({
    required Simulation simulation,
    required Country country,
  }) async {
    final bytes = await _buildImageBytes(
      simulation: simulation,
      country: country,
    );

    final tempDir = await Directory.systemTemp.createTemp('mi_lista_plus_share_');
    final file = File('${tempDir.path}/simulacion_${simulation.id}.png');
    await file.writeAsBytes(bytes, flush: true);
    return XFile(file.path, mimeType: 'image/png', name: 'simulacion_${simulation.id}.png');
  }

  static Future<void> shareAsImage({
    required Simulation simulation,
    required Country country,
  }) async {
    final file = await buildImageFile(simulation: simulation, country: country);
    await Share.shareXFiles(
      [file],
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
    required Simulation simulation,
    required Country country,
  }) async {
    final imageFiles = <String, File?>{};
    for (final item in simulation.items) {
      final imageUrl = item.product.imageUrl.trim();
      if (imageUrl.isEmpty || imageFiles.containsKey(imageUrl)) continue;
      imageFiles[imageUrl] = await ProductImageCacheService.getCachedOrDownloadImageFile(imageUrl);
    }

    const imageWidth = 720.0;

    final widget = MediaQuery(
      data: const MediaQueryData(
        size: Size(imageWidth, 1),
        devicePixelRatio: 3,
        textScaler: TextScaler.linear(1),
        padding: EdgeInsets.zero,
        viewInsets: EdgeInsets.zero,
        viewPadding: EdgeInsets.zero,
      ),
      child: Material(
        color: Colors.transparent,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: imageWidth,
            child: _SimulationShareImage(
              simulation: simulation,
              country: country,
              width: imageWidth,
              imageFiles: imageFiles,
            ),
          ),
        ),
      ),
    );

    return ScreenshotController().captureFromLongWidget(
      widget,
      pixelRatio: 3,
      delay: const Duration(milliseconds: 600),
      constraints: const BoxConstraints(
        minWidth: imageWidth,
        maxWidth: imageWidth,
      ),
    );
  }
}

class _SimulationShareImage extends StatelessWidget {
  const _SimulationShareImage({
    required this.simulation,
    required this.country,
    required this.width,
    required this.imageFiles,
  });

  final Simulation simulation;
  final Country country;
  final double width;
  final Map<String, File?> imageFiles;

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
      color: const Color(0xFFF4F1F7),
      padding: const EdgeInsets.all(22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HeaderCard(
            simulation: simulation,
            discountLabel: discountLabel,
            customerName: customerName,
          ),
          const SizedBox(height: 18),
          const Text(
            'Mi pedido',
            style: TextStyle(
              color: AppColors.deepPurple,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          _ProductListCard(
            simulation: simulation,
            formatter: formatter,
            imageFiles: imageFiles,
          ),
          const SizedBox(height: 18),
          _SummaryCard(
            simulation: simulation,
            formatter: formatter,
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Generado con Mi Lista+',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.simulation,
    required this.discountLabel,
    required this.customerName,
  });

  final Simulation simulation;
  final String discountLabel;
  final String customerName;

  @override
  Widget build(BuildContext context) {
    return _ShareCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Id: ${simulation.id}',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          Text('País: ${simulation.countryCode}', style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 8),
          Text(discountLabel, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 8),
          Text('Cliente: $customerName', style: const TextStyle(fontSize: 24)),
        ],
      ),
    );
  }
}

class _ProductListCard extends StatelessWidget {
  const _ProductListCard({
    required this.simulation,
    required this.formatter,
    required this.imageFiles,
  });

  final Simulation simulation;
  final CurrencyFormatter formatter;
  final Map<String, File?> imageFiles;

  @override
  Widget build(BuildContext context) {
    return _ShareCard(
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < simulation.items.length; i++) ...[
            _ShareProductRow(
              item: simulation.items[i],
              discountPercent: simulation.discountPercent,
              formatter: formatter,
              imageFile: imageFiles[simulation.items[i].product.imageUrl.trim()],
            ),
            if (i != simulation.items.length - 1)
              const Divider(height: 1, color: Color(0xFFE5E1E8)),
          ],
        ],
      ),
    );
  }
}

class _ShareProductRow extends StatelessWidget {
  const _ShareProductRow({
    required this.item,
    required this.discountPercent,
    required this.formatter,
    required this.imageFile,
  });

  final CartItem item;
  final int discountPercent;
  final CurrencyFormatter formatter;
  final File? imageFile;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 188,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _ShareProductAvatar(product: item.product, size: 96, imageFile: imageFile),
            const SizedBox(width: 22),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.product.name,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 24,
                      height: 1.05,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _ShareRow(label: 'Cantidad', value: '${item.quantity}'),
                  _ShareRow(label: 'Puntos:', value: '${item.totalPoints}'),
                  _ShareRow(
                    label: 'Precio:',
                    value: formatter.money(item.subtotal(discountPercent)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareProductAvatar extends StatelessWidget {
  const _ShareProductAvatar({
    required this.product,
    required this.size,
    required this.imageFile,
  });

  final Product product;
  final double size;
  final File? imageFile;

  @override
  Widget build(BuildContext context) {
    final trimmedName = product.name.trim();
    final label = trimmedName.isEmpty ? '?' : trimmedName[0].toUpperCase();
    final imageUrl = product.imageUrl.trim();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.purple, width: 4),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageFile == null
          ? _ShareAvatarInitial(label: label, size: size)
          : Padding(
              padding: const EdgeInsets.all(8),
              child: Image.file(
                imageFile!,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => _ShareAvatarInitial(label: label, size: size),
              ),
            ),
    );
  }
}

class _ShareAvatarInitial extends StatelessWidget {
  const _ShareAvatarInitial({required this.label, required this.size});

  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFEFE3FF), Color(0xFFFFF2F8)],
        ),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: AppColors.deepPurple,
            fontSize: size * .42,
            fontWeight: FontWeight.w900,
          ),
        ),
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
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 22, height: 1.1),
            ),
          ),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 22,
                height: 1.1,
                color: AppColors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.simulation, required this.formatter});

  final Simulation simulation;
  final CurrencyFormatter formatter;

  @override
  Widget build(BuildContext context) {
    return _ShareCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resumen de la simulación',
            style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 18),
          Text(
            _formatDate(simulation.createdAt),
            style: const TextStyle(fontSize: 22),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Puntos totales:',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                '${simulation.totalPoints}',
                style: const TextStyle(fontSize: 24, color: AppColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Precio total:',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                formatter.money(simulation.totalAmount),
                style: const TextStyle(fontSize: 24, color: AppColors.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }
}

class _ShareCard extends StatelessWidget {
  const _ShareCard({required this.child, this.padding = const EdgeInsets.all(26)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}
