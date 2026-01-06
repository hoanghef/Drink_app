class CategoryModel {
  final String id;
  final String name;
  final String displayName;
  final int order;
  final bool isActive;

  CategoryModel({
    required this.id,
    required this.name,
    required this.displayName,
    required this.order,
    this.isActive = true,
  });

  // Factory constructor from Firestore
  factory CategoryModel.fromFirestore(Map<String, dynamic> data, String id) {
    return CategoryModel(
      id: id,
      name: data['name'] ?? '',
      displayName: data['displayName'] ?? '',
      order: data['order'] ?? 0,
      isActive: data['isActive'] ?? true,
    );
  }

  // Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'displayName': displayName,
      'order': order,
      'isActive': isActive,
    };
  }

  @override
  String toString() => displayName;
}
