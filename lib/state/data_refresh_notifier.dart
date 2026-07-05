import 'package:flutter/material.dart';

/// A simple ChangeNotifier that broadcasts a "data changed" signal to all
/// listening screens. After any data mutation (save session, modify weight,
/// add/edit/delete body stat, edit session), call [notifyDataChanged] so
/// other screens can reload their data in real time without requiring a
/// manual refresh or app restart.
///
/// Screens watch [refreshCount] via `Provider.of<DataRefreshNotifier>(context,
/// listen: true)` — when it changes, the widget rebuilds and can trigger a
/// data reload in a post-frame callback.
class DataRefreshNotifier extends ChangeNotifier {
  int _refreshCount = 0;

  /// Increments each time [notifyDataChanged] is called. Screens compare
  /// this to their last-seen value to detect changes.
  int get refreshCount => _refreshCount;

  /// Signals that underlying database data has changed. Listeners should
  /// reload their data from the repository.
  void notifyDataChanged() {
    _refreshCount++;
    notifyListeners();
  }
}