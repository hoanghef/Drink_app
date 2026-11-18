import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

class UserProvider with ChangeNotifier {
  UserModel? _currentUser;
  bool _isAdmin = false;

  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  // Convenience getters
  String get fullName => _currentUser?.name ?? '';
  bool get isAdmin => _isAdmin;

  Future<void> loadUserData(String uid) async {
    try {
      final authUser = FirebaseAuth.instance.currentUser;
      if (authUser == null || authUser.uid != uid) return;
      _isAdmin =
          (await authUser.getIdTokenResult(true)).claims?['admin'] == true;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (doc.exists) {
        _currentUser = UserModel.fromMap(doc.data()!);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  void clearUser() {
    _currentUser = null;
    _isAdmin = false;
    notifyListeners();
  }
}
