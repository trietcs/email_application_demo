import 'package:flutter/material.dart';

enum ViewMode { detailed, basic }

class ViewModeNotifier extends ChangeNotifier {
  ViewMode _viewMode = ViewMode.detailed;

  ViewMode get viewMode => _viewMode;

  void toggleViewMode() {
    _viewMode =
        _viewMode == ViewMode.detailed ? ViewMode.basic : ViewMode.detailed;

    notifyListeners();
  }
}
