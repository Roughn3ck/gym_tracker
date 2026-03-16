/// Represents a specific weight training exercise with sets, reps, and weight
class WeightTraining {
  final int? id;
  final DateTime date;
  final String trainingStyle;
  final String exercises;
  final String weight; // Can be a range like "20-30" or single value like "40"
  final int reps;
  final int sets;

  WeightTraining({
    this.id,
    required this.date,
    required this.trainingStyle,
    required this.exercises,
    required this.weight,
    required this.reps,
    required this.sets,
  });

  /// Converts a WeightTraining object to a Map for database operations
  Map<String, dynamic> toMap() {
    return {
      'Date': date.toIso8601String(),
      'TrainingStyle': trainingStyle,
      'Exercises': exercises,
      'Weight': weight,
      'Reps': reps,
      'Sets': sets,
    };
  }

  /// Creates a WeightTraining object from a database Map
  factory WeightTraining.fromMap(Map<String, dynamic> map) {
    return WeightTraining(
      id: map['ID'] as int?,
      date: DateTime.parse(map['Date'] as String),
      trainingStyle: map['TrainingStyle'] as String,
      exercises: map['Exercises'] as String,
      weight: map['Weight'] as String,
      reps: map['Reps'] as int,
      sets: map['Sets'] as int,
    );
  }

  /// Creates a copy of the WeightTraining with updated values
  WeightTraining copyWith({
    int? id,
    DateTime? date,
    String? trainingStyle,
    String? exercises,
    String? weight,
    int? reps,
    int? sets,
  }) {
    return WeightTraining(
      id: id ?? this.id,
      date: date ?? this.date,
      trainingStyle: trainingStyle ?? this.trainingStyle,
      exercises: exercises ?? this.exercises,
      weight: weight ?? this.weight,
      reps: reps ?? this.reps,
      sets: sets ?? this.sets,
    );
  }

  /// Parses the weight string to get minimum and maximum weight values
  /// Returns a tuple of (minWeight, maxWeight) where both are doubles
  /// If weight is a single value, minWeight == maxWeight
  (double?, double?) parseWeightRange() {
    if (weight.contains('-')) {
      final parts = weight.split('-');
      if (parts.length == 2) {
        final min = double.tryParse(parts[0].trim());
        final max = double.tryParse(parts[1].trim());
        return (min, max);
      }
    }
    final single = double.tryParse(weight.trim());
    return (single, single);
  }

  /// Calculates total volume (weight × reps × sets)
  /// Uses average weight if weight is a range
  double? calculateVolume() {
    final (min, max) = parseWeightRange();
    if (min == null) return null;
    
    final avgWeight = max == null ? min : (min + max) / 2;
    return avgWeight * reps * sets;
  }

  @override
  String toString() {
    return 'WeightTraining(id: $id, date: $date, trainingStyle: $trainingStyle, exercises: $exercises, weight: $weight, reps: $reps, sets: $sets)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is WeightTraining &&
        other.id == id &&
        other.date == date &&
        other.trainingStyle == trainingStyle &&
        other.exercises == exercises &&
        other.weight == weight &&
        other.reps == reps &&
        other.sets == sets;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        date.hashCode ^
        trainingStyle.hashCode ^
        exercises.hashCode ^
        weight.hashCode ^
        reps.hashCode ^
        sets.hashCode;
  }
}