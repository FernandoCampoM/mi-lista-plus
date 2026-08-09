# Mi Lista +

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
| `ads_banner_sales_enabled` | Booleano | `true` | Banner de registro de ventas. |

Cada ubicacion tambien acepta un ID propio con el formato `ads_banner_<ubicacion>_unit_id_android` o `ads_banner_<ubicacion>_unit_id_ios`. Por ejemplo: `ads_banner_inventory_unit_id_android`. Si queda vacio, se usa el ID global y luego el ID de prueba/compilacion como respaldo.

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

## Mejoras futuras

- Cambiar `AppState` a Riverpod o Bloc si crecen los flujos.
- Guardar simulaciones en Firestore por usuario si se requiere cuenta.
- Agregar Firebase Authentication para respaldos multi-dispositivo.
- Usar Firebase Storage o CDN para imagenes reales de producto.
- Agregar tests de repositorio, calculo de descuentos y sincronizacion diaria.
