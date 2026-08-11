# Mi Lista +

## Seguimientos y notificaciones

- Los recordatorios se calculan en la zona horaria local y usan
  `America/Bogota` como respaldo cuando Android no informa una zona valida.
- Android agenda recordatorios inexactos con `inexactAllowWhileIdle`. Esta
  decision evita solicitar `SCHEDULE_EXACT_ALARM` en Android 14 y es adecuada
  para seguimientos comerciales que no requieren precision al minuto.
- Android 13 o posterior solicita permiso de notificaciones despues de mostrar
  la interfaz. El estado, la cantidad programada, la prueba y el acceso a
  ajustes estan disponibles en Configurar seguimiento.
- Los payloads tienen el formato JSON `{"v":1,"followUpId":"..."}` y son
  compatibles con los identificadores planos de versiones anteriores.

## Remote Config

El aviso de apertura utiliza `startup_notice_enabled`, `startup_notice_id` y
`startup_notice_image_url`. Solo acepta HTTPS, limita la descarga a 5 MB y la
imagen a 4096 px por lado, espera un maximo de ocho segundos y registra hasta
tres presentaciones por campaña e instalacion.

## Verificacion recomendada

Ejecutar `flutter test`, `flutter analyze` y una compilacion `flutter build apk
--release`. En un dispositivo real verificar permisos aceptados/rechazados,
reinicio, segundo plano, arranque desde notificacion, red lenta/sin red y
restricciones de bateria en Xiaomi/Redmi.

El arranque inicial solo abre Hive y preferencias para presentar inmediatamente
el catalogo almacenado. SQLite, sus migraciones, Firebase, Remote Config, AdMob
y las notificaciones se inicializan despues de que Home ya esta visible; una
falla de esos servicios no impide consultar precios sin Internet.

La cadena Android usa Gradle 8.14.3, Android Gradle Plugin 8.11.1 y Kotlin
2.2.20. Despues de reemplazar una version anterior, ejecutar `flutter clean`,
`flutter pub get` y `flutter run` para evitar metadatos Gradle en cache.

App Flutter online-first para consultar precios por pais, guardar catalogo local y generar simulaciones con puntos y total en dinero.

## Tecnologia recomendada

Flutter es la mejor opcion para este caso porque permite construir una interfaz muy fiel a los mockups en Android/iOS con un solo codigo, buen rendimiento visual y menor costo de mantenimiento que mantener apps nativas separadas. React Native tambien seria viable, pero Flutter da mas control de UI para pantallas densas tipo catalogo. .NET MAUI seria razonable si el equipo ya trabaja fuertemente en C#, pero el ecosistema movil y librerias visuales suele requerir mas cuidado.

## Arquitectura

- `domain`: entidades y contratos de repositorio.
- `data`: Hive/local store, Firestore remote data source y repositorio concreto.
- `presentation`: pantallas, estado global y widgets reutilizables.
- `core`: colores, errores y servicios compartidos.

La app usa Firestore como fuente online y Hive como cache local. En el primer arranque pregunta pais, guarda la seleccion y carga el catalogo. La primera vez de cada dia, si hay internet, lee `catalog_metadata/{pais}`. Solo si cambia `version`, descarga `countries/{pais}/products`.

## Configuracion Firebase

1. Crea un proyecto Firebase.
2. Agrega Android/iOS con `flutterfire configure`.
3. Copia el archivo generado `lib/firebase_options.dart`.
4. Cambia `main.dart` para usar:

```dart
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

5. Publica las reglas de `firebase/firestore.rules`.
6. Carga productos siguiendo la forma de `firebase/seed_colombia.json`.

## Estructura Firestore

```text
catalog_metadata/{countryCode}
  version: string
  updatedAt: timestamp

countries/{countryCode}/products/{productId}
  active: boolean
  countryCode: string
  name: string
  code: string
  category: nutrition | beauty | kit
  suggestedPrice: number
  points: number
  imageUrl: string
  updatedAt: timestamp
  discountPrices: map<string, number>
```

Para productos como KIT2BIMARCA2024, deja `points: 0` y `discountPrices: {}`.

## Como ejecutar

```bash
flutter create --platforms=android,ios,web --project-name mi_lista_plus .
flutter pub get
flutter run
```

El primer comando genera las carpetas nativas Android/iOS y la carpeta `web` si el proyecto se abre desde este paquete base. Revisa cualquier diff antes de aceptar reemplazos si Flutter pregunta por archivos existentes.

Para correr en Chrome:

```bash
flutter create --platforms=web .
flutter pub get
flutter run -d chrome
```

Si Firebase no esta configurado, la app abre igual con datos semilla locales de Colombia para revisar UI y flujo.

## Configuracion AdMob

La app integra `google_mobile_ads` para banners adaptativos e intersticiales. Por defecto usa IDs oficiales de prueba de Google para evitar trafico invalido durante desarrollo. Firebase Remote Config puede reemplazar esos valores sin publicar una nueva version.

Configura estos parametros en Remote Config:

| Parametro | Tipo | Predeterminado | Uso |
| --- | --- | --- | --- |
| `ads_interstitial_action_frequency` | Numero | `10` | Acciones importantes requeridas antes de intentar mostrar un intersticial. |
| `ads_interstitial_cooldown_seconds` | Numero | `180` | Espera minima entre intersticiales. |
| `ads_interstitial_unit_id_android` | Texto | Vacio | ID remoto de intersticial para Android. |
| `ads_interstitial_unit_id_ios` | Texto | Vacio | ID remoto de intersticial para iOS. |
| `ads_banner_unit_id_android` | Texto | Vacio | ID global de banner para Android. |
| `ads_banner_unit_id_ios` | Texto | Vacio | ID global de banner para iOS. |
| `ads_banner_home_enabled` | Booleano | `true` | Banner de inicio. |
| `ads_banner_simulations_enabled` | Booleano | `true` | Banner de simulaciones. |
| `ads_banner_inventory_enabled` | Booleano | `true` | Banner de inventario. |
| `ads_banner_sales_enabled` | Booleano | `true` | Banner de ventas e historial. |
| `ads_banner_customers_enabled` | Booleano | `true` | Banner al final de clientes. |
| `ads_banner_followups_enabled` | Booleano | `true` | Banner al final de seguimientos de hoy. |
| `ads_banner_deliveries_enabled` | Booleano | `true` | Banner al final de entregas por confirmar. |
| `ads_banner_backup_enabled` | Booleano | `true` | Banner de respaldo y sincronizacion. |
| `ads_banner_settings_enabled` | Booleano | `true` | Banner de configuracion de seguimiento. |

Cada ubicacion tambien acepta un ID propio con el formato `ads_banner_<ubicacion>_unit_id_android` o `ads_banner_<ubicacion>_unit_id_ios`. Por ejemplo: `ads_banner_inventory_unit_id_android`. Si queda vacio, se usa el ID global y luego el ID de prueba/compilacion como respaldo.

Las acciones importantes se cuentan solo cuando terminan correctamente: crear,
editar, cancelar o eliminar ventas; guardar inventario; registrar clientes;
completar seguimientos; confirmar entregas; y crear, compartir o importar
respaldos. Las cancelaciones de formularios y los errores no incrementan el
contador.

Cuando tengas los IDs reales, ejecuta con variables de entorno:

```bash
flutter run \
  --dart-define=ADMOB_ANDROID_BANNER_ID=ca-app-pub-xxxxxxxxxxxxxxxx/yyyyyyyyyy \
  --dart-define=ADMOB_ANDROID_INTERSTITIAL_ID=ca-app-pub-xxxxxxxxxxxxxxxx/yyyyyyyyyy \
  --dart-define=ADMOB_IOS_BANNER_ID=ca-app-pub-xxxxxxxxxxxxxxxx/yyyyyyyyyy \
  --dart-define=ADMOB_IOS_INTERSTITIAL_ID=ca-app-pub-xxxxxxxxxxxxxxxx/yyyyyyyyyy
```

Cuando generes las carpetas nativas con `flutter create`, agrega tambien el App ID de AdMob en:

- Android: `android/app/src/main/AndroidManifest.xml`, dentro de `<application>`.
- iOS: `ios/Runner/Info.plist`.

Los intersticiales se muestran con control de frecuencia remoto:

- Cada 10 acciones importantes de forma predeterminada.
- Con una espera minima predeterminada de 180 segundos entre anuncios.
- Acciones importantes: cambiar pais, terminar una simulacion, compartir/exportar una simulacion y volver al inicio despues de varios minutos.
- Al abrir "Descargo de responsabilidad", solo se intenta mostrar un intersticial la primera vez del dia.

## Como probar

1. Primer arranque: debe pedir pais y guardar la seleccion.
2. Home: categorias Nutricion/Belleza visibles y menu inferior solo de Productos.
3. Lista: busqueda por nombre/codigo y apertura de detalle.
4. Detalle: productos con descuento muestran tabla; kits muestran precio fijo.
5. Carrito: agregar/restar cantidades, seleccionar descuento y generar simulacion.
6. Simulaciones: debe aparecer la simulacion creada, permitir abrir detalle, editar y eliminar.
7. Anuncios: en desarrollo deben cargar IDs de prueba; valida banner compacto en Home, banner al final de Simulaciones e intersticiales solo despues de las reglas anteriores.
8. Edicion: abre una simulacion, selecciona Editar, vuelve a agregar productos y confirma que conserva el mismo ID.
9. Inventario: crea existencias, edita cantidades, registra ventas y confirma que no permite superar el stock.
10. Obsequios: registra un producto como obsequio y confirma venta en cero, costo positivo y ganancia negativa.
11. Historial: cambia de mes y valida ventas, puntos, ganancias y producto mas vendido.
12. Detalle de venta: valida productos, valores historicos, puntos y resumen financiero.
13. Edicion: reduce y aumenta cantidades, comprobando que el inventario se compense.
14. Cancelacion: confirma que devuelve existencias y deja de sumar en las metricas.
15. Eliminacion: confirma que una venta completada devuelve existencias y una cancelada no las duplica.
16. Selector de venta: confirma que el formulario inicia sin productos, permite
    seleccionar varios desde el buscador y solo muestra los elegidos.
17. Edicion de venta: valida que el selector excluya productos ya agregados y
    que permita usar el inventario actual mas las unidades de la venta original.
18. Dinero recibido: al editar una venta, cambia cantidades, agrega, elimina o
    marca un obsequio y confirma que el campo se recalcula automaticamente.
19. Conversion: abre una simulacion con stock suficiente, conviertela en venta
    y confirma el descuento de inventario y el bloqueo de una segunda conversion.
20. Inventario insuficiente: intenta convertir una simulacion sin stock y
    comprueba que se indiquen productos requeridos y cantidades disponibles.
21. Ordenamiento de inventario: valida existencias, A-Z, Z-A, precios, puntos y
    relacion costo por punto tanto en el resumen como en el editor.
22. Migracion: instala sobre una version con datos Hive y confirma que inventario,
    ventas y simulaciones conservan cantidades y totales. El archivo Hive permanece
    intacto y se crea una copia antes de activar SQLite.
23. Clientes: crea un cliente con indicativo separado, consentimiento, objetivo y
    cumpleaños; edita, pausa, reactiva, archiva y revoca su consentimiento.
24. Entrega: registra una venta pendiente, abre Clientes > Entregas y confirma la
    recepcion. Valida que solo entonces aparezcan seguimientos D+1, D+3 y D+8.
25. Reposicion: configura dias por producto y confirma que la cantidad multiplique
    la fecha esperada. Los kits comienzan desactivados.
26. Seguimiento: abre llamada y WhatsApp, guarda notas y completa una tarea. El
    seguimiento quincenal debe crear su siguiente tarea a 15 dias.
27. Respaldo: exporta modulos con contraseña, verifica la vista previa e importa en
    Combinar y Reemplazar. Una contraseña incorrecta no debe cambiar ningun dato.
28. Sincronizacion: en el emisor genera el codigo, comparte el archivo por la opcion
    cercana del sistema y en el receptor usa Recibir datos con el mismo codigo.

## Datos locales, notificaciones y permisos

SQLite se crea en paralelo y se activa solo al terminar una transaccion que valida
stock, cantidad de ventas, totales y simulaciones. Hive se conserva como espejo de
compatibilidad durante esta etapa. Firebase sigue limitado al catalogo de productos;
clientes, ventas, movimientos y seguimientos no se envian a Firestore.

Los respaldos usan GZIP antes de AES-256-GCM. La clave se deriva con Argon2id
(19 MiB, dos iteraciones) y nunca se escribe dentro del archivo. La importacion crea
automaticamente un respaldo previo y los movimientos usan UUID para ignorar duplicados.

Despues de generar las carpetas nativas con `flutter create --platforms=android,ios .`,
agrega a `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />

<receiver
    android:exported="false"
    android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
<receiver
    android:exported="false"
    android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
    <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED" />
        <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />
    </intent-filter>
</receiver>
```

Los dos `receiver` van dentro de `<application>`. Se usan alarmas inexactas, por lo
que no se solicita el permiso de alarma exacta. En iOS la app solicita permiso de
notificaciones en el primer arranque y mantiene una ventana movil de 50 recordatorios.

En `android/app/build.gradle.kts`, activa desugaring en `compileOptions` y agrega la
dependencia requerida por las notificaciones:

```kotlin
compileOptions {
    isCoreLibraryDesugaringEnabled = true
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
```

## Mejoras futuras

- Cambiar `AppState` a Riverpod o Bloc si crecen los flujos.
- Guardar simulaciones en Firestore por usuario si se requiere cuenta.
- Agregar Firebase Authentication para respaldos multi-dispositivo.
- Usar Firebase Storage o CDN para imagenes reales de producto.
- Agregar tests de repositorio, calculo de descuentos y sincronizacion diaria.

## Cambios UI v0.2.5+7

- Dashboard de Ventas renovado con 6 KPI, progreso de puntos, ventas por categoria y Top 3.
- Dashboard de Inventario renovado con costo, ganancia potencial, salud de inventario y resumen financiero.
- Banner de Clientes movido a una posicion visible justo debajo de las pestañas Clientes / Hoy / Entregas usando `ads_banner_customers_enabled` y el mismo unit ID existente.
- Entrar a Respaldo y sincronizacion registra `backupOpened` como accion importante; sigue respetando `ads_interstitial_action_frequency` y `ads_interstitial_cooldown_seconds`.
- Plantillas de seguimiento centralizadas con emojis funcionales/neutrales y sin corazones o emojis romanticos.
- Las notificaciones Android usan un icono derivado del logo de la app, adaptado al formato monocromatico requerido por Android, y el logo de la app como icono grande.
