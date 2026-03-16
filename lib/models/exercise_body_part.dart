/// Represents the relationship between exercises and body parts
/// This is a junction table for many-to-many relationship
class ExerciseBodyPart {
  final String exercise;
  final String bodyPart;

  ExerciseBodyPart({
    required this.exercise,
    required this.bodyPart,
  });

  /// Converts an ExerciseBodyPart object to a Map for database operations
  Map<String, dynamic> toMap() {
    return {
      'Exercise': exercise,
      'BodyPart': bodyPart,
    };
  }

  /// Creates an ExerciseBodyPart object from a database Map
  factory ExerciseBodyPart.fromMap(Map<String, dynamic> map) {
    return ExerciseBodyPart(
      exercise: map['Exercise'] as String,
      bodyPart: map['BodyPart'] as String,
    );
  }

  /// Creates a copy of the ExerciseBodyPart with updated values
  ExerciseBodyPart copyWith({
    String? exercise,
    String? bodyPart,
  }) {
    return ExerciseBodyPart(
      exercise: exercise ?? this.exercise,
      bodyPart: bodyPart ?? this.bodyPart,
    );
  }

  @override
  String toString() {
    return 'ExerciseBodyPart(exercise: $exercise, bodyPart: $bodyPart)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is ExerciseBodyPart &&
        other.exercise == exercise &&
        other.bodyPart == bodyPart;
  }

  @override
  int get hashCode {
    return exercise.hashCode ^ bodyPart.hashCode;
  }
}