import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../../domain/entities/product.dart';

class ProductImageCacheService {
  ProductImageCacheService._();

  static const String cacheKey = 'miListaProductImages';

  static final CacheManager cacheManager = CacheManager(
    Config(
      cacheKey,
      stalePeriod: const Duration(days: 90),
      maxNrOfCacheObjects: 1000,
    ),
  );

  static Future<void> cacheProductImagesInBackground(List<Product> products) async {
    for (final product in products) {
      final imageUrl = product.imageUrl.trim();
      if (imageUrl.isEmpty) continue;

      final uri = Uri.tryParse(imageUrl);
      if (uri == null || !uri.hasScheme || !uri.hasAuthority) continue;

      try {
        final cachedFile = await cacheManager.getFileFromCache(imageUrl);
        if (cachedFile != null) continue;

        await cacheManager.downloadFile(imageUrl, key: imageUrl);
      } catch (_) {
        // No bloquea la sincronizacion si una imagen falla.
      }
    }
  }
}
