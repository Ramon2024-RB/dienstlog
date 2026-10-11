import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/own_tour_entry.dart';
import '../models/monday_delivery_entry.dart';
import '../models/package_driver_entry.dart';
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
    await _importPendingWidgetStarts();
    final workDays = await _database.getWorkDays();
    await _syncTodayWithWidget();
    return workDays;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _importPendingWidgetStarts();
      return _database.getWorkDays();
    });
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
    return _database.getOwnTourEntriesForWorkDay(workDayId);
  }

  Future<List<PackageDriverEntry>> getPackageDriverEntries(
    String workDayId,
  ) async {
    return _database.getPackageDriverEntriesForWorkDay(workDayId);
  }

  Future<List<MondayDeliveryEntry>> getMondayDeliveryEntries(
    String workDayId,
  ) async {
    return _database.getMondayDeliveryEntriesForWorkDay(workDayId);
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
    return _database.getTotalOwnTourPackagesForWorkDay(workDayId);
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
    return _database.getSupportEntriesForWorkDay(workDayId);
  }

  Future<int> getTotalSupportPackages(
    String workDayId,
  ) async {
    return _database.getTotalSupportPackagesForWorkDay(workDayId);
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
    List<PackageDriverEntry> packageDriverEntries = const [],
    List<MondayDeliveryEntry> mondayDeliveryEntries = const [],
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

      await _database.replacePackageDriverEntriesForWorkDay(
        workDay.id,
        packageDriverEntries,
      );

      await _database.replaceMondayDeliveryEntriesForWorkDay(
        workDay.id,
        mondayDeliveryEntries,
      );

      final workDays = await _database.getWorkDays();
      state = AsyncData(workDays);
      await _syncTodayWithWidget();
    } catch (error, stackTrace) {
      state = previousState;
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> updateWorkDay({
    required WorkDay workDay,
    List<OwnTourEntry>? ownTourEntries,
    List<SupportEntry>? supportEntries,
    List<PackageDriverEntry>? packageDriverEntries,
    List<MondayDeliveryEntry>? mondayDeliveryEntries,
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

      if (packageDriverEntries != null) {
        await _database.replacePackageDriverEntriesForWorkDay(
          workDay.id,
          packageDriverEntries,
        );
      }

      if (mondayDeliveryEntries != null) {
        await _database.replaceMondayDeliveryEntriesForWorkDay(
          workDay.id,
          mondayDeliveryEntries,
        );
      }

      final workDays = await _database.getWorkDays();
      state = AsyncData(workDays);
      await _syncTodayWithWidget();
    } catch (error, stackTrace) {
      state = previousState;
      Error.throwWithStackTrace(error, stackTrace);
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
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  // Widget-Buchungen werden beim Laden der App in SQLite uebernommen.
  // Eine bereits vorhandene Dienstbeginn-Uhrzeit wird niemals ueberschrieben.
  Future<void> _importPendingWidgetStarts() async {
    List<dynamic> pending;
    try {
      pending = await _widgetChannel.invokeMethod<List<dynamic>>(
            'getPendingWorkStart',
          ) ??
          const [];
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }

    for (final raw in pending) {
      if (raw is! Map) continue;
      final key = raw['key'];
      final timestamp = raw['timestamp'];
      if (key is! String || timestamp is! int) continue;
      final instant = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final date = DateTime(instant.year, instant.month, instant.day);
      final dateText =
          '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';
      if (key != 'tourlog.pending.workStart.$dateText') continue;
      final minutes = instant.hour * 60 + instant.minute;

      try {
        final existing = await _database.getWorkDayByDate(date);
        if (existing == null) {
          await _database.insertWorkDay(
            WorkDay(
              id: 'workday_${date.year}_${date.month.toString().padLeft(2, '0')}_${date.day.toString().padLeft(2, '0')}',
              date: date,
              type: WorkDayType.work,
              workStart: minutes,
            ),
          );
        } else if (existing.isWorkDay && existing.workStart == null &&
            (existing.departureTime == null ||
                minutes <= existing.departureTime!)) {
          await _database.updateWorkDay(existing.copyWith(workStart: minutes));
        }
        // Bei Konflikten vorhandene Daten bewahren und den Widget-Eintrag
        // als verarbeitet bestaetigen, statt den Arbeitstag zu veraendern.
        await _widgetChannel.invokeMethod<void>('ackPendingWorkStart', {
          'key': key,
          'timestamp': timestamp,
        });
      } on MissingPluginException {
        return;
      } on PlatformException {
        return;
      } catch (_) {
        // Bei DB-Fehler bleibt die Buchung fuer einen spaeteren Versuch erhalten.
        return;
      }
    }
  }

  Future<void> _syncTodayWithWidget() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final workDay = await _database.getWorkDayByDate(today);

    if (workDay == null || !workDay.isWorkDay) {
      await _clearWidgetSafely();
      return;
    }

    try {
      await _widgetChannel.invokeMethod<void>(
        'updateWidget',
        {
          'date': _formatDate(today),
          'workStart': _formatMinutes(workDay.workStart),
          'deliveryStart': _formatMinutes(workDay.departureTime),
          'deliveryEnd': _formatMinutes(workDay.deliveryEnd),
          'workEnd': _formatMinutes(workDay.workEnd),
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
      await _widgetChannel.invokeMethod<void>('clearWidget');
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

    final hourText = hours.toString().padLeft(2, '0');
    final minuteText = remainingMinutes.toString().padLeft(2, '0');

    return '$hourText:$minuteText';
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }
}
