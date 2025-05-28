import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:email_application/models/email_data.dart';
import 'package:email_application/models/email_folder.dart';
import 'package:email_application/models/label_data.dart';
import 'package:email_application/services/auth_service.dart';
import 'package:email_application/services/firestore_service.dart';
import 'package:intl/intl.dart';
import 'package:email_application/config/app_colors.dart';

class EmailListItem extends StatefulWidget {
  final EmailData email;
  final EmailFolder currentScreenFolder;
  final List<LabelData> allUserLabels;
  final VoidCallback? onTap;
  final VoidCallback? onReadStatusChanged;
  final VoidCallback? onDeleteOrMove;
  final VoidCallback? onStarStatusChanged;

  const EmailListItem({
    super.key,
    required this.email,
    required this.currentScreenFolder,
    required this.allUserLabels,
    this.onTap,
    this.onReadStatusChanged,
    this.onDeleteOrMove,
    this.onStarStatusChanged,
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

  bool listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  void didUpdateWidget(covariant EmailListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    bool emailContentChanged =
        widget.email.id != oldWidget.email.id ||
        widget.email.subject != oldWidget.email.subject ||
        widget.email.previewText != oldWidget.email.previewText ||
        widget.email.isStarred != oldWidget.email.isStarred ||
        widget.email.isRead != _currentEmail.isRead ||
        !listEquals(widget.email.labelIds, oldWidget.email.labelIds);

    if (emailContentChanged) {
      setState(() {
        _currentEmail = widget.email;
      });
    }

    bool profileContextChanged =
        widget.email.from['userId'] != oldWidget.email.from['userId'] ||
        (widget.email.to.isNotEmpty &&
            oldWidget.email.to.isNotEmpty &&
            widget.email.to.first['userId'] !=
                oldWidget.email.to.first['userId']) ||
        (widget.email.to.isEmpty && oldWidget.email.to.isNotEmpty) ||
        (widget.email.to.isNotEmpty && oldWidget.email.to.isEmpty) ||
        widget.currentScreenFolder != oldWidget.currentScreenFolder ||
        widget.email.originalFolder != oldWidget.email.originalFolder;

    if (profileContextChanged) {
      _fetchRelevantProfileInfo();
    }

    if (!listEquals(widget.allUserLabels, oldWidget.allUserLabels)) {
      if (mounted) setState(() {});
    }
  }

  Future<void> _fetchRelevantProfileInfo() async {
    if (!mounted) return;
    setState(() {
      _isLoadingProfileInfo = true;
    });

    String? contactIdToLookup;
    String nameForInitialFallback = "Unknown";

    final effectiveFolder =
        widget.currentScreenFolder == EmailFolder.trash &&
                _currentEmail.originalFolder != null
            ? _currentEmail.originalFolder!
            : widget.currentScreenFolder;

    final currentUser =
        Provider.of<AuthService>(context, listen: false).currentUser;

    switch (effectiveFolder) {
      case EmailFolder.inbox:
        contactIdToLookup = _currentEmail.from['userId'];
        nameForInitialFallback =
            _currentEmail.from['displayName'] ?? 'Unknown Sender';
        break;
      case EmailFolder.sent:
        if (_currentEmail.to.isNotEmpty) {
          contactIdToLookup = _currentEmail.to.first['userId'];
          nameForInitialFallback =
              _currentEmail.to.first['displayName'] ?? 'Unknown Recipient';
        } else if (_currentEmail.cc?.isNotEmpty == true) {
          contactIdToLookup = _currentEmail.cc!.first['userId'];
          nameForInitialFallback =
              _currentEmail.cc!.first['displayName'] ?? 'Unknown Recipient';
        } else if (_currentEmail.bcc?.isNotEmpty == true) {
          contactIdToLookup = _currentEmail.bcc!.first['userId'];
          nameForInitialFallback =
              _currentEmail.bcc!.first['displayName'] ?? 'Unknown Recipient';
        } else {
          nameForInitialFallback = 'To: (No recipients)';
        }
        break;
      case EmailFolder.drafts:
        if (currentUser != null) {
          contactIdToLookup = currentUser.uid;
          nameForInitialFallback =
              currentUser.displayName ?? (currentUser.email ?? 'Me');
          if (mounted) {
            setState(() {
              _nameForAvatarAndInitial = nameForInitialFallback;
              _photoUrl = currentUser.photoURL;
              _isLoadingProfileInfo = false;
            });
          }
          return;
        } else {
          nameForInitialFallback = "Draft";
        }
        break;
      default:
        EmailFolder contextFolderForDisplay = _currentEmail.folder;
        if (_currentEmail.folder == EmailFolder.trash &&
            _currentEmail.originalFolder != null) {
          contextFolderForDisplay = _currentEmail.originalFolder!;
        }

        if (contextFolderForDisplay == EmailFolder.sent ||
            contextFolderForDisplay == EmailFolder.drafts) {
          if (currentUser != null &&
              _currentEmail.from['userId'] == currentUser.uid) {
            nameForInitialFallback =
                _currentEmail.to.isNotEmpty
                    ? (_currentEmail.to.first['displayName'] ??
                        'Unknown Recipient')
                    : 'To: (No recipients)';
            contactIdToLookup =
                _currentEmail.to.isNotEmpty
                    ? _currentEmail.to.first['userId']
                    : null;
          } else if (contextFolderForDisplay == EmailFolder.drafts) {
            nameForInitialFallback = "Draft";
            contactIdToLookup = _currentEmail.from['userId'];
          } else {
            contactIdToLookup = _currentEmail.from['userId'];
            nameForInitialFallback =
                _currentEmail.from['displayName'] ?? 'Unknown';
          }
        } else {
          contactIdToLookup = _currentEmail.from['userId'];
          nameForInitialFallback =
              _currentEmail.from['displayName'] ?? 'Unknown';
        }
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
        "EmailListItem (${_currentEmail.id}): Error fetching profile for contactId '$contactIdToLookup': $e",
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

  Future<void> _toggleReadStatus(BuildContext itemContext) async {
    if (widget.currentScreenFolder == EmailFolder.drafts ||
        widget.currentScreenFolder == EmailFolder.sent)
      return;

    final firestoreService = Provider.of<FirestoreService>(
      itemContext,
      listen: false,
    );
    final userId =
        Provider.of<AuthService>(itemContext, listen: false).currentUser?.uid;

    if (userId == null || !mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.of(itemContext);

    try {
      bool newReadStatus = !_currentEmail.isRead;
      await firestoreService.markEmailAsRead(
        userId: userId,
        emailId: _currentEmail.id,
        isRead: newReadStatus,
      );
      if (mounted) {
        setState(() {
          _currentEmail = _currentEmail.copyWith(isRead: newReadStatus);
        });
        widget.onReadStatusChanged?.call();
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Error changing read status: ${e.toString()}'),
          ),
        );
      }
    }
  }

  Future<void> _deleteEmail(BuildContext itemContext) async {
    final firestoreService = Provider.of<FirestoreService>(
      itemContext,
      listen: false,
    );
    final userId =
        Provider.of<AuthService>(itemContext, listen: false).currentUser?.uid;

    if (userId == null || !mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.of(itemContext);

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

    if (confirmed != true || !mounted) return;

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
        if (_currentEmail.folder == EmailFolder.trash &&
            _currentEmail.originalFolder != null) {
          folderToSaveAsOriginal = _currentEmail.originalFolder!;
        }
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

  Future<void> _toggleStarStatus(BuildContext itemContext) async {
    final firestoreService = Provider.of<FirestoreService>(
      itemContext,
      listen: false,
    );
    final userId =
        Provider.of<AuthService>(itemContext, listen: false).currentUser?.uid;

    if (userId == null || !mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.of(itemContext);

    try {
      bool newIsStarredState = !_currentEmail.isStarred;
      await firestoreService.toggleStarStatus(
        userId: userId,
        emailId: _currentEmail.id,
        newIsStarredState: newIsStarredState,
      );
      if (mounted) {
        setState(() {
          _currentEmail = _currentEmail.copyWith(isStarred: newIsStarredState);
        });
        widget.onStarStatusChanged?.call();
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Error updating star status: ${e.toString()}'),
          ),
        );
      }
    }
  }

  Widget _buildLabelChips() {
    if (_currentEmail.labelIds.isEmpty || widget.allUserLabels.isEmpty) {
      return const SizedBox.shrink();
    }
    List<Widget> chips = [];
    for (String labelId in _currentEmail.labelIds) {
      LabelData? foundLabel;
      try {
        foundLabel = widget.allUserLabels.firstWhere((l) => l.id == labelId);
      } catch (e) {}

      if (foundLabel != null) {
        final Color chipBackgroundColor = foundLabel.color.withOpacity(0.18);
        final Color chipTextColor = Colors.black87;
        chips.add(
          Padding(
            padding: const EdgeInsets.only(right: 5.0, top: 4.0),
            child: Chip(
              label: Text(
                foundLabel.name,
                style: TextStyle(
                  fontSize: 10.5,
                  color: chipTextColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              backgroundColor: chipBackgroundColor,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(
                horizontal: 7.0,
                vertical: 1.0,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
                side: BorderSide(
                  color: foundLabel.color.withOpacity(0.6),
                  width: 1.0,
                ),
              ),
            ),
          ),
        );
      }
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 3.0, runSpacing: 2.0, children: chips);
  }

  Future<void> _showLabelSelectionDialogForListItem(
    BuildContext parentContext,
  ) async {
    final String? currentUserId =
        Provider.of<AuthService>(parentContext, listen: false).currentUser?.uid;
    final FirestoreService firestoreService = Provider.of<FirestoreService>(
      parentContext,
      listen: false,
    );
    final ScaffoldMessengerState scaffoldMessenger = ScaffoldMessenger.of(
      parentContext,
    );

    if (currentUserId == null) {
      if (mounted)
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text("Please log in.")),
        );
      return;
    }

    List<String> selectedLabelIds = List<String>.from(_currentEmail.labelIds);
    bool dialogActionPerformed = false;

    bool? saved = await showDialog<bool>(
      context: parentContext,
      builder: (BuildContext dialogContext) {
        bool localChangesMade = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Label'),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 0,
                vertical: 20,
              ),
              content: SizedBox(
                width: double.maxFinite,
                child:
                    widget.allUserLabels.isEmpty
                        ? const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24.0),
                          child: Text(
                            "No labels created yet. Go to 'Manage Labels' to create some.",
                          ),
                        )
                        : ListView.builder(
                          shrinkWrap: true,
                          itemCount: widget.allUserLabels.length,
                          itemBuilder: (lbContext, index) {
                            final label = widget.allUserLabels[index];
                            final bool isSelected = selectedLabelIds.contains(
                              label.id,
                            );
                            return CheckboxListTile(
                              title: Text(
                                label.name,
                                style: const TextStyle(fontSize: 15),
                              ),
                              value: isSelected,
                              onChanged: (bool? value) {
                                setDialogState(() {
                                  if (value == true) {
                                    if (!isSelected)
                                      selectedLabelIds.add(label.id);
                                  } else {
                                    selectedLabelIds.remove(label.id);
                                  }
                                  localChangesMade = true;
                                });
                              },
                              secondary: Icon(Icons.label, color: label.color),
                              controlAffinity: ListTileControlAffinity.leading,
                              dense: true,
                            );
                          },
                        ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  child: Text(
                    'Apply',
                    style: TextStyle(color: AppColors.onPrimary),
                  ),
                  onPressed: () {
                    Navigator.of(dialogContext).pop(true);
                  },
                ),
              ],
            );
          },
        );
      },
    );

    if (saved == true) {
      bool hasActualChanges =
          !listEquals(_currentEmail.labelIds, selectedLabelIds);

      if (hasActualChanges) {
        if (!mounted) return;
        try {
          await firestoreService.updateEmailLabels(
            currentUserId,
            _currentEmail.id,
            selectedLabelIds,
          );
          if (mounted) {
            setState(() {
              _currentEmail = _currentEmail.copyWith(
                labelIds: selectedLabelIds,
              );
            });
            widget.onStarStatusChanged?.call();
            scaffoldMessenger.showSnackBar(
              const SnackBar(
                content: Text('Labels updated!'),
                duration: Duration(seconds: 1),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            scaffoldMessenger.showSnackBar(
              SnackBar(content: Text('Error updating labels: ${e.toString()}')),
            );
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isUnread = !_currentEmail.isRead;
    final bool isStarred = _currentEmail.isStarred;

    final EmailFolder displayContextFolder =
        (widget.currentScreenFolder == EmailFolder.trash &&
                _currentEmail.originalFolder != null)
            ? _currentEmail.originalFolder!
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

    String nameToDisplay = _nameForAvatarAndInitial ?? "Unknown";
    switch (displayContextFolder) {
      case EmailFolder.inbox:
        nameToDisplay =
            _nameForAvatarAndInitial ??
            _currentEmail.from['displayName'] ??
            _currentEmail.senderName;
        break;
      case EmailFolder.sent:
        nameToDisplay = _nameForAvatarAndInitial ?? 'To: (Error)';
        break;
      case EmailFolder.drafts:
        nameToDisplay = "Draft";
        displayNameColor = AppColors.error;
        break;
      default:
        nameToDisplay =
            _nameForAvatarAndInitial ??
            _currentEmail.from['displayName'] ??
            _currentEmail.senderName;
        if (_currentEmail.originalFolder == EmailFolder.drafts &&
            displayContextFolder == EmailFolder.trash) {
          nameToDisplay = "Draft";
          displayNameColor = AppColors.error;
        }
        break;
    }
    if (nameToDisplay.isEmpty) nameToDisplay = "Unknown";

    String initialLetter = "?";
    if (_nameForAvatarAndInitial != null &&
        _nameForAvatarAndInitial!.isNotEmpty &&
        _nameForAvatarAndInitial != "Unknown Sender" &&
        _nameForAvatarAndInitial != "Unknown Recipient" &&
        !_nameForAvatarAndInitial!.startsWith("To:") &&
        _nameForAvatarAndInitial != "Draft" &&
        _nameForAvatarAndInitial != "Unknown") {
      initialLetter = _nameForAvatarAndInitial![0].toUpperCase();
    } else if (nameToDisplay.isNotEmpty &&
        nameToDisplay != "Unknown" &&
        !nameToDisplay.startsWith("To:") &&
        nameToDisplay != "Draft") {
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
              (bottomSheetCtxt) => SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: Icon(
                        isStarred ? Icons.star : Icons.star_border,
                        color:
                            isStarred
                                ? AppColors.accent
                                : AppColors.secondaryIcon,
                      ),
                      title: Text(isStarred ? 'Unstar email' : 'Star email'),
                      onTap: () async {
                        Navigator.pop(bottomSheetCtxt);
                        await _toggleStarStatus(context);
                      },
                    ),
                    ListTile(
                      leading: const Icon(
                        Icons.label_outline_rounded,
                        color: AppColors.secondaryIcon,
                      ),
                      title: const Text('Label'),
                      onTap: () {
                        Navigator.pop(bottomSheetCtxt);
                        _showLabelSelectionDialogForListItem(context);
                      },
                    ),
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
                          Navigator.pop(bottomSheetCtxt);
                          await _toggleReadStatus(context);
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
                            : 'Move to Trash',
                      ),
                      onTap: () async {
                        Navigator.pop(bottomSheetCtxt);
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
                  backgroundColor: Colors.blueGrey[50],
                  child: const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
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
                  _buildLabelChips(),
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
                const SizedBox(height: 4),
                InkResponse(
                  onTap: () => _toggleStarStatus(context),
                  radius: 20,
                  child: Padding(
                    padding: const EdgeInsets.all(2.0),
                    child: Icon(
                      isStarred ? Icons.star : Icons.star_border,
                      color: isStarred ? AppColors.accent : Colors.grey[400],
                      size: 22.0,
                    ),
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
