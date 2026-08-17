import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/district.dart';
import 'app_database.dart';

final districtProvider =
    AsyncNotifierProvider<DistrictNotifier, List<District>>(
  DistrictNotifier.new,
);

class DistrictNotifier extends AsyncNotifier<List<District>> {
  final AppDatabase _database = AppDatabase.instance;

  @override
  Future<List<District>> build() async {
    return _database.getDistricts();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(
      () => _database.getDistricts(),
    );
  }

  Future<void> updateDistrict(District district) async {
    final previousState = state;

    state = AsyncData(
      [
        for (final item in previousState.value ?? <District>[])
          if (item.number == district.number) district else item,
      ],
    );

    try {
      await _database.updateDistrict(district);
    } catch (error, stackTrace) {
      state = previousState;

      Error.throwWithStackTrace(
        error,
        stackTrace,
      );
    }
  }

  Future<void> setCanDriveSafely(
    District district,
    bool canDriveSafely,
  ) async {
    await updateDistrict(
      district.copyWith(
        canDriveSafely: canDriveSafely,
      ),
    );
  }

  Future<void> setActive(
    District district,
    bool isActive,
  ) async {
    await updateDistrict(
      district.copyWith(
        isActive: isActive,
      ),
    );
  }

  Future<void> updateNote(
    District district,
    String? note,
  ) async {
    final trimmedNote = note?.trim();

    await updateDistrict(
      district.copyWith(
        note: trimmedNote,
        clearNote: trimmedNote == null || trimmedNote.isEmpty,
      ),
    );
  }
}