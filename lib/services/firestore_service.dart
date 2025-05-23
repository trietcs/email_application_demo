import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  CollectionReference get usersCollection => _db.collection('users');

  Future<void> createUserProfile({
    required User user,
    required String phoneNumber,
    required String customEmail,
    String? displayName,
    String? gender,
    DateTime? dateOfBirth,
    String? photoURL,
    bool isProfileFullyCompleted = false,
  }) async {
    try {
      Timestamp? dobTimestamp =
          dateOfBirth != null ? Timestamp.fromDate(dateOfBirth) : null;
      Map<String, dynamic> profileData = {
        'uid': user.uid,
        'phoneNumber': phoneNumber,
        'customEmail': customEmail,
        'authEmail': user.email,
        'displayName': displayName ?? '',
        'gender': gender,
        'dateOfBirth': dobTimestamp,
        'photoURL': photoURL,
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (isProfileFullyCompleted) {
        profileData['profileCompletedAt'] = FieldValue.serverTimestamp();
      }

      await usersCollection
          .doc(user.uid)
          .set(profileData, SetOptions(merge: true));
      print(
        'FirestoreService: User profile created/updated for UID ${user.uid}',
      );
    } catch (e) {
      print('Error creating/updating user profile: $e');
      throw e;
    }
  }

  Future<void> updateUserProfile(
    String userId, {
    String? displayName,
    String? gender,
    DateTime? dateOfBirth,
    String? photoURL,
  }) async {
    try {
      Map<String, dynamic> dataToUpdate = {};
      if (displayName != null) dataToUpdate['displayName'] = displayName;
      if (gender != null) dataToUpdate['gender'] = gender;
      if (dateOfBirth != null)
        dataToUpdate['dateOfBirth'] = Timestamp.fromDate(dateOfBirth);
      if (photoURL != null) dataToUpdate['photoURL'] = photoURL;

      if (dataToUpdate.isNotEmpty) {
        dataToUpdate['updatedAt'] = FieldValue.serverTimestamp();
        await usersCollection.doc(userId).update(dataToUpdate);
        print(
          'FirestoreService: User profile updated for UID $userId with data: $dataToUpdate',
        );
      }
    } catch (e) {
      print('Error updating user profile for UID $userId: $e');
      throw e;
    }
  }

  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      DocumentSnapshot doc = await usersCollection.doc(userId).get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Error getting user profile: $e');
      return null;
    }
  }

  Future<String?> getEmailForPhoneNumber(String e164PhoneNumber) async {
    try {
      final docSnapshot =
          await _db
              .collection('phoneNumberToEmailLookup')
              .doc(e164PhoneNumber)
              .get();
      if (docSnapshot.exists) {
        return docSnapshot.data()?['customEmail'] as String?;
      }
      return null;
    } catch (e) {
      print(
        'Error fetching email for phone number $e164PhoneNumber from lookup: $e',
      );
      if (e is FirebaseException && e.code == 'permission-denied') {
        print(
          'PERMISSION DENIED while fetching from phoneNumberToEmailLookup. Check rules.',
        );
      }
      return null;
    }
  }

  Future<Map<String, String>?> findUserByContactInfo(String contactInfo) async {
    try {
      String emailToFind = contactInfo;
      if (!contactInfo.contains('@')) {
        emailToFind = '$contactInfo@tvamail.com';
      }

      final snapshot =
          await usersCollection
              .where('customEmail', isEqualTo: emailToFind)
              .limit(1)
              .get();
      if (snapshot.docs.isEmpty) return null;

      final userDoc = snapshot.docs.first;
      final userData = userDoc.data() as Map<String, dynamic>?;
      if (userData == null) return null;

      return {
        'userId': userDoc.id,
        'displayName': userData['displayName'] as String? ?? '',
      };
    } catch (e) {
      print('Error finding user by contactInfo ($contactInfo): $e');
      return null;
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
      return snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
    } catch (e) {
      print('Error getting emails for folder $folder: $e');
      return [];
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

  Future<void> deleteEmail({
    required String userId,
    required String emailId,
    String? targetFolder,
  }) async {
    try {
      if (targetFolder == 'trash') {
        final emailRef = usersCollection
            .doc(userId)
            .collection('userEmails')
            .doc(emailId);
        final emailData = (await emailRef.get()).data();
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
