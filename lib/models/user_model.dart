import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String name;
  final String role;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'role': role,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    DateTime createdAtDate;
    final createdAtRaw = map['createdAt'];
    if (createdAtRaw is Timestamp) {
      createdAtDate = createdAtRaw.toDate();
    } else if (createdAtRaw is String) {
      createdAtDate = DateTime.tryParse(createdAtRaw) ?? DateTime.now();
    } else {
      createdAtDate = DateTime.now();
    }

    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      role: map['role'] ?? 'user',
      createdAt: createdAtDate,
    );
  }
}
