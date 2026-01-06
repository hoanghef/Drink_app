import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/category_model.dart';

class CategoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'categories';

  // Cache categories
  List<CategoryModel>? _cachedCategories;
  DateTime? _lastFetchTime;
  static const Duration _cacheDuration = Duration(hours: 1);

  /// Fetch all active categories from Firestore
  Future<List<CategoryModel>> getCategories({bool forceRefresh = false}) async {
    try {
      // Return cached data if valid
      if (!forceRefresh &&
          _cachedCategories != null &&
          _lastFetchTime != null &&
          DateTime.now().difference(_lastFetchTime!) < _cacheDuration) {
        debugPrint('Returning cached categories');
        return _cachedCategories!;
      }

      debugPrint('Fetching categories from Firestore...');

      // Fetch from Firestore - simple query, sort in memory
      final querySnapshot = await _firestore.collection(_collectionName).get();

      debugPrint('Got ${querySnapshot.docs.length} category documents');

      // Filter and map
      final categories = querySnapshot.docs
          .map((doc) {
            try {
              final category = CategoryModel.fromFirestore(doc.data(), doc.id);
              return category;
            } catch (e) {
              debugPrint('Error parsing category ${doc.id}: $e');
              return null;
            }
          })
          .where((category) => category != null && category.isActive)
          .cast<CategoryModel>()
          .toList();

      // Sort by order
      categories.sort((a, b) => a.order.compareTo(b.order));

      debugPrint('Filtered to ${categories.length} active categories');

      // Update cache
      _cachedCategories = categories;
      _lastFetchTime = DateTime.now();

      return categories;
    } catch (e) {
      debugPrint('Error fetching categories: $e');
      if (_cachedCategories != null) {
        debugPrint('Returning cached categories due to error');
        return _cachedCategories!;
      }
      rethrow;
    }
  }

  /// Initialize default categories
  Future<void> initializeDefaultCategories() async {
    try {
      final snapshot = await _firestore.collection(_collectionName).get();
      if (snapshot.docs.isNotEmpty) {
        debugPrint('Categories already initialized');
        return;
      }

      final defaultCategories = [
        CategoryModel(
          id: 'ca-phe-truyen-thong',
          name: 'traditional',
          displayName: 'Cà phê truyền thống',
          order: 1,
        ),
        CategoryModel(
          id: 'ca-phe-sua-beo',
          name: 'milk',
          displayName: 'Cà phê sữa & béo',
          order: 2,
        ),
        CategoryModel(
          id: 'ca-phe-y',
          name: 'espresso',
          displayName: 'Cà phê Ý (Espresso)',
          order: 3,
        ),
        CategoryModel(
          id: 'ca-phe-dac-biet',
          name: 'special',
          displayName: 'Cà phê đặc biệt',
          order: 4,
        ),
      ];

      final batch = _firestore.batch();
      for (final category in defaultCategories) {
        final docRef = _firestore.collection(_collectionName).doc(category.id);
        batch.set(docRef, category.toFirestore());
      }
      await batch.commit();

      debugPrint('Initialized ${defaultCategories.length} categories');
    } catch (e) {
      debugPrint('Error initializing categories: $e');
      rethrow;
    }
  }

  /// Clear cache
  void clearCache() {
    _cachedCategories = null;
    _lastFetchTime = null;
  }
}
