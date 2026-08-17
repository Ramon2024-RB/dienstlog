enum WorkDayType {
  work,
  free,
  vacation,
  holiday,
  sick,
}

enum WorkAssignmentType {
  ownDistrict,
  packageDriver,
}

enum DistrictPart {
  full,
  partA,
  partB,
}

class WorkDay {
  const WorkDay({
    required this.id,
    required this.date,
    required this.type,
    this.assignmentType = WorkAssignmentType.ownDistrict,
    this.districtId,
    this.districtPart = DistrictPart.full,
    this.workStart,
    this.departureTime,
    this.deliveryEnd,
    this.workEnd,
    this.breakMinutes = 0,
    this.packageCount = 0,
    this.cancelledPackageCount = 0,
    this.hasAdvertising = false,
    this.advertising,
    this.notes,
  });

  final String id;

  /// Datum des Eintrags.
  final DateTime date;

  /// Arbeit, Frei, Urlaub, Feiertag oder Krank.
  final WorkDayType type;

  /// Regulärer eigener Bezirk oder zusätzlicher Paketfahrer.
  final WorkAssignmentType assignmentType;

  /// Eigener regulärer Bezirk.
  ///
  /// Bei einem Paketfahrer-Tag kann dieser Wert leer bleiben.
  final String? districtId;

  /// Ganzer Bezirk, A-Teil oder B-Teil.
  final DistrictPart districtPart;

  /// Arbeitsbeginn in Minuten seit Mitternacht.
  ///
  /// Beispiel:
  /// 07:30 Uhr = 450.
  final int? workStart;

  /// Tatsächliche Abfahrt in Minuten seit Mitternacht.
  final int? departureTime;

  /// Ende der Zustellung in Minuten seit Mitternacht.
  final int? deliveryEnd;

  /// Arbeitsende in Minuten seit Mitternacht.
  final int? workEnd;

  /// Pause in Minuten.
  final int breakMinutes;

  /// Paketmenge der eigenen regulären Tour.
  ///
  /// Übernommene Pakete aus Unterstützungen werden separat
  /// über SupportEntry gespeichert.
  final int packageCount;

  /// Anzahl der abgebrochenen bzw. nicht zugestellten Pakete.
  final int cancelledPackageCount;

  /// Gibt an, ob an diesem Tag Werbung mitgenommen wurde.
  final bool hasAdvertising;

  /// Bezeichnung der mitgenommenen Werbung.
  final String? advertising;

  /// Freie Bemerkungen zum Arbeitstag.
  final String? notes;

  bool get isWorkDay => type == WorkDayType.work;

  bool get isPackageDriver =>
      assignmentType == WorkAssignmentType.packageDriver;

  int? get workDurationMinutes {
    if (workStart == null || workEnd == null) {
      return null;
    }

    final duration = workEnd! - workStart! - breakMinutes;

    if (duration < 0) {
      return null;
    }

    return duration;
  }

  int? get deliveryDurationMinutes {
    if (departureTime == null || deliveryEnd == null) {
      return null;
    }

    final duration = deliveryEnd! - departureTime!;

    if (duration < 0) {
      return null;
    }

    return duration;
  }

  int get deliveredPackageCount {
    final delivered = packageCount - cancelledPackageCount;

    if (delivered < 0) {
      return 0;
    }

    return delivered;
  }

  WorkDay copyWith({
    String? id,
    DateTime? date,
    WorkDayType? type,
    WorkAssignmentType? assignmentType,
    String? districtId,
    bool clearDistrictId = false,
    DistrictPart? districtPart,
    int? workStart,
    bool clearWorkStart = false,
    int? departureTime,
    bool clearDepartureTime = false,
    int? deliveryEnd,
    bool clearDeliveryEnd = false,
    int? workEnd,
    bool clearWorkEnd = false,
    int? breakMinutes,
    int? packageCount,
    int? cancelledPackageCount,
    bool? hasAdvertising,
    String? advertising,
    bool clearAdvertising = false,
    String? notes,
    bool clearNotes = false,
  }) {
    return WorkDay(
      id: id ?? this.id,
      date: date ?? this.date,
      type: type ?? this.type,
      assignmentType: assignmentType ?? this.assignmentType,
      districtId:
          clearDistrictId ? null : districtId ?? this.districtId,
      districtPart: districtPart ?? this.districtPart,
      workStart:
          clearWorkStart ? null : workStart ?? this.workStart,
      departureTime: clearDepartureTime
          ? null
          : departureTime ?? this.departureTime,
      deliveryEnd:
          clearDeliveryEnd ? null : deliveryEnd ?? this.deliveryEnd,
      workEnd:
          clearWorkEnd ? null : workEnd ?? this.workEnd,
      breakMinutes: breakMinutes ?? this.breakMinutes,
      packageCount: packageCount ?? this.packageCount,
      cancelledPackageCount:
          cancelledPackageCount ?? this.cancelledPackageCount,
      hasAdvertising: hasAdvertising ?? this.hasAdvertising,
      advertising: clearAdvertising
          ? null
          : advertising ?? this.advertising,
      notes: clearNotes ? null : notes ?? this.notes,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'date': _dateToDatabase(date),
      'type': type.name,
      'assignment_type': assignmentType.name,
      'district_id': districtId,
      'district_part': districtPart.name,
      'work_start': workStart,
      'departure_time': departureTime,
      'delivery_end': deliveryEnd,
      'work_end': workEnd,
      'break_minutes': breakMinutes,
      'package_count': packageCount,
      'cancelled_package_count': cancelledPackageCount,
      'has_advertising': hasAdvertising ? 1 : 0,
      'advertising': advertising,
      'notes': notes,
    };
  }

  factory WorkDay.fromMap(Map<String, Object?> map) {
    return WorkDay(
      id: map['id'] as String,
      date: DateTime.parse(map['date'] as String),
      type: WorkDayType.values.firstWhere(
        (type) => type.name == map['type'],
        orElse: () => WorkDayType.work,
      ),
      assignmentType: WorkAssignmentType.values.firstWhere(
        (type) => type.name == map['assignment_type'],
        orElse: () => WorkAssignmentType.ownDistrict,
      ),
      districtId: map['district_id'] as String?,
      districtPart: DistrictPart.values.firstWhere(
        (part) => part.name == map['district_part'],
        orElse: () => DistrictPart.full,
      ),
      workStart: map['work_start'] as int?,
      departureTime: map['departure_time'] as int?,
      deliveryEnd: map['delivery_end'] as int?,
      workEnd: map['work_end'] as int?,
      breakMinutes: (map['break_minutes'] as int?) ?? 0,
      packageCount: (map['package_count'] as int?) ?? 0,
      cancelledPackageCount:
          (map['cancelled_package_count'] as int?) ?? 0,
      hasAdvertising:
          (map['has_advertising'] as int? ?? 0) == 1,
      advertising: map['advertising'] as String?,
      notes: map['notes'] as String?,
    );
  }

  static String _dateToDatabase(DateTime date) {
    final normalizedDate = DateTime(
      date.year,
      date.month,
      date.day,
    );

    return normalizedDate.toIso8601String();
  }
}