import 'package:flutter/material.dart';
import 'package:email_application/models/email_data.dart';
import 'package:intl/intl.dart';

class EmailListItem extends StatelessWidget {
  final EmailData email;
  final VoidCallback? onTap;

  const EmailListItem({super.key, required this.email, this.onTap});

  String _formatDateTime(String dateTimeString) {
    try {
      final dateTime = DateTime.parse(dateTimeString).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = DateTime(now.year, now.month, now.day - 1);

      if (dateTime.year == today.year &&
          dateTime.month == today.month &&
          dateTime.day == today.day) {
        return DateFormat.Hm('vi_VN').format(dateTime);
      } else if (dateTime.year == yesterday.year &&
          dateTime.month == yesterday.month &&
          dateTime.day == yesterday.day) {
        return 'Hôm qua';
      } else if (dateTime.year == now.year) {
        return DateFormat('dd MMM', 'vi_VN').format(dateTime);
      } else {
        return DateFormat('dd/MM/yy', 'vi_VN').format(dateTime);
      }
    } catch (e) {
      print(
        "Error formatting time in EmailListItem: $e for time string: $dateTimeString",
      );
      return dateTimeString.split(' ')[0];
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isUnread = !email.isRead;
    final Color primaryTextColor = isUnread ? Colors.black87 : Colors.black54;
    final FontWeight fontWeight =
        isUnread ? FontWeight.bold : FontWeight.normal;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        decoration: BoxDecoration(
          color:
              isUnread
                  ? Theme.of(context).primaryColor.withOpacity(0.05)
                  : Colors.transparent,
          border: Border(
            bottom: BorderSide(color: Colors.grey[200]!, width: 0.5),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor:
                  isUnread
                      ? Theme.of(context).primaryColor.withOpacity(0.2)
                      : Colors.blueGrey[100],
              child: Text(
                email.senderName.isNotEmpty
                    ? email.senderName[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color:
                      isUnread
                          ? Theme.of(context).primaryColor
                          : Colors.blueGrey[700],
                ),
              ),
            ),
            const SizedBox(width: 12.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    email.senderName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: fontWeight,
                      fontSize: 16,
                      color: primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 2.0),
                  Text(
                    email.subject.isNotEmpty
                        ? email.subject
                        : '(Không có chủ đề)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: fontWeight,
                      fontSize: 14,
                      color: primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 2.0),
                  Text(
                    email.previewText.isNotEmpty
                        ? email.previewText
                        : '(Không có nội dung xem trước)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8.0),
            Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatDateTime(email.time),
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        isUnread
                            ? Theme.of(context).primaryColor
                            : Colors.grey[700],
                    fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                if (isUnread)
                  Container(
                    margin: const EdgeInsets.only(top: 6.0),
                    height: 8,
                    width: 8,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
