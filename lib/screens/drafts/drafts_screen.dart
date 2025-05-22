import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:email_application/models/email_data.dart';
import 'package:email_application/services/auth_service.dart';
import 'package:email_application/services/firestore_service.dart';
import 'package:email_application/screens/emails/compose_email_screen.dart';
import 'package:email_application/widgets/email_list_item.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DraftsScreen extends StatefulWidget {
  const DraftsScreen({super.key});

  @override
  State<DraftsScreen> createState() => _DraftsScreenState();
}

class _DraftsScreenState extends State<DraftsScreen> {
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
          _emailsFuture = _fetchEmails(context, _currentUser!.uid, 'drafts');
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

      String draftRecipientOrSubject = '';

      final toList = emailMap['to'] as List<dynamic>?;
      if (toList != null && toList.isNotEmpty) {
        final firstTo = toList[0] as Map<String, dynamic>?;
        draftRecipientOrSubject = firstTo?['displayName'] as String? ?? '';
      }

      if (draftRecipientOrSubject.isEmpty) {
        draftRecipientOrSubject =
            emailMap['subject'] as String? ?? '(Thư nháp không có chủ đề)';
      }
      if (draftRecipientOrSubject.isEmpty) {
        draftRecipientOrSubject = '(Thư nháp)';
      }

      return EmailData(
        id: emailMap['id'] as String? ?? '',
        senderName: 'Đến: $draftRecipientOrSubject',
        subject: emailMap['subject'] as String? ?? '(Không có chủ đề)',
        previewText: previewText,
        body: body,
        time: timeString,
        isRead: true,
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

  Future<void> _handleDraftTap(EmailData draftEmail) async {
    if (!mounted) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ComposeEmailScreen(draftToEdit: draftEmail),
      ),
    );
    if (result == true) {
      _loadEmails();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Thư nháp')),
        body: const Center(child: Text('Vui lòng đăng nhập.')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Thư nháp')),
      body: RefreshIndicator(
        onRefresh: () async => _loadEmails(),
        child: FutureBuilder<List<EmailData>>(
          future: _emailsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Text('Lỗi khi tải thư nháp: ${snapshot.error}'),
              );
            }
            final emails = snapshot.data ?? [];
            if (emails.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.edit_note_outlined,
                      size: 60,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Không có thư nháp nào!',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tải lại'),
                      onPressed: _loadEmails,
                    ),
                  ],
                ),
              );
            }
            return ListView.builder(
              itemCount: emails.length,
              itemBuilder: (context, index) {
                final email = emails[index];
                return EmailListItem(
                  email: email,
                  onTap: () => _handleDraftTap(email),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
