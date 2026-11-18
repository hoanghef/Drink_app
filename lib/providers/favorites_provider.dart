import 'package:flutter/foundation.dart';
import '../services/favorites_service.dart';

class FavoritesProvider with ChangeNotifier {
  final FavoritesStore _store;
  FavoritesProvider({FavoritesStore? store})
    : _store = store ?? FirestoreFavoritesStore();

  String? _uid;
  int _generation = 0;
  List<String> _favoriteProductIds = [];
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;

  String? get uid => _uid;
  List<String> get favoriteProductIds => List.unmodifiable(_favoriteProductIds);
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  bool isFavorite(String productId) => _favoriteProductIds.contains(productId);

  void bindUser(String? uid) {
    if (_uid == uid) return;
    _uid = uid;
    _generation++;
    _favoriteProductIds = [];
    _isLoading = false;
    _isSaving = false;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> loadFavorites(String userId) async {
    bindUser(userId);
    final generation = ++_generation;
    _favoriteProductIds = [];
    _isLoading = true;
    _isSaving = false;
    _errorMessage = null;
    notifyListeners();
    try {
      final ids = await _store.load(userId);
      if (_uid != userId || generation != _generation) return;
      _favoriteProductIds = ids.toSet().toList();
    } catch (error) {
      if (_uid != userId || generation != _generation) return;
      _errorMessage = 'Không tải được món yêu thích';
      debugPrint('Error loading favorites: $error');
    } finally {
      if (_uid == userId && generation == _generation) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> toggleFavorite(String productId, String userId) async {
    if (_uid != userId || _isLoading || _isSaving || productId.isEmpty) {
      return false;
    }
    final generation = _generation;
    final next = List<String>.from(_favoriteProductIds);
    if (next.contains(productId)) {
      next.remove(productId);
    } else {
      next.add(productId);
    }
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _store.save(userId, next);
      if (_uid != userId || generation != _generation) return false;
      _favoriteProductIds = next;
      return true;
    } catch (error) {
      if (_uid == userId && generation == _generation) {
        _errorMessage = 'Không lưu được món yêu thích';
        debugPrint('Error saving favorites: $error');
      }
      return false;
    } finally {
      if (_uid == userId && generation == _generation) {
        _isSaving = false;
        notifyListeners();
      }
    }
  }

  void clearFavorites() => bindUser(null);
}
