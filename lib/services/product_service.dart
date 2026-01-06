import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/product_model.dart';

class ProductService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'products';

  /// Seed comprehensive Vietnamese coffee menu to Firestore
  static Future<void> seedVietnameseCoffeeMenu() async {
    try {
      final snapshot = await _firestore.collection(_collection).get();

      // Only seed if collection is empty
      if (snapshot.docs.isNotEmpty) {
        debugPrint('Products already exist. Skipping seed.');
        return;
      }

      debugPrint('Seeding Vietnamese coffee menu...');

      // Define products by category
      final productsToSeed = [
        // Cà phê truyền thống (2 món)
        Product(
          id: 'den-da',
          name: 'Đen đá',
          description: 'Cà phê đen truyền thống pha phin, hương vị đậm đà',
          price: 15000,
          imageUrl: 'assets/images/coffee1.png',
          rating: 4.5,
          category: 'traditional',
        ),
        Product(
          id: 'sua-da',
          name: 'Sữa đá',
          description: 'Cà phê sữa đá thơm ngon, ngọt nhẹ',
          price: 18000,
          imageUrl: 'assets/images/coffee2.png',
          rating: 4.7,
          category: 'traditional',
        ),

        // Cà phê sữa & béo (1 món)
        Product(
          id: 'bac-xiu',
          name: 'Bạc xỉu',
          description: 'Cà phê sữa thơm béo, ít đắng',
          price: 20000,
          imageUrl: 'assets/images/coffee3.png',
          rating: 4.6,
          category: 'milk',
        ),

        // Cà phê Ý - Espresso (4 món)
        Product(
          id: 'espresso',
          name: 'Espresso',
          description: 'Cà phê Ý nguyên chất, đậm đà',
          price: 35000,
          imageUrl: 'assets/images/coffee4.png',
          rating: 4.8,
          category: 'espresso',
        ),
        Product(
          id: 'americano',
          name: 'Americano',
          description: 'Espresso pha loãng, vị nhẹ nhàng',
          price: 38000,
          imageUrl: 'assets/images/coffee1.png',
          rating: 4.5,
          category: 'espresso',
        ),
        Product(
          id: 'cappuccino',
          name: 'Cappuccino',
          description: 'Espresso với sữa tươi và foam mịn',
          price: 45000,
          imageUrl: 'assets/images/coffee2.png',
          rating: 4.9,
          category: 'espresso',
        ),
        Product(
          id: 'latte',
          name: 'Latte',
          description: 'Cà phê sữa Ý, béo ngậy thơm lừng',
          price: 48000,
          imageUrl: 'assets/images/coffee3.png',
          rating: 4.8,
          category: 'espresso',
        ),

        // Cà phê đặc biệt (3 món)
        Product(
          id: 'cold-brew',
          name: 'Cold Brew',
          description: 'Cà phê ủ lạnh, vị êm mượt',
          price: 42000,
          imageUrl: 'assets/images/coffee4.png',
          rating: 4.7,
          category: 'special',
        ),
        Product(
          id: 'ca-phe-trung',
          name: 'Cà phê trứng',
          description: 'Cà phê trứng Hà Nội đặc biệt',
          price: 35000,
          imageUrl: 'assets/images/coffee1.png',
          rating: 4.9,
          category: 'special',
        ),
        Product(
          id: 'da-xay',
          name: 'Đá xay',
          description: 'Cà phê đá xay mát lạnh, sảng khoái',
          price: 40000,
          imageUrl: 'assets/images/coffee2.png',
          rating: 4.6,
          category: 'special',
        ),
      ];

      // Batch write for efficiency
      final batch = _firestore.batch();
      for (var product in productsToSeed) {
        final docRef = _firestore.collection(_collection).doc(product.id);
        batch.set(docRef, product.toMap());
      }
      await batch.commit();

      debugPrint('Successfully seeded ${productsToSeed.length} products!');
      debugPrint('Breakdown:');
      debugPrint('- Cà phê truyền thống: 2');
      debugPrint('- Cà phê sữa & béo: 1');
      debugPrint('- Cà phê Ý (Espresso): 4');
      debugPrint('- Cà phê đặc biệt: 3');
    } catch (e) {
      debugPrint('Error seeding products: $e');
      rethrow;
    }
  }

  // Get products stream
  static Stream<List<Product>> getProducts() {
    return _firestore.collection(_collection).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return Product.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  // Get products by category
  static Stream<List<Product>> getProductsByCategory(String category) {
    return _firestore
        .collection(_collection)
        .where('category', isEqualTo: category)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return Product.fromMap(doc.data(), doc.id);
          }).toList();
        });
  }

  // Add new product
  static Future<void> addProduct(Product product) async {
    await _firestore.collection(_collection).add(product.toMap());
  }

  // Update product
  static Future<void> updateProduct(String id, Product product) async {
    await _firestore.collection(_collection).doc(id).update(product.toMap());
  }

  // Delete product
  static Future<void> deleteProduct(String id) async {
    await _firestore.collection(_collection).doc(id).delete();
  }
}
