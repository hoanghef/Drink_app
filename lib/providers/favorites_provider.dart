import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class FavoritesProvider with ChangeNotifier {
  final List<String> _favoriteProductIds = [];

  List<String> get favoriteProductIds => [..._favoriteProductIds];

  bool isFavorite(String productId) {
    return _favoriteProductIds.contains(productId);
  }

  Future<void> loadFavorites(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('favorites')
          .doc(userId)
          .get();

      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['productIds'] != null) {
          _favoriteProductIds.clear();
          _favoriteProductIds.addAll(List<String>.from(data['productIds']));
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error loading favorites: $e');
    }
  }

  Future<void> toggleFavorite(String productId, String userId) async {
    try {
      if (_favoriteProductIds.contains(productId)) {
        // Remove from favorites
        _favoriteProductIds.remove(productId);
      } else {
        // Add to favorites
        _favoriteProductIds.add(productId);
      }

      notifyListeners();

      // Sync with Firestore
      await FirebaseFirestore.instance.collection('favorites').doc(userId).set({
        'productIds': _favoriteProductIds,
      });
    } catch (e) {
      debugPrint('Error toggling favorite: $e');
    }
  }

  void clearFavorites() {
    _favoriteProductIds.clear();
    notifyListeners();
  }
}
