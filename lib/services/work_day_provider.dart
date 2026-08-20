import 'package:flutter/services.dart';
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

  static const MethodChannel _widgetChannel = MethodChannel(
    'com.example.dienstlog/widget',
  );

  @override
  Future<List<WorkDay>> build() async {
    final workDays = await _database.getWorkDays();

    await _syncTodayWithWidget();

    return workDays;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(
      () => _database.getWorkDays(),
    );

    await _syncTodayWithWidget();
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

  Future<List<OwnTourEntry>> getOwnTourEntriesForDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    return _database.getOwnTourEntriesForDateRange(
      startDate,
      endDate,
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

  Future<int> getTotalCancelledOwnTourPackagesForDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    return _database.getTotalCancelledOwnTourPackagesForDateRange(
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

      await _syncTodayWithWidget();
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

      await _syncTodayWithWidget();
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

      await _syncTodayWithWidget();
    } catch (error, stackTrace) {
      state = previousState;

      Error.throwWithStackTrace(
        error,
        stackTrace,
      );
    }
  }

  Future<void> _syncTodayWithWidget() async {
    final now = DateTime.now();

    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final workDay = await _database.getWorkDayByDate(
      today,
    );

    if (workDay == null ||
        !workDay.isWorkDay) {
      await _clearWidgetSafely();
      return;
    }

    try {
      await _widgetChannel.invokeMethod<void>(
        'updateWidget',
        {
          'date': _formatDate(today),
          'workStart': _formatMinutes(
            workDay.workStart,
          ),
          'deliveryStart': _formatMinutes(
            workDay.departureTime,
          ),
          'deliveryEnd': _formatMinutes(
            workDay.deliveryEnd,
          ),
          'workEnd': _formatMinutes(
            workDay.workEnd,
          ),
        },
      );
    } on MissingPluginException {
      // Auf Plattformen ohne iOS-Widget-Bridge
      // wird die Synchronisierung einfach übersprungen.
    } on PlatformException {
      // Ein Widget-Fehler soll niemals verhindern,
      // dass der eigentliche Arbeitstag gespeichert wird.
    }
  }

  Future<void> _clearWidgetSafely() async {
    try {
      await _widgetChannel.invokeMethod<void>(
        'clearWidget',
      );
    } on MissingPluginException {
      // Keine Widget-Bridge auf dieser Plattform.
    } on PlatformException {
      // Datenbank und App bleiben davon unberührt.
    }
  }

  String? _formatMinutes(int? minutes) {
    if (minutes == null) {
      return null;
    }

    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;

    final hourText = hours.toString().padLeft(
          2,
          '0',
        );

    final minuteText =
        remainingMinutes.toString().padLeft(
              2,
              '0',
            );

    return '$hourText:$minuteText';
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(
          4,
          '0',
        );

    final month = date.month.toString().padLeft(
          2,
          '0',
        );

    final day = date.day.toString().padLeft(
          2,
          '0',
        );

    return '$year-$month-$day';
  }
}