enum WorkDayType {
  work,
  free,
  vacation,
  holiday,
  sick,
}

class WorkDay {
  const WorkDay({
    required this.id,
    required this.date,
    required this.type,
    this.districtId,
    this.workStart,
    this.workEnd,
    this.breakMinutes = 0,
    this.deliveryStart,
    this.deliveryEnd,
    this.packageCount = 0,
    this.isPackageDriver = false,
    this.notes,
  });

  final String id;
  final DateTime date;
  final WorkDayType type;

  /// Eigener regulärer Bezirk an diesem Arbeitstag.
  ///
  /// Bei einem reinen Paketfahrer-/Unterstützungstag kann dieser Wert null sein.
  final String? districtId;

  /// Arbeitsbeginn, gespeichert als Minuten seit Mitternacht.
  ///
  /// Beispiel:
  /// 07:30 Uhr = 450 Minuten.
  final int? workStart;

  /// Arbeitsende, gespeichert als Minuten seit Mitternacht.
  final int? workEnd;

  /// Pausenzeit in Minuten.
  final int breakMinutes;

  /// Beginn der eigentlichen Zustellung in Minuten seit Mitternacht.
  final int? deliveryStart;

  /// Ende der eigentlichen Zustellung in Minuten seit Mitternacht.
  final int? deliveryEnd;

  /// Paketmenge des eigenen Bezirks.
  ///
  /// Übernommene Pakete aus Unterstützungen werden später getrennt
  /// über SupportEntry gespeichert.
  final int packageCount;

  /// true bedeutet:
  /// An diesem Tag war der Nutzer als zusätzlicher Paketfahrer eingesetzt.
  ///
  /// Die 25 regulären Bezirke bleiben dabei weiterhin durch ihre
  /// jeweiligen Zusteller besetzt.
  final bool isPackageDriver;

  final String? notes;

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
    if (deliveryStart == null || deliveryEnd == null) {
      return null;
    }

    final duration = deliveryEnd! - deliveryStart!;

    if (duration < 0) {
      return null;
    }

    return duration;
  }

  WorkDay copyWith({
    String? id,
    DateTime? date,
    WorkDayType? type,
    String? districtId,
    bool clearDistrictId = false,
    int? workStart,
    bool clearWorkStart = false,
    int? workEnd,
    bool clearWorkEnd = false,
    int? breakMinutes,
    int? deliveryStart,
    bool clearDeliveryStart = false,
    int? deliveryEnd,
    bool clearDeliveryEnd = false,
    int? packageCount,
    bool? isPackageDriver,
    String? notes,
    bool clearNotes = false,
  }) {
    return WorkDay(
      id: id ?? this.id,
      date: date ?? this.date,
      type: type ?? this.type,
      districtId: clearDistrictId ? null : districtId ?? this.districtId,
      workStart: clearWorkStart ? null : workStart ?? this.workStart,
      workEnd: clearWorkEnd ? null : workEnd ?? this.workEnd,
      breakMinutes: breakMinutes ?? this.breakMinutes,
      deliveryStart:
          clearDeliveryStart ? null : deliveryStart ?? this.deliveryStart,
      deliveryEnd: clearDeliveryEnd ? null : deliveryEnd ?? this.deliveryEnd,
      packageCount: packageCount ?? this.packageCount,
      isPackageDriver: isPackageDriver ?? this.isPackageDriver,
      notes: clearNotes ? null : notes ?? this.notes,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'date': _dateToDatabase(date),
      'type': type.name,
      'district_id': districtId,
      'work_start': workStart,
      'work_end': workEnd,
      'break_minutes': breakMinutes,
      'delivery_start': deliveryStart,
      'delivery_end': deliveryEnd,
      'package_count': packageCount,
      'is_package_driver': isPackageDriver ? 1 : 0,
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
      districtId: map['district_id'] as String?,
      workStart: map['work_start'] as int?,
      workEnd: map['work_end'] as int?,
      breakMinutes: (map['break_minutes'] as int?) ?? 0,
      deliveryStart: map['delivery_start'] as int?,
      deliveryEnd: map['delivery_end'] as int?,
      packageCount: (map['package_count'] as int?) ?? 0,
      isPackageDriver: (map['is_package_driver'] as int? ?? 0) == 1,
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