import 'zsp_location.dart';

class MondayDeliveryEntry {
  const MondayDeliveryEntry({
    this.id,
    required this.workDayId,
    required this.district,
    this.zspId = ZspLocation.werneckId,
  });

  final int? id;
  final String workDayId;
  final String district;
  final String zspId;

  MondayDeliveryEntry copyWith({
    int? id,
    bool clearId = false,
    String? workDayId,
    String? district,
    String? zspId,
  }) {
    return MondayDeliveryEntry(
      id: clearId ? null : id ?? this.id,
      workDayId: workDayId ?? this.workDayId,
      district: district ?? this.district,
      zspId: zspId ?? this.zspId,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'work_day_id': workDayId,
      'district': district,
      'zsp_id': zspId,
    };
  }

  factory MondayDeliveryEntry.fromMap(Map<String, Object?> map) {
    return MondayDeliveryEntry(
      id: map['id'] as int?,
      workDayId: map['work_day_id'] as String,
      district: map['district'] as String,
      zspId: (map['zsp_id'] as String?) ?? ZspLocation.werneckId,
    );
  }
}
