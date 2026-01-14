import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/location_model.dart';

class LocationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'locations';

  // Cache locations to reduce Firestore reads
  List<LocationModel>? _cachedLocations;
  DateTime? _lastFetchTime;
  static const Duration _cacheDuration = Duration(hours: 1);

  /// Fetch all active locations from Firestore
  /// Returns cached data if available and not expired
  Future<List<LocationModel>> getLocations({bool forceRefresh = false}) async {
    try {
      // Return cached data if valid and not forcing refresh
      if (!forceRefresh &&
          _cachedLocations != null &&
          _lastFetchTime != null &&
          DateTime.now().difference(_lastFetchTime!) < _cacheDuration) {
        debugPrint('Returning cached locations');
        return _cachedLocations!;
      }

      debugPrint('Fetching locations from Firestore...');

      // Fetch from Firestore - no filtering to maximize compatibility
      final querySnapshot = await _firestore.collection(_collectionName).get();

      debugPrint('Got ${querySnapshot.docs.length} documents from Firestore');

      // Filter, map, and sort in memory
      final locations = querySnapshot.docs
          .map((doc) {
            try {
              debugPrint('Processing document: ${doc.id}');
              final location = LocationModel.fromFirestore(doc.data(), doc.id);
              debugPrint(
                'Parsed location: ${location.displayName}, isActive: ${location.isActive}',
              );
              return location;
            } catch (e) {
              debugPrint('Error parsing document ${doc.id}: $e');
              return null;
            }
          })
          .where((location) => location != null && location.isActive)
          .cast<LocationModel>()
          .toList();

      // Sort by order in memory
      locations.sort((a, b) => a.order.compareTo(b.order));

      debugPrint('Filtered to ${locations.length} active locations');

      // Update cache
      _cachedLocations = locations;
      _lastFetchTime = DateTime.now();

      return locations;
    } catch (e) {
      debugPrint('Error fetching locations from Firestore: $e');
      // Return cached data if available, even if expired
      if (_cachedLocations != null) {
        debugPrint('Returning cached locations due to error');
        return _cachedLocations!;
      }
      rethrow;
    }
  }

  /// Stream of locations for real-time updates (optional)
  Stream<List<LocationModel>> locationsStream() {
    return _firestore
        .collection(_collectionName)
        .where('isActive', isEqualTo: true)
        .orderBy('order')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => LocationModel.fromFirestore(doc.data(), doc.id))
              .toList(),
        );
  }

  /// Initialize Firestore with default locations (one-time setup)
  /// This method will be called to populate initial data
  Future<void> initializeDefaultLocations() async {
    try {
      // Check if locations already exist
      final snapshot = await _firestore.collection(_collectionName).get();
      if (snapshot.docs.isNotEmpty) {
        debugPrint('Locations already initialized. Skipping...');
        return;
      }

      // Default locations list
      final defaultLocations = [
        LocationModel(
          id: 'ha-noi',
          name: 'Ha Noi',
          country: 'Viet Nam',
          displayName: 'Ha Noi, Viet Nam',
          order: 1,
        ),
        LocationModel(
          id: 'ho-chi-minh',
          name: 'Ho Chi Minh',
          country: 'Viet Nam',
          displayName: 'Ho Chi Minh, Viet Nam',
          order: 2,
        ),
        LocationModel(
          id: 'da-nang',
          name: 'Da Nang',
          country: 'Viet Nam',
          displayName: 'Da Nang, Viet Nam',
          order: 3,
        ),
        LocationModel(
          id: 'hai-phong',
          name: 'Hai Phong',
          country: 'Viet Nam',
          displayName: 'Hai Phong, Viet Nam',
          order: 4,
        ),
        LocationModel(
          id: 'can-tho',
          name: 'Can Tho',
          country: 'Viet Nam',
          displayName: 'Can Tho, Viet Nam',
          order: 5,
        ),
        LocationModel(
          id: 'nha-trang',
          name: 'Nha Trang',
          country: 'Viet Nam',
          displayName: 'Nha Trang, Viet Nam',
          order: 6,
        ),
        LocationModel(
          id: 'hue',
          name: 'Hue',
          country: 'Viet Nam',
          displayName: 'Hue, Viet Nam',
          order: 7,
        ),
        LocationModel(
          id: 'bien-hoa',
          name: 'Bien Hoa',
          country: 'Viet Nam',
          displayName: 'Bien Hoa, Viet Nam',
          order: 8,
        ),
      ];

      // Add each location to Firestore
      final batch = _firestore.batch();
      for (final location in defaultLocations) {
        final docRef = _firestore.collection(_collectionName).doc(location.id);
        batch.set(docRef, location.toFirestore());
      }
      await batch.commit();

      debugPrint(
        'Successfully initialized ${defaultLocations.length} locations',
      );
    } catch (e) {
      debugPrint('Error initializing default locations: $e');
      rethrow;
    }
  }

  /// Clear cache to force fresh fetch
  void clearCache() {
    _cachedLocations = null;
    _lastFetchTime = null;
  }
}
