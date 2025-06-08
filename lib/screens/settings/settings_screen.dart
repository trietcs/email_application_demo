import 'package:email_application/services/notification_settings_notifier.dart';
import 'package:email_application/services/theme_notifier.dart';
import 'package:email_application/services/view_mode_notifier.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final viewModeNotifier = Provider.of<ViewModeNotifier>(context);
    final notificationSettingsNotifier =
        Provider.of<NotificationSettingsNotifier>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _buildSectionTitle('Display', context),
          SwitchListTile(
            title: const Text('Dark Mode'),
            subtitle: const Text('Reduce glare and improve night viewing'),
            value: themeNotifier.themeMode == ThemeMode.dark,
            onChanged: (value) {
              themeNotifier.toggleTheme(value);
            },
            secondary: Icon(
              Icons.dark_mode_outlined,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          SwitchListTile(
            title: const Text('Detailed Email View'),
            subtitle: const Text(
              'Show previews, labels, and attachments in list',
            ),
            value: viewModeNotifier.viewMode == ViewMode.detailed,
            onChanged: (value) {
              viewModeNotifier.toggleViewMode();
            },
            secondary: Icon(
              Icons.view_list_outlined,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),

          _buildSectionTitle('Notifications', context),
          SwitchListTile(
            title: const Text('New Email Notifications'),
            subtitle: const Text('Receive alerts for new incoming emails'),
            value: notificationSettingsNotifier.areNotificationsEnabled,
            onChanged: (value) {
              notificationSettingsNotifier.toggleNotifications(value);
            },
            secondary: Icon(
              notificationSettingsNotifier.areNotificationsEnabled
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_off_outlined,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 20.0, 16.0, 8.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).primaryColor,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
}
