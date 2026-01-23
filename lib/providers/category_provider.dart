import 'package:flutter/foundation.dart';
import '../models/category_model.dart';
import '../services/category_service.dart';

class CategoryProvider with ChangeNotifier {
  final CategoryService _categoryService = CategoryService();

  List<CategoryModel> _categories = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<CategoryModel> get categories => _categories;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Load categories from Firestore
  Future<void> loadCategories({bool forceRefresh = false}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _categories = await _categoryService.getCategories(
        forceRefresh: forceRefresh,
      );
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Không thể tải danh mục';
      _isLoading = false;
      debugPrint('Error loading categories: $e');
      notifyListeners();
    }
  }

  /// Initialize default categories
  Future<void> initializeCategories() async {
    try {
      await _categoryService.initializeDefaultCategories();
      await loadCategories(forceRefresh: true);
    } catch (e) {
      debugPrint('Error initializing categories: $e');
      rethrow;
    }
  }

  /// Clear cache
  void clearCache() {
    _categoryService.clearCache();
  }
}
