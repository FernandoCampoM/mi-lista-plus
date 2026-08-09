import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/currency_formatter.dart';
import '../../domain/entities/product.dart';
import '../models/product_sort_option.dart';
import '../state/app_scope.dart';
import '../widgets/app_header.dart';
import '../widgets/cart_badge_button.dart';
import '../widgets/product_avatar.dart';
import '../widgets/product_sort_control.dart';
import 'product_detail_screen.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({required this.categoryName, super.key});

  final String categoryName;

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  String query = '';
  ProductSortOption? sortOption;
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
    sortProducts(products, sortOption);

    final categories = state.products
        .map((product) => product.category)
        .toSet()
        .toList()
      ..sort((a, b) => _categoryLabel(a).compareTo(_categoryLabel(b)));

    return Scaffold(
      backgroundColor: const Color(0xFFF0EEF4),
      body: Column(
        children: [
          AppHeader(
            title: 'Productos',
            showBack: true,
            actions: const [CartBadgeButton()],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
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
                const SizedBox(height: 10),
                ProductSortControl(
                  value: sortOption,
                  options: catalogProductSortOptions,
                  onChanged: (value) => setState(() => sortOption = value),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    elevation: 0,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => ProductDetailScreen(product: product),
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.black.withOpacity(.08),
                            width: .8,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(.025),
                              blurRadius: 7,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          leading: ProductAvatar(product: product, size: 58),
                          title: Text(
                            product.name,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          subtitle: Text(
                            'Codigo  ${product.code}\n'
                            'Puntos  ${product.points == 0 ? 'N/A' : product.points}\n'
                            'Precio sugerido',
                          ),
                          trailing: Text(
                            formatter.money(product.suggestedPrice),
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                            ),
                          ),
                        ),
                      ),
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
