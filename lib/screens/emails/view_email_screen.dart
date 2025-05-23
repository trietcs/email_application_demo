import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:email_application/screens/models/email_data.dart';
import 'package:email_application/services/auth_service.dart';
import 'package:email_application/services/firestore_service.dart';
import 'package:email_application/screens/compose/compose_email_screen.dart';
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
    if (_currentEmailData.id.isNotEmpty && !_currentEmailData.isRead) {
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
          if (mounted) {
            setState(() {
              _currentEmailData = _currentEmailData.copyWith(isRead: true);
            });
          }
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
      return DateFormat('MMM d, yyyy, h:mm a').format(dateTime);
    } catch (e) {
      print("Error formatting full date time: $e for $dateTimeString");
      return dateTimeString;
    }
  }

  Future<void> _handleDeleteEmail() async {
    if (!mounted || _isProcessingAction) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: const Text(
            'Are you sure you want to move this email to the trash?',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    if (!mounted) return;
    setState(() => _isProcessingAction = true);
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    if (user != null && _currentEmailData.id.isNotEmpty) {
      try {
        await firestoreService.deleteEmail(
          userId: user.uid,
          emailId: _currentEmailData.id,
          targetFolder: 'trash',
        );
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('Email moved to trash')),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(content: Text('Error deleting email: ${e.toString()}')),
          );
        }
        print("Error deleting email: $e");
      } finally {
        if (mounted) {
          setState(() => _isProcessingAction = false);
        }
      }
    } else {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Cannot delete email, missing user or email information.',
            ),
          ),
        );
        setState(() => _isProcessingAction = false);
      }
    }
  }

  Future<void> _toggleReadStatus() async {
    if (!mounted || _isProcessingAction || _currentEmailData.id.isEmpty) return;

    setState(() => _isProcessingAction = true);
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    if (user != null) {
      final newReadStatus = !_currentEmailData.isRead;
      try {
        await firestoreService.markEmailAsRead(
          userId: user.uid,
          emailId: _currentEmailData.id,
          isRead: newReadStatus,
        );
        if (mounted) {
          setState(() {
            _currentEmailData = _currentEmailData.copyWith(
              isRead: newReadStatus,
            );
          });
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(
                'Email marked as ${newReadStatus ? "read" : "unread"}',
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(content: Text('Error updating read status: $e')),
          );
        }
        print("Error toggling read status: $e");
      } finally {
        if (mounted) {
          setState(() => _isProcessingAction = false);
        }
      }
    } else {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('User not found to update read status.'),
          ),
        );
        setState(() => _isProcessingAction = false);
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
    );
  }

  void _handleForwardEmail() {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ComposeEmailScreen(forwardEmail: _currentEmailData),
      ),
    );
  }

  Widget _buildRecipientRow(
    BuildContext context,
    String label,
    List<Map<String, dynamic>> recipients, [
    String? currentUserEmailForToMeLogic,
  ]) {
    if (recipients.isEmpty) {
      return const SizedBox.shrink();
    }

    String displayText;
    bool showDropdown = true;

    if (label == "To:" &&
        currentUserEmailForToMeLogic != null &&
        recipients.length == 1 &&
        recipients.first['email'] == currentUserEmailForToMeLogic) {
      displayText = 'me';
      showDropdown = false;
    } else {
      displayText = recipients
          .map((r) {
            String displayName = r['displayName'] as String? ?? '';
            String email = r['email'] as String? ?? '';

            if (displayName.isNotEmpty) {
              return email.isNotEmpty ? '$displayName <$email>' : displayName;
            }
            return email.isNotEmpty ? email : 'Unknown';
          })
          .join(', ');
    }

    return Padding(
      padding: const EdgeInsets.only(top: 1.0, bottom: 1.0),
      child: GestureDetector(
        onTap: () {
          showDialog(
            context: context,
            builder: (BuildContext dialogContext) {
              return AlertDialog(
                title: Text(label.replaceAll(':', '')),
                content: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children:
                        recipients.map((r) {
                          String displayName =
                              r['displayName'] as String? ?? '';
                          String email = r['email'] as String? ?? 'no-email';
                          String textToShow;
                          if (displayName.isNotEmpty) {
                            textToShow =
                                email.isNotEmpty
                                    ? '$displayName <$email>'
                                    : displayName;
                          } else {
                            textToShow =
                                email.isNotEmpty ? email : 'Unknown recipient';
                          }
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                            child: Text(textToShow),
                          );
                        }).toList(),
                  ),
                ),
                actions: <Widget>[
                  TextButton(
                    child: const Text('Close'),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                  ),
                ],
              );
            },
          );
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                displayText,
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
            if (showDropdown)
              Icon(Icons.expand_more, size: 18, color: Colors.grey[700]),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipientDetails(
    BuildContext context,
    EmailData emailData,
    String? currentUserEmail,
  ) {
    final List<Map<String, dynamic>> ccRecipients = emailData.cc ?? [];
    final List<Map<String, dynamic>> bccRecipients = emailData.bcc ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (emailData.to.isNotEmpty)
          _buildRecipientRow(context, "To:", emailData.to, currentUserEmail),
        if (ccRecipients.isNotEmpty)
          _buildRecipientRow(context, "Cc:", ccRecipients),
        if (bccRecipients.isNotEmpty)
          _buildRecipientRow(context, "Bcc:", bccRecipients),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserEmail =
        Provider.of<AuthService>(context, listen: false).currentUser?.email;

    String senderDisplay = _currentEmailData.senderName;
    if (senderDisplay.isEmpty) {
      senderDisplay = _currentEmailData.senderEmail;
    }

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (_isProcessingAction)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            )
          else ...[
            IconButton(
              icon: Icon(
                _currentEmailData.isRead
                    ? Icons.mark_email_read_outlined
                    : Icons.mark_email_unread_outlined,
              ),
              tooltip:
                  _currentEmailData.isRead ? 'Mark as unread' : 'Mark as read',
              onPressed: _toggleReadStatus,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete email',
              onPressed: _handleDeleteEmail,
            ),
          ],
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
                  : '(No Subject)',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).primaryColor.withOpacity(0.1),
                  child: Text(
                    _currentEmailData.senderName.isNotEmpty
                        ? _currentEmailData.senderName[0].toUpperCase()
                        : (_currentEmailData.senderEmail.isNotEmpty == true
                            ? _currentEmailData.senderEmail[0].toUpperCase()
                            : '?'),
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        senderDisplay,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      _buildRecipientDetails(
                        context,
                        _currentEmailData,
                        currentUserEmail,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatFullDateTime(_currentEmailData.time),
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                    ],
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
                  : '(No content)',
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
                label: const Text('Reply'),
                onPressed: _handleReplyEmail,
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.forward_outlined),
                label: const Text('Forward'),
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
