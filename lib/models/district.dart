class District {
  const District({
    required this.number,
    this.isActive = true,
    this.canDriveSafely = false,
    this.note,
  });

  /// Nummer des regulären Bezirks.
  ///
  /// Aktuell gibt es die Bezirke 1 bis 25.
  final int number;

  /// Gibt an, ob der Bezirk aktuell verwendet wird.
  final bool isActive;

  /// Gibt an, ob der Bezirk selbstständig und sicher gefahren werden kann.
  final bool canDriveSafely;

  /// Optionale persönliche Notiz zum Bezirk.
  final String? note;

  String get displayName => 'Bezirk $number';

  District copyWith({
    int? number,
    bool? isActive,
    bool? canDriveSafely,
    String? note,
    bool clearNote = false,
  }) {
    return District(
      number: number ?? this.number,
      isActive: isActive ?? this.isActive,
      canDriveSafely: canDriveSafely ?? this.canDriveSafely,
      note: clearNote ? null : note ?? this.note,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'number': number,
      'is_active': isActive ? 1 : 0,
      'can_drive_safely': canDriveSafely ? 1 : 0,
      'note': note,
    };
  }

  factory District.fromMap(Map<String, Object?> map) {
    return District(
      number: map['number'] as int,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      canDriveSafely: (map['can_drive_safely'] as int? ?? 0) == 1,
      note: map['note'] as String?,
    );
  }

  @override
  String toString() {
    return 'District('
        'number: $number, '
        'isActive: $isActive, '
        'canDriveSafely: $canDriveSafely, '
        'note: $note'
        ')';
  }
}