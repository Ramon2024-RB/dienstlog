import 'work_day.dart';
import 'zsp_location.dart';

class OwnTourEntry {
  const OwnTourEntry({
    this.id,
    required this.workDayId,
    required this.district,
    this.zspId = ZspLocation.werneckId,
    this.districtPart = DistrictPart.full,
    this.packageCount = 0,
    this.cancelledPackageCount = 0,
  });

  final int? id;
  final String workDayId;
  final String district;
  final String zspId;
  final DistrictPart districtPart;
  final int packageCount;
  final int cancelledPackageCount;

  int get deliveredPackageCount {
    final delivered = packageCount - cancelledPackageCount;
    return delivered < 0 ? 0 : delivered;
  }

  OwnTourEntry copyWith({
    int? id,
    bool clearId = false,
    String? workDayId,
    String? district,
    String? zspId,
    DistrictPart? districtPart,
    int? packageCount,
    int? cancelledPackageCount,
  }) {
    return OwnTourEntry(
      id: clearId ? null : id ?? this.id,
      workDayId: workDayId ?? this.workDayId,
      district: district ?? this.district,
      zspId: zspId ?? this.zspId,
      districtPart: districtPart ?? this.districtPart,
      packageCount: packageCount ?? this.packageCount,
      cancelledPackageCount:
          cancelledPackageCount ?? this.cancelledPackageCount,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'work_day_id': workDayId,
      'district': district,
      'zsp_id': zspId,
      'district_part': districtPart.name,
      'package_count': packageCount,
      'cancelled_package_count': cancelledPackageCount,
    };
  }

  factory OwnTourEntry.fromMap(Map<String, Object?> map) {
    return OwnTourEntry(
      id: map['id'] as int?,
      workDayId: map['work_day_id'] as String,
      district: map['district'] as String,
      zspId: (map['zsp_id'] as String?) ?? ZspLocation.werneckId,
      districtPart: DistrictPart.values.firstWhere(
        (part) => part.name == map['district_part'],
        orElse: () => DistrictPart.full,
      ),
      packageCount: (map['package_count'] as int?) ?? 0,
      cancelledPackageCount:
          (map['cancelled_package_count'] as int?) ?? 0,
    );
  }
}
