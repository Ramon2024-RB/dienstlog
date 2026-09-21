import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/own_tour_entry.dart';
import '../../models/work_day.dart';
import '../../services/work_day_provider.dart';
import '../../utils/work_time_balance_calculator.dart';
import '../quick_entry/quick_entry_card.dart';
import '../work_days/add_work_day_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({
    super.key,
    required this.externalQuickAction,
    required this.onExternalQuickActionHandled,
  });

  final QuickEntryExternalAction? externalQuickAction;
  final VoidCallback onExternalQuickActionHandled;

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final workDaysAsync = ref.watch(workDayProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'TourLog',
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
                    'Die Arbeitsdaten konnten nicht geladen werden.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () {
                      ref.invalidate(workDayProvider);
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text(
                      'Erneut versuchen',
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        data: (workDays) {
          return _OverviewContent(
            workDays: workDays,
            externalQuickAction: externalQuickAction,
            onExternalQuickActionHandled:
                onExternalQuickActionHandled,
          );
        },
      ),
    );
  }
}

class _OverviewContent extends ConsumerWidget {
  const _OverviewContent({
    required this.workDays,
    required this.externalQuickAction,
    required this.onExternalQuickActionHandled,
  });

  final List<WorkDay> workDays;
  final QuickEntryExternalAction? externalQuickAction;
  final VoidCallback onExternalQuickActionHandled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayWorkDay = _findWorkDayForDate(workDays, today);

    final weekStart = today.subtract(
      Duration(days: today.weekday - DateTime.monday),
    );
    final weekEnd = weekStart.add(const Duration(days: 6));

    final weekWorkDays = workDays.where((workDay) {
      final date = _normalizeDate(workDay.date);
      return !date.isBefore(weekStart) &&
          !date.isAfter(weekEnd) &&
          workDay.type == WorkDayType.work;
    }).toList();

    final monthWorkDays = workDays.where((workDay) {
      return workDay.date.year == today.year &&
          workDay.date.month == today.month &&
          workDay.type == WorkDayType.work;
    }).toList();

    final weeklyWorkMinutes = weekWorkDays.fold<int>(
      0,
      (sum, workDay) => sum + (workDay.workDurationMinutes ?? 0),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
      children: [
        _HomeGreeting(todayWorkDay: todayWorkDay),
        const SizedBox(height: 18),
        _TodayOverviewCard(workDay: todayWorkDay),
        const SizedBox(height: 18),
        if (todayWorkDay == null ||
            todayWorkDay.type == WorkDayType.work) ...[
          QuickEntryCard(
            workDay: todayWorkDay,
            externalAction: externalQuickAction,
            onExternalActionHandled: onExternalQuickActionHandled,
          ),
          const SizedBox(height: 22),
        ] else ...[
          _NonWorkDayActions(workDay: todayWorkDay),
          const SizedBox(height: 22),
        ],
        _ExpandableDayDetails(workDay: todayWorkDay),
        const SizedBox(height: 28),
        const _OverviewSectionTitle(
          title: 'Diese Woche',
          icon: Icons.insights_outlined,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _WeeklyWorkTimeSummaryCard(
                workDays: weekWorkDays,
                workMinutes: weeklyWorkMinutes,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _WeeklyOwnPackagesSummaryCard(
                startDate: weekStart,
                endDate: weekEnd,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _WeeklySupportSummaryCard(
                startDate: weekStart,
                endDate: weekEnd,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                title: 'Dieser Monat',
                value: '${monthWorkDays.length}',
                subtitle: 'Arbeitstage',
                icon: Icons.calendar_today_outlined,
              ),
            ),
          ],
        ),
      ],
    );
  }

  static WorkDay? _findWorkDayForDate(
    List<WorkDay> workDays,
    DateTime date,
  ) {
    for (final workDay in workDays) {
      if (_isSameDate(workDay.date, date)) {
        return workDay;
      }
    }
    return null;
  }

  static bool _isSameDate(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  static DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
}

class _HomeGreeting extends StatelessWidget {
  const _HomeGreeting({required this.todayWorkDay});

  final WorkDay? todayWorkDay;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final theme = Theme.of(context);
    final greeting = now.hour < 11
        ? 'Guten Morgen'
        : now.hour < 18
            ? 'Hallo'
            : 'Guten Abend';

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            greeting,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_weekdayName(now.weekday)}, ${now.day}. ${_monthName(now.month)}',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  static String _weekdayName(int weekday) {
    return switch (weekday) {
      DateTime.monday => 'Montag',
      DateTime.tuesday => 'Dienstag',
      DateTime.wednesday => 'Mittwoch',
      DateTime.thursday => 'Donnerstag',
      DateTime.friday => 'Freitag',
      DateTime.saturday => 'Samstag',
      DateTime.sunday => 'Sonntag',
      _ => '',
    };
  }

  static String _monthName(int month) {
    return switch (month) {
      1 => 'Januar',
      2 => 'Februar',
      3 => 'März',
      4 => 'April',
      5 => 'Mai',
      6 => 'Juni',
      7 => 'Juli',
      8 => 'August',
      9 => 'September',
      10 => 'Oktober',
      11 => 'November',
      12 => 'Dezember',
      _ => '',
    };
  }
}

class _TodayOverviewCard extends ConsumerWidget {
  const _TodayOverviewCard({required this.workDay});

  final WorkDay? workDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    if (workDay == null) {
      return _HomePanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PanelEyebrow(
              icon: Icons.today_outlined,
              label: 'HEUTE',
            ),
            const SizedBox(height: 18),
            Text(
              'Noch kein Arbeitstag',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Starte über die Schnellerfassung oder trage den Tag vollständig ein.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: () async {
                await Navigator.of(context).push<bool>(
                  MaterialPageRoute<bool>(
                    builder: (context) => AddWorkDayPage(
                      initialDate: DateTime.now(),
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Arbeitstag eintragen'),
            ),
          ],
        ),
      );
    }

    if (workDay!.type != WorkDayType.work) {
      return _HomePanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PanelEyebrow(
              icon: _dayTypeIcon(workDay!.type),
              label: 'HEUTE',
            ),
            const SizedBox(height: 18),
            Text(
              _dayTypeLabel(workDay!.type),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Für heute ist kein regulärer Arbeitstag eingetragen.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return FutureBuilder<_HomeTodayData>(
      future: _loadData(ref, workDay!),
      builder: (context, snapshot) {
        final data = snapshot.data;
        final districts = data?.ownTours.isNotEmpty == true
            ? data!.ownTours.map((entry) => entry.district).join(' + ')
            : workDay!.districtId;

        final packages = data?.ownPackages ?? workDay!.deliveredPackageCount;
        final support = data?.supportPackages ?? 0;

        return _HomePanel(
          highlighted: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: _PanelEyebrow(
                      icon: Icons.local_shipping_outlined,
                      label: 'HEUTE',
                    ),
                  ),
                  _StatusPill(workDay: workDay!),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                districts == null || districts.trim().isEmpty
                    ? _assignmentLabel(workDay!)
                    : districts.contains(' + ')
                        ? 'Bezirke $districts'
                        : 'Bezirk $districts',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                _secondaryLine(workDay!),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoChip(
                    icon: Icons.inventory_2_outlined,
                    text: '$packages Pakete',
                  ),
                  if (support > 0)
                    _InfoChip(
                      icon: Icons.group_outlined,
                      text: '+ $support Unterstützung',
                    ),
                  if (workDay!.hasAdvertising)
                    _InfoChip(
                      icon: Icons.campaign_outlined,
                      text: workDay!.advertising?.trim().isNotEmpty == true
                          ? workDay!.advertising!.trim()
                          : 'Werbung',
                    ),
                ],
              ),
              const SizedBox(height: 22),
              _DayTimeline(workDay: workDay!),
            ],
          ),
        );
      },
    );
  }

  Future<_HomeTodayData> _loadData(WidgetRef ref, WorkDay day) async {
    final notifier = ref.read(workDayProvider.notifier);
    final results = await Future.wait<dynamic>([
      notifier.getOwnTourEntries(day.id),
      notifier.getTotalOwnTourPackages(day.id),
      notifier.getTotalSupportPackages(day.id),
    ]);
    return _HomeTodayData(
      ownTours: results[0] as List<OwnTourEntry>,
      ownPackages: results[1] as int,
      supportPackages: results[2] as int,
    );
  }

  static String _assignmentLabel(WorkDay day) {
    switch (day.assignmentType) {
      case WorkAssignmentType.packageDriver:
        return 'Paketfahrer';
      case WorkAssignmentType.mondayDelivery:
        return 'Montagszustellung';
      case WorkAssignmentType.ownDistrict:
        return 'Eigene Zustellung';
    }
  }

  static String _secondaryLine(WorkDay day) {
    if (day.assignmentType != WorkAssignmentType.ownDistrict) {
      return _assignmentLabel(day);
    }
    return switch (day.districtPart) {
      DistrictPart.partA => 'A-Teil',
      DistrictPart.partB => 'B-Teil',
      DistrictPart.full => 'Post nicht angegeben',
    };
  }

  static IconData _dayTypeIcon(WorkDayType type) {
    return switch (type) {
      WorkDayType.work => Icons.work_outline,
      WorkDayType.free => Icons.weekend_outlined,
      WorkDayType.vacation => Icons.beach_access_outlined,
      WorkDayType.holiday => Icons.celebration_outlined,
      WorkDayType.sick => Icons.sick_outlined,
    };
  }

  static String _dayTypeLabel(WorkDayType type) {
    return switch (type) {
      WorkDayType.work => 'Arbeit',
      WorkDayType.free => 'Frei',
      WorkDayType.vacation => 'Urlaub',
      WorkDayType.holiday => 'Feiertag',
      WorkDayType.sick => 'Krank',
    };
  }
}

class _HomePanel extends StatelessWidget {
  const _HomePanel({
    required this.child,
    this.highlighted = false,
  });

  final Widget child;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: highlighted
            ? scheme.primaryContainer.withValues(alpha: 0.42)
            : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: highlighted
              ? scheme.primary.withValues(alpha: 0.16)
              : scheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: child,
    );
  }
}

class _PanelEyebrow extends StatelessWidget {
  const _PanelEyebrow({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.workDay});

  final WorkDay workDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = workDay.workEnd != null
        ? 'Beendet'
        : workDay.deliveryEnd != null
            ? 'Zustellung fertig'
            : workDay.departureTime != null
                ? 'In Zustellung'
                : workDay.workStart != null
                    ? 'Im Dienst'
                    : 'Geplant';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: theme.colorScheme.primary),
          const SizedBox(width: 7),
          Text(
            text,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DayTimeline extends StatelessWidget {
  const _DayTimeline({required this.workDay});

  final WorkDay workDay;

  @override
  Widget build(BuildContext context) {
    final steps = <(String, int?, IconData)>[
      ('Dienstbeginn', workDay.workStart, Icons.badge_outlined),
      ('Zustellungsbeginn', workDay.departureTime, Icons.local_shipping_outlined),
      ('Zustellungsende', workDay.deliveryEnd, Icons.inventory_2_outlined),
      ('Dienstende', workDay.workEnd, Icons.logout),
    ];

    return Column(
      children: [
        for (var index = 0; index < steps.length; index++)
          _TimelineStep(
            label: steps[index].$1,
            minutes: steps[index].$2,
            icon: steps[index].$3,
            completed: steps[index].$2 != null,
            active: _isActive(index),
            showLine: index != steps.length - 1,
          ),
      ],
    );
  }

  bool _isActive(int index) {
    final values = [
      workDay.workStart,
      workDay.departureTime,
      workDay.deliveryEnd,
      workDay.workEnd,
    ];
    if (values[index] != null) return false;
    for (var i = 0; i < index; i++) {
      if (values[i] == null) return false;
    }
    return true;
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.label,
    required this.minutes,
    required this.icon,
    required this.completed,
    required this.active,
    required this.showLine,
  });

  final String label;
  final int? minutes;
  final IconData icon;
  final bool completed;
  final bool active;
  final bool showLine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final markerColor = completed || active
        ? scheme.primary
        : scheme.outlineVariant;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: completed || active
                        ? scheme.primaryContainer
                        : scheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                    border: active
                        ? Border.all(color: scheme.primary, width: 2)
                        : null,
                  ),
                  child: Icon(
                    completed ? Icons.check : icon,
                    size: 15,
                    color: markerColor,
                  ),
                ),
                if (showLine)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: completed
                          ? scheme.primary.withValues(alpha: 0.35)
                          : scheme.outlineVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: showLine ? 15 : 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                        color: completed || active
                            ? scheme.onSurface
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Text(
                    minutes == null ? '–' : '${_formatTime(minutes!)} Uhr',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: completed ? FontWeight.w700 : FontWeight.w500,
                      color: completed
                          ? scheme.onSurface
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeTodayData {
  const _HomeTodayData({
    required this.ownTours,
    required this.ownPackages,
    required this.supportPackages,
  });

  final List<OwnTourEntry> ownTours;
  final int ownPackages;
  final int supportPackages;
}

class _OverviewSectionTitle extends StatelessWidget {
  const _OverviewSectionTitle({
    required this.title,
    required this.icon,
  });

  final String title;
  final IconData icon;

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


class _NonWorkDayActions extends StatelessWidget {
  const _NonWorkDayActions({
    required this.workDay,
  });

  final WorkDay workDay;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.edit_calendar_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Der heutige Eintrag kann jederzeit geändert werden.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Heutigen Eintrag bearbeiten',
              onPressed: () async {
                await Navigator.of(context).push<bool>(
                  MaterialPageRoute<bool>(
                    builder: (context) => AddWorkDayPage(
                      initialDate: workDay.date,
                      existingWorkDay: workDay,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.edit_outlined),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpandableDayDetails extends StatefulWidget {
  const _ExpandableDayDetails({
    required this.workDay,
  });

  final WorkDay? workDay;

  @override
  State<_ExpandableDayDetails> createState() =>
      _ExpandableDayDetailsState();
}

class _ExpandableDayDetailsState extends State<_ExpandableDayDetails> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              setState(() {
                _expanded = !_expanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 16,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.dashboard_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tagesdetails',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(Icons.keyboard_arrow_down),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
              child: _TodayCard(workDay: widget.workDay),
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
          ),
        ],
      ),
    );
  }
}

class _TodayCard extends ConsumerWidget {
  const _TodayCard({
    required this.workDay,
  });

  final WorkDay? workDay;

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    if (workDay == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _TodayHeader(
                icon: Icons.today_outlined,
                title: 'Heute',
              ),
              const SizedBox(height: 20),
              Text(
                'Noch kein Arbeitstag eingetragen.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () async {
                  await Navigator.of(context).push<bool>(
                    MaterialPageRoute<bool>(
                      builder: (context) {
                        return AddWorkDayPage(
                          initialDate: DateTime.now(),
                        );
                      },
                    ),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text(
                  'Arbeitstag eintragen',
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (workDay!.type != WorkDayType.work) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TodayHeader(
                icon: _workDayTypeIcon(
                  workDay!.type,
                ),
                title: 'Heute',
              ),
              const SizedBox(height: 20),
              Text(
                _workDayTypeLabel(
                  workDay!.type,
                ),
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return FutureBuilder<_TodayWorkData>(
      future: _loadTodayWorkData(
        ref,
        workDay!,
      ),
      builder: (
        context,
        snapshot,
      ) {
        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _TodayHeader(
                    icon: Icons.today_outlined,
                    title: 'Heute',
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Die Tagesdetails konnten nicht vollständig geladen werden.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          );
        }

        final data = snapshot.data;

        final ownTours =
            data?.ownTours ?? const <OwnTourEntry>[];

        final supportPackages =
            data?.supportPackages ?? 0;

        final ownPackages =
            data?.ownPackages ??
            workDay!.deliveredPackageCount;

        final totalDelivered =
            ownPackages + supportPackages;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _TodayHeader(
                  icon: Icons.today_outlined,
                  title: 'Heute',
                ),

                const SizedBox(height: 20),

                Text(
                  _assignmentTitle(
                    workDay!,
                    ownTours,
                  ),
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),

                const SizedBox(height: 6),

                Text(
                  _assignmentSubtitle(
                    workDay!,
                    ownTours,
                  ),
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                ),

                const SizedBox(height: 20),

                _TodayStatusBanner(
                  workDay: workDay!,
                ),

                const SizedBox(height: 16),

                _TodayTimeGrid(
                  workDay: workDay!,
                ),

                const SizedBox(height: 16),

                _TodayInfoRow(
                  label: 'Arbeitszeit',
                  value:
                      workDay!.workDurationMinutes == null
                      ? '–'
                      : _formatDuration(
                          workDay!.workDurationMinutes!,
                        ),
                ),

                const SizedBox(height: 10),

                _TodayInfoRow(
                  label: 'Zeitraum',
                  value: _formatTimeRange(
                    workDay!.workStart,
                    workDay!.workEnd,
                  ),
                ),

                const SizedBox(height: 10),

                _TodayInfoRow(
                  label: 'Soll',
                  value: data?.targetMinutes == null
                      ? '–'
                      : _formatDuration(data!.targetMinutes!),
                ),

                const SizedBox(height: 10),

                _TodayInfoRow(
                  label: 'Differenz',
                  value: data?.balanceMinutes == null
                      ? '–'
                      : WorkTimeBalanceCalculator.formatBalance(
                          data!.balanceMinutes!,
                        ),
                  emphasize: data?.balanceMinutes != null,
                ),

                const SizedBox(height: 10),

                _TodayInfoRow(
                  label: 'Pause',
                  value: _formatDuration(workDay!.breakMinutes),
                ),

                const SizedBox(height: 10),

                _TodayInfoRow(
                  label: 'Zustellzeit',
                  value: workDay!.deliveryDurationMinutes == null
                      ? '–'
                      : _formatDuration(
                          workDay!.deliveryDurationMinutes!,
                        ),
                ),

                if (workDay!.assignmentType ==
                    WorkAssignmentType.ownDistrict) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Bezirke & Pakete',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 10),
                  if (ownTours.isNotEmpty)
                    for (final entry in ownTours) ...[
                      _TodayTourRow(
                        district: entry.district,
                        districtPart: entry.districtPart,
                        packages: entry.packageCount,
                        cancelledPackages:
                            entry.cancelledPackageCount,
                      ),
                      const SizedBox(height: 8),
                    ]
                  else
                    _TodayTourRow(
                      district: workDay!.districtId ?? '–',
                      districtPart: workDay!.districtPart,
                      packages: workDay!.deliveredPackageCount,
                      cancelledPackages:
                          workDay!.cancelledPackageCount,
                    ),
                  const SizedBox(height: 10),
                  _TodayInfoRow(
                    label: 'Eigene Pakete gesamt',
                    value: '$ownPackages Pakete',
                  ),
                ],

                const SizedBox(height: 10),

                _TodayInfoRow(
                  label: 'Unterstützung',
                  value: '$supportPackages Pakete',
                ),

                const SizedBox(height: 10),

                _TodayInfoRow(
                  label: 'Gesamt zugestellt',
                  value: '$totalDelivered Pakete',
                  emphasize: true,
                ),

                const SizedBox(height: 16),

                _TodayDetailBox(
                  icon: Icons.campaign_outlined,
                  label: 'Werbung',
                  value: workDay!.hasAdvertising
                      ? (workDay!.advertising?.trim().isNotEmpty == true
                          ? workDay!.advertising!.trim()
                          : 'Werbung dabei')
                      : 'Keine Werbung',
                ),

                if (workDay!.notes?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 10),
                  _TodayDetailBox(
                    icon: Icons.notes_outlined,
                    label: 'Bemerkungen',
                    value: workDay!.notes!.trim(),
                  ),
                ],

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await Navigator.of(context).push<bool>(
                        MaterialPageRoute<bool>(
                          builder: (context) {
                            return AddWorkDayPage(
                              initialDate: workDay!.date,
                              existingWorkDay: workDay,
                              initialOwnTourEntries: data?.ownTours ?? const <OwnTourEntry>[],
                            );
                          },
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Heutigen Arbeitstag bearbeiten'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<_TodayWorkData> _loadTodayWorkData(
    WidgetRef ref,
    WorkDay workDay,
  ) async {
    final notifier = ref.read(
      workDayProvider.notifier,
    );

    final ownToursFuture =
        notifier.getOwnTourEntries(
      workDay.id,
    );

    final ownPackagesFuture =
        notifier.getTotalOwnTourPackages(
      workDay.id,
    );

    final supportPackagesFuture =
        notifier.getTotalSupportPackages(
      workDay.id,
    );

    final targetMinutesFuture =
        WorkTimeBalanceCalculator.getTargetMinutesForDate(
      workDay.date,
    );

    final balanceMinutesFuture =
        WorkTimeBalanceCalculator.getBalanceMinutesForWorkDay(
      workDay,
    );

    final ownTours = await ownToursFuture;
    final ownPackages = await ownPackagesFuture;
    final supportPackages =
        await supportPackagesFuture;
    final targetMinutes = await targetMinutesFuture;
    final balanceMinutes = await balanceMinutesFuture;

    return _TodayWorkData(
      ownTours: ownTours,
      ownPackages: ownPackages,
      supportPackages: supportPackages,
      targetMinutes: targetMinutes,
      balanceMinutes: balanceMinutes,
    );
  }

  static String _assignmentTitle(
    WorkDay workDay,
    List<OwnTourEntry> ownTours,
  ) {
    if (workDay.assignmentType ==
        WorkAssignmentType.packageDriver) {
      return 'Paketfahrer / Unterstützung';
    }

    if (ownTours.isEmpty) {
      if (workDay.districtId == null) {
        return 'Eigene Zustellung';
      }

      return 'Bezirk ${workDay.districtId}';
    }

    if (ownTours.length == 1) {
      return 'Bezirk ${ownTours.first.district}';
    }

    final districts = ownTours
        .map(
          (entry) => entry.district,
        )
        .join(' + ');

    return 'Bezirke $districts';
  }

  static String _assignmentSubtitle(
    WorkDay workDay,
    List<OwnTourEntry> ownTours,
  ) {
    if (workDay.assignmentType ==
        WorkAssignmentType.packageDriver) {
      return 'Zusätzliche Unterstützung';
    }

    if (ownTours.length == 1) {
      return _districtPartLabel(
        ownTours.first.districtPart,
      );
    }

    if (ownTours.length > 1) {
      return '${ownTours.length} Bezirke selbst gefahren';
    }

    return _districtPartLabel(
      workDay.districtPart,
    );
  }

  static String _districtPartLabel(
    DistrictPart part,
  ) {
    switch (part) {
      case DistrictPart.full:
        return 'Ganzer Bezirk';

      case DistrictPart.partA:
        return 'A-Teil';

      case DistrictPart.partB:
        return 'B-Teil';
    }
  }

  static IconData _workDayTypeIcon(
    WorkDayType type,
  ) {
    switch (type) {
      case WorkDayType.work:
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

  static String _workDayTypeLabel(
    WorkDayType type,
  ) {
    switch (type) {
      case WorkDayType.work:
        return 'Arbeit';

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

class _TodayStatusBanner extends StatelessWidget {
  const _TodayStatusBanner({
    required this.workDay,
  });

  final WorkDay workDay;

  @override
  Widget build(BuildContext context) {
    final (icon, text) = _status();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .primaryContainer
            .withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  (IconData, String) _status() {
    if (workDay.workEnd != null) {
      return (
        Icons.check_circle_outline,
        'Dienst beendet · ${_formatTime(workDay.workEnd!)} Uhr',
      );
    }

    if (workDay.deliveryEnd != null) {
      return (
        Icons.inventory_2_outlined,
        'Zustellung beendet · ${_formatTime(workDay.deliveryEnd!)} Uhr',
      );
    }

    if (workDay.departureTime != null) {
      return (
        Icons.local_shipping_outlined,
        'In Zustellung seit ${_formatTime(workDay.departureTime!)} Uhr',
      );
    }

    if (workDay.workStart != null) {
      return (
        Icons.badge_outlined,
        'Im Dienst seit ${_formatTime(workDay.workStart!)} Uhr',
      );
    }

    return (
      Icons.schedule_outlined,
      'Arbeitstag vorbereitet',
    );
  }
}

class _TodayTimeGrid extends StatelessWidget {
  const _TodayTimeGrid({
    required this.workDay,
  });

  final WorkDay workDay;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _TodayTimeBox(
                label: 'Dienstbeginn',
                value: _time(workDay.workStart),
                icon: Icons.login,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _TodayTimeBox(
                label: 'Zustellbeginn',
                value: _time(workDay.departureTime),
                icon: Icons.local_shipping_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _TodayTimeBox(
                label: 'Zustellende',
                value: _time(workDay.deliveryEnd),
                icon: Icons.inventory_2_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _TodayTimeBox(
                label: 'Dienstende',
                value: _time(workDay.workEnd),
                icon: Icons.logout,
              ),
            ),
          ],
        ),
      ],
    );
  }

  static String _time(int? minutes) {
    return minutes == null ? '–' : '${_formatTime(minutes)} Uhr';
  }
}

class _TodayTimeBox extends StatelessWidget {
  const _TodayTimeBox({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }
}

class _TodayTourRow extends StatelessWidget {
  const _TodayTourRow({
    required this.district,
    required this.districtPart,
    required this.packages,
    required this.cancelledPackages,
  });

  final String district;
  final DistrictPart districtPart;
  final int packages;
  final int cancelledPackages;

  @override
  Widget build(BuildContext context) {
    final part = switch (districtPart) {
      DistrictPart.full => 'Ganz',
      DistrictPart.partA => 'A-Teil',
      DistrictPart.partB => 'B-Teil',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            Icons.route_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bezirk $district · $part',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (cancelledPackages > 0)
                  Text(
                    '$cancelledPackages Pakete abgebrochen',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          Text(
            '$packages',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(width: 4),
          Text(
            'Pakete',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _TodayDetailBox extends StatelessWidget {
  const _TodayDetailBox({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayWorkData {
  const _TodayWorkData({
    required this.ownTours,
    required this.ownPackages,
    required this.supportPackages,
    required this.targetMinutes,
    required this.balanceMinutes,
  });

  final List<OwnTourEntry> ownTours;
  final int ownPackages;
  final int supportPackages;
  final int? targetMinutes;
  final int? balanceMinutes;
}

class _WeeklyWorkTimeSummaryCard extends StatelessWidget {
  const _WeeklyWorkTimeSummaryCard({
    required this.workDays,
    required this.workMinutes,
  });

  final List<WorkDay> workDays;
  final int workMinutes;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: WorkTimeBalanceCalculator.getBalanceMinutesForWorkDays(
        workDays,
      ),
      builder: (context, snapshot) {
        final balance = snapshot.data;

        return _SummaryCard(
          title: 'Diese Woche',
          value: _formatDuration(workMinutes),
          subtitle: balance == null
              ? 'Arbeitszeit'
              : 'Arbeitszeit · ${WorkTimeBalanceCalculator.formatBalance(balance)}',
          icon: Icons.access_time,
        );
      },
    );
  }
}

class _WeeklyOwnPackagesSummaryCard
    extends ConsumerWidget {
  const _WeeklyOwnPackagesSummaryCard({
    required this.startDate,
    required this.endDate,
  });

  final DateTime startDate;
  final DateTime endDate;

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    return FutureBuilder<int>(
      future: ref
          .read(workDayProvider.notifier)
          .getTotalOwnTourPackagesForDateRange(
            startDate,
            endDate,
          ),
      builder: (
        context,
        snapshot,
      ) {
        if (snapshot.hasError) {
          return const _SummaryCard(
            title: 'Pakete',
            value: '–',
            subtitle: 'eigene diese Woche',
            icon: Icons.inventory_2_outlined,
          );
        }

        return _SummaryCard(
          title: 'Pakete',
          value: '${snapshot.data ?? 0}',
          subtitle: 'eigene diese Woche',
          icon: Icons.inventory_2_outlined,
        );
      },
    );
  }
}

class _WeeklySupportSummaryCard
    extends ConsumerWidget {
  const _WeeklySupportSummaryCard({
    required this.startDate,
    required this.endDate,
  });

  final DateTime startDate;
  final DateTime endDate;

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    return FutureBuilder<int>(
      future: ref
          .read(workDayProvider.notifier)
          .getTotalSupportPackagesForDateRange(
            startDate,
            endDate,
          ),
      builder: (
        context,
        snapshot,
      ) {
        if (snapshot.hasError) {
          return const _SummaryCard(
            title: 'Unterstützung',
            value: '–',
            subtitle: 'Pakete diese Woche',
            icon: Icons.group_outlined,
          );
        }

        return _SummaryCard(
          title: 'Unterstützung',
          value: '${snapshot.data ?? 0}',
          subtitle: 'Pakete diese Woche',
          icon: Icons.group_outlined,
        );
      },
    );
  }
}

class _TodayHeader extends StatelessWidget {
  const _TodayHeader({
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          color: Theme.of(context)
              .colorScheme
              .primary,
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }
}

class _TodayInfoRow extends StatelessWidget {
  const _TodayInfoRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(
    BuildContext context,
  ) {
    final style = emphasize
        ? Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(
                fontWeight: FontWeight.bold,
              )
        : Theme.of(context).textTheme.bodyLarge;

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant,
                ),
          ),
        ),
        Text(
          value,
          style: style,
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: Theme.of(context)
                  .colorScheme
                  .primary,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDuration(
  int minutes,
) {
  final hours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;

  return '$hours h ${remainingMinutes.toString().padLeft(2, '0')} min';
}

String _formatTimeRange(
  int? startMinutes,
  int? endMinutes,
) {
  if (startMinutes == null ||
      endMinutes == null) {
    return '–';
  }

  return '${_formatTime(startMinutes)} – ${_formatTime(endMinutes)}';
}

String _formatTime(
  int minutes,
) {
  final hours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;

  return '${hours.toString().padLeft(2, '0')}:'
      '${remainingMinutes.toString().padLeft(2, '0')}';
}