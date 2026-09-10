class ZspLocation {
  const ZspLocation({
    required this.id,
    required this.name,
    this.isDefault = false,
    this.isActive = true,
  });

  static const String werneckId = 'zsp-werneck';

  final String id;
  final String name;
  final bool isDefault;
  final bool isActive;

  String get displayName => name;

  ZspLocation copyWith({
    String? id,
    String? name,
    bool? isDefault,
    bool? isActive,
  }) {
    return ZspLocation(
      id: id ?? this.id,
      name: name ?? this.name,
      isDefault: isDefault ?? this.isDefault,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'is_default': isDefault ? 1 : 0,
      'is_active': isActive ? 1 : 0,
    };
  }

  factory ZspLocation.fromMap(Map<String, Object?> map) {
    return ZspLocation(
      id: map['id'] as String,
      name: map['name'] as String,
      isDefault: (map['is_default'] as int? ?? 0) == 1,
      isActive: (map['is_active'] as int? ?? 1) == 1,
    );
  }
}
