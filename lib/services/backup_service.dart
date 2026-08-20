import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

import 'app_database.dart';

class BackupService {
  BackupService._();

  static final BackupService instance = BackupService._();

  final AppDatabase _database = AppDatabase.instance;

  Future<String> createBackupFile() async {
    final backup = await _database.exportBackupData();

    final json = const JsonEncoder.withIndent(
      '  ',
    ).convert(backup);

    final now = DateTime.now();

    final fileName =
        'TourLog_Backup_${_twoDigits(now.day)}-'
        '${_twoDigits(now.month)}-${now.year}_'
        '${_twoDigits(now.hour)}-'
        '${_twoDigits(now.minute)}.json';

    final file = File(
      '${Directory.systemTemp.path}/$fileName',
    );

    await file.writeAsString(
      json,
      flush: true,
    );

    return file.path;
  }

  Future<void> shareBackup({
    required Rect sharePositionOrigin,
  }) async {
    final path = await createBackupFile();

    await SharePlus.instance.share(
      ShareParams(
        subject: 'TourLog Backup',
        files: [
          XFile(
            path,
            mimeType: 'application/json',
          ),
        ],
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }

  Future<String?> pickBackupFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    return result.files.single.path;
  }

  Future<void> importBackupFile(
    String path,
  ) async {
    final file = File(path);

    if (!await file.exists()) {
      throw const FileSystemException(
        'Die ausgewählte Backup-Datei wurde nicht gefunden.',
      );
    }

    final json = await file.readAsString();
    final decoded = jsonDecode(json);

    if (decoded is! Map) {
      throw const FormatException(
        'Die ausgewählte Datei ist kein gültiges TourLog-Backup.',
      );
    }

    final backup = Map<String, Object?>.from(
      decoded,
    );

    await _database.importBackupData(
      backup,
    );
  }

  static String _twoDigits(int value) {
    return value.toString().padLeft(2, '0');
  }
}
