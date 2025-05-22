import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:email_application/models/email_data.dart';
import 'package:email_application/services/auth_service.dart';
import 'package:email_application/services/firestore_service.dart';
import 'package:intl/intl.dart';

class EmailListItem extends StatefulWidget {
  final EmailData email;
  final VoidCallback? onTap;
  final VoidCallback? onReadStatusChanged; // Callback để thông báo cha làm mới

  const EmailListItem({
    super.key,
    required this.email,
    this.onTap,
    this.onReadStatusChanged,
  });

  @override
  State<EmailListItem> createState() => _EmailListItemState();
}

class _EmailListItemState extends State<EmailListItem> {
  late EmailData email;

  @override
  void initState() {
    super.initState();
    email = widget.email;
  }

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

  Future<void> _toggleReadStatus(BuildContext context) async {
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );
    final userId =
        Provider.of<AuthService>(context, listen: false).currentUser?.uid;
    final scaffoldMessenger = ScaffoldMessenger.of(context); // Lưu trước

    if (userId == null) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Vui lòng đăng nhập để thực hiện hành động này'),
          ),
        );
      }
      return;
    }

    try {
      await firestoreService.markEmailAsRead(
        userId: userId,
        emailId: email.id,
        isRead: !email.isRead,
      );
      if (mounted) {
        setState(() {
          email.isRead = !email.isRead;
        });
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              email.isRead ? 'Đã đánh dấu đã đọc' : 'Đã đánh dấu chưa đọc',
            ),
          ),
        );
      }
      widget.onReadStatusChanged?.call(); // Thông báo cha làm mới danh sách
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Lỗi khi thay đổi trạng thái: ${e.toString()}'),
          ),
        );
      }
    }
  }

  Future<void> _deleteEmail(BuildContext context) async {
    // Lưu các service và state trước khi thực hiện tác vụ bất đồng bộ
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );
    final userId =
        Provider.of<AuthService>(context, listen: false).currentUser?.uid;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    if (userId == null) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Vui lòng đăng nhập để thực hiện hành động này'),
          ),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Xác nhận xóa'),
          content: const Text(
            'Bạn có chắc chắn muốn chuyển thư này vào thùng rác không?',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Hủy'),
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
            ),
            TextButton(
              child: const Text('Xóa', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await firestoreService.deleteEmail(
        userId: userId,
        emailId: email.id,
        targetFolder: 'trash',
      );
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Đã chuyển thư vào thùng rác')),
        );
      }
      widget.onReadStatusChanged?.call(); // Thông báo cha làm mới danh sách
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Lỗi khi xóa thư: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isUnread = !email.isRead;
    final Color primaryTextColor = isUnread ? Colors.black87 : Colors.black54;
    final FontWeight fontWeight =
        isUnread ? FontWeight.bold : FontWeight.normal;

    return InkWell(
      onTap: widget.onTap,
      onLongPress: () {
        showModalBottomSheet(
          context: context,
          builder:
              (context) => SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: Icon(
                        email.isRead ? Icons.mail_outline : Icons.mail,
                        color: email.isRead ? Colors.blue : Colors.grey,
                      ),
                      title: Text(
                        email.isRead ? 'Đánh dấu chưa đọc' : 'Đánh dấu đã đọc',
                      ),
                      onTap: () async {
                        Navigator.pop(context);
                        await _toggleReadStatus(context);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.delete, color: Colors.red),
                      title: const Text('Xóa'),
                      onTap: () async {
                        Navigator.pop(context);
                        await _deleteEmail(context);
                      },
                    ),
                  ],
                ),
              ),
        );
      },
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
