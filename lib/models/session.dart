/// Represents a workout session with comprehensive tracking data
class Session {
  final int? id;
  final DateTime date;
  final String? workout; // free-text workout description (e.g. "chest and bis")
  final String? bodyParts; // JSON array of canonical body part names, e.g. ["Chest","Biceps"]
  final double? runDistance; // run distance in km
  final int? runTime; // run time in minutes
  final int? saunaDuration; // in minutes
  final double? bodyWeight; // in kg
  final String? trainingStyle;
  final String? other;

  Session({
    this.id,
    required this.date,
    this.workout,
    this.bodyParts,
    this.runDistance,
    this.runTime,
    this.saunaDuration,
    this.bodyWeight,
    this.trainingStyle,
    this.other,
  });

  /// Parses a date string that may be in YYYY/MM/DD or ISO 8601 format
  static DateTime _parseDate(String dateStr) {
    return DateTime.parse(dateStr.replaceAll('/', '-'));
  }

  /// Converts a Session object to a Map for database operations
  Map<String, dynamic> toMap() {
    return {
      'Date': '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}',
      'Workout': workout,
      'BodyParts': bodyParts,
      'RunDistance': runDistance,
      'RunTime': runTime,
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
      date: _parseDate(map['Date'] as String),
      workout: map['Workout'] as String?,
      bodyParts: map['BodyParts'] as String?,
      runDistance: map['RunDistance'] as double?,
      runTime: map['RunTime'] as int?,
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
    String? workout,
    String? bodyParts,
    double? runDistance,
    int? runTime,
    int? saunaDuration,
    double? bodyWeight,
    String? trainingStyle,
    String? other,
  }) {
    return Session(
      id: id ?? this.id,
      date: date ?? this.date,
      workout: workout ?? this.workout,
      bodyParts: bodyParts ?? this.bodyParts,
      runDistance: runDistance ?? this.runDistance,
      runTime: runTime ?? this.runTime,
      saunaDuration: saunaDuration ?? this.saunaDuration,
      bodyWeight: bodyWeight ?? this.bodyWeight,
      trainingStyle: trainingStyle ?? this.trainingStyle,
      other: other ?? this.other,
    );
  }

  @override
  String toString() {
    return 'Session(id: $id, date: $date, workout: $workout, bodyParts: $bodyParts, runDistance: $runDistance, runTime: $runTime, saunaDuration: $saunaDuration, bodyWeight: $bodyWeight, trainingStyle: $trainingStyle, other: $other)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Session &&
        other.id == id &&
        other.date == date &&
        other.workout == workout &&
        other.bodyParts == bodyParts &&
        other.runDistance == runDistance &&
        other.runTime == runTime &&
        other.saunaDuration == saunaDuration &&
        other.bodyWeight == bodyWeight &&
        other.trainingStyle == trainingStyle &&
        other.other == this.other;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        date.hashCode ^
        workout.hashCode ^
        bodyParts.hashCode ^
        runDistance.hashCode ^
        runTime.hashCode ^
        saunaDuration.hashCode ^
        bodyWeight.hashCode ^
        trainingStyle.hashCode ^
        other.hashCode;
  }
}
