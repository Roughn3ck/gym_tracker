import 'package:flutter/material.dart';

/// Enum representing the two training modes
enum TrainingMode {
  hypertrophy,
  strength,
}

/// Extension to provide display names for training modes
extension TrainingModeExtension on TrainingMode {
  String get displayName {
    switch (this) {
      case TrainingMode.hypertrophy:
        return 'Hypertrophy';
      case TrainingMode.strength:
        return 'Strength';
    }
  }

  String get description {
    switch (this) {
      case TrainingMode.hypertrophy:
        return '~12 reps / 3 sets\nFocus on muscle growth';
      case TrainingMode.strength:
        return '~6 reps / 5 sets\nFocus on maximal strength';
    }
  }

  Color get color {
    switch (this) {
      case TrainingMode.hypertrophy:
        return Colors.purple;
      case TrainingMode.strength:
        return Colors.blue;
    }
  }
}

/// State management class for training mode
class TrainingState extends ChangeNotifier {
  TrainingMode _currentMode = TrainingMode.hypertrophy;

  TrainingMode get currentMode => _currentMode;

  /// Toggle between hypertrophy and strength modes
  void toggleMode() {
    _currentMode = _currentMode == TrainingMode.hypertrophy
        ? TrainingMode.strength
        : TrainingMode.hypertrophy;
    notifyListeners();
  }

  /// Set a specific training mode
  void setMode(TrainingMode mode) {
    if (_currentMode != mode) {
      _currentMode = mode;
      notifyListeners();
    }
  }

  /// Get the current mode's display name
  String get currentModeName => _currentMode.displayName;

  /// Get the current mode's description
  String get currentModeDescription => _currentMode.description;

  /// Get the current mode's color
  Color get currentModeColor => _currentMode.color;

  /// Check if current mode is hypertrophy
  bool get isHypertrophy => _currentMode == TrainingMode.hypertrophy;

  /// Check if current mode is strength
  bool get isStrength => _currentMode == TrainingMode.strength;
}