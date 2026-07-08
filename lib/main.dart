import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/constants/app_colors.dart';
import 'core/services/connectivity_service.dart';
import 'data/datasources/firestore_product_remote_data_source.dart';
import 'data/datasources/local_store.dart';
import 'data/repositories/product_repository_impl.dart';
import 'presentation/screens/splash_screen.dart';
import 'presentation/state/app_scope.dart';
import 'presentation/state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_CO');
  await Hive.initFlutter();

  FirebaseFirestore? firestore;
  try {
    await Firebase.initializeApp();
    firestore = FirebaseFirestore.instance;
    firestore.settings = const Settings(persistenceEnabled: true);
  } catch (_) {
    firestore = null;
  }

  final preferences = await SharedPreferences.getInstance();
  final box = await Hive.openBox<String>(LocalStore.productsBoxName);
  final localStore = LocalStore(preferences, box);
  final repository = ProductRepositoryImpl(
    localStore: localStore,
    remoteDataSource: FirestoreProductRemoteDataSource(firestore),
    connectivityService: ConnectivityService(Connectivity()),
  );

  runApp(MiListaPlusApp(state: AppState(repository)));
}

class MiListaPlusApp extends StatelessWidget {
  const MiListaPlusApp({required this.state, super.key});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Mi Lista +',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: AppColors.purple),
          scaffoldBackgroundColor: AppColors.surface,
          textTheme: GoogleFonts.interTextTheme(),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.green),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
