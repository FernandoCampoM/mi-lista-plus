import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/currency_formatter.dart';
import '../../domain/entities/product.dart';
import '../state/app_scope.dart';
import '../widgets/app_header.dart';
import '../widgets/cart_badge_button.dart';
import '../widgets/product_avatar.dart';
import 'product_detail_screen.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({required this.categoryName, super.key});

  final String categoryName;

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  String query = '';
  late ProductCategory selectedCategory;

  @override
  void initState() {
    super.initState();
    selectedCategory = widget.categoryName.toLowerCase().contains('belleza')
        ? ProductCategory.beauty
        : ProductCategory.nutrition;
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final formatter = CurrencyFormatter(state.selectedCountry!);
    final products = state.products.where((product) {
      final matchesCategory = product.category == selectedCategory;
      final matchesQuery = query.isEmpty ||
          product.name.toLowerCase().contains(query.toLowerCase()) ||
          product.code.contains(query);
      return matchesCategory && matchesQuery;
    }).toList();
    final categories = state.products
        .map((product) => product.category)
        .toSet()
        .toList()
      ..sort((a, b) => _categoryLabel(a).compareTo(_categoryLabel(b)));

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          AppHeader(
            title: 'Productos',
            showBack: true,
            actions: const [CartBadgeButton()],
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                DropdownButtonFormField<ProductCategory>(
                  value: selectedCategory,
                  decoration: const InputDecoration(labelText: 'Filtrar por marca'),
                  items: categories
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(_categoryLabel(item)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => selectedCategory = value);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  onChanged: (value) => setState(() => query = value),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search, color: AppColors.purple),
                    hintText: 'Buscar...',
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              itemCount: products.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final product = products[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  leading: ProductAvatar(product: product),
                  title: Text(
                    product.name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    'Codigo  ${product.code}\n'
                    'Puntos  ${product.points == 0 ? 'N/A' : product.points}\n'
                    'Precio sugerido',
                  ),
                  trailing: Text(
                    formatter.money(product.suggestedPrice),
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => ProductDetailScreen(product: product),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _categoryLabel(ProductCategory category) {
    return switch (category) {
      ProductCategory.nutrition => 'Nutricion',
      ProductCategory.beauty => 'Belleza',
      ProductCategory.kit => 'Kits',
    };
  }
}
