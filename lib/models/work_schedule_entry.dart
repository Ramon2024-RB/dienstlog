enum WorkScheduleType {
  work,
  packageDriver,
  free,
  vacation,
  holiday,
}

class WorkScheduleEntry {
  const WorkScheduleEntry({
    required this.id,
    required this.date,
    required this.type,
    this.districts = const [],
    this.notes,
  });

  final String id;

  /// Geplanter Tag.
  final DateTime date;

  /// Geplanter Einsatz:
  /// Arbeit im Bezirk, Paketfahrer, Frei, Urlaub oder Feiertag.
  final WorkScheduleType type;

  /// Geplante Bezirke.
  ///
  /// Es können mehrere Bezirke an einem Tag geplant werden.
  final List<String> districts;

  /// Optionale Notiz zur Planung.
  final String? notes;

  bool get isWorkDay =>
      type == WorkScheduleType.work ||
      type == WorkScheduleType.packageDriver;

  bool get isPackageDriver =>
      type == WorkScheduleType.packageDriver;

  WorkScheduleEntry copyWith({
    String? id,
    DateTime? date,
    WorkScheduleType? type,
    List<String>? districts,
    String? notes,
    bool clearNotes = false,
  }) {
    return WorkScheduleEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      type: type ?? this.type,
      districts: districts ?? this.districts,
      notes: clearNotes ? null : notes ?? this.notes,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'date': _dateToDatabase(date),
      'type': type.name,
      'districts': districts.join(','),
      'notes': notes,
    };
  }

  factory WorkScheduleEntry.fromMap(
    Map<String, Object?> map,
  ) {
    final districtsValue =
        map['districts'] as String?;

    final districts = districtsValue == null ||
            districtsValue.trim().isEmpty
        ? <String>[]
        : districtsValue
            .split(',')
            .map((district) => district.trim())
            .where((district) => district.isNotEmpty)
            .toList();

    return WorkScheduleEntry(
      id: map['id'] as String,
      date: DateTime.parse(
        map['date'] as String,
      ),
      type: WorkScheduleType.values.firstWhere(
        (type) => type.name == map['type'],
        orElse: () => WorkScheduleType.work,
      ),
      districts: districts,
      notes: map['notes'] as String?,
    );
  }

  static String _dateToDatabase(
    DateTime date,
  ) {
    return DateTime(
      date.year,
      date.month,
      date.day,
    ).toIso8601String();
  }
}