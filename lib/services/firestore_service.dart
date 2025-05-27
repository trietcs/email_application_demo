import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:email_application/models/email_folder.dart';
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
      if (dateOfBirth != null) {
        dataToUpdate['dateOfBirth'] = Timestamp.fromDate(dateOfBirth);
      }
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
              'email': userData['customEmail'] as String? ?? '',
            };
          }
        }
        return null;
      } else {
        if (!contactInfo.contains('@')) {
          emailToFind = '$contactInfo@tvamail.com';
        } else if (!contactInfo.endsWith('@tvamail.com')) {
          print("findUserByContactInfo: Invalid email domain for $contactInfo");
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
        'email': userData['customEmail'] as String? ?? emailToFind,
      };
    } catch (e) {
      print('Error finding user by contactInfo ($contactInfo): $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getEmails(
    String userId,
    EmailFolder folder,
  ) async {
    try {
      Query query = usersCollection
          .doc(userId)
          .collection('userEmails')
          .where('folder', isEqualTo: folder.folderName);

      query = query.orderBy('timestamp', descending: true);

      final snapshot = await query.get();
      return snapshot.docs.map<Map<String, dynamic>>((doc) {
        final data = doc.data();
        if (data is Map<String, dynamic>) {
          return {...data, 'id': doc.id};
        } else {
          return {'id': doc.id};
        }
      }).toList();
    } catch (e) {
      print('Error getting emails for folder ${folder.folderName}: $e');
      return [];
    }
  }

  Future<void> sendEmail({
    required String senderId, // UID
    required String senderDisplayName,
    required List<Map<String, String>> to,
    List<Map<String, String>>? cc,
    List<Map<String, String>>? bcc,
    required String subject,
    required String body,
    List<Map<String, String>>? attachments,
  }) async {
    try {
      final Timestamp now = Timestamp.now();

      final senderProfile = await getUserProfile(senderId);
      final senderActualEmail =
          senderProfile?['customEmail'] ?? 'unknown_sender@tvamail.com';

      final emailDataForSender = {
        'from': {
          'userId': senderId,
          'displayName': senderDisplayName,
          'email': senderActualEmail,
        },
        'to': to,
        'cc': cc ?? [],
        'bcc': bcc ?? [],
        'subject': subject,
        'body': body,
        'timestamp': now,
        'folder': EmailFolder.sent.folderName,
        'originalFolder': EmailFolder.sent.folderName,
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
        'folder': EmailFolder.inbox.folderName,
        'originalFolder': EmailFolder.inbox.folderName,
        'isRead': false,
      };

      final emailDataForToCcRecipients = Map<String, dynamic>.from(
        emailDataForRecipient,
      )..remove('bcc');

      Future<void> addEmailToRecipient(
        String recipientUserId,
        bool isBccRecipient,
      ) async {
        await usersCollection
            .doc(recipientUserId)
            .collection('userEmails')
            .add(
              isBccRecipient
                  ? emailDataForRecipient
                  : emailDataForToCcRecipients,
            );
      }

      for (var recipient in to) {
        if (recipient['userId'] != null && recipient['userId']!.isNotEmpty) {
          await addEmailToRecipient(recipient['userId']!, false);
        }
      }
      if (cc != null) {
        for (var recipient in cc) {
          if (recipient['userId'] != null && recipient['userId']!.isNotEmpty) {
            await addEmailToRecipient(recipient['userId']!, false);
          }
        }
      }
      if (bcc != null) {
        for (var recipient in bcc) {
          if (recipient['userId'] != null && recipient['userId']!.isNotEmpty) {
            await addEmailToRecipient(recipient['userId']!, true);
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
        'FirestoreService: Marked email $emailId as ${isRead ? "read" : "unread"} for user $userId',
      );
    } catch (e) {
      print('Error marking email as read: $e');
      throw e;
    }
  }

  Future<void> toggleStarStatus({
    required String userId,
    required String emailId,
    required bool newIsStarredState,
  }) async {
    try {
      await usersCollection
          .doc(userId)
          .collection('userEmails')
          .doc(emailId)
          .update({'isStarred': newIsStarredState});
      print(
        'FirestoreService: Toggled star status for email $emailId for user $userId to $newIsStarredState',
      );
    } catch (e) {
      print('Error toggling star status for $emailId: $e');
      throw e;
    }
  }

  Future<List<Map<String, dynamic>>> getStarredEmails(String userId) async {
    try {
      final query = usersCollection
          .doc(userId)
          .collection('userEmails')
          .where('isStarred', isEqualTo: true)
          .orderBy('timestamp', descending: true);

      print(
        'FirestoreService: Executing query for starred emails for user $userId...',
      );
      final snapshot = await query.get();

      print(
        'FirestoreService: Starred emails query snapshot size: ${snapshot.size}',
      );
      if (snapshot.size > 0) {
        snapshot.docs.forEach((doc) {
          print(
            'FirestoreService: Starred Doc ID: ${doc.id}, Data: ${doc.data()}',
          );
        });
      }

      return snapshot.docs.map<Map<String, dynamic>>((doc) {
        final data = doc.data();
        if (data is Map<String, dynamic>) {
          return {...data, 'id': doc.id};
        } else {
          return {'id': doc.id};
        }
      }).toList();
    } catch (e) {
      print('Error getting starred emails for user $userId: $e');
      return [];
    }
  }

  Future<void> deleteEmail({
    required String userId,
    required String emailId,
    required EmailFolder currentFolder,
    required EmailFolder targetFolder,
  }) async {
    try {
      final emailRef = usersCollection
          .doc(userId)
          .collection('userEmails')
          .doc(emailId);
      final emailDoc = await emailRef.get();

      if (!emailDoc.exists) {
        print("Email $emailId does not exist for user $userId to delete/move.");
        return;
      }

      final String actualCurrentFolderFromDoc =
          (emailDoc.data() as Map<String, dynamic>?)?['folder'] ??
          currentFolder.folderName;

      if (targetFolder == EmailFolder.trash) {
        await emailRef.update({
          'folder': EmailFolder.trash.folderName,
          'originalFolder': actualCurrentFolderFromDoc,
          'timestamp':
              emailDoc.data()?['timestamp'] ?? FieldValue.serverTimestamp(),
        });
        print(
          'FirestoreService: Email $emailId moved to trash for user $userId from $actualCurrentFolderFromDoc.',
        );
      } else {
        await emailRef.update({
          'folder': targetFolder.folderName,
          'timestamp':
              emailDoc.data()?['timestamp'] ?? FieldValue.serverTimestamp(),
        });
        print(
          'FirestoreService: Email $emailId moved to folder ${targetFolder.folderName} for user $userId.',
        );
      }
    } catch (e) {
      print('Error deleting/moving email $emailId: $e');
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
      final senderProfile = await getUserProfile(userId);
      final senderActualEmail =
          senderProfile?['customEmail'] ?? 'unknown_draft_sender@tvamail.com';

      final draftData = {
        'from': {
          'userId': userId,
          'displayName': senderDisplayName,
          'email': senderActualEmail,
        },
        'to': to,
        'cc': cc ?? [],
        'bcc': bcc ?? [],
        'subject': subject,
        'body': body,
        'timestamp': FieldValue.serverTimestamp(),
        'folder': EmailFolder.drafts.folderName,
        'originalFolder': EmailFolder.drafts.folderName,
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
      final senderProfile = await getUserProfile(userId);
      final senderActualEmail =
          senderProfile?['customEmail'] ?? 'unknown_draft_sender@tvamail.com';

      final draftRef = usersCollection
          .doc(userId)
          .collection('userEmails')
          .doc(draftId);

      Map<String, dynamic> dataToUpdate = {
        'from': {
          'userId': userId,
          'displayName': senderDisplayName,
          'email': senderActualEmail,
        },
        'to': to,
        'cc': cc ?? [],
        'bcc': bcc ?? [],
        'subject': subject,
        'body': body,
        'timestamp': FieldValue.serverTimestamp(),
        'attachments': attachments ?? [],
      };

      await draftRef.update(dataToUpdate);
      print(
        'FirestoreService: Draft updated successfully for user $userId with ID $draftId',
      );
    } catch (e) {
      print('Error updating draft $draftId: $e');
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
      print('Error permanently deleting email $emailId: $e');
      throw e;
    }
  }
}
