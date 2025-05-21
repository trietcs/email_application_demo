import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:email_application/models/email_data.dart';
import 'package:email_application/services/auth_service.dart';
import 'package:email_application/services/firestore_service.dart';
import 'package:email_application/widgets/email_list_item.dart';
import 'package:email_application/screens/emails/view_email_screen.dart';
import 'package:email_application/screens/inbox/inbox_screen.dart';

class SentScreen extends StatelessWidget {
  const SentScreen({super.key});

  Future<List<EmailData>> fetchEmails(
    BuildContext context,
    String folder,
  ) async {
    final user = Provider.of<AuthService>(context, listen: false).user.value;
    if (user == null) return [];
    final emails = await Provider.of<FirestoreService>(
      context,
      listen: false,
    ).getEmails(user.uid, 'sent');
    return emails
        .map(
          (email) => EmailData(
            id: email['id'],
            senderName: email['from']['displayName'],
            subject: email['subject'],
            previewText:
                email['body'].length > 50
                    ? '${email['body'].substring(0, 50)}...'
                    : email['body'],
            body: email['body'],
            time:
                (email['timestamp'] as Timestamp?)?.toDate().toString() ??
                'N/A',
            isRead: email['isRead'] ?? false,
            to: List<Map<String, String>>.from(email['to']),
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đã gửi')),
      body: FutureBuilder<List<EmailData>>(
        future: fetchEmails(context, 'inbox'),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Lỗi khi tải email'));
          }
          final emails = snapshot.data ?? [];
          if (emails.isEmpty) {
            return const Center(child: Text('Không có thư trong đã gửi'));
          }
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: ListView.builder(
              itemCount: emails.length,
              itemBuilder: (context, index) {
                final email = emails[index];
                return InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ViewEmailScreen(emailData: email),
                      ),
                    );
                  },
                  child: EmailListItem(
                    senderName: email.senderName,
                    subject: email.subject,
                    previewText: email.previewText,
                    time: email.time,
                    isRead: email.isRead,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

extension on Stream<User?> {
  get value => null;
}
