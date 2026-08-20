import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/own_tour_entry.dart';
import 'models/work_day.dart';
import 'screens/calendar/calendar_page.dart';
import 'screens/quick_entry/quick_entry_card.dart';
import 'screens/districts/districts_page.dart';
import 'screens/statistics/statistics_page.dart';
import 'screens/settings/advertising_page.dart';
import 'screens/settings/settings_page.dart';
import 'screens/settings/work_times_page.dart';
import 'screens/settings/backup_page.dart';
import 'screens/work_schedule/work_schedule_page.dart';
import 'screens/work_days/add_work_day_page.dart';
import 'services/work_day_provider.dart';
import 'utils/work_time_balance_calculator.dart';

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
        cardTheme: const CardThemeData(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFCC00),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        cardTheme: const CardThemeData(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
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
  QuickEntryExternalAction? _externalQuickAction;

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initializeDeepLinks();
  }

  Future<void> _initializeDeepLinks() async {
    try {
      final initialLink = await _appLinks.getInitialLink();

      if (initialLink != null && mounted) {
        _handleDeepLink(initialLink);
      }
    } catch (_) {
      // TourLog startet normal weiter, falls kein
      // Initial-Link verfügbar ist.
    }

    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        if (mounted) {
          _handleDeepLink(uri);
        }
      },
    );
  }

  void _handleDeepLink(Uri uri) {
    if (uri.scheme != 'tourlog') {
      return;
    }

    final command =
        uri.host == 'quick' && uri.pathSegments.isNotEmpty
        ? uri.pathSegments.first
        : uri.pathSegments.isNotEmpty
        ? uri.pathSegments.last
        : null;

    QuickEntryExternalAction? action;

    switch (command) {
      case 'work-start':
        action = QuickEntryExternalAction.workStart;
        break;
      case 'delivery-start':
        action = QuickEntryExternalAction.deliveryStart;
        break;
      case 'delivery-end':
        action = QuickEntryExternalAction.deliveryEnd;
        break;
      case 'work-end':
        action = QuickEntryExternalAction.workEnd;
        break;
    }

    if (action == null) {
      return;
    }

    setState(() {
      _selectedIndex = 0;
      _externalQuickAction = action;
    });
  }

  void _onExternalQuickActionHandled() {
    if (!mounted) {
      return;
    }

    setState(() {
      _externalQuickAction = null;
    });
  }

  void _onDestinationSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _OverviewPage(
        externalQuickAction: _externalQuickAction,
        onExternalQuickActionHandled:
            _onExternalQuickActionHandled,
      ),
      const WorkSchedulePage(),
      const CalendarPage(),
      const StatisticsPage(),
      const _MorePage(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
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
  const _OverviewPage({
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
        _OverviewHero(
          todayWorkDay: todayWorkDay,
        ),
        const SizedBox(height: 20),

        QuickEntryCard(
          workDay: todayWorkDay,
          externalAction: externalQuickAction,
          onExternalActionHandled:
              onExternalQuickActionHandled,
        ),

        const SizedBox(height: 24),

        const _OverviewSectionTitle(
          title: 'Heute',
          icon: Icons.today_outlined,
        ),
        const SizedBox(height: 10),

        _TodayCard(
          workDay: todayWorkDay,
        ),

        const SizedBox(height: 24),

        const _OverviewSectionTitle(
          title: 'Wochenüberblick',
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

class _OverviewHero extends StatelessWidget {
  const _OverviewHero({
    required this.todayWorkDay,
  });

  final WorkDay? todayWorkDay;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weekday = _weekdayName(now.weekday);
    final date =
        '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}';

    final status = todayWorkDay == null
        ? 'Noch kein Tag eingetragen'
        : _statusLabel(todayWorkDay!);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              Icons.local_shipping_outlined,
              color: Theme.of(context).colorScheme.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$weekday, $date',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onPrimaryContainer,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Dein TourLog',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context)
                            .colorScheme
                            .onPrimaryContainer,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  status,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onPrimaryContainer,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _weekdayName(int weekday) {
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

  static String _statusLabel(WorkDay workDay) {
    switch (workDay.type) {
      case WorkDayType.work:
        if (workDay.workEnd != null) {
          return 'Dienst beendet · ${_formatTime(workDay.workEnd!)} Uhr';
        }

        if (workDay.deliveryEnd != null) {
          return 'Zustellung beendet · ${_formatTime(workDay.deliveryEnd!)} Uhr';
        }

        if (workDay.departureTime != null) {
          return 'In Zustellung seit ${_formatTime(workDay.departureTime!)} Uhr';
        }

        if (workDay.workStart != null) {
          return 'Im Dienst seit ${_formatTime(workDay.workStart!)} Uhr';
        }

        return 'Arbeitstag eingetragen';

      case WorkDayType.free:
        return 'Heute hast du frei';

      case WorkDayType.vacation:
        return 'Heute ist Urlaub';

      case WorkDayType.holiday:
        return 'Heute ist Feiertag';

      case WorkDayType.sick:
        return 'Heute bist du krank eingetragen';
    }
  }
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
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) =>
                            const AdvertisingPage(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.schedule_outlined,
                  ),
                  title: const Text(
                    'Arbeitszeiten',
                  ),
                  subtitle: const Text(
                    'Sollzeiten und Pausen verwalten',
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) =>
                            const WorkTimesPage(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.backup_outlined,
                  ),
                  title: const Text(
                    'Daten & Backup',
                  ),
                  subtitle: const Text(
                    'Daten exportieren und wiederherstellen',
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) =>
                            const BackupPage(),
                      ),
                    );
                  },
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
                    'Allgemeine App-Einstellungen',
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) =>
                            const SettingsPage(),
                      ),
                    );
                  },
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