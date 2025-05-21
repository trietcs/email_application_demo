import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:email_application/models/email_data.dart';
import 'package:email_application/services/auth_service.dart';
import 'package:email_application/services/firestore_service.dart';
import 'package:email_application/screens/emails/view_email_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  Future<List<EmailData>> fetchEmails(BuildContext context, String userId) async {
    final emails = await Provider.of<FirestoreService>(context, listen: false).getEmails(userId, 'inbox');
    return emails.map((email) => EmailData(
      id: email['id'] as String,
      senderName: email['from']['displayName'] as String? ?? 'Unknown',
      subject: email['subject'] as String? ?? '',
      previewText: (email['body'] as String? ?? '').length > 50
          ? '${(email['body'] as String).substring(0, 50)}...'
          : email['body'] as String? ?? '',
      body: email['body'] as String? ?? '',
      time: (email['timestamp'] as Timestamp?)?.toDate().toString() ?? 'N/A',
      isRead: email['isRead'] as bool? ?? false,
      to: List<Map<String, String>>.from(email['to'] as List? ?? []),
    )).toList();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: Provider.of<AuthService>(context, listen: false).user,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snapshot.data;
        if (user == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Hộp thư đến')),
            body: const Center(child: Text('Vui lòng đăng nhập')),
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Hộp thư đến')),
          body: FutureBuilder<List<EmailData>>(
            future: fetchEmails(context, user.uid),
            builder: (context, emailSnapshot) {
              if (emailSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (emailSnapshot.hasError) {
                return const Center(child: Text('Lỗi khi tải email'));
              }
              final emails = emailSnapshot.data ?? [];
              if (emails.isEmpty) {
                return const Center(child: Text('Không có thư trong hộp thư đến'));
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
                      child: EmailListItem(email: email),
                    );
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class EmailListItem extends StatelessWidget {
  final EmailData email;

  const EmailListItem({super.key, required this.email});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(email.senderName.isNotEmpty ? email.senderName[0] : '?'),
        ),
        title: Text(
          email.senderName,
          style: TextStyle(fontWeight: email.isRead ? FontWeight.normal : FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              email.subject,
              style: TextStyle(fontWeight: email.isRead ? FontWeight.normal : FontWeight.bold),
            ),
            Text(email.previewText, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
        trailing: Text(
          email.time.split(' ')[0],
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ),
    );
  }
}