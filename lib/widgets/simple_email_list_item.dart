import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:email_application/models/email_data.dart';
import 'package:email_application/models/email_folder.dart';
import 'package:email_application/services/auth_service.dart';
import 'package:email_application/services/firestore_service.dart';
import 'package:email_application/config/app_colors.dart';

class SimpleEmailListItem extends StatefulWidget {
  final EmailData email;
  final EmailFolder currentScreenFolder;
  final VoidCallback? onTap;
  final VoidCallback? onStarStatusChanged;

  const SimpleEmailListItem({
    super.key,
    required this.email,
    required this.currentScreenFolder,
    this.onTap,
    this.onStarStatusChanged,
  });

  @override
  State<SimpleEmailListItem> createState() => _SimpleEmailListItemState();
}

class _SimpleEmailListItemState extends State<SimpleEmailListItem> {
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
  void didUpdateWidget(covariant SimpleEmailListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.email.id != oldWidget.email.id ||
        widget.email.isStarred != oldWidget.email.isStarred) {
      setState(() {
        _currentEmail = widget.email;
      });
    }
    if (widget.email.from['userId'] != oldWidget.email.from['userId'] ||
        widget.currentScreenFolder != oldWidget.currentScreenFolder) {
      _fetchRelevantProfileInfo();
    }
  }

  Future<void> _fetchRelevantProfileInfo() async {
    if (!mounted) return;
    setState(() => _isLoadingProfileInfo = true);

    String? contactIdToLookup;
    String nameForInitialFallback = "Unknown";

    final effectiveFolder =
        widget.currentScreenFolder == EmailFolder.trash &&
                _currentEmail.originalFolder != null
            ? _currentEmail.originalFolder!
            : widget.currentScreenFolder;

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
        } else {
          nameForInitialFallback = 'To: (No recipients)';
        }
        break;
      case EmailFolder.drafts:
        nameForInitialFallback = "Draft";
        break;
      default:
        contactIdToLookup = _currentEmail.from['userId'];
        nameForInitialFallback = _currentEmail.from['displayName'] ?? 'Unknown';
        break;
    }

    if (mounted)
      setState(() => _nameForAvatarAndInitial = nameForInitialFallback);

    if (contactIdToLookup == null || contactIdToLookup.isEmpty) {
      if (mounted) setState(() => _isLoadingProfileInfo = false);
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
      if (mounted) setState(() => _isLoadingProfileInfo = false);
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
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUnread = !_currentEmail.isRead;
    final isStarred = _currentEmail.isStarred;
    final isDraft = widget.currentScreenFolder == EmailFolder.drafts;

    final displayNameStyle = theme.textTheme.titleMedium!.copyWith(
      fontWeight: isUnread && !isDraft ? FontWeight.bold : FontWeight.w500,
      color: isDraft ? AppColors.error : theme.colorScheme.onSurface,
    );

    String nameToDisplay = _nameForAvatarAndInitial ?? "Unknown";
    String initialLetter =
        nameToDisplay.isNotEmpty ? nameToDisplay[0].toUpperCase() : "?";

    return InkWell(
      onTap: widget.onTap,
      child: Container(
        color:
            isUnread && !isDraft
                ? (theme.brightness == Brightness.light
                    ? AppColors.lightUnreadBackground
                    : AppColors.darkUnreadBackground)
                : theme.scaffoldBackgroundColor,
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            if (_isLoadingProfileInfo)
              CircleAvatar(
                backgroundColor: theme.primaryColor.withOpacity(0.1),
                child: const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                ),
              )
            else
              CircleAvatar(
                key: ValueKey<String?>(_photoUrl ?? _nameForAvatarAndInitial),
                backgroundColor: theme.primaryColor.withOpacity(0.1),
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
                            color: theme.primaryColor,
                          ),
                        )
                        : null,
              ),
            const SizedBox(width: 12.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    nameToDisplay,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: displayNameStyle,
                  ),
                  const SizedBox(height: 2.0),
                  Text(
                    _currentEmail.subject.isNotEmpty
                        ? _currentEmail.subject
                        : '(No Subject)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium!.copyWith(
                      fontWeight:
                          isUnread && !isDraft
                              ? FontWeight.w500
                              : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8.0),
            IconButton(
              icon: Icon(
                isStarred ? Icons.star : Icons.star_border,
                color:
                    isStarred
                        ? AppColors.accent
                        : theme.colorScheme.onSurface.withOpacity(0.4),
              ),
              onPressed: () => _toggleStarStatus(context),
              tooltip: 'Star email',
            ),
          ],
        ),
      ),
    );
  }
}
