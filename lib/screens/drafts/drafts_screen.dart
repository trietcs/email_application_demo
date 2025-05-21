import 'package:flutter/material.dart';
import 'package:email_application/models/email_data.dart';
import 'package:email_application/widgets/email_list_item.dart';
import 'package:email_application/screens/emails/view_email_screen.dart';

class DraftsScreen extends StatelessWidget {
  const DraftsScreen({super.key});

  static final List<EmailData> mockEmails = [
    EmailData(
      id: '1',
      senderName: 'Bạn',
      subject: 'Bản nháp: Kế hoạch họp',
      previewText: 'Gửi kế hoạch họp tuần tới...',
      body: 'Nội dung bản nháp: Đây là kế hoạch sơ bộ cho cuộc họp tuần tới, cần bổ sung chi tiết.',
      time: 'Hôm nay',
      isRead: true,
      to: [{'displayName': 'Nguyễn Văn A'}, {'displayName': 'Trần Thị B'}],
    ),
    EmailData(
      id: '2',
      senderName: 'Bạn',
      subject: 'Bản nháp: Thư mời',
      previewText: 'Thư mời tham gia sự kiện...',
      body: 'Nội dung bản nháp: Thư mời tham gia sự kiện công ty, cần chỉnh sửa nội dung.',
      time: 'Hôm qua',
      isRead: true,
      to: [{'displayName': 'Lê Văn C'}],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bản nháp'),
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