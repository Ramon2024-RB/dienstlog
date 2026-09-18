import 'zsp_location.dart';

class PackageDriverEntry {
  const PackageDriverEntry({
    this.id,
    required this.workDayId,
    required this.district,
    this.zspId = ZspLocation.werneckId,
  });

  final int? id;
  final String workDayId;
  final String district;
  final String zspId;

  PackageDriverEntry copyWith({
    int? id,
    bool clearId = false,
    String? workDayId,
    String? district,
    String? zspId,
  }) {
    return PackageDriverEntry(
      id: clearId ? null : id ?? this.id,
      workDayId: workDayId ?? this.workDayId,
      district: district ?? this.district,
      zspId: zspId ?? this.zspId,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'work_day_id': workDayId,
        'district': district,
        'zsp_id': zspId,
      };

  factory PackageDriverEntry.fromMap(Map<String, Object?> map) {
    return PackageDriverEntry(
      id: map['id'] as int?,
      workDayId: map['work_day_id'] as String,
      district: map['district'] as String,
      zspId: (map['zsp_id'] as String?) ?? ZspLocation.werneckId,
    );
  }
}
