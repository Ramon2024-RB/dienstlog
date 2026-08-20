import 'package:flutter/material.dart';

import '../../services/app_database.dart';
import '../../services/backup_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final AppDatabase _database = AppDatabase.instance;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isExportingBackup = false;
  bool _isImportingBackup = false;

  final Map<int, _WorkTimeSetting> _settings = {
    for (var day = DateTime.monday; day <= DateTime.saturday; day++)
      day: const _WorkTimeSetting(),
  };

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final storedSettings = await _database.getWorkTimeSettings();

    if (!mounted) {
      return;
    }

    setState(() {
      for (var day = DateTime.monday; day <= DateTime.saturday; day++) {
        final stored = storedSettings[day];

        _settings[day] = _WorkTimeSetting(
          startMinutes: stored?['start_minutes'],
          endMinutes: stored?['end_minutes'],
          breakMinutes: stored?['break_minutes'],
        );
      }

      _isLoading = false;
    });
  }

  Future<void> _selectStartTime(int weekday) async {
    final setting = _settings[weekday] ?? const _WorkTimeSetting();

    final selected = await showTimePicker(
      context: context,
      initialTime: _minutesToTimeOfDay(
        setting.startMinutes ?? 7 * 60,
      ),
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _settings[weekday] = setting.copyWith(
        startMinutes: _timeOfDayToMinutes(selected),
      );
    });
  }

  Future<void> _selectEndTime(int weekday) async {
    final setting = _settings[weekday] ?? const _WorkTimeSetting();

    final selected = await showTimePicker(
      context: context,
      initialTime: _minutesToTimeOfDay(
        setting.endMinutes ?? 16 * 60,
      ),
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _settings[weekday] = setting.copyWith(
        endMinutes: _timeOfDayToMinutes(selected),
      );
    });
  }

  Future<void> _selectBreak(int weekday) async {
    final setting = _settings[weekday] ?? const _WorkTimeSetting();

    final selected = await showDialog<int?>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('Pause'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Keine Pause'),
            ),
            for (final minutes in [15, 20, 30, 45, 60])
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, minutes),
                child: Text('$minutes Minuten'),
              ),
          ],
        );
      },
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _settings[weekday] = setting.copyWith(
        breakMinutes: selected,
        clearBreakMinutes: selected == null,
      );
    });
  }

  void _clearDay(int weekday) {
    setState(() {
      _settings[weekday] = const _WorkTimeSetting();
    });
  }

  Future<void> _save() async {
    for (var day = DateTime.monday; day <= DateTime.saturday; day++) {
      final setting = _settings[day] ?? const _WorkTimeSetting();

      final hasStart = setting.startMinutes != null;
      final hasEnd = setting.endMinutes != null;

      if (hasStart != hasEnd) {
        _showMessage(
          'Bitte bei ${_weekdayName(day)} Start und Ende angeben.',
        );
        return;
      }

      if (hasStart &&
          hasEnd &&
          setting.endMinutes! <= setting.startMinutes!) {
        _showMessage(
          'Bei ${_weekdayName(day)} muss das Ende nach dem Start liegen.',
        );
        return;
      }

      final duration = setting.targetMinutes;

      if (duration != null && duration < 0) {
        _showMessage(
          'Die Pause bei ${_weekdayName(day)} ist länger als die Arbeitszeit.',
        );
        return;
      }
    }

    setState(() {
      _isSaving = true;
    });

    try {
      for (var day = DateTime.monday; day <= DateTime.saturday; day++) {
        final setting = _settings[day] ?? const _WorkTimeSetting();

        if (setting.startMinutes == null && setting.endMinutes == null) {
          await _database.clearWorkTimeSetting(day);
          continue;
        }

        await _database.saveWorkTimeSetting(
          weekday: day,
          startMinutes: setting.startMinutes,
          endMinutes: setting.endMinutes,
          breakMinutes: setting.breakMinutes,
        );
      }

      if (!mounted) {
        return;
      }

      _showMessage('Arbeitszeiten gespeichert.');
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Arbeitszeiten konnten nicht gespeichert werden.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _exportBackup() async {
    setState(() {
      _isExportingBackup = true;
    });

    try {
      final box = context.findRenderObject() as RenderBox?;

      final sharePositionOrigin = box == null
          ? const Rect.fromLTWH(1, 1, 1, 1)
          : box.localToGlobal(Offset.zero) & box.size;

      await BackupService.instance.shareBackup(
        sharePositionOrigin: sharePositionOrigin,
      );

      if (!mounted) {
        return;
      }

      _showMessage(
        'Backup wurde erstellt.',
      );
    } catch (error, stackTrace) {
      debugPrint('BACKUP EXPORT ERROR: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Backup-Fehler'),
            content: SelectableText(
              error.toString(),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    } finally {
      if (mounted) {
        setState(() {
          _isExportingBackup = false;
        });
      }
    }
  }

  Future<void> _importBackup() async {
    final path =
        await BackupService.instance.pickBackupFile();

    if (path == null || !mounted) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Backup importieren?',
          ),
          content: const Text(
            'Beim Import werden die aktuell in TourLog '
            'gespeicherten Daten vollständig durch die '
            'Daten aus dem Backup ersetzt.\n\n'
            'Erstelle vorher ein Backup, wenn du die '
            'aktuellen Daten behalten möchtest.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Importieren'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isImportingBackup = true;
    });

    try {
      await BackupService.instance.importBackupFile(
        path,
      );

      if (!mounted) {
        return;
      }

      await _loadSettings();

      if (!mounted) {
        return;
      }

      _showMessage(
        'Backup erfolgreich importiert.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Backup konnte nicht importiert werden. '
        'Bitte prüfe, ob es eine gültige TourLog-Backup-Datei ist.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isImportingBackup = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Einstellungen'),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Text(
                  'Soll-Arbeitszeiten',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Lege Start, Ende und optional eine Pause für jeden Wochentag fest.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 16),
                for (var day = DateTime.monday;
                    day <= DateTime.saturday;
                    day++) ...[
                  _DayCard(
                    weekday: day,
                    setting:
                        _settings[day] ?? const _WorkTimeSetting(),
                    onStartTap: () => _selectStartTime(day),
                    onEndTap: () => _selectEndTime(day),
                    onBreakTap: () => _selectBreak(day),
                    onClear: () => _clearDay(day),
                  ),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    _isSaving ? 'Speichern …' : 'Speichern',
                  ),
                ),

                const SizedBox(height: 32),

                Text(
                  'Daten & Backup',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),

                const SizedBox(height: 6),

                Text(
                  'Sichere deine TourLog-Daten als Datei oder stelle sie aus einem Backup wieder her.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                ),

                const SizedBox(height: 16),

                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(
                          Icons.ios_share_outlined,
                        ),
                        title: const Text(
                          'Backup exportieren',
                        ),
                        subtitle: const Text(
                          'Alle TourLog-Daten als Backup-Datei sichern',
                        ),
                        trailing: _isExportingBackup
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.chevron_right,
                              ),
                        onTap: _isExportingBackup ||
                                _isImportingBackup
                            ? null
                            : _exportBackup,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(
                          Icons.settings_backup_restore_outlined,
                        ),
                        title: const Text(
                          'Backup importieren',
                        ),
                        subtitle: const Text(
                          'Gesicherte TourLog-Daten wiederherstellen',
                        ),
                        trailing: _isImportingBackup
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.chevron_right,
                              ),
                        onTap: _isExportingBackup ||
                                _isImportingBackup
                            ? null
                            : _importBackup,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.weekday,
    required this.setting,
    required this.onStartTap,
    required this.onEndTap,
    required this.onBreakTap,
    required this.onClear,
  });

  final int weekday;
  final _WorkTimeSetting setting;
  final VoidCallback onStartTap;
  final VoidCallback onEndTap;
  final VoidCallback onBreakTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final targetMinutes = setting.targetMinutes;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _weekdayName(weekday),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                if (setting.hasValues)
                  IconButton(
                    tooltip: 'Tag leeren',
                    onPressed: onClear,
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _SettingButton(
                    label: 'Start',
                    value: _formatMinutes(setting.startMinutes),
                    onTap: onStartTap,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SettingButton(
                    label: 'Ende',
                    value: _formatMinutes(setting.endMinutes),
                    onTap: onEndTap,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SettingButton(
                    label: 'Pause',
                    value: setting.breakMinutes == null
                        ? 'Keine'
                        : '${setting.breakMinutes} min',
                    onTap: onBreakTap,
                  ),
                ),
              ],
            ),
            if (targetMinutes != null) ...[
              const SizedBox(height: 12),
              Text(
                'Soll-Arbeitszeit: ${_formatDuration(targetMinutes)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ] else ...[
              const SizedBox(height: 12),
              Text(
                'Keine Soll-Arbeitszeit',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SettingButton extends StatelessWidget {
  const _SettingButton({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 12,
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _WorkTimeSetting {
  const _WorkTimeSetting({
    this.startMinutes,
    this.endMinutes,
    this.breakMinutes,
  });

  final int? startMinutes;
  final int? endMinutes;
  final int? breakMinutes;

  bool get hasValues =>
      startMinutes != null ||
      endMinutes != null ||
      breakMinutes != null;

  int? get targetMinutes {
    if (startMinutes == null || endMinutes == null) {
      return null;
    }

    return endMinutes! -
        startMinutes! -
        (breakMinutes ?? 0);
  }

  _WorkTimeSetting copyWith({
    int? startMinutes,
    int? endMinutes,
    int? breakMinutes,
    bool clearBreakMinutes = false,
  }) {
    return _WorkTimeSetting(
      startMinutes: startMinutes ?? this.startMinutes,
      endMinutes: endMinutes ?? this.endMinutes,
      breakMinutes: clearBreakMinutes
          ? null
          : breakMinutes ?? this.breakMinutes,
    );
  }
}

int _timeOfDayToMinutes(TimeOfDay time) {
  return time.hour * 60 + time.minute;
}

TimeOfDay _minutesToTimeOfDay(int minutes) {
  return TimeOfDay(
    hour: minutes ~/ 60,
    minute: minutes % 60,
  );
}

String _formatMinutes(int? minutes) {
  if (minutes == null) {
    return '–';
  }

  final hours = minutes ~/ 60;
  final mins = minutes % 60;

  return '${hours.toString().padLeft(2, '0')}:'
      '${mins.toString().padLeft(2, '0')}';
}

String _formatDuration(int minutes) {
  final hours = minutes ~/ 60;
  final mins = minutes % 60;

  if (hours == 0) {
    return '$mins min';
  }

  if (mins == 0) {
    return '$hours h';
  }

  return '$hours h $mins min';
}

String _weekdayName(int weekday) {
  switch (weekday) {
    case DateTime.monday:
      return 'Montag';
    case DateTime.tuesday:
      return 'Dienstag';
    case DateTime.wednesday:
      return 'Mittwoch';
    case DateTime.thursday:
      return 'Donnerstag';
    case DateTime.friday:
      return 'Freitag';
    case DateTime.saturday:
      return 'Samstag';
    case DateTime.sunday:
      return 'Sonntag';
    default:
      return '';
  }
}
