import 'package:cloud_firestore/cloud_firestore.dart';

abstract class FavoritesStore {
  Future<List<String>> load(String uid);
  Future<void> save(String uid, List<String> productIds);
}

class FirestoreFavoritesStore implements FavoritesStore {
  final FirebaseFirestore _firestore;
  FirestoreFavoritesStore({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<List<String>> load(String uid) async {
    final document = await _firestore.collection('favorites').doc(uid).get();
    final ids = document.data()?['productIds'];
    return ids is List ? ids.whereType<String>().toList() : <String>[];
  }

  @override
  Future<void> save(String uid, List<String> productIds) => _firestore
      .collection('favorites')
      .doc(uid)
      .set({'productIds': productIds});
}
