import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../models/product_sort_option.dart';

class ProductSortControl extends StatelessWidget {
  const ProductSortControl({
    required this.value,
    required this.options,
    required this.onChanged,
    this.defaultOption,
    super.key,
  });

  final ProductSortOption? value;
  final List<ProductSortOption> options;
  final ProductSortOption? defaultOption;
  final ValueChanged<ProductSortOption?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => _openSortSheet(context),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      value == null
                          ? 'Ordenar por'
                          : 'Ordenar por: ${productSortLabel(value!)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.muted),
                    ),
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
        ),
        TextButton(
          onPressed: value == defaultOption
              ? null
              : () => onChanged(defaultOption),
          style: TextButton.styleFrom(foregroundColor: AppColors.muted),
          child: const Text('Limpiar'),
        ),
      ],
    );
  }

  Future<void> _openSortSheet(BuildContext context) async {
    var selected = value;
    final result = await showModalBottomSheet<_SortResult>(
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
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (context, index) {
                            final option = options[index];
                            return RadioListTile<ProductSortOption>(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              value: option,
                              groupValue: selected,
                              title: Text(productSortLabel(option)),
                              onChanged: (value) =>
                                  setSheetState(() => selected = value),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(
                                context,
                                _SortResult(defaultOption),
                              ),
                              child: const Text('LIMPIAR'),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(
                                context,
                                _SortResult(selected),
                              ),
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

    if (result != null) onChanged(result.value);
  }
}

class _SortResult {
  const _SortResult(this.value);

  final ProductSortOption? value;
}
