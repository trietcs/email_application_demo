import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Collection references
  CollectionReference get usersCollection => _db.collection('users');

  // Tạo profile người dùng trong Firestore
  Future<void> createUserProfile({
    required User user,
    required String phoneNumber,
    String? displayName,
  }) async {
    try {
      await usersCollection.doc(user.uid).set({
        'phoneNumber': phoneNumber,
        'displayName': displayName ?? '',
        'email': user.email ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error creating user profile: ${e.toString()}');
      throw e;
    }
  }
}
