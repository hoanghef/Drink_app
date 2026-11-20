import 'package:flutter/foundation.dart';
import '../models/category_model.dart';
import '../services/category_service.dart';

class CategoryProvider with ChangeNotifier {
  CategoryProvider({CategoryService? service})
    : _categoryService = service ?? CategoryService();

  final CategoryService _categoryService;

  List<CategoryModel> _categories = [];
  bool _isLoading = false;
  String? _errorMessage;
  int _loadVersion = 0;

  List<CategoryModel> get categories => _categories;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Load categories from Firestore
  Future<void> loadCategories({bool forceRefresh = false}) async {
    final version = ++_loadVersion;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final categories = await _categoryService.getCategories(
        forceRefresh: forceRefresh,
      );
      if (version != _loadVersion) return;
      _categories = categories;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      if (version != _loadVersion) return;
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
