import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  CollectionReference get usersCollection => _db.collection('users');

  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final docSnapshot = await usersCollection.doc(userId).get();
      if (docSnapshot.exists) {
        return docSnapshot.data() as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      print('Error getting user profile for $userId: $e');
      return null;
    }
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> getUserProfileDoc(
    String userId,
  ) async {
    try {
      final docSnapshot = await usersCollection.doc(userId).get();
      if (docSnapshot.exists) {
        return docSnapshot as DocumentSnapshot<Map<String, dynamic>>?;
      }
      return null;
    } catch (e) {
      print('Error getting user profile document for $userId: $e');
      return null;
    }
  }

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

  Future<String?> getEmailForPhoneNumber(String phoneNumber) async {
    try {
      final snapshot =
          await usersCollection
              .where('phoneNumber', isEqualTo: phoneNumber)
              .limit(1)
              .get();

      if (snapshot.docs.isNotEmpty) {
        final userData = snapshot.docs.first.data() as Map<String, dynamic>?;
        return userData?['customEmail'] as String?;
      }
      return null;
    } catch (e) {
      print('Error fetching email for phone number $phoneNumber: $e');
      return null;
    }
  }

  Future<Map<String, String>?> findUserByContactInfo(String contactInfo) async {
    try {
      String emailToFind = contactInfo;
      final phoneRegex = RegExp(r'^(?:\+?84|0)?\d{9,10}$');
      final numericRegex = RegExp(r'^\+?\d+$');

      if (phoneRegex.hasMatch(contactInfo) ||
          numericRegex.hasMatch(contactInfo)) {
        String e164PhoneNumber = contactInfo;
        if (contactInfo.startsWith('0')) {
          e164PhoneNumber = '+84${contactInfo.substring(1)}';
        } else if (!contactInfo.startsWith('+') && contactInfo.length == 9) {
          e164PhoneNumber = '+84$contactInfo';
        } else if (!contactInfo.startsWith('+')) {
          e164PhoneNumber = '+$contactInfo';
        }
        final userSnapshot =
            await usersCollection
                .where('phoneNumber', isEqualTo: e164PhoneNumber)
                .limit(1)
                .get();
        if (userSnapshot.docs.isNotEmpty) {
          final userDoc = userSnapshot.docs.first;
          final userData = userDoc.data() as Map<String, dynamic>?;
          if (userData != null) {
            return {
              'userId': userDoc.id,
              'displayName':
                  userData['displayName'] as String? ??
                  userData['customEmail'] as String? ??
                  e164PhoneNumber,
            };
          }
        }
        return null;
      } else {
        if (!contactInfo.contains('@')) {
          emailToFind = '$contactInfo@tvamail.com';
        } else if (!contactInfo.endsWith('@tvamail.com')) {
          return null;
        }
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
        'displayName': userData['displayName'] as String? ?? emailToFind,
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
    required List<Map<String, String>> to,
    List<Map<String, String>>? cc,
    List<Map<String, String>>? bcc,
    required String subject,
    required String body,
    List<Map<String, String>>? attachments,
  }) async {
    try {
      final emailDataForSender = {
        'from': {'userId': senderId, 'displayName': senderDisplayName},
        'to': to,
        'cc': cc ?? [],
        'bcc': bcc ?? [],
        'subject': subject,
        'body': body,
        'timestamp': FieldValue.serverTimestamp(),
        'folder': 'sent',
        'isRead': true,
        'isStarred': false,
        'attachments': attachments ?? [],
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

      for (var recipient in to) {
        if (recipient['userId'] != null && recipient['userId']!.isNotEmpty) {
          await usersCollection
              .doc(recipient['userId']!)
              .collection('userEmails')
              .add(emailDataForRecipient);
        }
      }
      if (cc != null) {
        for (var recipient in cc) {
          if (recipient['userId'] != null && recipient['userId']!.isNotEmpty) {
            await usersCollection
                .doc(recipient['userId']!)
                .collection('userEmails')
                .add(emailDataForRecipient);
          }
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
        'FirestoreService: Marked email $emailId as $isRead for user $userId',
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
      final emailRef = usersCollection
          .doc(userId)
          .collection('userEmails')
          .doc(emailId);
      final emailDoc = await emailRef.get();

      if (!emailDoc.exists) {
        print("Email $emailId does not exist for user $userId.");
        return;
      }
      final emailData = emailDoc.data();

      if (targetFolder == 'trash') {
        if (emailData != null) {
          await emailRef.update({
            'folder': 'trash',
            'timestamp': FieldValue.serverTimestamp(),
          });
          print(
            'FirestoreService: Email $emailId moved to trash for user $userId',
          );
        }
      } else {
        await emailRef.delete();
        print(
          'FirestoreService: Email $emailId permanently deleted for user $userId',
        );
      }
    } catch (e) {
      print('Error deleting email: $e');
      throw e;
    }
  }

  Future<String> saveDraft({
    required String userId,
    required String senderDisplayName,
    required List<Map<String, String>> to,
    List<Map<String, String>>? cc,
    List<Map<String, String>>? bcc,
    required String subject,
    required String body,
    List<Map<String, String>>? attachments,
  }) async {
    try {
      final draftData = {
        'from': {'userId': userId, 'displayName': senderDisplayName},
        'to': to,
        'cc': cc ?? [],
        'bcc': bcc ?? [],
        'subject': subject,
        'body': body,
        'timestamp': FieldValue.serverTimestamp(),
        'folder': 'drafts',
        'isRead': true,
        'isStarred': false,
        'attachments': attachments ?? [],
      };
      final docRef = await usersCollection
          .doc(userId)
          .collection('userEmails')
          .add(draftData);
      print(
        'FirestoreService: Draft saved successfully for user $userId with ID ${docRef.id}',
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
    required List<Map<String, String>> to,
    List<Map<String, String>>? cc,
    List<Map<String, String>>? bcc,
    required String subject,
    required String body,
    List<Map<String, String>>? attachments,
  }) async {
    try {
      final draftRef = usersCollection
          .doc(userId)
          .collection('userEmails')
          .doc(draftId);
      await draftRef.update({
        'from': {'userId': userId, 'displayName': senderDisplayName},
        'to': to,
        'cc': cc ?? [],
        'bcc': bcc ?? [],
        'subject': subject,
        'body': body,
        'timestamp': FieldValue.serverTimestamp(),
        'attachments': attachments ?? [],
      });
      print(
        'FirestoreService: Draft updated successfully for user $userId with ID $draftId',
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
      print(
        'FirestoreService: Permanently deleted email $emailId for user $userId',
      );
    } catch (e) {
      print('Error permanently deleting email: $e');
      throw e;
    }
  }
}
