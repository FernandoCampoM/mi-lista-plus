import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/product.dart';

class CatalogMetadata {
  const CatalogMetadata({required this.version, required this.updatedAt});

  final String version;
  final DateTime updatedAt;
}

class FirestoreProductRemoteDataSource {
  FirestoreProductRemoteDataSource(this._firestore);

  final FirebaseFirestore? _firestore;

  Future<CatalogMetadata?> fetchCatalogMetadata(String countryCode) async {
    final firestore = _firestore;
    if (firestore == null) return null;

    final snapshot = await firestore
        .collection('catalog_metadata')
        .doc(countryCode)
        .get();

    if (!snapshot.exists) return null;
    final data = snapshot.data()!;
    final timestamp = data['updatedAt'];

    return CatalogMetadata(
      version: data['version'] as String? ?? '0',
      updatedAt: timestamp is Timestamp
          ? timestamp.toDate()
          : DateTime.tryParse(timestamp.toString()) ?? DateTime.now(),
    );
  }

  Future<List<Product>> fetchProducts(String countryCode) async {
    final firestore = _firestore;
    if (firestore == null) return const [];

    final snapshot = await firestore
        .collection('countries')
        .doc(countryCode)
        .collection('products')
        .where('active', isEqualTo: true)
        .orderBy('name')
        .get();

    return snapshot.docs.map((doc) => _fromFirestore(doc.id, doc.data())).toList();
  }

  Product _fromFirestore(String id, Map<String, dynamic> data) {
    final timestamp = data['updatedAt'];

    return Product(
      id: id,
      countryCode: data['countryCode'] as String,
      name: data['name'] as String,
      code: data['code'] as String? ?? id,
      category: ProductCategory.values.firstWhere(
        (item) => item.name == data['category'],
        orElse: () => ProductCategory.nutrition,
      ),
      suggestedPrice: (data['suggestedPrice'] as num).toDouble(),
      points: (data['points'] as num? ?? 0).toInt(),
      imageUrl: data['imageUrl'] as String? ?? '',
      updatedAt: timestamp is Timestamp
          ? timestamp.toDate()
          : DateTime.tryParse(timestamp.toString()) ?? DateTime.now(),
      discountPrices: (data['discountPrices'] as Map<String, dynamic>? ?? {})
          .map((key, value) => MapEntry(int.parse(key), (value as num).toDouble())),
      description: data['description'] as String?,
    );
  }
}
