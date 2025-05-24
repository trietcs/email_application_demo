import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:email_application/models/email_data.dart';
import 'package:email_application/services/auth_service.dart';
import 'package:email_application/services/firestore_service.dart';
import 'package:email_application/screens/emails/view_email_screen.dart';
import 'package:email_application/widgets/email_list_item.dart';
import 'package:firebase_auth/firebase_auth.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
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
          _emailsFuture = _fetchEmails(context, _currentUser!.uid, 'inbox');
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

      return EmailData(
        id: emailMap['id'] as String? ?? '',
        senderName:
            (emailMap['from'] as Map<String, dynamic>?)?['displayName']
                as String? ??
            'N/A',
        subject: emailMap['subject'] as String? ?? '(No Subject)',
        previewText: previewText,
        body: body,
        time: timeString,
        isRead: emailMap['isRead'] as bool? ?? true,
        to:
            (emailMap['to'] as List<dynamic>?)
                ?.map((e) => e as Map<String, dynamic>)
                .map(
                  (recipientMap) => {
                    'userId': recipientMap['userId'] as String? ?? '',
                    'displayName': recipientMap['displayName'] as String? ?? '',
                  },
                )
                .toList() ??
            [],
      );
    }).toList();
  }

  Future<void> _handleEmailTap(EmailData email) async {
    if (_currentUser == null || !mounted) return;

    bool wasInitiallyUnread = !email.isRead;

    final resultFromView = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ViewEmailScreen(emailData: email),
      ),
    );

    if (resultFromView == true || wasInitiallyUnread) {
      _loadEmails();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return Scaffold(
        body: const Center(child: Text('Please log in to view your inbox.')),
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => _loadEmails(),
        child: FutureBuilder<List<EmailData>>(
          future: _emailsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              print('InboxScreen FutureBuilder Error: ${snapshot.error}');
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 100),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading emails: ${snapshot.error}',
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
                children: const [
                  SizedBox(height: 100),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 60,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Your inbox is empty!',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
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
                  onTap: () => _handleEmailTap(email),
                  onReadStatusChanged: _loadEmails,
                );
              },
            );
          },
        ),
      ),
    );
  }
}
