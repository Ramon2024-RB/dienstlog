import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/district.dart';
import '../models/own_tour_entry.dart';
import '../models/support_entry.dart';
import '../models/work_day.dart';
import '../models/work_schedule_entry.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  static Database? _database;

  static const String _databaseName = 'dienstlog.db';
  static const int _databaseVersion = 5;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, _databaseName);

    return openDatabase(
      path,
      version: _databaseVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createDistrictsTable(db);
    await _createWorkDaysTable(db);
    await _createSupportEntriesTable(db);
    await _createOwnTourEntriesTable(db);
    await _createWorkScheduleEntriesTable(db);
    await _createWorkTimeSettingsTable(db);

    await _insertInitialDistricts(db);
  }

  Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await _upgradeFromVersion1ToVersion2(db);
    }

    if (oldVersion < 3) {
      await _upgradeFromVersion2ToVersion3(db);
    }

    if (oldVersion < 4) {
      await _upgradeFromVersion3ToVersion4(db);
    }

    if (oldVersion < 5) {
      await _upgradeFromVersion4ToVersion5(db);
    }
  }

  Future<void> _createDistrictsTable(Database db) async {
    await db.execute(
      '''
      CREATE TABLE districts (
        number INTEGER PRIMARY KEY,
        is_active INTEGER NOT NULL DEFAULT 1,
        can_drive_safely INTEGER NOT NULL DEFAULT 0,
        note TEXT
      )
      ''',
    );
  }

  Future<void> _createWorkDaysTable(Database db) async {
    await db.execute(
      '''
      CREATE TABLE work_days (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL UNIQUE,
        type TEXT NOT NULL,
        assignment_type TEXT NOT NULL DEFAULT 'ownDistrict',
        district_id TEXT,
        district_part TEXT NOT NULL DEFAULT 'full',
        work_start INTEGER,
        departure_time INTEGER,
        delivery_end INTEGER,
        work_end INTEGER,
        break_minutes INTEGER NOT NULL DEFAULT 0,
        package_count INTEGER NOT NULL DEFAULT 0,
        cancelled_package_count INTEGER NOT NULL DEFAULT 0,
        has_advertising INTEGER NOT NULL DEFAULT 0,
        advertising TEXT,
        notes TEXT
      )
      ''',
    );
  }

  Future<void> _createSupportEntriesTable(Database db) async {
    await db.execute(
      '''
      CREATE TABLE support_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        work_day_id TEXT NOT NULL,
        district TEXT NOT NULL,
        packages_taken INTEGER NOT NULL DEFAULT 0,
        note TEXT,
        FOREIGN KEY (work_day_id)
          REFERENCES work_days(id)
          ON DELETE CASCADE
      )
      ''',
    );
  }

  Future<void> _createOwnTourEntriesTable(Database db) async {
    await db.execute(
      '''
      CREATE TABLE own_tour_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        work_day_id TEXT NOT NULL,
        district TEXT NOT NULL,
        district_part TEXT NOT NULL DEFAULT 'full',
        package_count INTEGER NOT NULL DEFAULT 0,
        cancelled_package_count INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (work_day_id)
          REFERENCES work_days(id)
          ON DELETE CASCADE
      )
      ''',
    );
  }

  Future<void> _createWorkScheduleEntriesTable(
    Database db,
  ) async {
    await db.execute(
      '''
      CREATE TABLE work_schedule_entries (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL UNIQUE,
        type TEXT NOT NULL,
        districts TEXT NOT NULL DEFAULT '',
        notes TEXT
      )
      ''',
    );
  }

  Future<void> _createWorkTimeSettingsTable(
    Database db,
  ) async {
    await db.execute(
      '''
      CREATE TABLE work_time_settings (
        weekday INTEGER PRIMARY KEY,
        start_minutes INTEGER,
        end_minutes INTEGER,
        break_minutes INTEGER
      )
      ''',
    );
  }

  Future<void> _upgradeFromVersion1ToVersion2(Database db) async {
    await db.transaction((txn) async {
      await txn.execute(
        '''
        ALTER TABLE work_days
        ADD COLUMN assignment_type TEXT NOT NULL DEFAULT 'ownDistrict'
        ''',
      );

      await txn.execute(
        '''
        ALTER TABLE work_days
        ADD COLUMN district_part TEXT NOT NULL DEFAULT 'full'
        ''',
      );

      await txn.execute(
        '''
        ALTER TABLE work_days
        ADD COLUMN departure_time INTEGER
        ''',
      );

      await txn.execute(
        '''
        ALTER TABLE work_days
        ADD COLUMN cancelled_package_count INTEGER NOT NULL DEFAULT 0
        ''',
      );

      await txn.execute(
        '''
        ALTER TABLE work_days
        ADD COLUMN has_advertising INTEGER NOT NULL DEFAULT 0
        ''',
      );

      await txn.execute(
        '''
        ALTER TABLE work_days
        ADD COLUMN advertising TEXT
        ''',
      );

      await txn.execute(
        '''
        UPDATE work_days
        SET assignment_type = CASE
          WHEN is_package_driver = 1 THEN 'packageDriver'
          ELSE 'ownDistrict'
        END
        ''',
      );

      await txn.execute(
        '''
        UPDATE work_days
        SET departure_time = delivery_start
        WHERE departure_time IS NULL
        ''',
      );
    });
  }

  Future<void> _upgradeFromVersion2ToVersion3(Database db) async {
    await db.transaction((txn) async {
      await txn.execute(
        '''
        CREATE TABLE own_tour_entries (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          work_day_id TEXT NOT NULL,
          district TEXT NOT NULL,
          district_part TEXT NOT NULL DEFAULT 'full',
          package_count INTEGER NOT NULL DEFAULT 0,
          cancelled_package_count INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY (work_day_id)
            REFERENCES work_days(id)
            ON DELETE CASCADE
        )
        ''',
      );

      await txn.execute(
        '''
        INSERT INTO own_tour_entries (
          work_day_id,
          district,
          district_part,
          package_count,
          cancelled_package_count
        )
        SELECT
          id,
          district_id,
          district_part,
          package_count,
          cancelled_package_count
        FROM work_days
        WHERE type = 'work'
          AND assignment_type = 'ownDistrict'
          AND district_id IS NOT NULL
          AND TRIM(district_id) != ''
        ''',
      );
    });
  }

  Future<void> _upgradeFromVersion3ToVersion4(Database db) async {
    await _createWorkScheduleEntriesTable(db);
  }

  Future<void> _upgradeFromVersion4ToVersion5(Database db) async {
    await _createWorkTimeSettingsTable(db);
  }

  Future<void> _insertInitialDistricts(Database db) async {
    final batch = db.batch();

    for (var number = 1; number <= 25; number++) {
      batch.insert(
        'districts',
        {
          'number': number,
          'is_active': 1,
          'can_drive_safely': 0,
          'note': null,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    await batch.commit(noResult: true);
  }

  Future<List<District>> getDistricts() async {
    final db = await database;

    final maps = await db.query(
      'districts',
      orderBy: 'number ASC',
    );

    return maps.map(District.fromMap).toList();
  }

  Future<District?> getDistrict(int number) async {
    final db = await database;

    final maps = await db.query(
      'districts',
      where: 'number = ?',
      whereArgs: [number],
      limit: 1,
    );

    if (maps.isEmpty) {
      return null;
    }

    return District.fromMap(maps.first);
  }

  Future<void> updateDistrict(District district) async {
    final db = await database;

    await db.update(
      'districts',
      district.toMap(),
      where: 'number = ?',
      whereArgs: [district.number],
    );
  }

  Future<List<WorkDay>> getWorkDays() async {
    final db = await database;

    final maps = await db.query(
      'work_days',
      orderBy: 'date DESC',
    );

    return maps.map(WorkDay.fromMap).toList();
  }

  Future<WorkDay?> getWorkDayById(String id) async {
    final db = await database;

    final maps = await db.query(
      'work_days',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) {
      return null;
    }

    return WorkDay.fromMap(maps.first);
  }

  Future<WorkDay?> getWorkDayByDate(DateTime date) async {
    final db = await database;

    final normalizedDate = DateTime(
      date.year,
      date.month,
      date.day,
    ).toIso8601String();

    final maps = await db.query(
      'work_days',
      where: 'date = ?',
      whereArgs: [normalizedDate],
      limit: 1,
    );

    if (maps.isEmpty) {
      return null;
    }

    return WorkDay.fromMap(maps.first);
  }

  Future<void> insertWorkDay(WorkDay workDay) async {
    final db = await database;

    await db.insert(
      'work_days',
      workDay.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateWorkDay(WorkDay workDay) async {
    final db = await database;

    await db.update(
      'work_days',
      workDay.toMap(),
      where: 'id = ?',
      whereArgs: [workDay.id],
    );
  }

  Future<void> deleteWorkDay(String id) async {
    final db = await database;

    await db.transaction((txn) async {
      await txn.delete(
        'own_tour_entries',
        where: 'work_day_id = ?',
        whereArgs: [id],
      );

      await txn.delete(
        'support_entries',
        where: 'work_day_id = ?',
        whereArgs: [id],
      );

      await txn.delete(
        'work_days',
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<List<OwnTourEntry>> getOwnTourEntriesForWorkDay(
    String workDayId,
  ) async {
    final db = await database;

    final maps = await db.query(
      'own_tour_entries',
      where: 'work_day_id = ?',
      whereArgs: [workDayId],
      orderBy: 'id ASC',
    );

    return maps.map(OwnTourEntry.fromMap).toList();
  }

  Future<List<OwnTourEntry>> getOwnTourEntriesForDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;

    final normalizedStartDate = _normalizeDate(
      startDate,
    );

    final normalizedEndDate = _normalizeDate(
      endDate,
    );

    final maps = await db.rawQuery(
      '''
      SELECT ote.*
      FROM own_tour_entries ote
      INNER JOIN work_days wd
        ON wd.id = ote.work_day_id
      WHERE wd.date >= ?
        AND wd.date <= ?
        AND wd.type = ?
      ORDER BY wd.date ASC, ote.id ASC
      ''',
      [
        normalizedStartDate,
        normalizedEndDate,
        WorkDayType.work.name,
      ],
    );

    return maps.map(OwnTourEntry.fromMap).toList();
  }

  Future<int> insertOwnTourEntry(
    OwnTourEntry entry,
  ) async {
    final db = await database;

    final map = entry.toMap()
      ..remove('id');

    return db.insert(
      'own_tour_entries',
      map,
    );
  }

  Future<void> updateOwnTourEntry(
    OwnTourEntry entry,
  ) async {
    if (entry.id == null) {
      throw ArgumentError(
        'OwnTourEntry muss eine ID besitzen, um aktualisiert zu werden.',
      );
    }

    final db = await database;

    await db.update(
      'own_tour_entries',
      entry.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  Future<void> deleteOwnTourEntry(int id) async {
    final db = await database;

    await db.delete(
      'own_tour_entries',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> replaceOwnTourEntriesForWorkDay(
    String workDayId,
    List<OwnTourEntry> entries,
  ) async {
    final db = await database;

    await db.transaction((txn) async {
      await txn.delete(
        'own_tour_entries',
        where: 'work_day_id = ?',
        whereArgs: [workDayId],
      );

      for (final entry in entries) {
        final map = entry
            .copyWith(
              workDayId: workDayId,
              clearId: true,
            )
            .toMap()
          ..remove('id');

        await txn.insert(
          'own_tour_entries',
          map,
        );
      }
    });
  }

  Future<int> getTotalOwnTourPackagesForWorkDay(
    String workDayId,
  ) async {
    final db = await database;

    final result = await db.rawQuery(
      '''
      SELECT COALESCE(
        SUM(
          CASE
            WHEN package_count - cancelled_package_count < 0
              THEN 0
            ELSE package_count - cancelled_package_count
          END
        ),
        0
      ) AS total
      FROM own_tour_entries
      WHERE work_day_id = ?
      ''',
      [workDayId],
    );

    return _readIntValue(
      result.first['total'],
    );
  }

  Future<int> getTotalOwnTourPackagesForDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;

    final normalizedStartDate = _normalizeDate(
      startDate,
    );

    final normalizedEndDate = _normalizeDate(
      endDate,
    );

    final result = await db.rawQuery(
      '''
      SELECT COALESCE(
        SUM(
          CASE
            WHEN ote.package_count - ote.cancelled_package_count < 0
              THEN 0
            ELSE ote.package_count - ote.cancelled_package_count
          END
        ),
        0
      ) AS total
      FROM own_tour_entries ote
      INNER JOIN work_days wd
        ON wd.id = ote.work_day_id
      WHERE wd.date >= ?
        AND wd.date <= ?
        AND wd.type = ?
      ''',
      [
        normalizedStartDate,
        normalizedEndDate,
        WorkDayType.work.name,
      ],
    );

    return _readIntValue(
      result.first['total'],
    );
  }

  Future<int> getTotalCancelledOwnTourPackagesForDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;

    final normalizedStartDate = _normalizeDate(
      startDate,
    );

    final normalizedEndDate = _normalizeDate(
      endDate,
    );

    final result = await db.rawQuery(
      '''
      SELECT COALESCE(
        SUM(ote.cancelled_package_count),
        0
      ) AS total
      FROM own_tour_entries ote
      INNER JOIN work_days wd
        ON wd.id = ote.work_day_id
      WHERE wd.date >= ?
        AND wd.date <= ?
        AND wd.type = ?
      ''',
      [
        normalizedStartDate,
        normalizedEndDate,
        WorkDayType.work.name,
      ],
    );

    return _readIntValue(
      result.first['total'],
    );
  }

  Future<List<SupportEntry>> getSupportEntriesForWorkDay(
    String workDayId,
  ) async {
    final db = await database;

    final maps = await db.query(
      'support_entries',
      where: 'work_day_id = ?',
      whereArgs: [workDayId],
      orderBy: 'id ASC',
    );

    return maps.map(SupportEntry.fromMap).toList();
  }

  Future<int> insertSupportEntry(
    SupportEntry entry,
  ) async {
    final db = await database;

    final map = entry.toMap()
      ..remove('id');

    return db.insert(
      'support_entries',
      map,
    );
  }

  Future<void> updateSupportEntry(
    SupportEntry entry,
  ) async {
    if (entry.id == null) {
      throw ArgumentError(
        'SupportEntry muss eine ID besitzen, um aktualisiert zu werden.',
      );
    }

    final db = await database;

    await db.update(
      'support_entries',
      entry.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  Future<void> deleteSupportEntry(int id) async {
    final db = await database;

    await db.delete(
      'support_entries',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> replaceSupportEntriesForWorkDay(
    String workDayId,
    List<SupportEntry> entries,
  ) async {
    final db = await database;

    await db.transaction((txn) async {
      await txn.delete(
        'support_entries',
        where: 'work_day_id = ?',
        whereArgs: [workDayId],
      );

      for (final entry in entries) {
        final map = entry
            .copyWith(
              workDayId: workDayId,
            )
            .toMap()
          ..remove('id');

        await txn.insert(
          'support_entries',
          map,
        );
      }
    });
  }

  Future<int> getTotalSupportPackagesForWorkDay(
    String workDayId,
  ) async {
    final db = await database;

    final result = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(packages_taken), 0) AS total
      FROM support_entries
      WHERE work_day_id = ?
      ''',
      [workDayId],
    );

    return _readIntValue(
      result.first['total'],
    );
  }

  Future<int> getTotalSupportPackagesForDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;

    final normalizedStartDate = _normalizeDate(
      startDate,
    );

    final normalizedEndDate = _normalizeDate(
      endDate,
    );

    final result = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(se.packages_taken), 0) AS total
      FROM support_entries se
      INNER JOIN work_days wd
        ON wd.id = se.work_day_id
      WHERE wd.date >= ?
        AND wd.date <= ?
        AND wd.type = ?
      ''',
      [
        normalizedStartDate,
        normalizedEndDate,
        WorkDayType.work.name,
      ],
    );

    return _readIntValue(
      result.first['total'],
    );
  }

  Future<List<WorkScheduleEntry>> getWorkScheduleEntries() async {
    final db = await database;

    final maps = await db.query(
      'work_schedule_entries',
      orderBy: 'date ASC',
    );

    return maps.map(WorkScheduleEntry.fromMap).toList();
  }

  Future<WorkScheduleEntry?> getWorkScheduleEntryById(
    String id,
  ) async {
    final db = await database;

    final maps = await db.query(
      'work_schedule_entries',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) {
      return null;
    }

    return WorkScheduleEntry.fromMap(maps.first);
  }

  Future<WorkScheduleEntry?> getWorkScheduleEntryByDate(
    DateTime date,
  ) async {
    final db = await database;

    final normalizedDate = _normalizeDate(
      date,
    );

    final maps = await db.query(
      'work_schedule_entries',
      where: 'date = ?',
      whereArgs: [normalizedDate],
      limit: 1,
    );

    if (maps.isEmpty) {
      return null;
    }

    return WorkScheduleEntry.fromMap(maps.first);
  }

  Future<List<WorkScheduleEntry>> getWorkScheduleEntriesForDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;

    final normalizedStartDate = _normalizeDate(
      startDate,
    );

    final normalizedEndDate = _normalizeDate(
      endDate,
    );

    final maps = await db.query(
      'work_schedule_entries',
      where: 'date >= ? AND date <= ?',
      whereArgs: [
        normalizedStartDate,
        normalizedEndDate,
      ],
      orderBy: 'date ASC',
    );

    return maps.map(WorkScheduleEntry.fromMap).toList();
  }

  Future<void> insertWorkScheduleEntry(
    WorkScheduleEntry entry,
  ) async {
    final db = await database;

    await db.insert(
      'work_schedule_entries',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateWorkScheduleEntry(
    WorkScheduleEntry entry,
  ) async {
    final db = await database;

    await db.update(
      'work_schedule_entries',
      entry.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  Future<void> deleteWorkScheduleEntry(
    String id,
  ) async {
    final db = await database;

    await db.delete(
      'work_schedule_entries',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Map<int, Map<String, int?>>> getWorkTimeSettings() async {
    final db = await database;

    final maps = await db.query(
      'work_time_settings',
      orderBy: 'weekday ASC',
    );

    final result = <int, Map<String, int?>>{};

    for (var weekday = DateTime.monday;
        weekday <= DateTime.sunday;
        weekday++) {
      result[weekday] = {
        'start_minutes': null,
        'end_minutes': null,
        'break_minutes': null,
      };
    }

    for (final map in maps) {
      final weekday = map['weekday'] as int;

      result[weekday] = {
        'start_minutes': map['start_minutes'] as int?,
        'end_minutes': map['end_minutes'] as int?,
        'break_minutes': map['break_minutes'] as int?,
      };
    }

    return result;
  }

  Future<Map<String, int?>?> getWorkTimeSettingForWeekday(
    int weekday,
  ) async {
    final db = await database;

    final maps = await db.query(
      'work_time_settings',
      where: 'weekday = ?',
      whereArgs: [weekday],
      limit: 1,
    );

    if (maps.isEmpty) {
      return null;
    }

    final map = maps.first;

    return {
      'start_minutes': map['start_minutes'] as int?,
      'end_minutes': map['end_minutes'] as int?,
      'break_minutes': map['break_minutes'] as int?,
    };
  }

  Future<void> saveWorkTimeSetting({
    required int weekday,
    int? startMinutes,
    int? endMinutes,
    int? breakMinutes,
  }) async {
    final db = await database;

    await db.insert(
      'work_time_settings',
      {
        'weekday': weekday,
        'start_minutes': startMinutes,
        'end_minutes': endMinutes,
        'break_minutes': breakMinutes,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> clearWorkTimeSetting(
    int weekday,
  ) async {
    final db = await database;

    await db.delete(
      'work_time_settings',
      where: 'weekday = ?',
      whereArgs: [weekday],
    );
  }

  String _normalizeDate(DateTime date) {
    return DateTime(
      date.year,
      date.month,
      date.day,
    ).toIso8601String();
  }

  int _readIntValue(Object? value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    if (value is String) {
      return int.tryParse(value) ?? 0;
    }

    return 0;
  }

  Future<void> close() async {
    final db = _database;

    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}