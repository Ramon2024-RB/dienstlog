import 'zsp_location.dart';

class SupportEntry {
  const SupportEntry({
    this.id,
    required this.workDayId,
    required this.district,
    this.zspId = ZspLocation.werneckId,
    required this.packagesTaken,
    this.note,
  });

  final int? id;
  final String workDayId;
  final String district;
  final String zspId;
  final int packagesTaken;
  final String? note;

  SupportEntry copyWith({
    int? id,
    String? workDayId,
    String? district,
    String? zspId,
    int? packagesTaken,
    String? note,
    bool clearNote = false,
  }) {
    return SupportEntry(
      id: id ?? this.id,
      workDayId: workDayId ?? this.workDayId,
      district: district ?? this.district,
      zspId: zspId ?? this.zspId,
      packagesTaken: packagesTaken ?? this.packagesTaken,
      note: clearNote ? null : note ?? this.note,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'work_day_id': workDayId,
      'district': district,
      'zsp_id': zspId,
      'packages_taken': packagesTaken,
      'note': note,
    };
  }

  factory SupportEntry.fromMap(Map<String, Object?> map) {
    return SupportEntry(
      id: map['id'] as int?,
      workDayId: map['work_day_id'] as String,
      district: map['district'] as String,
      zspId: (map['zsp_id'] as String?) ?? ZspLocation.werneckId,
      packagesTaken: map['packages_taken'] as int,
      note: map['note'] as String?,
    );
  }

  @override
  String toString() {
    return 'SupportEntry(id: $id, workDayId: $workDayId, zspId: $zspId, '
        'district: $district, packagesTaken: $packagesTaken, note: $note)';
  }
}
