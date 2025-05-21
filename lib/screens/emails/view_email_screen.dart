import 'package:flutter/material.dart';
import 'package:email_application/models/email_data.dart';

class ViewEmailScreen extends StatelessWidget {
  final EmailData emailData;

  const ViewEmailScreen({super.key, required this.emailData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(emailData.subject),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Từ: ${emailData.senderName}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Đến: ${emailData.to.map((recipient) => recipient['displayName']).join(', ')}',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              'Thời gian: ${emailData.time}',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            const Divider(),
            Text(
              emailData.body,
              style: const TextStyle(fontSize: 16),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: () {
                    // TODO: Logic trả lời
                  },
                  child: const Text('Trả lời'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    // TODO: Logic chuyển tiếp
                  },
                  child: const Text('Chuyển tiếp'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    // TODO: Logic xóa
                  },
                  child: const Text('Xóa'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}