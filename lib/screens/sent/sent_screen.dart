import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:email_application/models/email_data.dart';
import 'package:email_application/services/auth_service.dart';
import 'package:email_application/services/firestore_service.dart';
import 'package:email_application/screens/emails/view_email_screen.dart';
import 'package:email_application/widgets/email_list_item.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:email_application/config/app_colors.dart';

class SentScreen extends StatefulWidget {
  const SentScreen({super.key});

  @override
  State<SentScreen> createState() => _SentScreenState();
}

class _SentScreenState extends State<SentScreen> {
  late Future<List<EmailData>> _emailsFuture;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = Provider.of<AuthService>(context, listen: false).currentUser;
    _loadEmails();
  }

  void _loadEmails() {
    if (_currentUser != null) {
      if (mounted) {
        setState(() {
          _emailsFuture = _fetchEmails(context, _currentUser!.uid, 'sent');
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _emailsFuture = Future.value([]);
        });
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newUser = Provider.of<User?>(context);
    if (newUser != _currentUser) {
      _currentUser = newUser;
      _loadEmails();
    }
  }

  Future<List<EmailData>> _fetchEmails(
    BuildContext context,
    String userId,
    String folder,
  ) async {
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );
    final emailsData = await firestoreService.getEmails(userId, folder);

    if (!mounted) return [];

    return emailsData.map((emailMap) {
      Timestamp? timestamp = emailMap['timestamp'] as Timestamp?;
      String timeString = 'N/A';
      if (timestamp != null) {
        try {
          timeString = timestamp.toDate().toLocal().toString();
        } catch (e) {
          print(
            "Error converting timestamp: $e for email ID ${emailMap['id']}",
          );
        }
      }

      String body = emailMap['body'] as String? ?? '';
      String previewText =
          body.length > 50 ? '${body.substring(0, 50)}...' : body;

      String primaryRecipientDisplayName = 'Unknown Recipient';
      String primaryRecipientUserIdForAvatarLookup = '';

      final toList = emailMap['to'] as List<dynamic>?;
      if (toList != null && toList.isNotEmpty) {
        final firstTo = toList[0] as Map<String, dynamic>?;
        if (firstTo != null) {
          primaryRecipientDisplayName =
              firstTo['displayName'] as String? ??
              (firstTo['userId'] as String? ?? 'Unknown Recipient');
          primaryRecipientUserIdForAvatarLookup =
              firstTo['userId'] as String? ?? '';
        }
      }

      if (primaryRecipientDisplayName == 'Unknown Recipient' ||
          primaryRecipientDisplayName.isEmpty) {
        final ccList = emailMap['cc'] as List<dynamic>?;
        if (ccList != null && ccList.isNotEmpty) {
          final firstCc = ccList[0] as Map<String, dynamic>?;
          if (firstCc != null) {
            primaryRecipientDisplayName =
                firstCc['displayName'] as String? ??
                (firstCc['userId'] as String? ?? 'Unknown Recipient');
            primaryRecipientUserIdForAvatarLookup =
                firstCc['userId'] as String? ?? '';
          }
        } else {
          final bccList = emailMap['bcc'] as List<dynamic>?;
          if (bccList != null && bccList.isNotEmpty) {
            final firstBcc = bccList[0] as Map<String, dynamic>?;
            if (firstBcc != null) {
              primaryRecipientDisplayName =
                  firstBcc['displayName'] as String? ??
                  (firstBcc['userId'] as String? ?? 'Unknown Recipient');
              primaryRecipientUserIdForAvatarLookup =
                  firstBcc['userId'] as String? ?? '';
            }
          }
        }
      }

      if (primaryRecipientDisplayName.isEmpty) {
        primaryRecipientDisplayName =
            emailMap['subject'] as String? ?? '(No Subject)';
      }
      if (primaryRecipientDisplayName.isEmpty) {
        primaryRecipientDisplayName = '(No Recipient or Subject)';
      }

      return EmailData(
        id: emailMap['id'] as String? ?? '',
        senderName: primaryRecipientDisplayName,
        senderEmail: primaryRecipientUserIdForAvatarLookup,
        subject: emailMap['subject'] as String? ?? '(No Subject)',
        previewText: previewText,
        body: body,
        time: timeString,
        isRead: true,
        to:
            (emailMap['to'] as List<dynamic>?)
                ?.map((e) => Map<String, String>.from(e as Map? ?? {}))
                .toList() ??
            [],
        cc:
            (emailMap['cc'] as List<dynamic>?)
                ?.map((e) => Map<String, String>.from(e as Map? ?? {}))
                .toList() ??
            [],
        bcc:
            (emailMap['bcc'] as List<dynamic>?)
                ?.map((e) => Map<String, String>.from(e as Map? ?? {}))
                .toList() ??
            [],
        attachments:
            (emailMap['attachments'] as List<dynamic>?)
                ?.map((e) => Map<String, String>.from(e as Map? ?? {}))
                .toList() ??
            [],
        folder: emailMap['folder'] as String? ?? folder,
      );
    }).toList();
  }

  Future<void> _handleEmailTap(EmailData email) async {
    if (!mounted) return;
    final resultFromView = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ViewEmailScreen(emailData: email),
      ),
    );
    if (resultFromView == true) {
      _loadEmails();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return Scaffold(
        body: const Center(
          child: Text('Please log in to view your sent emails.'),
        ),
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => _loadEmails(),
        color: AppColors.primary,
        child: FutureBuilder<List<EmailData>>(
          future: _emailsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }

            if (snapshot.hasError) {
              print('SentScreen FutureBuilder Error: ${snapshot.error}');
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: AppColors.error,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading sent emails: ${snapshot.error}',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Pull down to try again.',
                          style: TextStyle(fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            final emails = snapshot.data ?? [];
            if (emails.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.outbox_outlined,
                          size: 60,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No emails in Sent folder!',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            return ListView.builder(
              itemCount: emails.length,
              itemBuilder: (context, index) {
                final email = emails[index];
                return EmailListItem(
                  email: email,
                  isSentItem: true,
                  onTap: () => _handleEmailTap(email),
                  onReadStatusChanged: null,
                  onDeleteOrMove: _loadEmails,
                );
              },
            );
          },
        ),
      ),
    );
  }
}
