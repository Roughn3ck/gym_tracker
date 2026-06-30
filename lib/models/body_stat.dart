/// Represents body measurements and metrics tracking
class BodyStat {
  final int? id;
  final DateTime date;
  final double? weightKg;
  final double? waistInches;
  final double? neckInches;
  final String? notes;

  BodyStat({
    this.id,
    required this.date,
    this.weightKg,
    this.waistInches,
    this.neckInches,
    this.notes,
  });

  /// Converts a BodyStat object to a Map for database operations
  Map<String, dynamic> toMap() {
    return {
      'Date': '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}',
      'Weight_kg': weightKg,
      'Waist_inches': waistInches,
      'Neck_inches': neckInches,
      'Notes': notes,
    };
  }

  /// Parses a date string that may be in YYYY/MM/DD or ISO 8601 format
  static DateTime _parseDate(String dateStr) {
    // The database stores dates as YYYY/MM/DD; DateTime.parse expects
    // ISO 8601 (YYYY-MM-DD), so normalise slashes to dashes.
    return DateTime.parse(dateStr.replaceAll('/', '-'));
  }

  /// Creates a BodyStat object from a database Map
  factory BodyStat.fromMap(Map<String, dynamic> map) {
    return BodyStat(
      id: map['ID'] as int?,
      date: _parseDate(map['Date'] as String),
      weightKg: map['Weight_kg'] as double?,
      waistInches: map['Waist_inches'] as double?,
      neckInches: map['Neck_inches'] as double?,
      notes: map['Notes'] as String?,
    );
  }

  /// Creates a copy of the BodyStat with updated values
  BodyStat copyWith({
    int? id,
    DateTime? date,
    double? weightKg,
    double? waistInches,
    double? neckInches,
    String? notes,
  }) {
    return BodyStat(
      id: id ?? this.id,
      date: date ?? this.date,
      weightKg: weightKg ?? this.weightKg,
      waistInches: waistInches ?? this.waistInches,
      neckInches: neckInches ?? this.neckInches,
      notes: notes ?? this.notes,
    );
  }

  /// Calculates BMI (Body Mass Index) using weight in kg and height in meters
  /// Returns null if weight or height is not available
  double? calculateBmi(double heightMeters) {
    if (weightKg == null) return null;
    return weightKg! / (heightMeters * heightMeters);
  }

  @override
  String toString() {
    return 'BodyStat(id: $id, date: $date, weightKg: $weightKg, waistInches: $waistInches, neckInches: $neckInches, notes: $notes)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is BodyStat &&
        other.id == id &&
        other.date == date &&
        other.weightKg == weightKg &&
        other.waistInches == waistInches &&
        other.neckInches == neckInches &&
        other.notes == notes;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        date.hashCode ^
        weightKg.hashCode ^
        waistInches.hashCode ^
        neckInches.hashCode ^
        notes.hashCode;
  }
}