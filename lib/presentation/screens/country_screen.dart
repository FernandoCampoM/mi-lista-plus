import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/app_ad_service.dart';
import '../../domain/entities/country.dart';
import '../state/app_scope.dart';
import 'home_screen.dart';

class CountryScreen extends StatefulWidget {
  const CountryScreen({super.key});

  @override
  State<CountryScreen> createState() => _CountryScreenState();
}

class _CountryScreenState extends State<CountryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Country> _filterCountries(List<Country> countries) {
    final query = _searchText.trim().toLowerCase();
    if (query.isEmpty) return countries;

    return countries.where((country) {
      return country.name.toLowerCase().contains(query) ||
          country.code.toLowerCase().contains(query) ||
          country.currencyCode.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _selectCountry(BuildContext context, Country country) async {
    final state = AppScope.of(context);
    final hasProducts = await state.loadCountry(country);
    if (!context.mounted) return;

    if (!hasProducts) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            state.errorMessage ??
                '${country.name} no tiene productos disponibles aun.',
          ),
        ),
      );
      return;
    }

    await AppScope.adsOf(context).recordImportantAction(
      ImportantAdAction.countryChanged,
    );
    if (!context.mounted) return;

    await Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const HomeScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final filteredCountries = _filterCountries(state.countries);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Image.asset('assets/images/logo.png', height: 160),
              const SizedBox(height: 22),
              Text(
                'Elige tu país',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: AppColors.deepPurple,
                    ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Descargaremos el catálogo correcto de productos, precios y moneda.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchText = value;
                  });
                },
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Buscar país',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchText.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchText = '';
                            });
                          },
                        ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: filteredCountries.isEmpty
                    ? const Center(
                        child: Text(
                          'No encontramos ese país.',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      )
                    : ListView.separated(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.only(bottom: 16),
                        itemCount: filteredCountries.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final country = filteredCountries[index];

                          return ElevatedButton(
                            onPressed: state.isLoading
                                ? null
                                : () => _selectCountry(context, country),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.purple,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor:
                                  AppColors.purple.withOpacity(.45),
                              minimumSize: const Size.fromHeight(54),
                            ),
                            child: Text('${country.flagEmoji}  ${country.name}'),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
