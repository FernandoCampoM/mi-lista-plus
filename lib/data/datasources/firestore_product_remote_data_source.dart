import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/product.dart';

class CatalogMetadata {
  const CatalogMetadata({
    required this.version,
    required this.updatedAt,
    required this.productsCount,
  });

  final String version;
  final DateTime updatedAt;
  final int productsCount;
}

class FirestoreProductRemoteDataSource {
  FirestoreProductRemoteDataSource(this._firestore);

  final FirebaseFirestore? _firestore;
  bool get isAvailable => _firestore != null;

  Future<CatalogMetadata?> fetchCatalogMetadata(String countryCode) async {
    final firestore = _firestore;
    if (firestore == null) return null;

    final snapshot = await firestore
        .collection('catalog_metadata')
        .doc(countryCode)
        .get(_serverOnly);

    if (!snapshot.exists) return null;

    final data = snapshot.data()!;
    final timestamp = data['updatedAt'];

    return CatalogMetadata(
      version: data['version'] as String? ?? '0',
      updatedAt: timestamp is Timestamp
          ? timestamp.toDate()
          : DateTime.tryParse(timestamp.toString()) ?? DateTime.now(),
      productsCount: (data['productsCount'] as num? ?? 0).toInt(),
    );
  }

  Future<List<Product>> fetchProducts(String countryCode) async {
    final firestore = _firestore;
    if (firestore == null) return const [];

    final snapshot = await firestore
        .collection('countries')
        .doc(countryCode)
        .collection('products')
        .orderBy('name')
        .get(_serverOnly);

    final products = <Product>[];
    for (final doc in snapshot.docs.where((doc) => doc.data()['active'] != false)) {
      // Un documento mal formado se omite en vez de invalidar todo el catálogo.
      try {
        products.add(_fromFirestore(doc.id, doc.data()));
      } catch (error) {
        developer.log(
          'Producto remoto omitido por formato inválido: ${doc.id}',
          name: 'mi_lista_plus.catalog',
          error: error,
        );
      }
    }
    return products;
  }

  // ── NUEVO: lectura solo desde el servidor ───────────────────────────────
  // Propósito: evitar que la caché offline de Firestore se guarde en Hive como
  //            si fuera la versión nueva del catálogo.
  // Depende de: cloud_firestore GetOptions.
  // No modifica: la persistencia de Firestore configurada en main.dart.
  static const _serverOnly = GetOptions(source: Source.server);

  Product _fromFirestore(String id, Map<String, dynamic> data) {
    final timestamp = data['updatedAt'];

    return Product(
      id: id,
      countryCode: data['countryCode'] as String? ?? 'COL',
      name: data['name'] as String? ?? '',
      code: data['code'] as String? ?? id,
      category: ProductCategory.values.firstWhere(
        (item) => item.name == data['category'],
        orElse: () => ProductCategory.nutrition,
      ),
      suggestedPrice: (data['suggestedPrice'] as num? ?? 0).toDouble(),
      points: (data['points'] as num? ?? 0).toInt(),
      imageUrl: data['imageUrl'] as String? ?? '',
      updatedAt: timestamp is Timestamp
          ? timestamp.toDate()
          : DateTime.tryParse(timestamp.toString()) ?? DateTime.now(),
      discountPrices: (data['discountPrices'] as Map<String, dynamic>? ?? {})
          .map((key, value) => MapEntry(
                int.parse(key),
                (value as num).toDouble(),
              )),
      description: data['description'] as String?,
    );
  }
}
