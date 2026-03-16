import 'package:sqflite/sqflite.dart';

/// Represents a workout session with comprehensive tracking data
class Session {
  final int? id;
  final DateTime date;
  final String? bodyPart;
  final double? runDuration; // in minutes
  final int? saunaDuration; // in minutes
  final double? bodyWeight; // in kg
  final String? trainingStyle;
  final String? other;

  Session({
    this.id,
    required this.date,
    this.bodyPart,
    this.runDuration,
    this.saunaDuration,
    this.bodyWeight,
    this.trainingStyle,
    this.other,
  });

  /// Converts a Session object to a Map for database operations
  Map<String, dynamic> toMap() {
    return {
      'Date': date.toIso8601String(),
      'BodyPart': bodyPart,
      'RunDuration': runDuration,
      'SaunaDuration': saunaDuration,
      'BodyWeight': bodyWeight,
      'TrainingStyle': trainingStyle,
      'Other': other,
    };
  }

  /// Creates a Session object from a database Map
  factory Session.fromMap(Map<String, dynamic> map) {
    return Session(
      id: map['ID'] as int?,
      date: DateTime.parse(map['Date'] as String),
      bodyPart: map['BodyPart'] as String?,
      runDuration: map['RunDuration'] as double?,
      saunaDuration: map['SaunaDuration'] as int?,
      bodyWeight: map['BodyWeight'] as double?,
      trainingStyle: map['TrainingStyle'] as String?,
      other: map['Other'] as String?,
    );
  }

  /// Creates a copy of the Session with updated values
  Session copyWith({
    int? id,
    DateTime? date,
    String? bodyPart,
    double? runDuration,
    int? saunaDuration,
    double? bodyWeight,
    String? trainingStyle,
    String? other,
  }) {
    return Session(
      id: id ?? this.id,
      date: date ?? this.date,
      bodyPart: bodyPart ?? this.bodyPart,
      runDuration: runDuration ?? this.runDuration,
      saunaDuration: saunaDuration ?? this.saunaDuration,
      bodyWeight: bodyWeight ?? this.bodyWeight,
      trainingStyle: trainingStyle ?? this.trainingStyle,
      other: other ?? this.other,
    );
  }

  @override
  String toString() {
    return 'Session(id: $id, date: $date, bodyPart: $bodyPart, runDuration: $runDuration, saunaDuration: $saunaDuration, bodyWeight: $bodyWeight, trainingStyle: $trainingStyle, other: $other)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is Session &&
        other.id == id &&
        other.date == date &&
        other.bodyPart == bodyPart &&
        other.runDuration == runDuration &&
        other.saunaDuration == saunaDuration &&
        other.bodyWeight == bodyWeight &&
        other.trainingStyle == trainingStyle &&
        other.other == this.other;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        date.hashCode ^
        bodyPart.hashCode ^
        runDuration.hashCode ^
        saunaDuration.hashCode ^
        bodyWeight.hashCode ^
        trainingStyle.hashCode ^
        other.hashCode;
  }
}