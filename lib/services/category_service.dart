import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/category_model.dart';

class CategoryService {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  static const String _collectionName = 'categories';

  // Cache categories
  List<CategoryModel>? _cachedCategories;
  DateTime? _lastFetchTime;
  static const Duration _cacheDuration = Duration(hours: 1);

  /// Keep old category documents readable until their IDs are migrated.
  /// A canonical document always wins, including when it is hidden.
  @visibleForTesting
  static List<CategoryModel> visibleCategories(
    Iterable<CategoryModel> documents,
  ) {
    final byKey = <String, List<CategoryModel>>{};
    final validKey = RegExp(r'^[a-z][a-z0-9-]{1,39}$');
    for (final category in documents) {
      if (validKey.hasMatch(category.name)) {
        byKey.putIfAbsent(category.name, () => []).add(category);
      }
    }

    final visible = <CategoryModel>[];
    for (final group in byKey.values) {
      final canonical = group.where((category) => category.id == category.name);
      final category = canonical.isNotEmpty
          ? canonical.single
          : group.length == 1
          ? group.single
          : null;
      if (category != null && category.isActive) visible.add(category);
    }
    visible.sort((a, b) => a.order.compareTo(b.order));
    return visible;
  }

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
      final documents = querySnapshot.docs
          .map((doc) {
            try {
              final category = CategoryModel.fromFirestore(doc.data(), doc.id);
              return category;
            } catch (e) {
              debugPrint('Error parsing category ${doc.id}: $e');
              return null;
            }
          })
          .where((category) => category != null)
          .cast<CategoryModel>()
          .toList();
      final categories = visibleCategories(documents);

      debugPrint('Filtered to ${categories.length} active categories');

      // Update cache
      _cachedCategories = categories;
      _lastFetchTime = DateTime.now();

      return categories;
    } catch (e) {
      debugPrint('Error fetching categories: $e');
      if (!forceRefresh && _cachedCategories != null) {
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
          id: 'traditional',
          name: 'traditional',
          displayName: 'Cà phê truyền thống',
          order: 1,
        ),
        CategoryModel(
          id: 'milk',
          name: 'milk',
          displayName: 'Cà phê sữa & béo',
          order: 2,
        ),
        CategoryModel(
          id: 'espresso',
          name: 'espresso',
          displayName: 'Cà phê Ý (Espresso)',
          order: 3,
        ),
        CategoryModel(
          id: 'special',
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
