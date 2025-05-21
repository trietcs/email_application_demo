import 'package:flutter/material.dart';
import 'package:email_application/models/email_data.dart';
import 'package:email_application/widgets/email_list_item.dart';
import 'package:email_application/screens/emails/view_email_screen.dart';

class SentScreen extends StatelessWidget {
  const SentScreen({super.key});

  static final List<EmailData> mockEmails = [
    EmailData(
      id: '1',
      senderName: 'Bạn',
      subject: 'Gửi báo cáo',
      previewText: 'Mình vừa gửi báo cáo tuần này...',
      body: 'Nội dung đầy đủ: Báo cáo tuần này đã được hoàn thành và gửi đi.',
      time: '10:00 AM',
      isRead: true,
      to: [{'displayName': 'Nguyễn Văn A'}],
    ),
    EmailData(
      id: '2',
      senderName: 'Bạn',
      subject: 'Hẹn gặp',
      previewText: 'Cuối tuần này bạn rảnh không?',
      body: 'Nội dung đầy đủ: Mình muốn hẹn gặp để bàn về dự án.',
      time: 'Hôm qua',
      isRead: true,
      to: [{'displayName': 'Trần Thị B'}],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đã gửi'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ListView.builder(
          itemCount: mockEmails.length,
          itemBuilder: (context, index) {
            final email = mockEmails[index];
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
      ),
    );
  }
}