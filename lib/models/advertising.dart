class Advertising {
  const Advertising({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;

  factory Advertising.fromMap(Map<String, Object?> map) {
    return Advertising(
      id: map['id'] as String,
      name: map['name'] as String,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
    };
  }

  Advertising copyWith({
    String? id,
    String? name,
  }) {
    return Advertising(
      id: id ?? this.id,
      name: name ?? this.name,
    );
  }
}
