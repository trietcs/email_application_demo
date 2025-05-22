import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference get usersCollection => _db.collection('users');

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

  Future<void> sendEmail({
    required String senderId,
    required String senderDisplayName,
    required List<Map<String, String>> recipients,
    required String subject,
    required String body,
  }) async {
    try {
      final emailDataForSender = {
        'from': {'userId': senderId, 'displayName': senderDisplayName},
        'to': recipients,
        'subject': subject,
        'body': body,
        'timestamp': FieldValue.serverTimestamp(),
        'folder': 'sent',
        'isRead': true,
        'isStarred': false,
        'attachments': [],
      };
      await usersCollection
          .doc(senderId)
          .collection('userEmails')
          .add(emailDataForSender);

      final emailDataForRecipient = {
        ...emailDataForSender,
        'folder': 'inbox',
        'isRead': false,
      };
      for (var recipient in recipients) {
        if (recipient['userId'] != null && recipient['userId']!.isNotEmpty) {
          await usersCollection
              .doc(recipient['userId']!)
              .collection('userEmails')
              .add(emailDataForRecipient);
        }
      }
    } catch (e) {
      print('Error sending email: $e');
      throw e;
    }
  }

  Future<void> markEmailAsRead({
    required String userId,
    required String emailId,
    required bool isRead,
  }) async {
    try {
      await usersCollection
          .doc(userId)
          .collection('userEmails')
          .doc(emailId)
          .update({'isRead': isRead});
      print(
        'FirestoreService: Đánh dấu email $emailId thành $isRead cho user $userId',
      );
    } catch (e) {
      print('Error marking email as read: $e');
      throw e;
    }
  }

  Future<Map<String, String>?> findUserByContactInfo(String contactInfo) async {
    try {
      String email = '$contactInfo@tvamail.com';
      final snapshot =
          await usersCollection.where('email', isEqualTo: email).limit(1).get();
      if (snapshot.docs.isEmpty) return null;
      final userDoc = snapshot.docs.first;
      final userData = userDoc.data() as Map<String, dynamic>?;
      if (userData == null) return null;
      return {
        'userId': userDoc.id,
        'displayName': userData['displayName'] as String? ?? '',
      };
    } catch (e) {
      print('Error finding user by contactInfo: $e');
      return null;
    }
  }

  Future<void> deleteEmail({
    required String userId,
    required String emailId,
    String? targetFolder, // 'trash' hoặc null để xóa hẳn
  }) async {
    try {
      if (targetFolder == 'trash') {
        final emailRef = usersCollection
            .doc(userId)
            .collection('userEmails')
            .doc(emailId);
        final emailData =
            (await emailRef.get()).data() as Map<String, dynamic>?;
        if (emailData != null) {
          await emailRef.delete();
          await usersCollection.doc(userId).collection('userEmails').add({
            ...emailData,
            'folder': 'trash',
            'timestamp': FieldValue.serverTimestamp(),
          });
        }
      } else {
        await usersCollection
            .doc(userId)
            .collection('userEmails')
            .doc(emailId)
            .delete();
      }
      print(
        'FirestoreService: Email $emailId đã được ${targetFolder == 'trash' ? 'chuyển vào thùng rác' : 'xóa'} cho user $userId',
      );
    } catch (e) {
      print('Error deleting email: $e');
      throw e;
    }
  }

  Future<String> saveDraft({
    required String userId,
    required String senderDisplayName,
    required List<Map<String, String>> recipients,
    required String subject,
    required String body,
  }) async {
    try {
      final draftData = {
        'from': {'userId': userId, 'displayName': senderDisplayName},
        'to': recipients,
        'subject': subject,
        'body': body,
        'timestamp': FieldValue.serverTimestamp(),
        'folder': 'drafts',
        'isRead': true,
        'isStarred': false,
        'attachments': [],
      };
      final docRef = await usersCollection
          .doc(userId)
          .collection('userEmails')
          .add(draftData);
      print(
        'FirestoreService: Lưu nháp thành công cho user $userId với ID ${docRef.id}',
      );
      return docRef.id;
    } catch (e) {
      print('Error saving draft: $e');
      throw e;
    }
  }

  Future<void> updateDraft({
    required String userId,
    required String draftId,
    required String senderDisplayName,
    required List<Map<String, String>> recipients,
    required String subject,
    required String body,
  }) async {
    try {
      final draftRef = usersCollection
          .doc(userId)
          .collection('userEmails')
          .doc(draftId);

      await draftRef.update({
        'from': {'userId': userId, 'displayName': senderDisplayName},
        'to': recipients,
        'subject': subject,
        'body': body,
        'timestamp': FieldValue.serverTimestamp(),
        'folder': 'drafts',
        'isRead': true,
        'isStarred': false,
        'attachments': [],
      });
      print(
        'FirestoreService: Cập nhật nháp thành công cho user $userId với ID $draftId',
      );
    } catch (e) {
      print('Error updating draft: $e');
      throw e;
    }
  }

  Future<void> deleteEmailPermanently({
    required String userId,
    required String emailId,
  }) async {
    try {
      final emailRef = usersCollection
          .doc(userId)
          .collection('userEmails')
          .doc(emailId);

      await emailRef.delete();
      print('FirestoreService: Xóa vĩnh viễn email $emailId cho user $userId');
    } catch (e) {
      print('Error permanently deleting email: $e');
      throw e;
    }
  }
}
