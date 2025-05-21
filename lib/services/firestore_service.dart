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
      print('Error creating user profile: $e');
      throw e;
    }
  }

  Future<List<Map<String, dynamic>>> getEmails(
    String userId,
    String folder,
  ) async {
    try {
      final snapshot =
          await usersCollection
              .doc(userId)
              .collection('userEmails')
              .where('folder', isEqualTo: folder)
              .orderBy('timestamp', descending: true)
              .get();
      return snapshot.docs
          .map((doc) => {...doc.data() as Map<String, dynamic>, 'id': doc.id})
          .toList();
    } catch (e) {
      print('Error getting emails for folder $folder: $e');
      return [];
    }
  }

  Future<void> updateUserProfile(String userId, {String? displayName}) async {
    try {
      Map<String, dynamic> dataToUpdate = {};
      if (displayName != null) dataToUpdate['displayName'] = displayName;
      if (dataToUpdate.isNotEmpty) {
        await usersCollection.doc(userId).update(dataToUpdate);
      }
    } catch (e) {
      print('Error updating user profile: $e');
      throw e;
    }
  }
}
