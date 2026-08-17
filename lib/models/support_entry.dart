class SupportEntry {
  const SupportEntry({
    this.id,
    required this.workDayId,
    required this.district,
    required this.packagesTaken,
    this.note,
  });

  final int? id;

  /// ID des Arbeitstages, zu dem diese Unterstützung gehört.
  final int workDayId;

  /// Bezirk, den du zusätzlich unterstützt hast.
  /// Beispiele: "13", "16", "21" oder später auch andere Bezeichnungen.
  final String district;

  /// Anzahl der Pakete, die du von diesem Bezirk übernommen hast.
  final int packagesTaken;

  /// Optionale Bemerkung speziell zu dieser Unterstützung.
  final String? note;

  SupportEntry copyWith({
    int? id,
    int? workDayId,
    String? district,
    int? packagesTaken,
    String? note,
    bool clearNote = false,
  }) {
    return SupportEntry(
      id: id ?? this.id,
      workDayId: workDayId ?? this.workDayId,
      district: district ?? this.district,
      packagesTaken: packagesTaken ?? this.packagesTaken,
      note: clearNote ? null : note ?? this.note,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'work_day_id': workDayId,
      'district': district,
      'packages_taken': packagesTaken,
      'note': note,
    };
  }

  factory SupportEntry.fromMap(Map<String, Object?> map) {
    return SupportEntry(
      id: map['id'] as int?,
      workDayId: map['work_day_id'] as int,
      district: map['district'] as String,
      packagesTaken: map['packages_taken'] as int,
      note: map['note'] as String?,
    );
  }

  @override
  String toString() {
    return 'SupportEntry('
        'id: $id, '
        'workDayId: $workDayId, '
        'district: $district, '
        'packagesTaken: $packagesTaken, '
        'note: $note'
        ')';
  }
}