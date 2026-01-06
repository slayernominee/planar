import 'package:flutter/material.dart';

enum DayViewMode { regular, compact }

class SettingsProvider with ChangeNotifier {
  DayViewMode _dayViewMode = DayViewMode.regular;

  DayViewMode get dayViewMode => _dayViewMode;

  void setDayViewMode(DayViewMode mode) {
    if (_dayViewMode != mode) {
      _dayViewMode = mode;
      notifyListeners();
    }
  }

  bool get isCompact => _dayViewMode == DayViewMode.compact;
}
