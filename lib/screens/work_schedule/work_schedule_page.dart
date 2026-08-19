import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/work_schedule_entry.dart';
import '../../services/work_schedule_provider.dart';

class WorkSchedulePage extends ConsumerStatefulWidget {
  const WorkSchedulePage({super.key});

  @override
  ConsumerState<WorkSchedulePage> createState() =>
      _WorkSchedulePageState();
}

class _WorkSchedulePageState
    extends ConsumerState<WorkSchedulePage> {
  late DateTime _visibleMonth;
  bool _isMultiSelectMode = false;
  final Set<DateTime> _selectedDates = <DateTime>{};

  static const List<String> _monthNames = [
    'Januar',
    'Februar',
    'März',
    'April',
    'Mai',
    'Juni',
    'Juli',
    'August',
    'September',
    'Oktober',
    'November',
    'Dezember',
  ];

  static const List<String> _weekDayNames = [
    'Mo',
    'Di',
    'Mi',
    'Do',
    'Fr',
    'Sa',
    'So',
  ];

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();

    _visibleMonth = DateTime(
      now.year,
      now.month,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheduleAsync = ref.watch(
      workScheduleProvider,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Arbeitsplan',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: _isMultiSelectMode
                ? 'Mehrfachauswahl beenden'
                : 'Mehrere Tage planen',
            onPressed: _toggleMultiSelectMode,
            icon: Icon(
              _isMultiSelectMode
                  ? Icons.close
                  : Icons.library_add_check_outlined,
            ),
          ),
          IconButton(
            tooltip: 'Heute',
            onPressed: _showCurrentMonth,
            icon: const Icon(
              Icons.today_outlined,
            ),
          ),
        ],
      ),
      body: scheduleAsync.when(
        loading: () {
          return const Center(
            child: CircularProgressIndicator(),
          );
        },
        error: (error, stackTrace) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Der Arbeitsplan konnte nicht geladen werden.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () {
                      ref.invalidate(
                        workScheduleProvider,
                      );
                    },
                    icon: const Icon(
                      Icons.refresh,
                    ),
                    label: const Text(
                      'Erneut versuchen',
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        data: (entries) {
          return _buildContent(
            context,
            entries,
          );
        },
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<WorkScheduleEntry> entries,
  ) {
    final monthEntries = <DateTime, WorkScheduleEntry>{};

    for (final entry in entries) {
      if (entry.date.year == _visibleMonth.year &&
          entry.date.month == _visibleMonth.month) {
        monthEntries[
            _normalizeDate(entry.date)] = entry;
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        16,
        8,
        16,
        32,
      ),
      children: [
        Text(
          'Plane hier deine voraussichtlichen Einsätze.',
          style: Theme.of(context)
              .textTheme
              .bodyLarge
              ?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 20),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              12,
              8,
              12,
              16,
            ),
            child: Column(
              children: [
                _MonthHeader(
                  month:
                      '${_monthNames[_visibleMonth.month - 1]} '
                      '${_visibleMonth.year}',
                  onPrevious: _showPreviousMonth,
                  onNext: _showNextMonth,
                ),
                const SizedBox(height: 8),
                _WeekDayHeader(
                  weekDayNames: _weekDayNames,
                ),
                const SizedBox(height: 4),
                _buildCalendarGrid(
                  context,
                  monthEntries,
                ),
              ],
            ),
          ),
        ),
        if (_isMultiSelectMode) ...[
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _selectedDates.isEmpty
                        ? 'Wähle die Tage aus, die du gemeinsam planen möchtest.'
                        : '${_selectedDates.length} Tage ausgewählt',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _selectedDates.isEmpty
                        ? null
                        : _openMultiDayEditor,
                    icon: const Icon(Icons.edit_calendar_outlined),
                    label: const Text(
                      'Ausgewählte Tage planen',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        _Legend(),
      ],
    );
  }

  Widget _buildCalendarGrid(
    BuildContext context,
    Map<DateTime, WorkScheduleEntry> entries,
  ) {
    final firstDay = DateTime(
      _visibleMonth.year,
      _visibleMonth.month,
      1,
    );

    final lastDay = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + 1,
      0,
    );

    final leadingDays = firstDay.weekday - 1;

    final cellCount =
        leadingDays + lastDay.day;

    final rowCount = (cellCount / 7).ceil();

    final totalCells = rowCount * 7;

    return GridView.builder(
      shrinkWrap: true,
      physics:
          const NeverScrollableScrollPhysics(),
      gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 0.78,
        crossAxisSpacing: 3,
        mainAxisSpacing: 3,
      ),
      itemCount: totalCells,
      itemBuilder: (context, index) {
        final dayNumber =
            index - leadingDays + 1;

        if (dayNumber < 1 ||
            dayNumber > lastDay.day) {
          return const SizedBox.shrink();
        }

        final date = DateTime(
          _visibleMonth.year,
          _visibleMonth.month,
          dayNumber,
        );

        final entry = entries[
            _normalizeDate(date)];

        return _CalendarDay(
          date: date,
          entry: entry,
          isToday: _isSameDate(
            date,
            DateTime.now(),
          ),
          isSelected: _selectedDates.contains(
            _normalizeDate(date),
          ),
          onTap: () {
            if (_isMultiSelectMode) {
              _toggleSelectedDate(date);
              return;
            }

            _openDayEditor(
              date,
              entry,
            );
          },
        );
      },
    );
  }

  Future<void> _openDayEditor(
    DateTime date,
    WorkScheduleEntry? existingEntry,
  ) async {
    final result =
        await showModalBottomSheet<
            _WorkScheduleEditorResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return _WorkScheduleEditorSheet(
          date: date,
          existingEntry: existingEntry,
        );
      },
    );

    if (result == null || !mounted) {
      return;
    }

    final notifier = ref.read(
      workScheduleProvider.notifier,
    );

    try {
      if (result.deleteEntry) {
        if (existingEntry != null) {
          await notifier.delete(
            existingEntry.id,
          );
        }

        return;
      }

      final entry = result.entry;

      if (entry == null) {
        return;
      }

      if (existingEntry == null) {
        await notifier.save(entry);
      } else {
        await notifier.updateEntry(entry);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Die Planung konnte nicht gespeichert werden: $error',
          ),
        ),
      );
    }
  }

  void _toggleMultiSelectMode() {
    setState(() {
      _isMultiSelectMode = !_isMultiSelectMode;

      if (!_isMultiSelectMode) {
        _selectedDates.clear();
      }
    });
  }

  void _toggleSelectedDate(DateTime date) {
    final normalizedDate = _normalizeDate(date);

    setState(() {
      if (_selectedDates.contains(normalizedDate)) {
        _selectedDates.remove(normalizedDate);
      } else {
        _selectedDates.add(normalizedDate);
      }
    });
  }

  Future<void> _openMultiDayEditor() async {
    final dates = _selectedDates.toList()
      ..sort();

    final result = await showModalBottomSheet<
        _MultiDayScheduleResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return _MultiDayScheduleSheet(
          dates: dates,
        );
      },
    );

    if (result == null || !mounted) {
      return;
    }

    final notifier = ref.read(
      workScheduleProvider.notifier,
    );

    try {
      final currentEntries =
          ref.read(workScheduleProvider).when(
                data: (entries) => entries,
                loading: () =>
                    const <WorkScheduleEntry>[],
                error: (error, stackTrace) =>
                    const <WorkScheduleEntry>[],
              );

      for (final date in dates) {
        WorkScheduleEntry? existingEntry;

        for (final entry in currentEntries) {
          if (_isSameDate(entry.date, date)) {
            existingEntry = entry;
            break;
          }
        }

        final id = existingEntry?.id ??
            'schedule_'
                '${date.year}_'
                '${date.month.toString().padLeft(2, '0')}_'
                '${date.day.toString().padLeft(2, '0')}';

        final entry = WorkScheduleEntry(
          id: id,
          date: date,
          type: result.type,
          districts: result.type ==
                  WorkScheduleType.work
              ? List<String>.from(
                  result.districts,
                )
              : const [],
          notes: result.notes,
        );

        if (existingEntry == null) {
          await notifier.save(entry);
        } else {
          await notifier.updateEntry(entry);
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedDates.clear();
        _isMultiSelectMode = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Die Mehrfachplanung konnte nicht gespeichert werden: $error',
          ),
        ),
      );
    }
  }

  void _showPreviousMonth() {
    setState(() {
      _visibleMonth = DateTime(
        _visibleMonth.year,
        _visibleMonth.month - 1,
      );
    });
  }

  void _showNextMonth() {
    setState(() {
      _visibleMonth = DateTime(
        _visibleMonth.year,
        _visibleMonth.month + 1,
      );
    });
  }

  void _showCurrentMonth() {
    final now = DateTime.now();

    setState(() {
      _visibleMonth = DateTime(
        now.year,
        now.month,
      );
    });
  }

  static DateTime _normalizeDate(
    DateTime date,
  ) {
    return DateTime(
      date.year,
      date.month,
      date.day,
    );
  }

  static bool _isSameDate(
    DateTime first,
    DateTime second,
  ) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });

  final String month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Vorheriger Monat',
          onPressed: onPrevious,
          icon: const Icon(
            Icons.chevron_left,
          ),
        ),
        Expanded(
          child: Text(
            month,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        IconButton(
          tooltip: 'Nächster Monat',
          onPressed: onNext,
          icon: const Icon(
            Icons.chevron_right,
          ),
        ),
      ],
    );
  }
}

class _WeekDayHeader extends StatelessWidget {
  const _WeekDayHeader({
    required this.weekDayNames,
  });

  final List<String> weekDayNames;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: weekDayNames.map(
        (name) {
          return Expanded(
            child: Center(
              child: Text(
                name,
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(
                      fontWeight:
                          FontWeight.bold,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant,
                    ),
              ),
            ),
          );
        },
      ).toList(),
    );
  }
}

class _CalendarDay extends StatelessWidget {
  const _CalendarDay({
    required this.date,
    required this.entry,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  final DateTime date;
  final WorkScheduleEntry? entry;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        Theme.of(context).colorScheme;

    final entryColor = entry == null
        ? null
        : _scheduleTypeColor(
            context,
            entry!.type,
          );

    return Material(
      color: entryColor ??
          colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(12),
            border: isSelected
                ? Border.all(
                    color: colorScheme.primary,
                    width: 3,
                  )
                : isToday
                    ? Border.all(
                        color: colorScheme.primary,
                        width: 2,
                      )
                    : null,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 2,
            vertical: 5,
          ),
          child: Column(
            children: [
              Text(
                '${date.day}',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(
                      fontWeight: isToday
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
              ),
              if (entry != null) ...[
                const SizedBox(height: 3),
                Icon(
                  _scheduleTypeIcon(
                    entry!.type,
                  ),
                  size: 15,
                ),
                const SizedBox(height: 2),
                Expanded(
                  child: Center(
                    child: Text(
                      _shortEntryLabel(
                        entry!,
                      ),
                      textAlign:
                          TextAlign.center,
                      maxLines: 2,
                      overflow:
                          TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(
                            fontSize: 9,
                            height: 1.05,
                            fontWeight:
                                FontWeight.w600,
                          ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _shortEntryLabel(
    WorkScheduleEntry entry,
  ) {
    switch (entry.type) {
      case WorkScheduleType.work:
        if (entry.districts.isEmpty) {
          return 'Arbeit';
        }

        if (entry.districts.length == 1) {
          return 'B ${entry.districts.first}';
        }

        return 'B ${entry.districts.join(' · ')}';

      case WorkScheduleType.packageDriver:
        return 'Paket';

      case WorkScheduleType.free:
        return 'Frei';

      case WorkScheduleType.vacation:
        return 'Urlaub';

      case WorkScheduleType.holiday:
        return 'Feiertag';
    }
  }
}

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 16,
          runSpacing: 12,
          children: const [
            _LegendItem(
              icon: Icons.route_outlined,
              label: 'Bezirk',
            ),
            _LegendItem(
              icon:
                  Icons.local_shipping_outlined,
              label: 'Paketfahrer',
            ),
            _LegendItem(
              icon: Icons.weekend_outlined,
              label: 'Frei',
            ),
            _LegendItem(
              icon:
                  Icons.beach_access_outlined,
              label: 'Urlaub',
            ),
            _LegendItem(
              icon:
                  Icons.celebration_outlined,
              label: 'Feiertag',
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 18,
          color:
              Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}

class _WorkScheduleEditorSheet
    extends StatefulWidget {
  const _WorkScheduleEditorSheet({
    required this.date,
    required this.existingEntry,
  });

  final DateTime date;
  final WorkScheduleEntry? existingEntry;

  @override
  State<_WorkScheduleEditorSheet>
      createState() =>
          _WorkScheduleEditorSheetState();
}

class _WorkScheduleEditorSheetState
    extends State<_WorkScheduleEditorSheet> {
  late WorkScheduleType _type;
  late List<String> _districts;

  final TextEditingController
      _districtController =
      TextEditingController();

  final TextEditingController
      _notesController =
      TextEditingController();

  @override
  void initState() {
    super.initState();

    _type = widget.existingEntry?.type ??
        WorkScheduleType.work;

    _districts = List<String>.from(
      widget.existingEntry?.districts ??
          const [],
    );

    _notesController.text =
        widget.existingEntry?.notes ?? '';
  }

  @override
  void dispose() {
    _districtController.dispose();
    _notesController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset =
        MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        20 + bottomInset,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin:
                    const EdgeInsets.only(
                  bottom: 20,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .outlineVariant,
                  borderRadius:
                      BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              _formatDate(widget.date),
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Geplanten Einsatz festlegen',
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 24),
            Text(
              'Planung',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<
                WorkScheduleType>(
              initialValue: _type,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Geplanter Einsatz',
              ),
              items: WorkScheduleType.values
                  .map(
                    (type) =>
                        DropdownMenuItem<
                            WorkScheduleType>(
                      value: type,
                      child: Row(
                        children: [
                          Icon(
                            _scheduleTypeIcon(
                              type,
                            ),
                            size: 20,
                          ),
                          const SizedBox(
                            width: 10,
                          ),
                          Text(
                            _scheduleTypeLabel(
                              type,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  _type = value;

                  if (_type !=
                      WorkScheduleType.work) {
                    _districts.clear();
                  }
                });
              },
            ),
            if (_type ==
                WorkScheduleType.work) ...[
              const SizedBox(height: 24),
              Text(
                'Geplante Bezirke',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(
                      fontWeight:
                          FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Du kannst auch mehrere Bezirke für einen Tag eintragen.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller:
                          _districtController,
                      keyboardType:
                          TextInputType.number,
                      decoration:
                          const InputDecoration(
                        border:
                            OutlineInputBorder(),
                        labelText: 'Bezirk',
                        hintText: 'z. B. 7',
                      ),
                      onSubmitted: (_) {
                        _addDistrict();
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filled(
                    tooltip:
                        'Bezirk hinzufügen',
                    onPressed: _addDistrict,
                    icon: const Icon(
                      Icons.add,
                    ),
                  ),
                ],
              ),
              if (_districts.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _districts
                      .map(
                        (district) =>
                            InputChip(
                          label: Text(
                            'Bezirk $district',
                          ),
                          avatar: const Icon(
                            Icons.route_outlined,
                            size: 18,
                          ),
                          onDeleted: () {
                            setState(() {
                              _districts.remove(
                                district,
                              );
                            });
                          },
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
            const SizedBox(height: 24),
            TextField(
              controller: _notesController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Notiz',
                hintText:
                    'Optional, z. B. Springer oder kurzfristige Änderung',
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(
                  Icons.check,
                ),
                label: const Text(
                  'Planung speichern',
                ),
              ),
            ),
            if (widget.existingEntry !=
                null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: _delete,
                  icon: const Icon(
                    Icons.delete_outline,
                  ),
                  label: const Text(
                    'Planung löschen',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _addDistrict() {
    final district =
        _districtController.text.trim();

    if (district.isEmpty) {
      return;
    }

    if (_districts.contains(district)) {
      _districtController.clear();
      return;
    }

    setState(() {
      _districts.add(district);

      _districts.sort(
        (first, second) {
          final firstNumber =
              int.tryParse(first);

          final secondNumber =
              int.tryParse(second);

          if (firstNumber != null &&
              secondNumber != null) {
            return firstNumber.compareTo(
              secondNumber,
            );
          }

          return first.compareTo(second);
        },
      );

      _districtController.clear();
    });
  }

  void _save() {
    if (_type == WorkScheduleType.work &&
        _districtController.text
            .trim()
            .isNotEmpty) {
      _addDistrict();
    }

    final notes =
        _notesController.text.trim();

    final existing =
        widget.existingEntry;

    final id = existing?.id ??
        'schedule_'
            '${widget.date.year}_'
            '${widget.date.month.toString().padLeft(2, '0')}_'
            '${widget.date.day.toString().padLeft(2, '0')}';

    final entry = WorkScheduleEntry(
      id: id,
      date: widget.date,
      type: _type,
      districts:
          _type == WorkScheduleType.work
              ? List<String>.from(
                  _districts,
                )
              : const [],
      notes: notes.isEmpty ? null : notes,
    );

    Navigator.of(context).pop(
      _WorkScheduleEditorResult(
        entry: entry,
      ),
    );
  }

  void _delete() {
    Navigator.of(context).pop(
      const _WorkScheduleEditorResult(
        deleteEntry: true,
      ),
    );
  }

  static String _formatDate(
    DateTime date,
  ) {
    const weekDays = [
      'Montag',
      'Dienstag',
      'Mittwoch',
      'Donnerstag',
      'Freitag',
      'Samstag',
      'Sonntag',
    ];

    const months = [
      'Januar',
      'Februar',
      'März',
      'April',
      'Mai',
      'Juni',
      'Juli',
      'August',
      'September',
      'Oktober',
      'November',
      'Dezember',
    ];

    return '${weekDays[date.weekday - 1]}, '
        '${date.day}. '
        '${months[date.month - 1]} '
        '${date.year}';
  }
}


class _MultiDayScheduleSheet extends StatefulWidget {
  const _MultiDayScheduleSheet({
    required this.dates,
  });

  final List<DateTime> dates;

  @override
  State<_MultiDayScheduleSheet> createState() =>
      _MultiDayScheduleSheetState();
}

class _MultiDayScheduleSheetState
    extends State<_MultiDayScheduleSheet> {
  WorkScheduleType _type = WorkScheduleType.work;
  final List<String> _districts = <String>[];
  final TextEditingController _districtController =
      TextEditingController();
  final TextEditingController _notesController =
      TextEditingController();

  @override
  void dispose() {
    _districtController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset =
        MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        20 + bottomInset,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(
                  bottom: 20,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .outlineVariant,
                  borderRadius:
                      BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              '${widget.dates.length} Tage planen',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Die Planung wird für alle ausgewählten Tage übernommen.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<WorkScheduleType>(
              initialValue: _type,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Geplanter Einsatz',
              ),
              items: WorkScheduleType.values
                  .map(
                    (type) =>
                        DropdownMenuItem<
                            WorkScheduleType>(
                      value: type,
                      child: Row(
                        children: [
                          Icon(
                            _scheduleTypeIcon(type),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _scheduleTypeLabel(type),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  _type = value;

                  if (_type !=
                      WorkScheduleType.work) {
                    _districts.clear();
                  }
                });
              },
            ),
            if (_type ==
                WorkScheduleType.work) ...[
              const SizedBox(height: 24),
              Text(
                'Geplante Bezirke',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller:
                          _districtController,
                      keyboardType:
                          TextInputType.number,
                      decoration:
                          const InputDecoration(
                        border:
                            OutlineInputBorder(),
                        labelText: 'Bezirk',
                        hintText: 'z. B. 19',
                      ),
                      onSubmitted: (_) =>
                          _addDistrict(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filled(
                    onPressed: _addDistrict,
                    tooltip: 'Bezirk hinzufügen',
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              if (_districts.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _districts
                      .map(
                        (district) => InputChip(
                          label: Text(
                            'Bezirk $district',
                          ),
                          avatar: const Icon(
                            Icons.route_outlined,
                            size: 18,
                          ),
                          onDeleted: () {
                            setState(() {
                              _districts.remove(
                                district,
                              );
                            });
                          },
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
            const SizedBox(height: 24),
            TextField(
              controller: _notesController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Notiz',
                hintText: 'Optional',
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check),
                label: const Text(
                  'Für alle Tage speichern',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addDistrict() {
    final district =
        _districtController.text.trim();

    if (district.isEmpty ||
        _districts.contains(district)) {
      _districtController.clear();
      return;
    }

    setState(() {
      _districts.add(district);
      _districtController.clear();
    });
  }

  void _save() {
    if (_type == WorkScheduleType.work &&
        _districtController.text
            .trim()
            .isNotEmpty) {
      _addDistrict();
    }

    final notes =
        _notesController.text.trim();

    Navigator.of(context).pop(
      _MultiDayScheduleResult(
        type: _type,
        districts: List<String>.from(
          _districts,
        ),
        notes: notes.isEmpty ? null : notes,
      ),
    );
  }
}

class _MultiDayScheduleResult {
  const _MultiDayScheduleResult({
    required this.type,
    required this.districts,
    required this.notes,
  });

  final WorkScheduleType type;
  final List<String> districts;
  final String? notes;
}

class _WorkScheduleEditorResult {
  const _WorkScheduleEditorResult({
    this.entry,
    this.deleteEntry = false,
  });

  final WorkScheduleEntry? entry;
  final bool deleteEntry;
}

IconData _scheduleTypeIcon(
  WorkScheduleType type,
) {
  switch (type) {
    case WorkScheduleType.work:
      return Icons.route_outlined;

    case WorkScheduleType.packageDriver:
      return Icons.local_shipping_outlined;

    case WorkScheduleType.free:
      return Icons.weekend_outlined;

    case WorkScheduleType.vacation:
      return Icons.beach_access_outlined;

    case WorkScheduleType.holiday:
      return Icons.celebration_outlined;
  }
}

String _scheduleTypeLabel(
  WorkScheduleType type,
) {
  switch (type) {
    case WorkScheduleType.work:
      return 'Bezirk';

    case WorkScheduleType.packageDriver:
      return 'Paketfahrer';

    case WorkScheduleType.free:
      return 'Frei';

    case WorkScheduleType.vacation:
      return 'Urlaub';

    case WorkScheduleType.holiday:
      return 'Feiertag';
  }
}

Color _scheduleTypeColor(
  BuildContext context,
  WorkScheduleType type,
) {
  final colorScheme =
      Theme.of(context).colorScheme;

  switch (type) {
    case WorkScheduleType.work:
      return colorScheme.primaryContainer;

    case WorkScheduleType.packageDriver:
      return colorScheme.secondaryContainer;

    case WorkScheduleType.free:
      return colorScheme.surfaceContainerHighest;

    case WorkScheduleType.vacation:
      return colorScheme.tertiaryContainer;

    case WorkScheduleType.holiday:
      return colorScheme.errorContainer;
  }
}