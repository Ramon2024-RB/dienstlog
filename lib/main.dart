import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/own_tour_entry.dart';
import 'models/work_day.dart';
import 'screens/calendar/calendar_page.dart';
import 'screens/quick_entry/quick_entry_card.dart';
import 'screens/districts/districts_page.dart';
import 'screens/statistics/statistics_page.dart';
import 'screens/work_schedule/work_schedule_page.dart';
import 'screens/work_days/add_work_day_page.dart';
import 'services/work_day_provider.dart';

void main() {
  runApp(
    const ProviderScope(
      child: TourLogApp(),
    ),
  );
}

class TourLogApp extends StatelessWidget {
  const TourLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TourLog',
      debugShowCheckedModeBanner: false,
      locale: const Locale('de', 'DE'),
      supportedLocales: const [
        Locale('de', 'DE'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFCC00),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFCC00),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const MainNavigationPage(),
    );
  }
}

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() =>
      _MainNavigationPageState();
}

class _MainNavigationPageState
    extends State<MainNavigationPage> {
  int _selectedIndex = 0;

  static const List<Widget> _pages = [
    _OverviewPage(),
    WorkSchedulePage(),
    CalendarPage(),
    StatisticsPage(),
    _MorePage(),
  ];

  void _onDestinationSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Startseite',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(Icons.event_note),
            label: 'Arbeitsplan',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Kalender',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Statistik',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz),
            selectedIcon: Icon(Icons.more_horiz),
            label: 'Mehr',
          ),
        ],
      ),
    );
  }
}

class _OverviewPage extends ConsumerWidget {
  const _OverviewPage();

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
          );
        },
      ),
    );
  }
}

class _OverviewContent extends ConsumerWidget {
  const _OverviewContent({
    required this.workDays,
  });

  final List<WorkDay> workDays;

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final now = DateTime.now();

    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final todayWorkDay = _findWorkDayForDate(
      workDays,
      today,
    );

    final weekStart = today.subtract(
      Duration(
        days: today.weekday - DateTime.monday,
      ),
    );

    final weekEnd = weekStart.add(
      const Duration(days: 6),
    );

    final weekWorkDays = workDays.where(
      (workDay) {
        final date = _normalizeDate(
          workDay.date,
        );

        return !date.isBefore(weekStart) &&
            !date.isAfter(weekEnd) &&
            workDay.type == WorkDayType.work;
      },
    ).toList();

    final monthWorkDays = workDays.where(
      (workDay) {
        return workDay.date.year == today.year &&
            workDay.date.month == today.month &&
            workDay.type == WorkDayType.work;
      },
    ).toList();

    final weeklyWorkMinutes = weekWorkDays.fold<int>(
      0,
      (sum, workDay) {
        return sum +
            (workDay.workDurationMinutes ?? 0);
      },
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        20,
        16,
        20,
        32,
      ),
      children: [
        Text(
          'Übersicht',
          style: Theme.of(context)
              .textTheme
              .headlineMedium
              ?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Dein heutiger Arbeitstag auf einen Blick.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),

        QuickEntryCard(
          workDay: todayWorkDay,
        ),

        const SizedBox(height: 16),

        _TodayCard(
          workDay: todayWorkDay,
        ),

        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                title: 'Diese Woche',
                value: _formatDuration(
                  weeklyWorkMinutes,
                ),
                subtitle: 'Arbeitszeit',
                icon: Icons.access_time,
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

  static DateTime _normalizeDate(
    DateTime date,
  ) {
    return DateTime(
      date.year,
      date.month,
      date.day,
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

                if (workDay!.assignmentType ==
                    WorkAssignmentType.ownDistrict) ...[
                  const SizedBox(height: 10),
                  _TodayInfoRow(
                    label: 'Gefahrene Bezirke',
                    value: _districtCountLabel(
                      ownTours,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _TodayInfoRow(
                    label: 'Eigene Pakete',
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

    final ownTours = await ownToursFuture;
    final ownPackages = await ownPackagesFuture;
    final supportPackages =
        await supportPackagesFuture;

    return _TodayWorkData(
      ownTours: ownTours,
      ownPackages: ownPackages,
      supportPackages: supportPackages,
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

  static String _districtCountLabel(
    List<OwnTourEntry> ownTours,
  ) {
    if (ownTours.isEmpty) {
      return '–';
    }

    if (ownTours.length == 1) {
      return '1';
    }

    return '${ownTours.length}';
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

class _TodayWorkData {
  const _TodayWorkData({
    required this.ownTours,
    required this.ownPackages,
    required this.supportPackages,
  });

  final List<OwnTourEntry> ownTours;
  final int ownPackages;
  final int supportPackages;
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

class _MorePage extends StatelessWidget {
  const _MorePage();

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mehr',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          20,
          16,
          20,
          32,
        ),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.route_outlined,
                  ),
                  title: const Text(
                    'Bezirke',
                  ),
                  subtitle: const Text(
                    '25 Bezirke verwalten',
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) =>
                            const DistrictsPage(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.campaign_outlined,
                  ),
                  title: const Text(
                    'Werbung',
                  ),
                  subtitle: const Text(
                    'Gespeicherte Werbungen verwalten',
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                  ),
                  onTap: () {},
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.settings_outlined,
                  ),
                  title: const Text(
                    'Einstellungen',
                  ),
                  subtitle: const Text(
                    'Arbeitszeiten und App-Einstellungen',
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                  ),
                  onTap: () {},
                ),
              ],
            ),
          ),
        ],
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