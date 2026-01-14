class LocationModel {
  final String id;
  final String name;
  final String country;
  final String displayName;
  final bool isActive;
  final int order;

  LocationModel({
    required this.id,
    required this.name,
    required this.country,
    required this.displayName,
    this.isActive = true,
    this.order = 0,
  });

  // Factory constructor to create LocationModel from Firestore document
  factory LocationModel.fromFirestore(Map<String, dynamic> data, String id) {
    return LocationModel(
      id: id,
      name: data['name'] ?? '',
      country: data['country'] ?? 'Viet Nam',
      displayName: data['displayName'] ?? '',
      isActive: data['isActive'] ?? true,
      order: data['order'] ?? 0,
    );
  }

  // Convert LocationModel to Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'country': country,
      'displayName': displayName,
      'isActive': isActive,
      'order': order,
    };
  }

  @override
  String toString() => displayName;
}
