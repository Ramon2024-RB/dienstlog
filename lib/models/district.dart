import 'zsp_location.dart';

class District {
  const District({
    required this.number,
    this.zspId = ZspLocation.werneckId,
    this.isActive = true,
    this.canDriveSafely = false,
    this.note,
  });

  final int number;
  final String zspId;
  final bool isActive;
  final bool canDriveSafely;
  final String? note;

  String get displayName => 'Bezirk $number';
  String get storageKey => '$zspId:$number';

  District copyWith({
    int? number,
    String? zspId,
    bool? isActive,
    bool? canDriveSafely,
    String? note,
    bool clearNote = false,
  }) {
    return District(
      number: number ?? this.number,
      zspId: zspId ?? this.zspId,
      isActive: isActive ?? this.isActive,
      canDriveSafely: canDriveSafely ?? this.canDriveSafely,
      note: clearNote ? null : note ?? this.note,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'zsp_id': zspId,
      'number': number,
      'is_active': isActive ? 1 : 0,
      'can_drive_safely': canDriveSafely ? 1 : 0,
      'note': note,
    };
  }

  factory District.fromMap(Map<String, Object?> map) {
    return District(
      number: map['number'] as int,
      zspId: (map['zsp_id'] as String?) ?? ZspLocation.werneckId,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      canDriveSafely: (map['can_drive_safely'] as int? ?? 0) == 1,
      note: map['note'] as String?,
    );
  }

  @override
  String toString() {
    return 'District(zspId: $zspId, number: $number, isActive: $isActive, '
        'canDriveSafely: $canDriveSafely, note: $note)';
  }
}
