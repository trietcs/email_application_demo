import 'package:flutter/material.dart';

class NotificationSettingsNotifier extends ChangeNotifier {
  bool _areNotificationsEnabled = true;

  bool get areNotificationsEnabled => _areNotificationsEnabled;

  void toggleNotifications(bool value) {
    _areNotificationsEnabled = value;
    notifyListeners();
  }
}
