import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/currency_formatter.dart';
import '../../domain/entities/product.dart';
import '../state/app_scope.dart';
import '../widgets/app_header.dart';
import '../widgets/cart_badge_button.dart';
import '../widgets/product_avatar.dart';
import 'product_detail_screen.dart';

enum ProductSortOption {
  az,
  za,
  lowerPrice,
  higherPrice,
  morePoints,
  lessPoints,
}

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
    _sortProducts(products);

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
                Row(
                  children: [
                    InkWell(
                      onTap: _openSortSheet,
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              sortOption == null
                                  ? 'Ordenar por'
                                  : 'Ordenar por: ${_sortLabel(sortOption!)}',
                              style: const TextStyle(color: AppColors.muted),
                            ),
                            const SizedBox(width: 3),
                            const Icon(
                              Icons.keyboard_arrow_down,
                              size: 20,
                              color: AppColors.muted,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: sortOption == null
                          ? null
                          : () => setState(() => sortOption = null),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.muted,
                      ),
                      child: const Text('Limpiar'),
                    ),
                  ],
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
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
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

  void _sortProducts(List<Product> products) {
    switch (sortOption) {
      case ProductSortOption.az:
        products.sort((a, b) => a.name.compareTo(b.name));
      case ProductSortOption.za:
        products.sort((a, b) => b.name.compareTo(a.name));
      case ProductSortOption.lowerPrice:
        products.sort((a, b) => a.suggestedPrice.compareTo(b.suggestedPrice));
      case ProductSortOption.higherPrice:
        products.sort((a, b) => b.suggestedPrice.compareTo(a.suggestedPrice));
      case ProductSortOption.morePoints:
        products.sort((a, b) => b.points.compareTo(a.points));
      case ProductSortOption.lessPoints:
        products.sort((a, b) => a.points.compareTo(b.points));
      case null:
        break;
    }
  }

  Future<void> _openSortSheet() async {
    var selected = sortOption;

    final result = await showModalBottomSheet<ProductSortOption?>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * .82,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ordenar por',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Flexible(
                        child: ListView(
                          shrinkWrap: true,
                          children: ProductSortOption.values
                              .map(
                                (option) => RadioListTile<ProductSortOption>(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  value: option,
                                  groupValue: selected,
                                  title: Text(_sortLabel(option)),
                                  onChanged: (value) =>
                                      setSheetState(() => selected = value),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context, null),
                              child: const Text('LIMPIAR'),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(context, selected),
                              child: const Text('CONFIRMAR'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted) return;
    setState(() => sortOption = result);
  }

  String _categoryLabel(ProductCategory category) {
    return switch (category) {
      ProductCategory.nutrition => 'Nutricion',
      ProductCategory.beauty => 'Belleza',
      ProductCategory.kit => 'Kits',
    };
  }

  String _sortLabel(ProductSortOption option) {
    return switch (option) {
      ProductSortOption.az => 'A-Z',
      ProductSortOption.za => 'Z-a',
      ProductSortOption.lowerPrice => 'Menor Precio',
      ProductSortOption.higherPrice => 'Mayor Precio',
      ProductSortOption.morePoints => 'Más Puntos',
      ProductSortOption.lessPoints => 'Menos Puntos',
    };
  }
}
