import 'package:flutter/material.dart';

class EmailListItem extends StatelessWidget {
  final String senderName;
  final String subject;
  final String previewText;
  final String time;
  final bool isRead;

  const EmailListItem({
    super.key,
    required this.senderName,
    required this.subject,
    required this.previewText,
    required this.time,
    this.isRead = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        child: Text(senderName.isNotEmpty ? senderName[0].toUpperCase() : '?'),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            senderName,
            style: TextStyle(
              fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
            ),
          ),
          Text(
            subject,
            style: TextStyle(
              fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      subtitle: Text(previewText, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(time),
          if (!isRead) const Icon(Icons.circle, color: Colors.blue, size: 10),
        ],
      ),
    );
  }
}
