import '../models/work_day.dart';
import '../services/app_database.dart';

class WorkTimeBalanceCalculator {
  WorkTimeBalanceCalculator._();

  static final AppDatabase _database = AppDatabase.instance;

  /// Soll-Arbeitszeit für ein konkretes Datum.
  ///
  /// Ergebnis in Minuten, bereits abzüglich der eingestellten Soll-Pause.
  /// Gibt null zurück, wenn für den Wochentag keine Sollzeit hinterlegt ist.
  static Future<int?> getTargetMinutesForDate(
    DateTime date,
  ) async {
    final setting =
        await _database.getWorkTimeSettingForWeekday(date.weekday);

    if (setting == null) {
      return null;
    }

    final startMinutes = setting['start_minutes'];
    final endMinutes = setting['end_minutes'];
    final breakMinutes = setting['break_minutes'] ?? 0;

    if (startMinutes == null || endMinutes == null) {
      return null;
    }

    final targetMinutes =
        endMinutes - startMinutes - breakMinutes;

    if (targetMinutes < 0) {
      return null;
    }

    return targetMinutes;
  }

  /// Plus-/Minusstunden eines einzelnen Arbeitstags.
  ///
  /// Positiv = Pluszeit
  /// Negativ = Minuszeit
  /// 0 = Soll genau erreicht
  /// null = Berechnung nicht möglich
  static Future<int?> getBalanceMinutesForWorkDay(
    WorkDay workDay,
  ) async {
    if (!workDay.isWorkDay) {
      return null;
    }

    final actualMinutes = workDay.workDurationMinutes;

    if (actualMinutes == null) {
      return null;
    }

    final targetMinutes =
        await getTargetMinutesForDate(workDay.date);

    if (targetMinutes == null) {
      return null;
    }

    return actualMinutes - targetMinutes;
  }

  /// Gesamte Soll-Arbeitszeit für einen Zeitraum.
  ///
  /// Es werden nur tatsächlich eingetragene Arbeitstage berücksichtigt.
  static Future<int> getTargetMinutesForWorkDays(
    Iterable<WorkDay> workDays,
  ) async {
    var total = 0;

    for (final workDay in workDays) {
      if (!workDay.isWorkDay) {
        continue;
      }

      final targetMinutes =
          await getTargetMinutesForDate(workDay.date);

      if (targetMinutes != null) {
        total += targetMinutes;
      }
    }

    return total;
  }

  /// Gesamte tatsächliche Arbeitszeit für Arbeitstage,
  /// für die auch eine Sollzeit hinterlegt ist.
  static Future<int> getActualMinutesForComparableWorkDays(
    Iterable<WorkDay> workDays,
  ) async {
    var total = 0;

    for (final workDay in workDays) {
      if (!workDay.isWorkDay) {
        continue;
      }

      final actualMinutes = workDay.workDurationMinutes;

      if (actualMinutes == null) {
        continue;
      }

      final targetMinutes =
          await getTargetMinutesForDate(workDay.date);

      if (targetMinutes == null) {
        continue;
      }

      total += actualMinutes;
    }

    return total;
  }

  /// Gesamte Plus-/Minuszeit für einen Zeitraum.
  ///
  /// Berücksichtigt nur Arbeitstage, bei denen sowohl eine tatsächliche
  /// Arbeitszeit als auch eine Sollzeit vorhanden sind.
  static Future<int> getBalanceMinutesForWorkDays(
    Iterable<WorkDay> workDays,
  ) async {
    var total = 0;

    for (final workDay in workDays) {
      final balance =
          await getBalanceMinutesForWorkDay(workDay);

      if (balance != null) {
        total += balance;
      }
    }

    return total;
  }

  static String formatDuration(int minutes) {
    final isNegative = minutes < 0;
    final absoluteMinutes = minutes.abs();

    final hours = absoluteMinutes ~/ 60;
    final remainingMinutes = absoluteMinutes % 60;

    final prefix = isNegative ? '-' : '';

    return '$prefix$hours h '
        '${remainingMinutes.toString().padLeft(2, '0')} min';
  }

  static String formatBalance(int minutes) {
    if (minutes == 0) {
      return '±0 min';
    }

    final prefix = minutes > 0 ? '+' : '-';
    final absoluteMinutes = minutes.abs();

    final hours = absoluteMinutes ~/ 60;
    final remainingMinutes = absoluteMinutes % 60;

    if (hours == 0) {
      return '$prefix$remainingMinutes min';
    }

    return '$prefix$hours h '
        '${remainingMinutes.toString().padLeft(2, '0')} min';
  }
}
