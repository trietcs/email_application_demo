import 'package:flutter/material.dart';
import 'package:email_application/models/email_data.dart';
import 'package:email_application/widgets/email_list_item.dart';
import 'package:email_application/screens/emails/view_email_screen.dart';

class TrashScreen extends StatelessWidget {
  const TrashScreen({super.key});

  static final List<EmailData> mockEmails = [
    EmailData(
      id: '1',
      senderName: 'Nguyễn Văn A',
      subject: 'Quảng cáo sản phẩm',
      previewText: 'Ưu đãi đặc biệt dành cho bạn...',
      body: 'Nội dung đầy đủ: Đây là email quảng cáo sản phẩm mới, đã bị xóa.',
      time: 'Thứ Ba',
      isRead: true,
      to: [{'displayName': 'Bạn'}],
    ),
    EmailData(
      id: '2',
      senderName: 'Trần Thị B',
      subject: 'Nhắc nhở cuộc họp',
      previewText: 'Đừng quên cuộc họp ngày mai...',
      body: 'Nội dung đầy đủ: Nhắc nhở về cuộc họp ngày mai, đã bị xóa nhầm.',
      time: 'Hôm qua',
      isRead: false,
      to: [{'displayName': 'Bạn'}],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thùng rác'),
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