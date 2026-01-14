import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/location_model.dart';
import '../services/location_service.dart';

class LocationProvider extends ChangeNotifier {
  final LocationService _locationService = LocationService();

  String _currentCity = 'Ha Noi, Viet Nam';
  String _detailedAddress = '';
  List<LocationModel> _availableLocations = [];
  bool _isLoading = false;
  String? _errorMessage;

  String get currentCity => _currentCity;
  String get detailedAddress => _detailedAddress;
  List<LocationModel> get availableLocations => _availableLocations;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Full address for display (city + detailed address)
  String get fullAddress {
    if (_detailedAddress.isEmpty) {
      return _currentCity;
    }
    return '$_detailedAddress, $_currentCity';
  }

  LocationProvider() {
    _loadAddress();
    loadAvailableLocations();
  }

  Future<void> _loadAddress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentCity = prefs.getString('delivery_city') ?? 'Ha Noi, Viet Nam';
      _detailedAddress = prefs.getString('delivery_detailed_address') ?? '';
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading address: $e');
    }
  }

  /// Load available locations from Firestore
  Future<void> loadAvailableLocations({bool forceRefresh = false}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _availableLocations = await _locationService.getLocations(
        forceRefresh: forceRefresh,
      );
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Không thể tải danh sách địa điểm';
      _isLoading = false;
      debugPrint('Error loading available locations: $e');
      notifyListeners();
    }
  }

  /// Initialize default locations in Firestore (one-time setup)
  Future<void> initializeLocations() async {
    try {
      await _locationService.initializeDefaultLocations();
      await loadAvailableLocations(forceRefresh: true);
    } catch (e) {
      debugPrint('Error initializing locations: $e');
      rethrow;
    }
  }

  Future<void> setCity(String city) async {
    _currentCity = city;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('delivery_city', city);
    } catch (e) {
      debugPrint('Error saving city: $e');
    }
  }

  Future<void> setDetailedAddress(String address) async {
    _detailedAddress = address;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('delivery_detailed_address', address);
    } catch (e) {
      debugPrint('Error saving detailed address: $e');
    }
  }

  // For backward compatibility with old setAddress method
  Future<void> setAddress(String address) async {
    await setCity(address);
  }

  // Getter for backward compatibility (used in HomeScreen)
  String get currentAddress => _currentCity;
}
