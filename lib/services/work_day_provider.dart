import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/own_tour_entry.dart';
import '../models/support_entry.dart';
import '../models/work_day.dart';
import 'app_database.dart';

final workDayProvider =
    AsyncNotifierProvider<WorkDayNotifier, List<WorkDay>>(
  WorkDayNotifier.new,
);

class WorkDayNotifier extends AsyncNotifier<List<WorkDay>> {
  final AppDatabase _database = AppDatabase.instance;

  @override
  Future<List<WorkDay>> build() async {
    return _database.getWorkDays();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(
      () => _database.getWorkDays(),
    );
  }

  Future<WorkDay?> getWorkDayById(String id) async {
    return _database.getWorkDayById(id);
  }

  Future<WorkDay?> getWorkDayByDate(DateTime date) async {
    return _database.getWorkDayByDate(date);
  }

  Future<List<OwnTourEntry>> getOwnTourEntries(
    String workDayId,
  ) async {
    return _database.getOwnTourEntriesForWorkDay(
      workDayId,
    );
  }

  Future<int> getTotalOwnTourPackages(
    String workDayId,
  ) async {
    return _database.getTotalOwnTourPackagesForWorkDay(
      workDayId,
    );
  }

  Future<int> getTotalOwnTourPackagesForDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    return _database.getTotalOwnTourPackagesForDateRange(
      startDate,
      endDate,
    );
  }

  Future<List<SupportEntry>> getSupportEntries(
    String workDayId,
  ) async {
    return _database.getSupportEntriesForWorkDay(
      workDayId,
    );
  }

  Future<int> getTotalSupportPackages(
    String workDayId,
  ) async {
    return _database.getTotalSupportPackagesForWorkDay(
      workDayId,
    );
  }

  Future<int> getTotalSupportPackagesForDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    return _database.getTotalSupportPackagesForDateRange(
      startDate,
      endDate,
    );
  }

  Future<void> saveWorkDay({
    required WorkDay workDay,
    List<OwnTourEntry> ownTourEntries = const [],
    List<SupportEntry> supportEntries = const [],
  }) async {
    final previousState = state;

    try {
      await _database.insertWorkDay(workDay);

      await _database.replaceOwnTourEntriesForWorkDay(
        workDay.id,
        ownTourEntries,
      );

      await _database.replaceSupportEntriesForWorkDay(
        workDay.id,
        supportEntries,
      );

      final workDays = await _database.getWorkDays();

      state = AsyncData(workDays);
    } catch (error, stackTrace) {
      state = previousState;

      Error.throwWithStackTrace(
        error,
        stackTrace,
      );
    }
  }

  Future<void> updateWorkDay({
    required WorkDay workDay,
    List<OwnTourEntry>? ownTourEntries,
    List<SupportEntry>? supportEntries,
  }) async {
    final previousState = state;

    try {
      await _database.updateWorkDay(workDay);

      if (ownTourEntries != null) {
        await _database.replaceOwnTourEntriesForWorkDay(
          workDay.id,
          ownTourEntries,
        );
      }

      if (supportEntries != null) {
        await _database.replaceSupportEntriesForWorkDay(
          workDay.id,
          supportEntries,
        );
      }

      final workDays = await _database.getWorkDays();

      state = AsyncData(workDays);
    } catch (error, stackTrace) {
      state = previousState;

      Error.throwWithStackTrace(
        error,
        stackTrace,
      );
    }
  }

  Future<void> deleteWorkDay(String id) async {
    final previousState = state;

    try {
      await _database.deleteWorkDay(id);

      final workDays = await _database.getWorkDays();

      state = AsyncData(workDays);
    } catch (error, stackTrace) {
      state = previousState;

      Error.throwWithStackTrace(
        error,
        stackTrace,
      );
    }
  }
}