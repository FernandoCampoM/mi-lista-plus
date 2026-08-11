import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../state/app_scope.dart';
import 'country_screen.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String? error;
  bool loading = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    if (mounted) setState(() { loading = true; error = null; });
    try {
      final state = AppScope.of(context);
      await state.bootstrap().timeout(const Duration(seconds: 20));
      if (!mounted) return;
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(
          builder: (_) => state.selectedCountry == null
              ? const CountryScreen()
              : const HomeScreen(),
        ),
      );
    } catch (exception) {
      if (mounted) setState(() { loading = false; error = exception.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Center(
        child: error == null
            ? const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.purple),
                  SizedBox(height: 14),
                  Text('Cargando información local...'),
                ],
              )
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('No se pudieron cargar los datos locales indispensables.', textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: loading ? null : _bootstrap, child: const Text('REINTENTAR')),
                ]),
              ),
      ),
    );
  }
}
