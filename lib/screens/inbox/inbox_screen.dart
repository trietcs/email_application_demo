import 'package:flutter/material.dart';
import 'package:email_application/models/email_data.dart';
import 'package:email_application/widgets/email_list_item.dart';
import 'package:email_application/screens/emails/view_email_screen.dart';

class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  // Mock data
  static final List<EmailData> mockEmails = [
    EmailData(
      id: '1',
      senderName: 'Nguyễn Văn A',
      subject: 'Họp khẩn cấp đội dự án',
      previewText: 'Chào cả nhóm, chúng ta sẽ có một buổi họp ngắn...',
      body: 'Nội dung đầy đủ của email họp khẩn cấp: Chúng ta cần thảo luận về tiến độ dự án và phân công nhiệm vụ mới.',
      time: '9:30 AM',
      isRead: false,
      to: [{'displayName': 'Bạn'}],
    ),
    EmailData(
      id: '2',
      senderName: 'Trần Thị B',
      subject: 'Chúc mừng sinh nhật!',
      previewText: 'Chúc bạn một ngày sinh nhật vui vẻ và ý nghĩa!',
      body: 'Nội dung đầy đủ của email chúc mừng sinh nhật: Chúc bạn một năm mới tràn đầy sức khỏe và thành công!',
      time: 'Hôm qua',
      isRead: true,
      to: [{'displayName': 'Bạn'}],
    ),
    EmailData(
      id: '3',
      senderName: 'Lê Văn C',
      subject: 'Báo cáo tuần',
      previewText: 'Báo cáo tuần này đã được gửi, vui lòng xem xét...',
      body: 'Nội dung đầy đủ: Báo cáo tuần này bao gồm các cập nhật về tiến độ phát triển ứng dụng email.',
      time: 'Thứ Hai',
      isRead: false,
      to: [{'displayName': 'Bạn'}],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hộp thư đến'),
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