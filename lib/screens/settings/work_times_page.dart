import 'package:flutter/material.dart';

import '../../services/app_database.dart';

class WorkTimesPage extends StatefulWidget {
  const WorkTimesPage({super.key});

  @override
  State<WorkTimesPage> createState() => _WorkTimesPageState();
}

class _WorkTimesPageState extends State<WorkTimesPage> {
  final AppDatabase _database = AppDatabase.instance;

  bool _isLoading = true;
  bool _isSaving = false;

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

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Arbeitszeiten',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer
                        .withValues(alpha: 0.42),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.14),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color:
                              theme.colorScheme.surface.withValues(alpha: 0.78),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(
                          Icons.schedule_outlined,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Deine Sollzeiten',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Lege Start, Ende und Pause für deine regulären Arbeitstage fest.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_view_week_outlined,
                      size: 21,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Wochenplan',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  'Die Soll-Arbeitszeit wird automatisch aus Start, Ende und Pause berechnet.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
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
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 8),
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
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
                      _isSaving ? 'Speichern …' : 'Arbeitszeiten speichern',
                    ),
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
    final theme = Theme.of(context);
    final targetMinutes = setting.targetMinutes;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer
                        .withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Text(
                    _weekdayShortName(weekday),
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _weekdayName(weekday),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        targetMinutes == null
                            ? 'Keine Soll-Arbeitszeit'
                            : 'Soll: ${_formatDuration(targetMinutes)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: targetMinutes == null
                              ? theme.colorScheme.onSurfaceVariant
                              : theme.colorScheme.primary,
                          fontWeight: targetMinutes == null
                              ? FontWeight.normal
                              : FontWeight.w700,
                        ),
                      ),
                    ],
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
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _SettingButton(
                    icon: Icons.login_outlined,
                    label: 'Start',
                    value: _formatMinutes(setting.startMinutes),
                    onTap: onStartTap,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SettingButton(
                    icon: Icons.logout_outlined,
                    label: 'Ende',
                    value: _formatMinutes(setting.endMinutes),
                    onTap: onEndTap,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SettingButton(
                    icon: Icons.coffee_outlined,
                    label: 'Pause',
                    value: setting.breakMinutes == null
                        ? 'Keine'
                        : '${setting.breakMinutes} min',
                    onTap: onBreakTap,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingButton extends StatelessWidget {
  const _SettingButton({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 11,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest
              .withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 18,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
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

String _weekdayShortName(int weekday) {
  switch (weekday) {
    case DateTime.monday:
      return 'MO';
    case DateTime.tuesday:
      return 'DI';
    case DateTime.wednesday:
      return 'MI';
    case DateTime.thursday:
      return 'DO';
    case DateTime.friday:
      return 'FR';
    case DateTime.saturday:
      return 'SA';
    case DateTime.sunday:
      return 'SO';
    default:
      return '';
  }
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
