import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/constants/app_colors.dart';
import 'core/services/app_ad_service.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/follow_up_notification_service.dart';
import 'data/datasources/firestore_product_remote_data_source.dart';
import 'data/datasources/local_store.dart';
import 'data/datasources/operational_database.dart';
import 'data/repositories/product_repository_impl.dart';
import 'firebase_options.dart';
import 'presentation/screens/splash_screen.dart';
import 'presentation/screens/customers_screen.dart';
import 'presentation/state/app_scope.dart';
import 'presentation/state/app_state.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_CO');
  await Hive.initFlutter();

  FirebaseFirestore? firestore;
  FirebaseRemoteConfig? remoteConfig;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firestore = FirebaseFirestore.instance;
    firestore.settings = const Settings(persistenceEnabled: true);
    remoteConfig = FirebaseRemoteConfig.instance;
  } catch (_) {
    firestore = null;
    remoteConfig = null;
  }

  final preferences = await SharedPreferences.getInstance();
  final adService = AppAdService(preferences, remoteConfig: remoteConfig);
  await adService.initialize();

  final box = await Hive.openBox<String>(LocalStore.productsBoxName);
  final localStore = LocalStore(preferences, box);
  OperationalDatabase? operationalDatabase;
  try {
    operationalDatabase = await OperationalDatabase.open(localStore);
  } catch (error, stackTrace) {
    // La app continua con Hive si la copia o la validacion SQLite falla.
    debugPrint('Migracion SQLite omitida: $error\n$stackTrace');
  }
  final notificationService = FollowUpNotificationService(
    onTap: (_) => appNavigatorKey.currentState?.push(
      MaterialPageRoute<void>(builder: (_) => const CustomersScreen(initialIndex: 1)),
    ),
  );
  try {
    await notificationService.initialize();
  } catch (error) {
    debugPrint('Notificaciones no disponibles: $error');
  }
  final repository = ProductRepositoryImpl(
    localStore: localStore,
    remoteDataSource: FirestoreProductRemoteDataSource(firestore),
    connectivityService: ConnectivityService(Connectivity()),
    operationalDatabase: operationalDatabase,
  );

  runApp(MiListaPlusApp(
    state: AppState(
      repository,
      operationalDatabase: operationalDatabase,
      notificationService: notificationService,
    ),
    adService: adService,
  ));
}

class MiListaPlusApp extends StatelessWidget {
  const MiListaPlusApp({
    required this.state,
    required this.adService,
    super.key,
  });

  final AppState state;
  final AppAdService adService;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      adService: adService,
      child: MaterialApp(
        navigatorKey: appNavigatorKey,
        debugShowCheckedModeBanner: false,
        title: 'Mi Lista +',
        locale: const Locale('es', 'CO'),
        supportedLocales: const [Locale('es', 'CO')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
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
