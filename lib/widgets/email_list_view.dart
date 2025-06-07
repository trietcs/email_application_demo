import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:email_application/models/email_data.dart';
import 'package:email_application/models/email_folder.dart';
import 'package:email_application/widgets/email_list_item.dart';
import 'package:email_application/models/label_data.dart';
import 'package:email_application/services/view_mode_notifier.dart';
import 'package:email_application/widgets/simple_email_list_item.dart';

typedef EmailTapCallback = Future<void> Function(EmailData email);
typedef VoidFutureCallBack = Future<void> Function();
typedef StarStatusChangedCallback = void Function();

class EmailListView extends StatelessWidget {
  final List<EmailData> emails;
  final EmailFolder currentScreenFolder;
  final EmailTapCallback onEmailTap;
  final VoidFutureCallBack? onRefresh;
  final VoidCallback? onReadStatusChanged;
  final VoidCallback? onDeleteOrMove;
  final StarStatusChangedCallback? onStarStatusChanged;
  final String? emptyListMessage;
  final IconData? emptyListIcon;
  final List<LabelData> allUserLabels;

  const EmailListView({
    super.key,
    required this.emails,
    required this.currentScreenFolder,
    required this.onEmailTap,
    required this.allUserLabels,
    this.onRefresh,
    this.onReadStatusChanged,
    this.onDeleteOrMove,
    this.onStarStatusChanged,
    this.emptyListMessage,
    this.emptyListIcon,
  });

  @override
  Widget build(BuildContext context) {
    final viewMode = Provider.of<ViewModeNotifier>(context).viewMode;

    if (emails.isEmpty) {
      String message;
      IconData iconData;

      if (emptyListMessage != null) {
        message = emptyListMessage!;
        iconData = emptyListIcon ?? Icons.email_outlined;
      } else {
        switch (currentScreenFolder) {
          case EmailFolder.inbox:
            message = 'Your inbox is empty!';
            iconData = Icons.inbox_outlined;
            break;
          case EmailFolder.sent:
            message = 'No emails in Sent folder!';
            iconData = Icons.outbox_outlined;
            break;
          case EmailFolder.drafts:
            message = 'No drafts!';
            iconData = Icons.edit_note_outlined;
            break;
          case EmailFolder.trash:
            message = 'Trash is empty!';
            iconData = Icons.delete_sweep_outlined;
            break;
        }
      }

      final theme = Theme.of(context);

      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  iconData,
                  size: 60,
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      itemCount: emails.length,
      itemBuilder: (context, index) {
        final email = emails[index];

        if (viewMode == ViewMode.basic) {
          return SimpleEmailListItem(
            email: email,
            currentScreenFolder: currentScreenFolder,
            onTap: () => onEmailTap(email),
            onStarStatusChanged: onStarStatusChanged,
          );
        } else {
          return EmailListItem(
            email: email,
            currentScreenFolder: currentScreenFolder,
            allUserLabels: allUserLabels,
            onTap: () => onEmailTap(email),
            onReadStatusChanged: onReadStatusChanged,
            onDeleteOrMove: onDeleteOrMove,
            onStarStatusChanged: onStarStatusChanged,
          );
        }
      },
    );
  }
}

class EmailListErrorView extends StatelessWidget {
  final Object error;
  final VoidFutureCallBack onRetry;

  const EmailListErrorView({
    super.key,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  color: theme.colorScheme.error,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading emails: $error',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                  onPressed: onRetry,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
