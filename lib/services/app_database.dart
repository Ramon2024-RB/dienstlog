import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/district.dart';
import '../models/support_entry.dart';
import '../models/work_day.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  static Database? _database;

  static const String _databaseName = 'dienstlog.db';
  static const int _databaseVersion = 2;

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

  Future<int> insertSupportEntry(SupportEntry entry) async {
    final db = await database;

    final map = entry.toMap()
      ..remove('id');

    return db.insert(
      'support_entries',
      map,
    );
  }

  Future<void> updateSupportEntry(SupportEntry entry) async {
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

    final value = result.first['total'];

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
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