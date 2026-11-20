import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

typedef AdminClaimLoader = Future<bool> Function(String uid);
typedef UserProfileLoader = Future<UserModel?> Function(String uid);

class UserProvider with ChangeNotifier {
  UserProvider({
    AdminClaimLoader? claimLoader,
    UserProfileLoader? profileLoader,
  }) : _claimLoader = claimLoader ?? _firebaseClaim,
       _profileLoader = profileLoader ?? _firestoreProfile;

  final AdminClaimLoader _claimLoader;
  final UserProfileLoader _profileLoader;
  UserModel? _currentUser;
  bool _isAdmin = false;
  String? _verifiedUid;
  int _loadVersion = 0;

  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _verifiedUid != null;

  // Convenience getters
  String get fullName => _currentUser?.name ?? '';
  bool get isAdmin => _isAdmin;

  static Future<bool> _firebaseClaim(String uid) async {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null || authUser.uid != uid) {
      throw StateError('Phiên đăng nhập đã thay đổi');
    }
    return (await authUser.getIdTokenResult(true)).claims?['admin'] == true;
  }

  static Future<UserModel?> _firestoreProfile(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    return doc.exists ? UserModel.fromMap(doc.data()!) : null;
  }

  Future<void> loadUserData(String uid) async {
    final version = ++_loadVersion;
    _currentUser = null;
    _isAdmin = false;
    _verifiedUid = null;
    notifyListeners();
    try {
      final admin = await _claimLoader(uid);
      if (version != _loadVersion) return;
      _isAdmin = admin;
      _verifiedUid = uid;
      notifyListeners();
    } catch (e) {
      if (version == _loadVersion) rethrow;
      return;
    }
    try {
      final profile = await _profileLoader(uid);
      if (version != _loadVersion) return;
      _currentUser = profile;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading user profile: $e');
    }
  }

  void clearUser() {
    ++_loadVersion;
    _currentUser = null;
    _isAdmin = false;
    _verifiedUid = null;
    notifyListeners();
  }
}
