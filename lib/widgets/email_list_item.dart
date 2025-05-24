import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:email_application/models/email_data.dart';
import 'package:email_application/services/auth_service.dart';
import 'package:email_application/services/firestore_service.dart';
import 'package:intl/intl.dart';
import 'package:email_application/config/app_colors.dart';

class EmailListItem extends StatefulWidget {
  final EmailData email;
  final VoidCallback? onTap;
  final VoidCallback? onReadStatusChanged;
  final VoidCallback? onDeleteOrMove;
  final bool isSentItem;

  const EmailListItem({
    super.key,
    required this.email,
    this.onTap,
    this.onReadStatusChanged,
    this.onDeleteOrMove,
    this.isSentItem = false,
  });

  @override
  State<EmailListItem> createState() => _EmailListItemState();
}

class _EmailListItemState extends State<EmailListItem> {
  late EmailData _currentEmail;
  String? _fetchedDisplayName;
  String? _photoUrl;
  bool _isLoadingProfileInfo = true;

  @override
  void initState() {
    super.initState();
    _currentEmail = widget.email;
    _fetchRelevantProfileInfo();
  }

  @override
  void didUpdateWidget(covariant EmailListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    bool emailChanged = widget.email.id != oldWidget.email.id;
    if (emailChanged || widget.email.isRead != _currentEmail.isRead) {
      setState(() {
        _currentEmail = widget.email;
      });
    }
    if (emailChanged ||
        widget.email.senderEmail != oldWidget.email.senderEmail ||
        widget.isSentItem != oldWidget.isSentItem) {
      _fetchRelevantProfileInfo();
    }
  }

  Future<void> _fetchRelevantProfileInfo() async {
    if (!mounted) return;
    setState(() => _isLoadingProfileInfo = true);

    final String contactIdToLookup = widget.email.senderEmail;

    print(
      "EmailListItem (${widget.email.id}, isSent: ${widget.isSentItem}): Fetching profile for contactId: '$contactIdToLookup'",
    );

    if (contactIdToLookup.isEmpty) {
      print(
        "EmailListItem (${widget.email.id}): contactIdToLookup is empty. Using name from EmailData: '${widget.email.senderName}'",
      );
      setState(() {
        _fetchedDisplayName =
            widget.email.senderName.isNotEmpty
                ? widget.email.senderName
                : 'Unknown';
        _photoUrl = null;
        _isLoadingProfileInfo = false;
      });
      return;
    }

    try {
      final firestoreService = Provider.of<FirestoreService>(
        context,
        listen: false,
      );
      final userProfile = await firestoreService.getUserProfile(
        contactIdToLookup,
      );
      print(
        "EmailListItem (${widget.email.id}): Profile fetched for $contactIdToLookup: $userProfile",
      );

      if (mounted) {
        setState(() {
          _fetchedDisplayName =
              userProfile?['displayName'] ??
              (widget.isSentItem
                  ? widget.email.senderName.replaceFirst('To: ', '')
                  : widget.email.senderName);
          _photoUrl = userProfile?['photoURL'] as String?;
          _isLoadingProfileInfo = false;
          print(
            "EmailListItem (${widget.email.id}): Updated state - DisplayName: $_fetchedDisplayName, PhotoURL: $_photoUrl",
          );
        });
      }
    } catch (e) {
      print(
        "EmailListItem (${widget.email.id}): Error fetching profile for contactId '$contactIdToLookup': $e",
      );
      if (mounted) {
        setState(() {
          _fetchedDisplayName = widget.email.senderName;
          _photoUrl = null;
          _isLoadingProfileInfo = false;
        });
      }
    }
  }

  String _formatDateTime(String dateTimeString) {
    try {
      final dateTime = DateTime.parse(dateTimeString).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));

      if (dateTime.year == today.year &&
          dateTime.month == today.month &&
          dateTime.day == today.day) {
        return DateFormat.Hm('en_US').format(dateTime);
      } else if (dateTime.year == yesterday.year &&
          dateTime.month == yesterday.month &&
          dateTime.day == yesterday.day) {
        return 'Yesterday';
      } else if (dateTime.year == now.year) {
        return DateFormat('MMM d', 'en_US').format(dateTime);
      } else {
        return DateFormat('MM/dd/yy', 'en_US').format(dateTime);
      }
    } catch (e) {
      print("Error formatting time: $e for time string: $dateTimeString");
      try {
        return dateTimeString.split('T')[0];
      } catch (_) {
        return dateTimeString;
      }
    }
  }

  Future<void> _toggleReadStatus(BuildContext context) async {
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );
    final userId =
        Provider.of<AuthService>(context, listen: false).currentUser?.uid;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    if (userId == null) {
      if (mounted)
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Please sign in to continue')),
        );
      return;
    }

    try {
      bool newReadStatus = !_currentEmail.isRead;
      await firestoreService.markEmailAsRead(
        userId: userId,
        emailId: _currentEmail.id,
        isRead: newReadStatus,
      );
      if (mounted) {
        setState(() => _currentEmail.isRead = newReadStatus);
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              _currentEmail.isRead ? 'Marked as read' : 'Marked as unread',
            ),
          ),
        );
      }
      widget.onReadStatusChanged?.call();
    } catch (e) {
      if (mounted)
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Error changing status: ${e.toString()}')),
        );
    }
  }

  Future<void> _deleteEmail(BuildContext context) async {
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );
    final userId =
        Provider.of<AuthService>(context, listen: false).currentUser?.uid;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    if (userId == null) {
      if (mounted)
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Please sign in to continue')),
        );
      return;
    }

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
              child: Text('Delete', style: TextStyle(color: AppColors.error)),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await firestoreService.deleteEmail(
        userId: userId,
        emailId: _currentEmail.id,
        targetFolder: 'trash',
      );
      if (mounted)
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Moved to Trash')),
        );
      widget.onDeleteOrMove?.call();
    } catch (e) {
      if (mounted)
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Error deleting email: ${e.toString()}')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isUnread = !_currentEmail.isRead;
    final Color itemTextColor = isUnread ? Colors.black87 : Colors.black54;
    final FontWeight itemFontWeight =
        isUnread ? FontWeight.bold : FontWeight.normal;

    String nameToDisplay =
        _isLoadingProfileInfo
            ? "..."
            : (_fetchedDisplayName ?? widget.email.senderName);

    if (widget.isSentItem &&
        nameToDisplay.isNotEmpty &&
        nameToDisplay != "..." &&
        !nameToDisplay.toLowerCase().startsWith('to: ')) {
      nameToDisplay = 'To: $nameToDisplay';
    }

    String initialLetter = "?";
    if (nameToDisplay.isNotEmpty && nameToDisplay != "...") {
      String namePartForInitial =
          widget.isSentItem
              ? nameToDisplay.replaceFirst('To: ', '')
              : nameToDisplay;
      if (namePartForInitial.isNotEmpty) {
        initialLetter = namePartForInitial[0].toUpperCase();
      }
    }

    return InkWell(
      onTap: widget.onTap,
      onLongPress: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder:
              (context) => SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: Icon(
                        _currentEmail.isRead
                            ? Icons.drafts_outlined
                            : Icons.mark_email_read_outlined,
                        color:
                            _currentEmail.isRead
                                ? AppColors.primary
                                : AppColors.secondaryIcon,
                      ),
                      title: Text(
                        _currentEmail.isRead
                            ? 'Mark as unread'
                            : 'Mark as read',
                      ),
                      onTap: () async {
                        Navigator.pop(context);
                        await _toggleReadStatus(context);
                      },
                    ),
                    ListTile(
                      leading: Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.error,
                      ),
                      title: const Text('Delete'),
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
                  ? AppColors.primary.withOpacity(0.05)
                  : Colors.transparent,
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade200, width: 0.5),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              key: ValueKey<String?>(_photoUrl ?? nameToDisplay),
              backgroundColor:
                  isUnread
                      ? AppColors.primary.withOpacity(0.15)
                      : Colors.blueGrey[100],
              backgroundImage:
                  (_photoUrl != null && _photoUrl!.isNotEmpty)
                      ? NetworkImage(_photoUrl!)
                      : null,
              child:
                  (_photoUrl == null || _photoUrl!.isEmpty)
                      ? Text(
                        initialLetter,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color:
                              isUnread
                                  ? AppColors.primary
                                  : AppColors.secondaryText,
                        ),
                      )
                      : null,
            ),
            const SizedBox(width: 12.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nameToDisplay,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: itemFontWeight,
                      fontSize: 16,
                      color: itemTextColor,
                    ),
                  ),
                  const SizedBox(height: 2.0),
                  Text(
                    _currentEmail.subject.isNotEmpty
                        ? _currentEmail.subject
                        : '(No Subject)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: itemFontWeight,
                      fontSize: 14,
                      color: itemTextColor,
                    ),
                  ),
                  const SizedBox(height: 2.0),
                  Text(
                    _currentEmail.previewText.isNotEmpty
                        ? _currentEmail.previewText.replaceAll('\n', ' ')
                        : '(No preview content)',
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
                  _formatDateTime(_currentEmail.time),
                  style: TextStyle(
                    fontSize: 12,
                    color: isUnread ? AppColors.primary : Colors.grey[700],
                    fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                if (isUnread)
                  Container(
                    margin: const EdgeInsets.only(top: 6.0),
                    height: 8,
                    width: 8,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
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
