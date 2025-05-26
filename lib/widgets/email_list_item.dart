import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:email_application/models/email_data.dart';
import 'package:email_application/models/email_folder.dart';
import 'package:email_application/services/auth_service.dart';
import 'package:email_application/services/firestore_service.dart';
import 'package:intl/intl.dart';
import 'package:email_application/config/app_colors.dart';

class EmailListItem extends StatefulWidget {
  final EmailData email;
  final EmailFolder currentScreenFolder;
  final VoidCallback? onTap;
  final VoidCallback? onReadStatusChanged;
  final VoidCallback? onDeleteOrMove;

  const EmailListItem({
    super.key,
    required this.email,
    required this.currentScreenFolder,
    this.onTap,
    this.onReadStatusChanged,
    this.onDeleteOrMove,
  });

  @override
  State<EmailListItem> createState() => _EmailListItemState();
}

class _EmailListItemState extends State<EmailListItem> {
  late EmailData _currentEmail;
  String? _nameForAvatarAndInitial;
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
    bool emailChanged =
        widget.email.id != oldWidget.email.id ||
        widget.email.from['userId'] != oldWidget.email.from['userId'];
    if (emailChanged || widget.email.isRead != _currentEmail.isRead) {
      setState(() {
        _currentEmail = widget.email;
      });
    }
    if (emailChanged ||
        widget.currentScreenFolder != oldWidget.currentScreenFolder ||
        widget.email.originalFolder != oldWidget.email.originalFolder) {
      _fetchRelevantProfileInfo();
    }
  }

  Future<void> _fetchRelevantProfileInfo() async {
    if (!mounted) return;
    setState(() {
      _isLoadingProfileInfo = true;
      _photoUrl = null;
    });

    String? contactIdToLookup;
    String nameForInitialFallback = "Unknown";

    final effectiveFolder =
        widget.currentScreenFolder == EmailFolder.trash
            ? widget.email.originalFolder ?? widget.email.folder
            : widget.currentScreenFolder;

    final currentUser =
        Provider.of<AuthService>(context, listen: false).currentUser;

    switch (effectiveFolder) {
      case EmailFolder.inbox:
        contactIdToLookup = widget.email.from['userId'];
        nameForInitialFallback =
            widget.email.from['displayName'] ?? 'Unknown Sender';
        break;
      case EmailFolder.sent:
        if (widget.email.to.isNotEmpty) {
          contactIdToLookup = widget.email.to.first['userId'];
          nameForInitialFallback =
              widget.email.to.first['displayName'] ?? 'Unknown Recipient';
        } else if (widget.email.cc?.isNotEmpty == true) {
          contactIdToLookup = widget.email.cc!.first['userId'];
          nameForInitialFallback =
              widget.email.cc!.first['displayName'] ?? 'Unknown Recipient';
        } else if (widget.email.bcc?.isNotEmpty == true) {
          contactIdToLookup = widget.email.bcc!.first['userId'];
          nameForInitialFallback =
              widget.email.bcc!.first['displayName'] ?? 'Unknown Recipient';
        } else {
          nameForInitialFallback = 'Unknown Recipient';
        }
        break;
      case EmailFolder.drafts:
        if (currentUser != null) {
          contactIdToLookup = currentUser.uid;
          nameForInitialFallback =
              currentUser.displayName ?? (currentUser.email ?? 'Draft');
          if (mounted) {
            setState(() {
              _nameForAvatarAndInitial = nameForInitialFallback;
              _photoUrl = currentUser.photoURL;
              _isLoadingProfileInfo = false;
            });
          }
          return;
        }
        break;
      default:
        contactIdToLookup = widget.email.from['userId'];
        nameForInitialFallback = widget.email.from['displayName'] ?? 'Unknown';
        break;
    }

    if (mounted) {
      setState(() {
        _nameForAvatarAndInitial = nameForInitialFallback;
      });
    }

    if (contactIdToLookup == null || contactIdToLookup.isEmpty) {
      if (mounted) {
        setState(() {
          _photoUrl = null;
          _isLoadingProfileInfo = false;
        });
      }
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
      if (mounted) {
        setState(() {
          _nameForAvatarAndInitial =
              userProfile?['displayName'] as String? ?? nameForInitialFallback;
          _photoUrl = userProfile?['photoURL'] as String?;
          _isLoadingProfileInfo = false;
        });
      }
    } catch (e) {
      print(
        "EmailListItem (${widget.email.id}): Error fetching profile for contactId '$contactIdToLookup': $e",
      );
      if (mounted) {
        setState(() {
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
      try {
        return dateTimeString.split('T')[0];
      } catch (_) {
        return dateTimeString;
      }
    }
  }

  Future<void> _toggleReadStatus(BuildContext context) async {
    if (widget.currentScreenFolder == EmailFolder.drafts ||
        widget.currentScreenFolder == EmailFolder.sent)
      return;

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
        widget.onReadStatusChanged?.call();
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              _currentEmail.isRead ? 'Marked as unread' : 'Marked as read',
            ),
          ),
        );
      }
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

    bool confirmPermanentDelete = false;
    String dialogTitle = 'Confirm Deletion';
    String dialogContent =
        'Are you sure you want to move this email to the trash?';
    String confirmButtonText = 'Move to Trash';

    if (widget.currentScreenFolder == EmailFolder.trash) {
      confirmPermanentDelete = true;
      dialogTitle = 'Confirm Permanent Deletion';
      dialogContent = 'Are you sure you want to permanently delete this email?';
      confirmButtonText = 'Delete Permanently';
    } else if (widget.currentScreenFolder == EmailFolder.drafts) {
      confirmPermanentDelete = false;
      dialogTitle = 'Delete Draft';
      dialogContent = 'Are you sure you want to move this draft to the trash?';
      confirmButtonText = 'Move to Trash';
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(dialogTitle),
          content: Text(dialogContent),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            TextButton(
              child: Text(
                confirmButtonText,
                style: TextStyle(color: AppColors.error),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      if (confirmPermanentDelete) {
        await firestoreService.deleteEmailPermanently(
          userId: userId,
          emailId: _currentEmail.id,
        );
        if (mounted)
          scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('Email permanently deleted')),
          );
      } else {
        EmailFolder folderToSaveAsOriginal = widget.currentScreenFolder;
        await firestoreService.deleteEmail(
          userId: userId,
          emailId: _currentEmail.id,
          currentFolder: folderToSaveAsOriginal,
          targetFolder: EmailFolder.trash,
        );
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(
                widget.currentScreenFolder == EmailFolder.drafts
                    ? 'Draft moved to trash'
                    : 'Email moved to trash',
              ),
            ),
          );
        }
      }
      widget.onDeleteOrMove?.call();
    } catch (e) {
      if (mounted)
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Error performing action: ${e.toString()}')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isUnread = !_currentEmail.isRead;

    final EmailFolder displayContextFolder =
        widget.currentScreenFolder == EmailFolder.trash
            ? _currentEmail.originalFolder ?? _currentEmail.folder
            : widget.currentScreenFolder;

    bool isActuallyDraftDisplay = displayContextFolder == EmailFolder.drafts;

    Color displayNameColor =
        (isUnread && !isActuallyDraftDisplay) ? Colors.black87 : Colors.black54;
    FontWeight displayNameFontWeight =
        (isUnread && !isActuallyDraftDisplay)
            ? FontWeight.bold
            : FontWeight.normal;
    FontWeight itemFontWeight =
        (isUnread && !isActuallyDraftDisplay)
            ? FontWeight.bold
            : FontWeight.normal;
    Color itemTextColor =
        (isUnread && !isActuallyDraftDisplay) ? Colors.black87 : Colors.black54;

    String nameToDisplay;

    switch (displayContextFolder) {
      case EmailFolder.inbox:
        nameToDisplay =
            _currentEmail.from['displayName'] ?? _currentEmail.senderName;
        break;
      case EmailFolder.sent:
        String recipientName = "Unknown Recipient";
        if (_currentEmail.to.isNotEmpty) {
          recipientName =
              _currentEmail.to.first['displayName'] ??
              _currentEmail.to.first['email'] ??
              recipientName;
        } else if (_currentEmail.cc?.isNotEmpty == true) {
          recipientName =
              _currentEmail.cc!.first['displayName'] ??
              _currentEmail.cc!.first['email'] ??
              recipientName;
        } else if (_currentEmail.bcc?.isNotEmpty == true) {
          recipientName =
              _currentEmail.bcc!.first['displayName'] ??
              _currentEmail.bcc!.first['email'] ??
              recipientName;
        }
        nameToDisplay = 'To: $recipientName';
        break;
      case EmailFolder.drafts:
        nameToDisplay = "Draft";
        displayNameColor = AppColors.error;
        break;
      default:
        nameToDisplay =
            _currentEmail.from['displayName'] ?? _currentEmail.senderName;
        if (_currentEmail.originalFolder == EmailFolder.drafts) {
          nameToDisplay = "Draft";
          displayNameColor = AppColors.error;
        } else if (_currentEmail.originalFolder == EmailFolder.sent) {
          String recipientName = "Unknown Recipient";
          if (_currentEmail.to.isNotEmpty) {
            recipientName =
                _currentEmail.to.first['displayName'] ??
                _currentEmail.to.first['email'] ??
                recipientName;
          }
          nameToDisplay = 'To: $recipientName';
        }
        break;
    }
    if (nameToDisplay.isEmpty) nameToDisplay = "Unknown";

    String initialLetter = "?";
    if (_nameForAvatarAndInitial != null &&
        _nameForAvatarAndInitial!.isNotEmpty &&
        _nameForAvatarAndInitial != "Unknown Sender" &&
        _nameForAvatarAndInitial != "Unknown Recipient" &&
        _nameForAvatarAndInitial != "Unknown") {
      initialLetter = _nameForAvatarAndInitial![0].toUpperCase();
    } else if (nameToDisplay.isNotEmpty &&
        nameToDisplay != "Unknown" &&
        !nameToDisplay.startsWith("To:")) {
      initialLetter = nameToDisplay[0].toUpperCase();
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
              (bottomSheetContext) => SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.currentScreenFolder == EmailFolder.inbox ||
                        (widget.currentScreenFolder == EmailFolder.trash &&
                            _currentEmail.originalFolder == EmailFolder.inbox))
                      ListTile(
                        leading: Icon(
                          _currentEmail.isRead
                              ? Icons.mark_email_unread_outlined
                              : Icons.mark_email_read_outlined,
                          color:
                              _currentEmail.isRead
                                  ? AppColors.secondaryIcon
                                  : AppColors.primary,
                        ),
                        title: Text(
                          _currentEmail.isRead
                              ? 'Mark as unread'
                              : 'Mark as read',
                        ),
                        onTap: () async {
                          Navigator.pop(bottomSheetContext);
                          await _toggleReadStatus(bottomSheetContext);
                        },
                      ),
                    ListTile(
                      leading: Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.error,
                      ),
                      title: Text(
                        widget.currentScreenFolder == EmailFolder.trash
                            ? 'Delete Permanently'
                            : 'Delete',
                      ),
                      onTap: () async {
                        Navigator.pop(bottomSheetContext);
                        await _deleteEmail(bottomSheetContext);
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
              (isUnread && !isActuallyDraftDisplay)
                  ? AppColors.primary.withOpacity(0.05)
                  : Colors.transparent,
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade200, width: 0.5),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _isLoadingProfileInfo
                ? CircleAvatar(
                  backgroundColor: Colors.blueGrey[100],
                  child: const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
                )
                : CircleAvatar(
                  key: ValueKey<String?>(_photoUrl ?? _nameForAvatarAndInitial),
                  backgroundColor:
                      (isUnread && !isActuallyDraftDisplay)
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
                                  (isUnread && !isActuallyDraftDisplay) ||
                                          isActuallyDraftDisplay
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
                      fontWeight: displayNameFontWeight,
                      fontSize: 16,
                      color: displayNameColor,
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
                        : '(No content)',
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
                    color:
                        (isUnread && !isActuallyDraftDisplay)
                            ? AppColors.primary
                            : Colors.grey[700],
                    fontWeight:
                        (isUnread && !isActuallyDraftDisplay)
                            ? FontWeight.bold
                            : FontWeight.normal,
                  ),
                ),
                if (isUnread && !isActuallyDraftDisplay)
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
