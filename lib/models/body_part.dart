/// Represents a body part category for organizing exercises
class BodyPart {
  final int? id;
  final String name;

  BodyPart({
    this.id,
    required this.name,
  });

  /// Converts a BodyPart object to a Map for database operations
  Map<String, dynamic> toMap() {
    return {
      'Name': name,
    };
  }

  /// Creates a BodyPart object from a database Map
  factory BodyPart.fromMap(Map<String, dynamic> map) {
    return BodyPart(
      id: map['ID'] as int?,
      name: map['Name'] as String,
    );
  }

  /// Creates a copy of the BodyPart with updated values
  BodyPart copyWith({
    int? id,
    String? name,
  }) {
    return BodyPart(
      id: id ?? this.id,
      name: name ?? this.name,
    );
  }

  @override
  String toString() {
    return 'BodyPart(id: $id, name: $name)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is BodyPart &&
        other.id == id &&
        other.name == name;
  }

  @override
  int get hashCode {
    return id.hashCode ^ name.hashCode;
  }
}