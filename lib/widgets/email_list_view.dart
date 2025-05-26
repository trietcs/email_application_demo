import 'package:flutter/material.dart';
import 'package:email_application/models/email_data.dart';
import 'package:email_application/models/email_folder.dart';
import 'package:email_application/widgets/email_list_item.dart';
import 'package:email_application/config/app_colors.dart';

typedef EmailTapCallback = Future<void> Function(EmailData email);
typedef VoidFutureCallBack = Future<void> Function();

class EmailListView extends StatelessWidget {
  final List<EmailData> emails;
  final EmailFolder currentScreenFolder;
  final EmailTapCallback onEmailTap;
  final VoidFutureCallBack? onRefresh;
  final VoidCallback? onReadStatusChanged;
  final VoidCallback? onDeleteOrMove;

  const EmailListView({
    super.key,
    required this.emails,
    required this.currentScreenFolder,
    required this.onEmailTap,
    this.onRefresh,
    this.onReadStatusChanged,
    this.onDeleteOrMove,
  });

  @override
  Widget build(BuildContext context) {
    if (emails.isEmpty) {
      String message;
      IconData iconData;
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
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(iconData, size: 60, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
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
        return EmailListItem(
          email: email,
          currentScreenFolder: currentScreenFolder,
          onTap: () => onEmailTap(email),
          onReadStatusChanged: onReadStatusChanged,
          onDeleteOrMove: onDeleteOrMove,
        );
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
                Icon(Icons.error_outline, color: AppColors.error, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Error loading emails: $error',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.secondaryText),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                  onPressed: onRetry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
