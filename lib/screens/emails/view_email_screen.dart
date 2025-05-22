import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:email_application/models/email_data.dart';
import 'package:email_application/services/auth_service.dart';
import 'package:email_application/services/firestore_service.dart';
import 'package:email_application/screens/emails/compose_email_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ViewEmailScreen extends StatefulWidget {
  final EmailData emailData;

  const ViewEmailScreen({super.key, required this.emailData});

  @override
  State<ViewEmailScreen> createState() => _ViewEmailScreenState();
}

class _ViewEmailScreenState extends State<ViewEmailScreen> {
  late EmailData _currentEmailData;
  bool _isProcessingAction = false;

  @override
  void initState() {
    super.initState();
    _currentEmailData = widget.emailData;
    _markEmailAsReadOnOpen();
  }

  Future<void> _markEmailAsReadOnOpen() async {
    if (!mounted) return;
    if (!_currentEmailData.isRead && _currentEmailData.id.isNotEmpty) {
      final user = Provider.of<AuthService>(context, listen: false).currentUser;
      if (user != null) {
        try {
          await Provider.of<FirestoreService>(
            context,
            listen: false,
          ).markEmailAsRead(
            userId: user.uid,
            emailId: _currentEmailData.id,
            isRead: true,
          );
          print(
            "ViewEmailScreen: Marked email ${_currentEmailData.id} as read.",
          );
        } catch (e) {
          print("Error marking email as read in ViewEmailScreen: $e");
        }
      }
    }
  }

  String _formatFullDateTime(String dateTimeString) {
    try {
      final dateTime = DateTime.parse(dateTimeString).toLocal();
      return DateFormat('EEEE, dd MMMM yyyy, HH:mm', 'vi_VN').format(dateTime);
    } catch (e) {
      print("Error formatting full date time: $e for $dateTimeString");
      return dateTimeString;
    }
  }

  Future<void> _handleDeleteEmail() async {
    if (!mounted) return;

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

    if (confirmed == true) {
      if (!mounted) return;
      setState(() => _isProcessingAction = true);
      final user = Provider.of<AuthService>(context, listen: false).currentUser;
      final firestoreService = Provider.of<FirestoreService>(
        context,
        listen: false,
      );

      if (user != null && _currentEmailData.id.isNotEmpty) {
        try {
          print(
            "ViewEmailScreen: Placeholder for moveEmailToTrash API call for ${_currentEmailData.id}",
          );
          await Future.delayed(const Duration(milliseconds: 500));

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Đã chuyển thư vào thùng rác (Chức năng chờ API).',
                ),
              ),
            );
            Navigator.pop(context, true);
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Lỗi khi xóa thư: ${e.toString()}')),
            );
          }
          print("Error moving email to trash: $e");
        } finally {
          if (mounted) {
            setState(() => _isProcessingAction = false);
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Không thể xóa thư, thiếu thông tin người dùng hoặc email.',
              ),
            ),
          );
          setState(() => _isProcessingAction = false);
        }
      }
    }
  }

  void _handleReplyEmail() {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ComposeEmailScreen(replyToEmail: _currentEmailData),
      ),
    ).then((emailSent) {
      if (emailSent == true && mounted) {}
    });
  }

  void _handleForwardEmail() {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ComposeEmailScreen(forwardEmail: _currentEmailData),
      ),
    ).then((emailSent) {
      if (emailSent == true && mounted) {
        //
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentEmailData.subject.isNotEmpty
              ? _currentEmailData.subject
              : '(Không có chủ đề)',
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_isProcessingAction)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Xóa thư',
              onPressed: _handleDeleteEmail,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _currentEmailData.subject.isNotEmpty
                  ? _currentEmailData.subject
                  : '(Không có chủ đề)',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).primaryColor.withOpacity(0.1),
                  child: Text(
                    _currentEmailData.senderName.isNotEmpty
                        ? _currentEmailData.senderName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentEmailData.senderName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (_currentEmailData.to.isNotEmpty)
                        Text(
                          'Đến: ${_currentEmailData.to.map((r) => r['displayName']).where((name) => name != null && name.isNotEmpty).join(', ')}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Text(
                    _formatFullDateTime(_currentEmailData.time),
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Divider(color: Colors.grey[300]),
            const SizedBox(height: 12),
            SelectableText(
              _currentEmailData.body.isNotEmpty
                  ? _currentEmailData.body
                  : '(Không có nội dung)',
              style: const TextStyle(fontSize: 16, height: 1.6),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        elevation: 4.0,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.reply_outlined),
                label: const Text('Trả lời'),
                onPressed: _handleReplyEmail,
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.forward_outlined),
                label: const Text('Chuyển tiếp'),
                onPressed: _handleForwardEmail,
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
