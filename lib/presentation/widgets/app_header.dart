import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../state/app_scope.dart';

class AppHeader extends StatelessWidget {
  const AppHeader({
    required this.title,
    this.showBack = false,
    this.actions = const [],
    super.key,
  });

  final String title;
  final bool showBack;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 14,
        top: MediaQuery.paddingOf(context).top + 10,
        bottom: 14,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.deepPurple, AppColors.purple],
        ),
      ),
      child: Row(
        children: [
          IconButton.filled(
            onPressed: showBack ? () => Navigator.pop(context) : () {},
            icon: Icon(showBack ? Icons.arrow_back : Icons.menu),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(.13),
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          if (state.selectedCountry != null)
            PopupMenuButton<String>(
              tooltip: 'Cambiar pais',
              initialValue: state.selectedCountry!.code,
              onSelected: (countryCode) async {
                final country = state.countries.firstWhere(
                  (item) => item.code == countryCode,
                );
                await state.loadCountry(country);
                if (context.mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              },
              itemBuilder: (context) => state.countries
                  .map(
                    (country) => PopupMenuItem(
                      value: country.code,
                      child: Text('${country.flagEmoji} ${country.name}'),
                    ),
                  )
                  .toList(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.deepPurple.withOpacity(.35),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${state.selectedCountry!.name} ${state.selectedCountry!.flagEmoji}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_drop_down,
                      color: Colors.white,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(width: 8),
          ...actions,
        ],
      ),
    );
  }
}
