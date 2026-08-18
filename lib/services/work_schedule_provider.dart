import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/work_schedule_entry.dart';
import 'app_database.dart';

final workScheduleProvider =
    AsyncNotifierProvider<
        WorkScheduleNotifier,
        List<WorkScheduleEntry>>(
  WorkScheduleNotifier.new,
);

class WorkScheduleNotifier
    extends AsyncNotifier<List<WorkScheduleEntry>> {
  final AppDatabase _database = AppDatabase.instance;

  @override
  Future<List<WorkScheduleEntry>> build() async {
    return _database.getWorkScheduleEntries();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(
      () => _database.getWorkScheduleEntries(),
    );
  }

  Future<WorkScheduleEntry?> getById(
    String id,
  ) async {
    return _database.getWorkScheduleEntryById(
      id,
    );
  }

  Future<WorkScheduleEntry?> getByDate(
    DateTime date,
  ) async {
    return _database.getWorkScheduleEntryByDate(
      date,
    );
  }

  Future<List<WorkScheduleEntry>>
      getForDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    return _database
        .getWorkScheduleEntriesForDateRange(
      startDate,
      endDate,
    );
  }

  Future<void> save(
    WorkScheduleEntry entry,
  ) async {
    final previousState = state;

    try {
      await _database.insertWorkScheduleEntry(
        entry,
      );

      final entries =
          await _database.getWorkScheduleEntries();

      state = AsyncData(entries);
    } catch (error, stackTrace) {
      state = previousState;

      Error.throwWithStackTrace(
        error,
        stackTrace,
      );
    }
  }

  Future<void> updateEntry(
    WorkScheduleEntry entry,
  ) async {
    final previousState = state;

    try {
      await _database.updateWorkScheduleEntry(
        entry,
      );

      final entries =
          await _database.getWorkScheduleEntries();

      state = AsyncData(entries);
    } catch (error, stackTrace) {
      state = previousState;

      Error.throwWithStackTrace(
        error,
        stackTrace,
      );
    }
  }

  Future<void> delete(
    String id,
  ) async {
    final previousState = state;

    try {
      await _database.deleteWorkScheduleEntry(
        id,
      );

      final entries =
          await _database.getWorkScheduleEntries();

      state = AsyncData(entries);
    } catch (error, stackTrace) {
      state = previousState;

      Error.throwWithStackTrace(
        error,
        stackTrace,
      );
    }
  }
}