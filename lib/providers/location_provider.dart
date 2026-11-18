import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/location_model.dart';
import '../services/location_service.dart';

class SavedAddress {
  final String id, city, detailedAddress;
  const SavedAddress(this.id, this.city, this.detailedAddress);
  String get fullAddress => '$detailedAddress, $city';
  Map<String, String> toJson() => {
    'id': id,
    'city': city,
    'detailedAddress': detailedAddress,
  };
  factory SavedAddress.fromJson(Map<String, dynamic> data) => SavedAddress(
    data['id'] as String,
    data['city'] as String,
    data['detailedAddress'] as String,
  );
}

class LocationProvider extends ChangeNotifier {
  late final LocationService _locationService = LocationService();
  String? _uid, _defaultId;
  String _draftCity = 'Ha Noi, Viet Nam';
  List<SavedAddress> _addresses = [];
  List<LocationModel> _availableLocations = [];
  bool _isLoading = false;
  String? _errorMessage;
  List<SavedAddress> get addresses => List.unmodifiable(_addresses);
  SavedAddress? get defaultAddress {
    for (final item in _addresses) {
      if (item.id == _defaultId) return item;
    }
    return null;
  }

  String get currentCity => defaultAddress?.city ?? _draftCity;
  String get detailedAddress => defaultAddress?.detailedAddress ?? '';
  String get fullAddress => defaultAddress?.fullAddress ?? currentCity;
  String get currentAddress => currentCity;
  List<LocationModel> get availableLocations => _availableLocations;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  LocationProvider({bool loadLocations = true}) {
    if (loadLocations) loadAvailableLocations();
  }

  Future<void> bindUser(String? uid) async {
    if (_uid == uid) return;
    _uid = uid;
    _addresses = [];
    _defaultId = null;
    notifyListeners();
    _draftCity = 'Ha Noi, Viet Nam';
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('addresses_$uid');
    if (_uid != uid || raw == null) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      _addresses = (data['addresses'] as List)
          .map((e) => SavedAddress.fromJson(e as Map<String, dynamic>))
          .toList();
      _defaultId = data['defaultId'] as String?;
      if (defaultAddress == null && _addresses.isNotEmpty) {
        _defaultId = _addresses.first.id;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Invalid saved address data: $e');
    }
  }

  Future<void> _save() async {
    final uid = _uid;
    if (uid == null) throw StateError('Sign in to manage addresses');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'addresses_$uid',
      jsonEncode({
        'defaultId': _defaultId,
        'addresses': _addresses.map((e) => e.toJson()).toList(),
      }),
    );
    notifyListeners();
  }

  Future<void> saveAddress(String city, String detail, {String? id}) async {
    if (_uid == null) throw StateError('Sign in to manage addresses');
    city = city.trim();
    detail = detail.trim();
    if (city.isEmpty ||
        city.length > 120 ||
        detail.isEmpty ||
        detail.length > 300) {
      throw ArgumentError('Invalid address');
    }
    final addressId =
        id ??
        List.generate(
          16,
          (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
        ).join();
    final index = _addresses.indexWhere((a) => a.id == addressId);
    final item = SavedAddress(addressId, city, detail);
    if (index < 0) {
      _addresses.add(item);
    } else {
      _addresses[index] = item;
    }
    _defaultId ??= addressId;
    await _save();
  }

  Future<void> deleteAddress(String id) async {
    _addresses.removeWhere((a) => a.id == id);
    if (_defaultId == id) {
      _defaultId = _addresses.isEmpty ? null : _addresses.first.id;
    }
    await _save();
  }

  Future<void> setDefault(String id) async {
    if (!_addresses.any((a) => a.id == id)) throw ArgumentError.value(id);
    _defaultId = id;
    await _save();
  }

  Future<void> setCity(String city) async {
    final current = defaultAddress;
    if (current != null) {
      await saveAddress(city, current.detailedAddress, id: current.id);
    } else {
      _draftCity = city;
      notifyListeners();
    }
  }

  Future<void> setDetailedAddress(String detail) async {
    await saveAddress(currentCity, detail, id: defaultAddress?.id);
  }

  Future<void> setAddress(String city) => setCity(city);
  Future<void> loadAvailableLocations({bool forceRefresh = false}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _availableLocations = await _locationService.getLocations(
        forceRefresh: forceRefresh,
      );
    } catch (e) {
      _errorMessage = 'Không thể tải danh sách địa điểm';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
