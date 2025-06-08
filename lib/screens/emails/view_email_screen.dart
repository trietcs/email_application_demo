import 'package:email_application/screens/attachments/attachment_viewer_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:email_application/models/email_data.dart';
import 'package:email_application/models/email_folder.dart';
import 'package:email_application/services/auth_service.dart';
import 'package:email_application/services/firestore_service.dart';
import 'package:email_application/screens/compose/compose_email_screen.dart';
import 'package:email_application/config/app_colors.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:collection';
import 'package:email_application/models/label_data.dart';

class ViewEmailScreen extends StatefulWidget {
  final EmailData emailData;

  const ViewEmailScreen({super.key, required this.emailData});

  @override
  State<ViewEmailScreen> createState() => _ViewEmailScreenState();
}

class _ViewEmailScreenState extends State<ViewEmailScreen> {
  late EmailData _currentEmailData;
  bool _isProcessingAction = false;
  bool _showDetails = false;
  String? _currentUserEmail;
  String? _currentUserId;
  String? _senderPhotoUrl;
  bool _isLoadingSenderProfile = true;
  String? _senderDisplayableEmail;

  final double _labelWidth = 55.0;
  final EdgeInsets _detailItemPadding = const EdgeInsets.symmetric(
    vertical: 4.0,
  );
  bool _starStatusChanged = false;

  List<LabelData> _userLabels = [];
  bool _isLoadingLabels = false;

  @override
  void initState() {
    super.initState();
    _currentEmailData = widget.emailData;
    final authService = Provider.of<AuthService>(context, listen: false);
    _currentUserEmail = authService.currentUser?.email;
    _currentUserId = authService.currentUser?.uid;
    _markEmailAsReadOnOpen();
    _fetchSenderProfile();
    _fetchUserLabels();
  }

  Future<void> _fetchUserLabels() async {
    if (_currentUserId == null) return;
    if (mounted) setState(() => _isLoadingLabels = true);
    try {
      final firestoreService = Provider.of<FirestoreService>(
        context,
        listen: false,
      );
      _userLabels = await firestoreService.getLabelsForUser(_currentUserId!);
    } catch (e) {
      print("Error fetching user labels: $e");
    } finally {
      if (mounted) setState(() => _isLoadingLabels = false);
    }
  }

  Future<void> _fetchSenderProfile() async {
    final String? senderId = _currentEmailData.from['userId'];

    if (senderId == null || senderId.isEmpty) {
      if (mounted) {
        print(
          "ViewEmailScreen: Sender UID is empty for email ID: ${widget.emailData.id}. Cannot fetch profile.",
        );
        setState(() {
          _senderDisplayableEmail =
              _currentEmailData.from['email'] ?? _currentEmailData.senderName;
          _isLoadingSenderProfile = false;
        });
      }
      return;
    }

    if (!mounted) return;
    setState(() => _isLoadingSenderProfile = true);

    try {
      final firestoreService = Provider.of<FirestoreService>(
        context,
        listen: false,
      );
      final profile = await firestoreService.getUserProfile(senderId);
      if (mounted) {
        setState(() {
          _senderPhotoUrl = profile?['photoURL'] as String?;
          _senderDisplayableEmail =
              profile?['customEmail'] as String? ??
              _currentEmailData.from['email'] ??
              senderId;
          _isLoadingSenderProfile = false;
        });
      }
    } catch (e) {
      print("Error fetching sender profile for UID $senderId: $e");
      if (mounted) {
        setState(() {
          _senderDisplayableEmail = _currentEmailData.from['email'] ?? senderId;
          _senderPhotoUrl = null;
          _isLoadingSenderProfile = false;
        });
      }
    }
  }

  Future<void> _markEmailAsReadOnOpen() async {
    if (!mounted) return;
    if ((_currentEmailData.folder == EmailFolder.inbox ||
            _currentEmailData.folder == EmailFolder.trash) &&
        _currentEmailData.id.isNotEmpty &&
        !_currentEmailData.isRead) {
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
        } catch (e) {
          print("Error marking email as read in ViewEmailScreen: $e");
        }
      }
    }
  }

  String _formatShortDate(String dateTimeString) {
    try {
      final dateTime = DateTime.parse(dateTimeString).toLocal();
      return DateFormat('MMM dd', 'en_US').format(dateTime);
    } catch (e) {
      return dateTimeString;
    }
  }

  String _formatFullDateTime(String dateTimeString) {
    try {
      final dateTime = DateTime.parse(dateTimeString).toLocal();
      return DateFormat("d MMMM yyyy 'at' HH:mm", 'en_US').format(dateTime);
    } catch (e) {
      print("Error formatting full date time: $e for string: $dateTimeString");
      return dateTimeString;
    }
  }

  Future<void> _handleDeleteEmail() async {
    if (!mounted || _isProcessingAction) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );
    final User? currentUser =
        Provider.of<AuthService>(context, listen: false).currentUser;

    if (currentUser == null) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('User not logged in.')),
      );
      return;
    }
    bool isPermanentDelete = _currentEmailData.folder == EmailFolder.trash;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
            isPermanentDelete
                ? 'Confirm Permanent Deletion'
                : 'Confirm Deletion',
          ),
          content: Text(
            isPermanentDelete
                ? 'Are you sure you want to permanently delete this email?'
                : 'Are you sure you want to move this email to the trash?',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            TextButton(
              child: Text(
                isPermanentDelete ? 'Delete Permanently' : 'Move to Trash',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;
    setState(() => _isProcessingAction = true);
    try {
      if (isPermanentDelete) {
        await firestoreService.deleteEmailPermanently(
          userId: currentUser.uid,
          emailId: _currentEmailData.id,
        );
      } else {
        await firestoreService.deleteEmail(
          userId: currentUser.uid,
          emailId: _currentEmailData.id,
          currentFolder: _currentEmailData.folder,
          targetFolder: EmailFolder.trash,
        );
      }
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            isPermanentDelete
                ? 'Email permanently deleted'
                : 'Email moved to trash',
          ),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted)
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  Future<void> _toggleReadStatus() async {
    if (!mounted || _isProcessingAction || _currentEmailData.id.isEmpty) return;
    if (_currentEmailData.folder != EmailFolder.inbox) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Read status can only be changed for inbox emails.'),
        ),
      );
      return;
    }

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
      } finally {
        if (mounted) setState(() => _isProcessingAction = false);
      }
    } else {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('User not found.')),
        );
        setState(() => _isProcessingAction = false);
      }
    }
  }

  Future<void> _toggleStar() async {
    if (!mounted || _isProcessingAction || _currentEmailData.id.isEmpty) return;

    setState(() => _isProcessingAction = true);
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );

    if (user != null) {
      final newIsStarredState = !_currentEmailData.isStarred;
      try {
        await firestoreService.toggleStarStatus(
          userId: user.uid,
          emailId: _currentEmailData.id,
          newIsStarredState: newIsStarredState,
        );
        if (!mounted) return;
        setState(() {
          _currentEmailData = _currentEmailData.copyWith(
            isStarred: newIsStarredState,
          );
          _starStatusChanged = true;
        });
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating star status: $e')),
          );
      } finally {
        if (mounted) setState(() => _isProcessingAction = false);
      }
    } else {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('User not found.')));
      if (mounted) setState(() => _isProcessingAction = false);
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
    ).then((_) => _refreshDataIfNeeded());
  }

  void _handleForwardEmail() {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ComposeEmailScreen(forwardEmail: _currentEmailData),
      ),
    ).then((_) => _refreshDataIfNeeded());
  }

  void _refreshDataIfNeeded() {}

  void _viewAttachment(Map<String, String> attachment) {
    if (!mounted) return;
    final String? url = attachment['url'];
    final String name = attachment['name'] ?? 'Attachment';
    final String? mimeType = attachment['mimeType'];

    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attachment URL is missing.')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => AttachmentViewerScreen(
              attachmentUrl: url,
              attachmentName: name,
              attachmentMimeType: mimeType,
            ),
      ),
    );
  }

  String _getFirstName(String? fullName) {
    if (fullName == null || fullName.trim().isEmpty) {
      return "Unknown";
    }
    return fullName.trim().split(' ').first;
  }

  Widget _buildRecipientSummary(ThemeData theme) {
    List<String> toCcDisplayNames = [];
    bool currentUserIsInToCc = false;

    for (var recipient in _currentEmailData.to) {
      if (recipient['userId'] == _currentUserId ||
          recipient['email'] == _currentUserEmail) {
        if (!currentUserIsInToCc) {
          toCcDisplayNames.add("me");
          currentUserIsInToCc = true;
        }
      } else {
        toCcDisplayNames.add(_getFirstName(recipient['displayName']));
      }
    }

    if (_currentEmailData.cc != null) {
      for (var recipient in _currentEmailData.cc!) {
        if (recipient['userId'] == _currentUserId ||
            recipient['email'] == _currentUserEmail) {
          if (!currentUserIsInToCc) {
            toCcDisplayNames.add("me");
            currentUserIsInToCc = true;
          }
        } else {
          toCcDisplayNames.add(_getFirstName(recipient['displayName']));
        }
      }
    }

    List<String> uniqueDisplayNames = [];
    if (currentUserIsInToCc) {
      uniqueDisplayNames.add("me");
    }
    for (String name in toCcDisplayNames) {
      if (name != "me" && !uniqueDisplayNames.contains(name)) {
        uniqueDisplayNames.add(name);
      }
    }
    const maxNamesToShow = 2;
    String toCcSummary = "";
    if (uniqueDisplayNames.isNotEmpty) {
      if (uniqueDisplayNames.length > maxNamesToShow) {
        toCcSummary =
            "to ${uniqueDisplayNames.take(maxNamesToShow).join(', ')}, ...";
      } else {
        toCcSummary = "to ${uniqueDisplayNames.join(', ')}";
      }
    }

    String bccSummarySegment = "";
    bool currentUserIsInBccList =
        _currentEmailData.bcc?.any(
          (r) =>
              r['userId'] == _currentUserId || r['email'] == _currentUserEmail,
        ) ??
        false;

    final bool isCurrentUserTheOriginalSender =
        _currentUserId != null &&
        _currentEmailData.from['userId'] == _currentUserId;

    if (currentUserIsInBccList && !isCurrentUserTheOriginalSender) {
      if (toCcSummary.isNotEmpty) {
        if (!currentUserIsInToCc) {
          bccSummarySegment = (toCcSummary.isEmpty ? "bcc: me" : ", bcc: me");
        }
      } else {
        return Text(
          "bcc: me",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium,
        );
      }
    }

    String finalSummary = toCcSummary + bccSummarySegment;

    if (finalSummary.isEmpty) {
      List<String> allRecipientFirstNames = [];
      _currentEmailData.to.forEach(
        (r) => allRecipientFirstNames.add(_getFirstName(r['displayName'])),
      );
      _currentEmailData.cc?.forEach(
        (r) => allRecipientFirstNames.add(_getFirstName(r['displayName'])),
      );

      if (allRecipientFirstNames.isNotEmpty) {
        finalSummary =
            "to ${LinkedHashSet<String>.from(allRecipientFirstNames).toList().join(', ')}";
      } else {
        return const SizedBox.shrink();
      }
    }

    if (finalSummary.startsWith(", ")) {
      finalSummary = finalSummary.substring(2);
    }

    return Text(
      finalSummary,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodyMedium,
    );
  }

  Widget _buildDetailedRecipientInfo(
    String label,
    List<Map<String, String>> recipients,
    ThemeData theme, {
    bool hideLabelColon = false,
  }) {
    if (recipients.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: _detailItemPadding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: _labelWidth,
            child: Text(
              hideLabelColon ? label : '$label:',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children:
                  recipients.map((r) {
                    String name = r['displayName'] ?? 'Unknown Name';
                    String email =
                        r['email'] ?? r['userId'] ?? 'Email not available';
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom:
                            recipients.indexOf(r) < recipients.length - 1
                                ? 4.0
                                : 0.0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            email,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBccEntry(ThemeData theme) {
    final bool isCurrentUserTheOriginalSender =
        _currentUserId != null &&
        _currentEmailData.from['userId'] == _currentUserId;

    if (_currentEmailData.bcc == null || _currentEmailData.bcc!.isEmpty) {
      return const SizedBox.shrink();
    }

    if (isCurrentUserTheOriginalSender) {
      return _buildDetailedRecipientInfo("Bcc", _currentEmailData.bcc!, theme);
    } else {
      if (_currentUserId == null || _currentUserEmail == null) {
        return const SizedBox.shrink();
      }
      final bool isCurrentUserInBccList = _currentEmailData.bcc!.any(
        (r) => r['userId'] == _currentUserId || r['email'] == _currentUserEmail,
      );

      if (isCurrentUserInBccList) {
        return Padding(
          padding: _detailItemPadding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: _labelWidth,
                child: Text(
                  'Bcc:',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'me',
                      style: theme.textTheme.bodyLarge?.copyWith(fontSize: 14),
                    ),
                    Text(
                      _currentUserEmail!,
                      style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      } else {
        return const SizedBox.shrink();
      }
    }
  }

  Future<void> _showManageLabelsDialog() async {
    if (_currentUserId == null || !mounted) return;

    final scaffoldMessenger = ScaffoldMessenger.of(this.context);
    final firestoreService = Provider.of<FirestoreService>(
      this.context,
      listen: false,
    );
    final String currentUserIdForDialog = _currentUserId!;
    final String currentEmailIdForDialog = _currentEmailData.id;

    if (_isLoadingLabels) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text("Labels are loading, please wait...")),
      );
      return;
    }

    List<String> selectedLabelIds = List<String>.from(
      _currentEmailData.labelIds,
    );

    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Manage Labels'),
              content: SizedBox(
                width: double.maxFinite,
                child:
                    _userLabels.isEmpty
                        ? const Text(
                          "No labels created yet. You can create them in 'Manage Labels' screen.",
                        )
                        : ListView.builder(
                          shrinkWrap: true,
                          itemCount: _userLabels.length,
                          itemBuilder: (lbContext, index) {
                            final label = _userLabels[index];
                            final bool isSelected = selectedLabelIds.contains(
                              label.id,
                            );
                            return CheckboxListTile(
                              title: Text(label.name),
                              value: isSelected,
                              onChanged: (bool? value) {
                                setDialogState(() {
                                  if (value == true) {
                                    if (!isSelected)
                                      selectedLabelIds.add(label.id);
                                  } else {
                                    selectedLabelIds.remove(label.id);
                                  }
                                });
                              },
                              secondary: Icon(Icons.label, color: label.color),
                              controlAffinity: ListTileControlAffinity.leading,
                            );
                          },
                        ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                ElevatedButton(
                  child: Text('Save'),
                  onPressed: () async {
                    Navigator.of(dialogContext).pop();

                    if (!mounted) return;

                    setState(() => _isProcessingAction = true);
                    try {
                      await firestoreService.updateEmailLabels(
                        currentUserIdForDialog,
                        currentEmailIdForDialog,
                        selectedLabelIds,
                      );
                      if (!mounted) return;
                      setState(() {
                        _currentEmailData = _currentEmailData.copyWith(
                          labelIds: selectedLabelIds,
                        );
                      });
                      scaffoldMessenger.showSnackBar(
                        const SnackBar(
                          content: Text('Labels updated successfully!'),
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      scaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            'Error updating labels: ${e.toString()}',
                          ),
                        ),
                      );
                    } finally {
                      if (mounted) {
                        setState(() => _isProcessingAction = false);
                      }
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildAppliedLabels(ThemeData theme) {
    if (_currentEmailData.labelIds.isEmpty || _userLabels.isEmpty) {
      return const SizedBox.shrink();
    }
    List<Widget> labelChips = [];
    for (String labelId in _currentEmailData.labelIds) {
      final labelData = _userLabels.firstWhere(
        (l) => l.id == labelId,
        orElse: () => LabelData(id: '', name: 'Unknown', color: Colors.grey),
      );
      if (labelData.name != 'Unknown') {
        labelChips.add(
          Padding(
            padding: const EdgeInsets.only(right: 6.0, top: 4.0),
            child: Chip(
              label: Text(labelData.name, style: const TextStyle(fontSize: 11)),
              backgroundColor: labelData.color.withOpacity(0.2),
              avatar: CircleAvatar(backgroundColor: labelData.color, radius: 6),
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 2.0,
              ),
              labelStyle: TextStyle(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: labelData.color.withOpacity(0.5)),
              ),
            ),
          ),
        );
      }
    }
    if (labelChips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Wrap(children: labelChips),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String headerDisplayName;
    String emailForFromLineInDetails =
        _senderDisplayableEmail ??
        _currentEmailData.from['email'] ??
        _currentEmailData.senderUid;

    final bool isCurrentUserTheSender =
        _currentUserId != null &&
        _currentEmailData.from['userId'] == _currentUserId;

    if (isCurrentUserTheSender) {
      headerDisplayName = "Me";
    } else {
      headerDisplayName =
          _currentEmailData.from['displayName'] ?? _currentEmailData.senderName;
    }

    String nameForAvatarInitials = headerDisplayName;
    if (headerDisplayName == "Me") {
      final currentUser =
          Provider.of<AuthService>(context, listen: false).currentUser;
      nameForAvatarInitials =
          currentUser?.displayName ?? currentUser?.email ?? "Me";
    }

    return WillPopScope(
      onWillPop: () async {
        bool readStatusChanged =
            _currentEmailData.isRead != widget.emailData.isRead;
        bool anythingChanged = readStatusChanged || _starStatusChanged;
        Navigator.pop(context, anythingChanged);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              bool readStatusChanged =
                  _currentEmailData.isRead != widget.emailData.isRead;
              bool anythingChanged = readStatusChanged || _starStatusChanged;
              Navigator.pop(context, anythingChanged);
            },
          ),
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
                icon: const Icon(Icons.label_outline_rounded),
                tooltip: 'Manage Labels',
                onPressed: _showManageLabelsDialog,
              ),
              IconButton(
                icon: Icon(
                  _currentEmailData.isStarred ? Icons.star : Icons.star_border,
                  color:
                      _currentEmailData.isStarred
                          ? AppColors.accent
                          : theme.iconTheme.color?.withOpacity(0.7),
                ),
                tooltip:
                    _currentEmailData.isStarred ? 'Unstar email' : 'Star email',
                onPressed: _toggleStar,
              ),
              if (_currentEmailData.folder == EmailFolder.inbox)
                IconButton(
                  icon: Icon(
                    _currentEmailData.isRead
                        ? Icons.mark_email_read_outlined
                        : Icons.mark_email_unread_outlined,
                  ),
                  tooltip:
                      _currentEmailData.isRead
                          ? 'Mark as unread'
                          : 'Mark as read',
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
              _buildAppliedLabels(theme),
              const SizedBox(height: 4),

              Text(
                _currentEmailData.subject.isNotEmpty
                    ? _currentEmailData.subject
                    : '(No Subject)',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _isLoadingSenderProfile
                      ? CircleAvatar(
                        backgroundColor: theme.primaryColor.withOpacity(0.1),
                        child: const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                      : CircleAvatar(
                        backgroundColor: theme.primaryColor.withOpacity(0.1),
                        backgroundImage:
                            (_senderPhotoUrl != null &&
                                    _senderPhotoUrl!.isNotEmpty)
                                ? NetworkImage(_senderPhotoUrl!)
                                : null,
                        child:
                            (_senderPhotoUrl == null ||
                                    _senderPhotoUrl!.isEmpty)
                                ? Text(
                                  (nameForAvatarInitials.isNotEmpty
                                          ? nameForAvatarInitials[0]
                                          : '?')
                                      .toUpperCase(),
                                  style: TextStyle(
                                    color: theme.primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                                : null,
                      ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                headerDisplayName,
                                style: theme.textTheme.titleMedium,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatShortDate(_currentEmailData.time),
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        GestureDetector(
                          onTap:
                              () =>
                                  setState(() => _showDetails = !_showDetails),
                          child: Row(
                            children: [
                              Expanded(child: _buildRecipientSummary(theme)),
                              Icon(
                                _showDetails
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                size: 20,
                                color: theme.textTheme.bodyMedium?.color,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_showDetails)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(height: 12),
                      Padding(
                        padding: _detailItemPadding,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: _labelWidth,
                              child: Text(
                                'From:',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _currentEmailData.from['displayName'] ??
                                        _currentEmailData.senderName,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    emailForFromLineInDetails,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildDetailedRecipientInfo(
                        'To',
                        _currentEmailData.to,
                        theme,
                      ),
                      if (_currentEmailData.cc?.isNotEmpty ?? false)
                        _buildDetailedRecipientInfo(
                          'Cc',
                          _currentEmailData.cc!,
                          theme,
                        ),
                      _buildBccEntry(theme),
                      Padding(
                        padding: _detailItemPadding,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: _labelWidth,
                              child: Text(
                                'Date:',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                _formatFullDateTime(_currentEmailData.time),
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 12),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              if (!_showDetails) const Divider(),
              const SizedBox(height: 12),
              SelectableText(
                _currentEmailData.body.isNotEmpty
                    ? _currentEmailData.body
                    : '(No content)',
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
              ),
              const SizedBox(height: 20),
              if (_currentEmailData.attachments?.isNotEmpty ?? false) ...[
                Text('Attachments:', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  children:
                      _currentEmailData.attachments!.map((attachment) {
                        return ActionChip(
                          avatar: Icon(
                            Icons.attach_file,
                            size: 16,
                            color: theme.textTheme.bodyMedium?.color,
                          ),
                          label: Text(attachment['name'] ?? 'file'),
                          onPressed: () => _viewAttachment(attachment),
                          backgroundColor: theme.chipTheme.backgroundColor,
                          labelStyle: theme.chipTheme.labelStyle,
                        );
                      }).toList(),
                ),
                const SizedBox(height: 20),
              ],
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
                ),
                TextButton.icon(
                  icon: const Icon(Icons.forward_outlined),
                  label: const Text('Forward'),
                  onPressed: _handleForwardEmail,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
