import 'work_day.dart';

class OwnTourEntry {
  const OwnTourEntry({
    this.id,
    required this.workDayId,
    required this.district,
    this.districtPart = DistrictPart.full,
    this.packageCount = 0,
    this.cancelledPackageCount = 0,
  });

  final int? id;

  /// ID des zugehörigen Arbeitstags.
  final String workDayId;

  /// Gefahrener Bezirk.
  final String district;

  /// Ganzer Bezirk, A-Teil oder B-Teil.
  final DistrictPart districtPart;

  /// Paketmenge dieser eigenen Tour.
  final int packageCount;

  /// Nicht zugestellte bzw. abgebrochene Pakete dieser Tour.
  final int cancelledPackageCount;

  int get deliveredPackageCount {
    final delivered =
        packageCount - cancelledPackageCount;

    if (delivered < 0) {
      return 0;
    }

    return delivered;
  }

  OwnTourEntry copyWith({
    int? id,
    bool clearId = false,
    String? workDayId,
    String? district,
    DistrictPart? districtPart,
    int? packageCount,
    int? cancelledPackageCount,
  }) {
    return OwnTourEntry(
      id: clearId ? null : id ?? this.id,
      workDayId:
          workDayId ?? this.workDayId,
      district: district ?? this.district,
      districtPart:
          districtPart ?? this.districtPart,
      packageCount:
          packageCount ?? this.packageCount,
      cancelledPackageCount:
          cancelledPackageCount ??
              this.cancelledPackageCount,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'work_day_id': workDayId,
      'district': district,
      'district_part': districtPart.name,
      'package_count': packageCount,
      'cancelled_package_count':
          cancelledPackageCount,
    };
  }

  factory OwnTourEntry.fromMap(
    Map<String, Object?> map,
  ) {
    return OwnTourEntry(
      id: map['id'] as int?,
      workDayId:
          map['work_day_id'] as String,
      district:
          map['district'] as String,
      districtPart:
          DistrictPart.values.firstWhere(
        (part) =>
            part.name ==
            map['district_part'],
        orElse: () => DistrictPart.full,
      ),
      packageCount:
          (map['package_count'] as int?) ??
              0,
      cancelledPackageCount:
          (map['cancelled_package_count']
                  as int?) ??
              0,
    );
  }
}