import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/own_tour_entry.dart';
import '../../models/support_entry.dart';
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
      final notifier = ref.read(
        workDayProvider.notifier,
      );

      final ownTourEntries =
          await notifier.getOwnTourEntries(
        existingWorkDay.id,
      );

      final supportEntries =
          await notifier.getSupportEntries(
        existingWorkDay.id,
      );

      if (!mounted) {
        return;
      }

      final action =
          await showModalBottomSheet<_WorkDayAction>(
        context: context,
        showDragHandle: true,
        builder: (context) {
          return _ExistingWorkDaySheet(
            workDay: existingWorkDay,
            ownTourEntries: ownTourEntries,
            supportEntries: supportEntries,
          );
        },
      );

      if (!mounted || action == null) {
        return;
      }

      if (action == _WorkDayAction.edit) {
        await Navigator.of(context).push<bool>(
          MaterialPageRoute<bool>(
            builder: (context) {
              return AddWorkDayPage(
                initialDate: existingWorkDay.date,
                existingWorkDay: existingWorkDay,
                initialOwnTourEntries: ownTourEntries,
                initialSupportEntries: supportEntries,
              );
            },
          ),
        );

        return;
      }

      if (action == _WorkDayAction.delete) {
        await _deleteWorkDay(existingWorkDay);
      }

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

  Future<void> _deleteWorkDay(WorkDay workDay) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Arbeitstag löschen?'),
          content: Text(
            'Möchtest du den Eintrag vom ${_formatDate(workDay.date)} '
            'wirklich löschen? Auch gespeicherte Unterstützungen dieses '
            'Tages werden gelöscht.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Löschen'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true || !mounted) {
      return;
    }

    try {
      await ref
          .read(workDayProvider.notifier)
          .deleteWorkDay(workDay.id);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Arbeitstag wurde gelöscht.'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Arbeitstag konnte nicht gelöscht werden: $error',
          ),
        ),
      );
    }
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
        const _CalendarIntroCard(),
        const SizedBox(height: 20),
        const _CalendarSectionTitle(
          icon: Icons.calendar_month_outlined,
          title: 'Monatskalender',
        ),
        const SizedBox(height: 10),
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

class _CalendarIntroCard extends StatelessWidget {
  const _CalendarIntroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.calendar_today_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Deine Arbeitstage',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Alle eingetragenen Arbeitstage und Abwesenheiten auf einen Blick.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarSectionTitle extends StatelessWidget {
  const _CalendarSectionTitle({
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
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

enum _WorkDayAction {
  edit,
  delete,
}

class _ExistingWorkDaySheet extends StatelessWidget {
  const _ExistingWorkDaySheet({
    required this.workDay,
    required this.ownTourEntries,
    required this.supportEntries,
  });

  final WorkDay workDay;
  final List<OwnTourEntry> ownTourEntries;
  final List<SupportEntry> supportEntries;

  @override
  Widget build(BuildContext context) {
    final isWorkDay = workDay.type == WorkDayType.work;

    return SafeArea(
      child: SingleChildScrollView(
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
              if (isWorkDay) ...[
                const SizedBox(height: 20),
                Text(
                  'Zeiten',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 10),
                _WorkDayTimesCard(
                  workStart: workDay.workStart,
                  departureTime: workDay.departureTime,
                  deliveryEnd: workDay.deliveryEnd,
                  workEnd: workDay.workEnd,
                ),
                const SizedBox(height: 10),
                _SheetInfoRow(
                  label: 'Arbeitszeit gesamt',
                  value: workDay.workDurationMinutes == null
                      ? '–'
                      : _formatDuration(
                          workDay.workDurationMinutes!,
                        ),
                ),
                if (ownTourEntries.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Eigene Zustellung',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 10),
                  for (final entry in ownTourEntries) ...[
                    _TourDetailCard(
                      icon: Icons.route_outlined,
                      title: 'Bezirk ${entry.district}',
                      packageText: '${entry.packageCount} Pakete',
                      secondaryText: entry.cancelledPackageCount > 0
                          ? '${entry.cancelledPackageCount} abgebrochen'
                          : null,
                    ),
                    const SizedBox(height: 8),
                  ],
                ] else if (workDay.assignmentType ==
                    WorkAssignmentType.ownDistrict) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Eigene Zustellung',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 10),
                  _TourDetailCard(
                    icon: Icons.route_outlined,
                    title: workDay.districtId == null
                        ? 'Bezirk nicht angegeben'
                        : 'Bezirk ${workDay.districtId}',
                    packageText: '${workDay.deliveredPackageCount} Pakete',
                    secondaryText: workDay.cancelledPackageCount > 0
                        ? '${workDay.cancelledPackageCount} abgebrochen'
                        : null,
                  ),
                ],
                if (supportEntries.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Unterstützungen',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 10),
                  for (final entry in supportEntries) ...[
                    _TourDetailCard(
                      icon: Icons.group_outlined,
                      title: 'Bezirk ${entry.district}',
                      packageText: '${entry.packagesTaken} Pakete übernommen',
                      secondaryText: entry.note,
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
                const SizedBox(height: 12),
                Text(
                  'Werbung',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 10),
                _DetailInfoCard(
                  icon: Icons.campaign_outlined,
                  title: workDay.hasAdvertising
                      ? (workDay.advertising?.trim().isNotEmpty == true
                          ? workDay.advertising!.trim()
                          : 'Werbung dabei')
                      : 'Keine Werbung',
                ),
                if (workDay.notes?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Bemerkungen',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 10),
                  _DetailInfoCard(
                    icon: Icons.notes_outlined,
                    title: workDay.notes!.trim(),
                  ),
                ],
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop(
                      _WorkDayAction.edit,
                    );
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Bearbeiten'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop(
                      _WorkDayAction.delete,
                    );
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Löschen'),
                ),
              ),
            ],
          ),
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

        if (workDay.districtId == null) {
          return 'Arbeit';
        }

        return 'Eigene Zustellung';

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

class _WorkDayTimesCard extends StatelessWidget {
  const _WorkDayTimesCard({
    required this.workStart,
    required this.departureTime,
    required this.deliveryEnd,
    required this.workEnd,
  });

  final int? workStart;
  final int? departureTime;
  final int? deliveryEnd;
  final int? workEnd;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        children: [
          _WorkDayTimeRow(
            icon: Icons.login_outlined,
            label: 'Arbeitsbeginn',
            minutes: workStart,
          ),
          const SizedBox(height: 12),
          _WorkDayTimeRow(
            icon: Icons.local_shipping_outlined,
            label: 'Zustellungsbeginn',
            minutes: departureTime,
          ),
          const SizedBox(height: 12),
          _WorkDayTimeRow(
            icon: Icons.inventory_2_outlined,
            label: 'Zustellungsende',
            minutes: deliveryEnd,
          ),
          const SizedBox(height: 12),
          _WorkDayTimeRow(
            icon: Icons.logout_outlined,
            label: 'Arbeitsende',
            minutes: workEnd,
          ),
        ],
      ),
    );
  }
}

class _WorkDayTimeRow extends StatelessWidget {
  const _WorkDayTimeRow({
    required this.icon,
    required this.label,
    required this.minutes,
  });

  final IconData icon;
  final String label;
  final int? minutes;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        Text(
          _formatClockTime(minutes),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

class _TourDetailCard extends StatelessWidget {
  const _TourDetailCard({
    required this.icon,
    required this.title,
    required this.packageText,
    this.secondaryText,
  });

  final IconData icon;
  final String title;
  final String packageText;
  final String? secondaryText;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 22,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 3),
                Text(packageText),
                if (secondaryText?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 3),
                  Text(
                    secondaryText!.trim(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailInfoCard extends StatelessWidget {
  const _DetailInfoCard({
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 22,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
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

String _formatClockTime(int? minutes) {
  if (minutes == null) {
    return '–';
  }

  final hours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;

  return '${hours.toString().padLeft(2, '0')}:'
      '${remainingMinutes.toString().padLeft(2, '0')} Uhr';
}

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');

  return '$day.$month.${date.year}';
}