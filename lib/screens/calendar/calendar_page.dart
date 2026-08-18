import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/work_day.dart';
import '../../services/work_day_provider.dart';
import '../work_days/add_work_day_page.dart';

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  late DateTime _visibleMonth;

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
    final workDaysAsync = ref.watch(workDayProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Kalender',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: workDaysAsync.when(
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
                    'Die Kalendereinträge konnten nicht geladen werden.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () {
                      ref.invalidate(workDayProvider);
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Erneut versuchen'),
                  ),
                ],
              ),
            ),
          );
        },
        data: (workDays) {
          return _CalendarContent(
            visibleMonth: _visibleMonth,
            workDays: workDays,
            onPreviousMonth: _showPreviousMonth,
            onNextMonth: _showNextMonth,
            onTodayPressed: _showCurrentMonth,
            onDatePressed: _openDate,
          );
        },
      ),
    );
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

  Future<void> _openDate(
    DateTime date,
    WorkDay? existingWorkDay,
  ) async {
    if (existingWorkDay != null) {
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (context) {
          return _ExistingWorkDaySheet(
            workDay: existingWorkDay,
          );
        },
      );

      return;
    }

    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) {
          return AddWorkDayPage(
            initialDate: date,
          );
        },
      ),
    );
  }
}

class _CalendarContent extends StatelessWidget {
  const _CalendarContent({
    required this.visibleMonth,
    required this.workDays,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onTodayPressed,
    required this.onDatePressed,
  });

  final DateTime visibleMonth;
  final List<WorkDay> workDays;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onTodayPressed;
  final Future<void> Function(
    DateTime date,
    WorkDay? existingWorkDay,
  ) onDatePressed;

  @override
  Widget build(BuildContext context) {
    final monthWorkDays = workDays.where((workDay) {
      return workDay.date.year == visibleMonth.year &&
          workDay.date.month == visibleMonth.month;
    }).toList();

    final workDayCount = monthWorkDays.where((workDay) {
      return workDay.type == WorkDayType.work;
    }).length;

    final totalWorkMinutes = monthWorkDays.fold<int>(
      0,
      (sum, workDay) {
        if (workDay.type != WorkDayType.work) {
          return sum;
        }

        return sum + (workDay.workDurationMinutes ?? 0);
      },
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        _MonthHeader(
          visibleMonth: visibleMonth,
          onPreviousMonth: onPreviousMonth,
          onNextMonth: onNextMonth,
          onTodayPressed: onTodayPressed,
        ),
        const SizedBox(height: 16),
        _WeekdayHeader(),
        const SizedBox(height: 8),
        _MonthGrid(
          visibleMonth: visibleMonth,
          workDays: workDays,
          onDatePressed: onDatePressed,
        ),
        const SizedBox(height: 24),
        Text(
          'Monatsübersicht',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _CalendarSummaryCard(
                icon: Icons.work_outline,
                value: '$workDayCount',
                label: 'Arbeitstage',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _CalendarSummaryCard(
                icon: Icons.access_time,
                value: _formatDuration(totalWorkMinutes),
                label: 'Arbeitszeit',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const _Legend(),
      ],
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.visibleMonth,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onTodayPressed,
  });

  final DateTime visibleMonth;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onTodayPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Vorheriger Monat',
          onPressed: onPreviousMonth,
          icon: const Icon(
            Icons.chevron_left,
          ),
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                _monthName(
                  visibleMonth.month,
                ),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Text(
                '${visibleMonth.year}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Nächster Monat',
          onPressed: onNextMonth,
          icon: const Icon(
            Icons.chevron_right,
          ),
        ),
        const SizedBox(width: 4),
        TextButton(
          onPressed: onTodayPressed,
          child: const Text('Heute'),
        ),
      ],
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const weekdays = [
      'Mo',
      'Di',
      'Mi',
      'Do',
      'Fr',
      'Sa',
      'So',
    ];

    return Row(
      children: [
        for (final weekday in weekdays)
          Expanded(
            child: Center(
              child: Text(
                weekday,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant,
                    ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.visibleMonth,
    required this.workDays,
    required this.onDatePressed,
  });

  final DateTime visibleMonth;
  final List<WorkDay> workDays;
  final Future<void> Function(
    DateTime date,
    WorkDay? existingWorkDay,
  ) onDatePressed;

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(
      visibleMonth.year,
      visibleMonth.month,
      1,
    );

    final lastDay = DateTime(
      visibleMonth.year,
      visibleMonth.month + 1,
      0,
    );

    final leadingEmptyDays = firstDay.weekday - 1;

    final totalCells = leadingEmptyDays + lastDay.day;

    final rowCount = (totalCells / 7).ceil();

    return Column(
      children: [
        for (var row = 0; row < rowCount; row++)
          Padding(
            padding: const EdgeInsets.only(
              bottom: 8,
            ),
            child: Row(
              children: [
                for (var column = 0; column < 7; column++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2,
                      ),
                      child: _buildCell(
                        context,
                        row,
                        column,
                        leadingEmptyDays,
                        lastDay.day,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCell(
    BuildContext context,
    int row,
    int column,
    int leadingEmptyDays,
    int daysInMonth,
  ) {
    final cellIndex = (row * 7) + column;

    final dayNumber = cellIndex - leadingEmptyDays + 1;

    if (dayNumber < 1 || dayNumber > daysInMonth) {
      return const SizedBox(
        height: 62,
      );
    }

    final date = DateTime(
      visibleMonth.year,
      visibleMonth.month,
      dayNumber,
    );

    final workDay = _findWorkDay(
      date,
    );

    return _CalendarDayCell(
      date: date,
      workDay: workDay,
      onTap: () {
        onDatePressed(
          date,
          workDay,
        );
      },
    );
  }

  WorkDay? _findWorkDay(DateTime date) {
    for (final workDay in workDays) {
      if (_isSameDate(
        workDay.date,
        date,
      )) {
        return workDay;
      }
    }

    return null;
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

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    required this.date,
    required this.workDay,
    required this.onTap,
  });

  final DateTime date;
  final WorkDay? workDay;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();

    final isToday = today.year == date.year &&
        today.month == date.month &&
        today.day == date.day;

    final backgroundColor = _backgroundColor(
      context,
      workDay,
    );

    final borderColor = isToday
        ? Theme.of(context).colorScheme.primary
        : Colors.transparent;

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 62,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: borderColor,
              width: isToday ? 2 : 0,
            ),
          ),
          padding: const EdgeInsets.symmetric(
            vertical: 7,
            horizontal: 4,
          ),
          child: Column(
            children: [
              Text(
                '${date.day}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: isToday
                          ? FontWeight.bold
                          : FontWeight.w600,
                    ),
              ),
              const Spacer(),
              if (workDay != null)
                Icon(
                  _workDayIcon(
                    workDay!,
                  ),
                  size: 16,
                ),
            ],
          ),
        ),
      ),
    );
  }

  static Color _backgroundColor(
    BuildContext context,
    WorkDay? workDay,
  ) {
    if (workDay == null) {
      return Theme.of(context)
          .colorScheme
          .surfaceContainerLow;
    }

    switch (workDay.type) {
      case WorkDayType.work:
        return Theme.of(context)
            .colorScheme
            .primaryContainer;
      case WorkDayType.free:
        return Theme.of(context)
            .colorScheme
            .secondaryContainer;
      case WorkDayType.vacation:
        return Theme.of(context)
            .colorScheme
            .tertiaryContainer;
      case WorkDayType.holiday:
        return Theme.of(context)
            .colorScheme
            .surfaceContainerHighest;
      case WorkDayType.sick:
        return Theme.of(context)
            .colorScheme
            .errorContainer;
    }
  }

  static IconData _workDayIcon(
    WorkDay workDay,
  ) {
    switch (workDay.type) {
      case WorkDayType.work:
        if (workDay.assignmentType ==
            WorkAssignmentType.packageDriver) {
          return Icons.local_shipping_outlined;
        }

        return Icons.work_outline;
      case WorkDayType.free:
        return Icons.weekend_outlined;
      case WorkDayType.vacation:
        return Icons.beach_access_outlined;
      case WorkDayType.holiday:
        return Icons.celebration_outlined;
      case WorkDayType.sick:
        return Icons.sick_outlined;
    }
  }
}

class _ExistingWorkDaySheet extends StatelessWidget {
  const _ExistingWorkDaySheet({
    required this.workDay,
  });

  final WorkDay workDay;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          20,
          8,
          20,
          24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatDate(workDay.date),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              _workDayDescription(workDay),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (workDay.type == WorkDayType.work) ...[
              const SizedBox(height: 16),
              _SheetInfoRow(
                label: 'Arbeitszeit',
                value: workDay.workDurationMinutes == null
                    ? '–'
                    : _formatDuration(
                        workDay.workDurationMinutes!,
                      ),
              ),
              const SizedBox(height: 8),
              _SheetInfoRow(
                label: 'Eigene Pakete',
                value:
                    '${workDay.deliveredPackageCount}',
              ),
            ],
            const SizedBox(height: 20),
            Text(
              'Bearbeiten und Löschen bauen wir als nächsten Schritt ein.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  static String _workDayDescription(
    WorkDay workDay,
  ) {
    switch (workDay.type) {
      case WorkDayType.work:
        if (workDay.assignmentType ==
            WorkAssignmentType.packageDriver) {
          return 'Paketfahrer / Unterstützung';
        }

        return workDay.districtId == null
            ? 'Arbeit'
            : 'Bezirk ${workDay.districtId}';
      case WorkDayType.free:
        return 'Frei';
      case WorkDayType.vacation:
        return 'Urlaub';
      case WorkDayType.holiday:
        return 'Feiertag';
      case WorkDayType.sick:
        return 'Krank';
    }
  }
}

class _SheetInfoRow extends StatelessWidget {
  const _SheetInfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant,
                ),
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

class _CalendarSummaryCard extends StatelessWidget {
  const _CalendarSummaryCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 14),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 10,
      children: const [
        _LegendItem(
          icon: Icons.work_outline,
          label: 'Arbeit',
        ),
        _LegendItem(
          icon: Icons.local_shipping_outlined,
          label: 'Paketfahrer',
        ),
        _LegendItem(
          icon: Icons.weekend_outlined,
          label: 'Frei',
        ),
        _LegendItem(
          icon: Icons.beach_access_outlined,
          label: 'Urlaub',
        ),
        _LegendItem(
          icon: Icons.celebration_outlined,
          label: 'Feiertag',
        ),
        _LegendItem(
          icon: Icons.sick_outlined,
          label: 'Krank',
        ),
      ],
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
        ),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}

String _monthName(int month) {
  const monthNames = [
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

  return monthNames[month - 1];
}

String _formatDuration(int minutes) {
  final hours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;

  return '$hours h ${remainingMinutes.toString().padLeft(2, '0')} min';
}

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');

  return '$day.$month.${date.year}';
}