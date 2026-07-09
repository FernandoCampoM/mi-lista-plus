import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/product_image_cache_service.dart';
import '../../domain/entities/product.dart';

class ProductAvatar extends StatelessWidget {
  const ProductAvatar({required this.product, this.size = 54, super.key});

  final Product product;
  final double size;

  @override
  Widget build(BuildContext context) {
    final trimmedName = product.name.trim();
    final label = trimmedName.isEmpty ? '?' : trimmedName[0].toUpperCase();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.purple, width: 2.4),
      ),
      clipBehavior: Clip.antiAlias,
      child: product.imageUrl.isEmpty
          ? DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: product.category == ProductCategory.beauty
                      ? const [Color(0xFFEFE3FF), Color(0xFFFFF2F8)]
                      : const [Color(0xFFE8FFF9), Color(0xFFFFF4DC)],
                ),
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: AppColors.deepPurple,
                    fontSize: size * .42,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            )
          : CachedNetworkImage(
              imageUrl: product.imageUrl,
              cacheManager: ProductImageCacheService.cacheManager,
              fit: BoxFit.cover,
              memCacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
              memCacheHeight: (size * MediaQuery.devicePixelRatioOf(context)).round(),
              placeholder: (_, __) => Center(
                child: SizedBox(
                  width: size * .35,
                  height: size * .35,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              errorWidget: (_, __, ___) => Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: AppColors.deepPurple,
                    fontSize: size * .42,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
    );
  }
}
