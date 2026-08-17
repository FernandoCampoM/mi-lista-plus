import 'dart:async';
import 'dart:developer' as developer;

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
import 'package:url_launcher/url_launcher.dart';

import 'core/constants/app_colors.dart';
import 'core/services/app_ad_service.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/follow_up_notification_service.dart';
import 'core/services/startup_notice_service.dart';
import 'data/datasources/firestore_product_remote_data_source.dart';
import 'data/datasources/local_store.dart';
import 'data/datasources/operational_database.dart';
import 'data/repositories/product_repository_impl.dart';
import 'domain/entities/country.dart';
import 'firebase_options.dart';
import 'presentation/screens/customers_screen.dart';
import 'presentation/screens/follow_up_detail_sheet.dart';
import 'presentation/screens/splash_screen.dart';
import 'presentation/state/app_scope.dart';
import 'presentation/state/app_state.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _BootstrapRoot());
}

class _BootstrapRoot extends StatefulWidget {
  const _BootstrapRoot();
  @override
  State<_BootstrapRoot> createState() => _BootstrapRootState();
}

class _BootstrapRootState extends State<_BootstrapRoot> {
  Future<_Runtime>? runtime;

  @override
  void initState() {
    super.initState();
    runtime = _createRuntimeWithLimit();
  }

  void _startRuntime() {
    setState(() => runtime = _createRuntimeWithLimit());
  }

  Future<_Runtime> _createRuntimeWithLimit() =>
      _createRuntime().timeout(const Duration(seconds: 20));

  Future<_Runtime> _createRuntime() async {
    final total = Stopwatch()..start();
    unawaited(
      initializeDateFormatting('es_CO')
          .timeout(const Duration(seconds: 2))
          .catchError((_) {}),
    );
    final hiveWatch = Stopwatch()..start();
    await Hive.initFlutter().timeout(const Duration(seconds: 8));
    final preferencesFuture = SharedPreferences.getInstance()
        .timeout(const Duration(seconds: 8));
    final boxFuture = Hive.openBox<String>(LocalStore.productsBoxName)
        .timeout(const Duration(seconds: 8));
    final preferences = await preferencesFuture;
    final box = await boxFuture;
    _timing('Hive/SharedPreferences', hiveWatch);
    final localStore = LocalStore(preferences, box);
    final notificationService = FollowUpNotificationService();

    // Inicio local-first:
    // 1) si Hive ya tiene catálogo, no esperamos red para mostrar la app;
    // 2) si no existe catálogo local, intentamos Firebase una sola vez para
    //    descargarlo y guardarlo en Hive antes de continuar.
    final startupCountryCode =
        localStore.getSelectedCountry() ?? defaultCountryCode;
    final hasLocalCatalog =
        localStore.loadProducts(startupCountryCode).isNotEmpty;

    var remoteDataSource = FirestoreProductRemoteDataSource(null);
    if (!hasLocalCatalog) {
      final firebaseWatch = Stopwatch()..start();
      try {
        await _ensureFirebaseInitialized()
            .timeout(const Duration(seconds: 6));
        final firestore = _configuredFirestore();
        remoteDataSource = FirestoreProductRemoteDataSource(firestore);
        final firstCatalogRepository = ProductRepositoryImpl(
          localStore: localStore,
          remoteDataSource: remoteDataSource,
          connectivityService: ConnectivityService(Connectivity()),
        );
        await firstCatalogRepository
            .syncProductsIfNeeded(startupCountryCode, force: true)
            .timeout(const Duration(seconds: 10));
        _timing('Primer catálogo Firebase -> Hive', firebaseWatch);
      } catch (error, stackTrace) {
        developer.log(
          'No fue posible descargar el catálogo inicial; se continuará offline.',
          name: 'mi_lista_plus.startup',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    final repository = ProductRepositoryImpl(
      localStore: localStore,
      remoteDataSource: remoteDataSource,
      connectivityService: ConnectivityService(Connectivity()),
    );
    final state = AppState(
      repository,
      notificationService: notificationService,
    );
    _timing('Runtime local listo', total);
    return _Runtime(
      state: state,
      adService: AppAdService(preferences),
      notificationService: notificationService,
      preferences: preferences,
      localStore: localStore,
      operationalDatabase: null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pending = runtime;
    if (pending == null) return const _FirstFrameApp();
    return FutureBuilder<_Runtime>(
      future: pending,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _BootstrapFailureApp(
            error: snapshot.error.toString(),
            onRetry: _startRuntime,
          );
        }
        if (!snapshot.hasData) return const _FirstFrameApp();
        final value = snapshot.data!;
        return MiListaPlusApp(
          state: value.state,
          adService: value.adService,
          notificationService: value.notificationService,
          preferences: value.preferences,
          localStore: value.localStore,
          operationalDatabase: value.operationalDatabase,
        );
      },
    );
  }
}

class _BootstrapFailureApp extends StatelessWidget {
  const _BootstrapFailureApp({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: AppColors.surface,
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.storage_outlined,
                      size: 48,
                      color: AppColors.orange,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'No se pudo abrir el almacenamiento local.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('REINTENTAR'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

class _FirstFrameApp extends StatelessWidget {
  const _FirstFrameApp();
  @override
  Widget build(BuildContext context) => const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: AppColors.surface,
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppColors.purple),
                SizedBox(height: 14),
                Text('Preparando almacenamiento local...'),
              ],
            ),
          ),
        ),
      );
}

class MiListaPlusApp extends StatefulWidget {
  const MiListaPlusApp({
    required this.state,
    required this.adService,
    this.notificationService,
    this.preferences,
    this.localStore,
    this.operationalDatabase,
    super.key,
  });

  final AppState state;
  final AppAdService adService;
  final FollowUpNotificationService? notificationService;
  final SharedPreferences? preferences;
  final LocalStore? localStore;
  final OperationalDatabase? operationalDatabase;

  @override
  State<MiListaPlusApp> createState() => _MiListaPlusAppState();
}

class _MiListaPlusAppState extends State<MiListaPlusApp> {
  StreamSubscription<String>? payloadSubscription;
  bool postHomeStarted = false;
  bool modalOpen = false;
  String? lastOpenedFollowUpId;
  final Stopwatch homeWatch = Stopwatch()..start();
  bool databaseInitializationStarted = false;

  @override
  void initState() {
    super.initState();
    widget.state.addListener(_stateChanged);
    final firstFrame = Stopwatch()..start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _timing('Primer frame Flutter', firstFrame);
      _stateChanged();
    });
    final service = widget.notificationService;
    if (service != null) {
      payloadSubscription = service.payloads.listen(_openPayload);
    }
  }

  void _stateChanged() {
    if (!widget.state.isLoading && !postHomeStarted) {
      postHomeStarted = true;
      _timing('Interfaz con datos locales', homeWatch);
      WidgetsBinding.instance.addPostFrameCallback((_) => _initializeAfterHome());
    }
  }

  Future<void> _initializeAfterHome() async {
    if (!databaseInitializationStarted) {
      databaseInitializationStarted = true;
      unawaited(_initializeOperationalDatabase());
    }
    final notifications = widget.notificationService;
    var openedFromNotification = false;
    if (notifications != null) {
      final watch = Stopwatch()..start();
      try {
        await notifications.initialize();
        await widget.state.rescheduleNotifications();
        final launchPayload = notifications.takeLaunchPayload();
        openedFromNotification = launchPayload != null;
        if (launchPayload != null) await _openPayload(launchPayload);
      } catch (error) {
        developer.log('Notificaciones no disponibles', error: error);
      }
      _timing('Notificaciones', watch);
    }
    // AdMob espera a que Remote Config esté realmente disponible.
    // Esto no toca ni bloquea el flujo local-first del catálogo.
    unawaited(_initializeRemote(openedFromNotification: openedFromNotification));
  }

  Future<void> _initializeOperationalDatabase() async {
    final localStore = widget.localStore;
    if (localStore == null) return;
    final watch = Stopwatch()..start();
    try {
      final database = await OperationalDatabase.open(localStore);
      await widget.state.attachOperationalDatabase(database);
      _timing('SQLite/migraciones en segundo plano', watch);
    } catch (error, stackTrace) {
      developer.log(
        'SQLite no disponible; el catalogo continua funcionando con Hive.',
        name: 'mi_lista_plus.storage',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _initializeRemote({required bool openedFromNotification}) async {
    final preferences = widget.preferences;
    final localStore = widget.localStore;
    if (preferences == null || localStore == null) return;
    final watch = Stopwatch()..start();
    try {
      await _ensureFirebaseInitialized()
          .timeout(const Duration(seconds: 6));
      final firestore = _configuredFirestore();
      _timing('Firebase', watch);

      // Firebase se conecta siempre después de que la UI local está disponible.
      // Al adjuntar este repositorio, cambios de país posteriores también pueden
      // descargar el catálogo aunque la aplicación haya arrancado sin caché.
      final remoteRepository = ProductRepositoryImpl(
        localStore: localStore,
        remoteDataSource: FirestoreProductRemoteDataSource(firestore),
        connectivityService: ConnectivityService(Connectivity()),
        operationalDatabase: widget.operationalDatabase,
      );
      widget.state.attachRepository(remoteRepository);

      // La UI y el catálogo ya están disponibles en este punto. Ahora sí
      // obtenemos Remote Config y, solo cuando termine correctamente,
      // habilitamos/cargamos publicidad según los parámetros de Firebase.
      await widget.adService.configureRemoteConfig(
        FirebaseRemoteConfig.instance,
      );

      var country = widget.state.selectedCountry;
      if (country == null) {
        final storedCode = localStore.getSelectedCountry();
        if (storedCode != null && widget.state.countries.isNotEmpty) {
          for (final candidate in widget.state.countries) {
            if (candidate.code == storedCode) {
              country = candidate;
              break;
            }
          }
        }
      }
      if (country != null) {
        final countryToRefresh = country;
        unawaited(remoteRepository
            .syncProductsIfNeeded(countryToRefresh.code)
            .timeout(const Duration(seconds: 8))
            .then((_) => widget.state.loadCountry(
                  countryToRefresh,
                  persist: false,
                ))
            .catchError((_) => false));
      }
      final noticeService = StartupNoticeService(
        FirebaseRemoteConfig.instance,
        preferences,
      );
      final notice = await noticeService.load(
        openedFromFollowUp: openedFromNotification || modalOpen,
      );
      if (notice != null && !modalOpen && mounted) {
        final context = appNavigatorKey.currentContext;
        if (context == null) return;
        await showDialog<void>(
          context: context,
          builder: (dialogContext) {
            final media = MediaQuery.of(dialogContext);
            final noticeWidth = media.size.width * .94;
            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 18),
              child: SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: noticeWidth,
                      maxHeight: media.size.height * .88,
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Material(
                            color: Colors.black,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: notice.linkUrl == null
                                  ? null
                                  : () async {
                                      final uri = notice.linkUrl!;
                                      if (await canLaunchUrl(uri)) {
                                        await launchUrl(
                                          uri,
                                          mode: LaunchMode.externalApplication,
                                        );
                                      }
                                    },
                              child: InteractiveViewer(
                                minScale: 1,
                                maxScale: 3,
                                child: Image.memory(
                                  notice.bytes,
                                  width: noticeWidth,
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.medium,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 8,
                          top: 8,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0x22000000)),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x55000000),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: IconButton(
                              tooltip: 'Cerrar',
                              color: Colors.black87,
                              iconSize: 24,
                              onPressed: () => Navigator.pop(dialogContext),
                              icon: const Icon(Icons.close),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
        await noticeService.markShown(notice.id);
      }
    } catch (error) {
      developer.log('Servicios remotos omitidos; se usan datos locales.', error: error);
    }
  }

  Future<void> _openPayload(String payload) async {
    final id = FollowUpNotificationService.followUpIdFromPayload(payload);
    if (id == null || modalOpen || lastOpenedFollowUpId == id) return;
    final context = appNavigatorKey.currentContext;
    if (context == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openPayload(payload));
      return;
    }
    final followUp = widget.state.followUpById(id);
    if (followUp == null) {
      await appNavigatorKey.currentState?.push(MaterialPageRoute<void>(
        builder: (_) => const CustomersScreen(initialIndex: 1),
      ));
      return;
    }
    modalOpen = true;
    lastOpenedFollowUpId = id;
    try {
      await showFollowUpDetail(context, id);
    } finally {
      modalOpen = false;
    }
  }

  @override
  void dispose() {
    widget.state.removeListener(_stateChanged);
    payloadSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppScope(
        state: widget.state,
        adService: widget.adService,
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
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.line)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.line)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.green)),
            ),
          ),
          home: const SplashScreen(),
        ),
      );
}

class _Runtime {
  const _Runtime({
    required this.state,
    required this.adService,
    required this.notificationService,
    required this.preferences,
    required this.localStore,
    required this.operationalDatabase,
  });
  final AppState state;
  final AppAdService adService;
  final FollowUpNotificationService notificationService;
  final SharedPreferences preferences;
  final LocalStore localStore;
  final OperationalDatabase? operationalDatabase;
}

Future<void> _ensureFirebaseInitialized() async {
  if (Firebase.apps.isNotEmpty) return;
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

FirebaseFirestore _configuredFirestore() {
  final firestore = FirebaseFirestore.instance;
  try {
    firestore.settings = const Settings(persistenceEnabled: true);
  } catch (_) {
    // Si Firestore ya fue utilizado, su configuración ya quedó aplicada.
  }
  return firestore;
}

void _timing(String stage, Stopwatch watch) {
  watch.stop();
  developer.log('$stage: ${watch.elapsedMilliseconds} ms', name: 'mi_lista_plus.startup');
}
