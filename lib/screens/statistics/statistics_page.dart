import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/own_tour_entry.dart';
import '../../models/work_day.dart';
import '../../models/zsp_location.dart';
import '../../services/app_settings_provider.dart';
import '../../services/work_day_provider.dart';
import '../../services/zsp_provider.dart';
import '../../utils/work_time_balance_calculator.dart';
import 'district_analysis_page.dart';

enum StatisticsPeriod {
  week,
  month,
  year,
}

class StatisticsPage extends ConsumerStatefulWidget {
  const StatisticsPage({super.key});

  @override
  ConsumerState<StatisticsPage> createState() =>
      _StatisticsPageState();
}

class _StatisticsPageState
    extends ConsumerState<StatisticsPage> {
  StatisticsPeriod _selectedPeriod =
      StatisticsPeriod.month;

  @override
  Widget build(BuildContext context) {
    final workDaysAsync =
        ref.watch(workDayProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Statistik',
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
                    'Die Statistik konnte nicht geladen werden.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () {
                      ref.invalidate(
                        workDayProvider,
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
        data: (workDays) {
          return _buildContent(
            context,
            workDays,
          );
        },
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<WorkDay> workDays,
  ) {
    final now = DateTime.now();

    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final dateRange = _getDateRange(
      today,
      _selectedPeriod,
    );

    final filteredWorkDays = workDays.where(
      (workDay) {
        final date = DateTime(
          workDay.date.year,
          workDay.date.month,
          workDay.date.day,
        );

        return workDay.type == WorkDayType.work &&
            !date.isBefore(dateRange.start) &&
            !date.isAfter(dateRange.end);
      },
    ).toList();

    final totalWorkMinutes =
        filteredWorkDays.fold<int>(
      0,
      (sum, workDay) {
        return sum +
            (workDay.workDurationMinutes ?? 0);
      },
    );

    final totalDeliveryMinutes =
        filteredWorkDays.fold<int>(
      0,
      (sum, workDay) {
        return sum +
            (workDay.deliveryDurationMinutes ?? 0);
      },
    );

    final workDaysWithWorkTime =
        filteredWorkDays.where(
      (workDay) =>
          workDay.workDurationMinutes != null,
    );

    final workDaysWithDeliveryTime =
        filteredWorkDays.where(
      (workDay) =>
          workDay.deliveryDurationMinutes != null,
    );

    final averageWorkMinutes =
        workDaysWithWorkTime.isEmpty
            ? 0
            : totalWorkMinutes ~/
                workDaysWithWorkTime.length;

    final averageDeliveryMinutes =
        workDaysWithDeliveryTime.isEmpty
            ? 0
            : totalDeliveryMinutes ~/
                workDaysWithDeliveryTime.length;

    final packageDriverDays =
        filteredWorkDays.where(
      (workDay) =>
          workDay.assignmentType ==
          WorkAssignmentType.packageDriver,
    ).length;

    final mondayDeliveryDays =
        filteredWorkDays.where(
      (workDay) =>
          workDay.assignmentType ==
          WorkAssignmentType.mondayDelivery,
    ).length;

    final ownDistrictWorkDays =
        filteredWorkDays.where(
      (workDay) =>
          workDay.assignmentType ==
          WorkAssignmentType.ownDistrict,
    ).toList();

    final ownDistrictDays =
        ownDistrictWorkDays.length;

    final extendedAnalyticsEnabled = ref
            .watch(appSettingsProvider)
            .value
            ?.extendedAnalyticsEnabled ??
        false;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      children: [
        _StatisticsHero(
          period: _periodDescription(dateRange),
          workDayCount: filteredWorkDays.length,
          totalWorkMinutes: totalWorkMinutes,
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<StatisticsPeriod>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: StatisticsPeriod.week,
                label: Text('Woche'),
              ),
              ButtonSegment(
                value: StatisticsPeriod.month,
                label: Text('Monat'),
              ),
              ButtonSegment(
                value: StatisticsPeriod.year,
                label: Text('Jahr'),
              ),
            ],
            selected: {_selectedPeriod},
            onSelectionChanged: (selection) {
              setState(() {
                _selectedPeriod = selection.first;
              });
            },
          ),
        ),
        const SizedBox(height: 26),
        const _StatisticsSectionTitle(
          icon: Icons.dashboard_outlined,
          title: 'Übersicht',
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _StatisticCard(
                icon: Icons.work_outline,
                title: 'Arbeitstage',
                value: '${filteredWorkDays.length}',
                subtitle: 'im Zeitraum',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatisticCard(
                icon: Icons.access_time_outlined,
                title: 'Arbeitszeit',
                value: _formatDuration(totalWorkMinutes),
                subtitle: 'gesamt',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _WorkTimeBalanceStatistics(
          workDays: filteredWorkDays,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatisticCard(
                icon: Icons.route_outlined,
                title: 'Eigene Tour',
                value: '$ownDistrictDays',
                subtitle: 'Arbeitstage',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatisticCard(
                icon: Icons.calendar_view_week_outlined,
                title: 'Montagszust.',
                value: '$mondayDeliveryDays',
                subtitle: 'Arbeitstage',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _StatisticDetailCard(
          icon: Icons.local_shipping_outlined,
          title: 'Paketfahrer',
          value: '$packageDriverDays Arbeitstage',
          description:
              'Arbeitstage, die als Paketfahrer erfasst wurden.',
        ),
        const SizedBox(height: 26),
        const _StatisticsSectionTitle(
          icon: Icons.schedule_outlined,
          title: 'Zeiten',
        ),
        const SizedBox(height: 10),
        _StatisticDetailCard(
          icon: Icons.schedule_outlined,
          title: 'Ø Arbeitszeit',
          value: _formatDuration(averageWorkMinutes),
          description:
              'Durchschnitt pro Arbeitstag mit eingetragener Arbeitszeit.',
        ),
        const SizedBox(height: 12),
        _StatisticDetailCard(
          icon: Icons.local_shipping_outlined,
          title: 'Ø Zustellzeit',
          value: _formatDuration(averageDeliveryMinutes),
          description: 'Zeit zwischen Abfahrt und Zustellende.',
        ),
        const SizedBox(height: 26),
        const _StatisticsSectionTitle(
          icon: Icons.inventory_2_outlined,
          title: 'Pakete & Bezirke',
        ),
        const SizedBox(height: 10),
        _PackageDistrictStatistics(
          startDate: dateRange.start,
          endDate: dateRange.end,
          workDays: ownDistrictWorkDays,
          allWorkDays: filteredWorkDays,
          periodLabel: _periodDescription(dateRange),
          extendedAnalyticsEnabled: extendedAnalyticsEnabled,
        ),
      ],
    );
  }

  _DateRange _getDateRange(
    DateTime today,
    StatisticsPeriod period,
  ) {
    switch (period) {
      case StatisticsPeriod.week:
        final start = today.subtract(
          Duration(
            days: today.weekday -
                DateTime.monday,
          ),
        );

        final end = start.add(
          const Duration(days: 6),
        );

        return _DateRange(
          start: start,
          end: end,
        );

      case StatisticsPeriod.month:
        final start = DateTime(
          today.year,
          today.month,
          1,
        );

        final end = DateTime(
          today.year,
          today.month + 1,
          0,
        );

        return _DateRange(
          start: start,
          end: end,
        );

      case StatisticsPeriod.year:
        return _DateRange(
          start: DateTime(
            today.year,
            1,
            1,
          ),
          end: DateTime(
            today.year,
            12,
            31,
          ),
        );
    }
  }

  String _periodDescription(
    _DateRange range,
  ) {
    switch (_selectedPeriod) {
      case StatisticsPeriod.week:
        return '${_formatDate(range.start)} – ${_formatDate(range.end)}';

      case StatisticsPeriod.month:
        return '${_monthName(range.start.month)} ${range.start.year}';

      case StatisticsPeriod.year:
        return '${range.start.year}';
    }
  }

  static String _formatDate(
    DateTime date,
  ) {
    final day = date.day
        .toString()
        .padLeft(2, '0');

    final month = date.month
        .toString()
        .padLeft(2, '0');

    return '$day.$month.${date.year}';
  }

  static String _monthName(
    int month,
  ) {
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

    return months[month - 1];
  }
}

class _StatisticsHero extends StatelessWidget {
  const _StatisticsHero({
    required this.period,
    required this.workDayCount,
    required this.totalWorkMinutes,
  });

  final String period;
  final int workDayCount;
  final int totalWorkMinutes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.insights_outlined,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Deine Auswertung',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      period,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _HeroMetric(
                  value: '$workDayCount',
                  label: 'Arbeitstage',
                ),
              ),
              Container(
                width: 1,
                height: 42,
                color: theme.colorScheme.outlineVariant,
              ),
              Expanded(
                child: _HeroMetric(
                  value: _formatDuration(totalWorkMinutes),
                  label: 'Arbeitszeit',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatisticsSectionTitle extends StatelessWidget {
  const _StatisticsSectionTitle({
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(
          icon,
          size: 22,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 9),
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _WorkTimeBalanceStatistics extends StatelessWidget {
  const _WorkTimeBalanceStatistics({
    required this.workDays,
  });

  final List<WorkDay> workDays;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<int>>(
      future: Future.wait<int>([
        WorkTimeBalanceCalculator.getTargetMinutesForWorkDays(
          workDays,
        ),
        WorkTimeBalanceCalculator
            .getActualMinutesForComparableWorkDays(
          workDays,
        ),
        WorkTimeBalanceCalculator.getBalanceMinutesForWorkDays(
          workDays,
        ),
      ]),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _StatisticDetailCard(
            icon: Icons.balance_outlined,
            title: 'Plus / Minus',
            value: '–',
            description:
                'Die Soll-Arbeitszeit konnte nicht berechnet werden.',
          );
        }

        final values = snapshot.data;

        if (values == null) {
          return const _StatisticDetailCard(
            icon: Icons.balance_outlined,
            title: 'Plus / Minus',
            value: '…',
            description:
                'Soll- und Ist-Arbeitszeit werden berechnet.',
          );
        }

        final targetMinutes = values[0];
        final actualMinutes = values[1];
        final balanceMinutes = values[2];

        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _StatisticCard(
                    icon: Icons.flag_outlined,
                    title: 'Sollzeit',
                    value: _formatDuration(targetMinutes),
                    subtitle: 'im Zeitraum',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatisticCard(
                    icon: Icons.timelapse_outlined,
                    title: 'Istzeit',
                    value: _formatDuration(actualMinutes),
                    subtitle: 'vergleichbar',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _StatisticDetailCard(
              icon: Icons.balance_outlined,
              title: 'Plus / Minus',
              value: WorkTimeBalanceCalculator.formatBalance(
                balanceMinutes,
              ),
              description:
                  'Differenz zwischen deiner Soll- und tatsächlichen Arbeitszeit.',
            ),
          ],
        );
      },
    );
  }
}

class _PackageDistrictStatistics
    extends ConsumerWidget {
  const _PackageDistrictStatistics({
    required this.startDate,
    required this.endDate,
    required this.workDays,
    required this.allWorkDays,
    required this.periodLabel,
    required this.extendedAnalyticsEnabled,
  });

  final DateTime startDate;
  final DateTime endDate;
  final List<WorkDay> workDays;
  final List<WorkDay> allWorkDays;
  final String periodLabel;
  final bool extendedAnalyticsEnabled;

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    ref.watch(zspProvider);

    return FutureBuilder<_PackageStatisticsData>(
      future: _loadStatistics(
        ref,
      ),
      builder: (
        context,
        snapshot,
      ) {
        if (snapshot.connectionState ==
                ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 40,
                    color: Theme.of(context)
                        .colorScheme
                        .error,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Die Paket- und Bezirksdaten konnten nicht geladen werden.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge,
                  ),
                ],
              ),
            ),
          );
        }

        final data = snapshot.data;

        if (data == null) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _StatisticCard(
                    icon:
                        Icons.inventory_2_outlined,
                    title: 'Eigene Pakete',
                    value:
                        '${data.ownPackages}',
                    subtitle: 'zugestellt',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatisticCard(
                    icon:
                        Icons.route_outlined,
                    title: 'Eigene Touren',
                    value:
                        '${data.totalTours}',
                    subtitle:
                        'selbst gefahren',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _StatisticCard(
                    icon: Icons.calendar_view_week_outlined,
                    title: 'Montagspakete',
                    value: '${data.mondayDeliveryPackages}',
                    subtitle: 'zugestellt',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatisticCard(
                    icon: Icons.local_shipping_outlined,
                    title: 'Paketfahrer',
                    value: '${data.packageDriverPackages}',
                    subtitle: 'Pakete',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            _StatisticDetailCard(
              icon: Icons.group_outlined,
              title: 'Unterstützung',
              value: '${data.supportPackages} Pakete',
              description:
                  'Zusätzlich übernommene Pakete im ausgewählten Zeitraum.',
            ),

            if (data.cancelledPackages > 0) ...[
              const SizedBox(height: 12),
              _StatisticDetailCard(
                icon: Icons.cancel_outlined,
                title: 'Abgebrochene Pakete',
                value: '${data.cancelledPackages}',
                description: 'Eigene Pakete im ausgewählten Zeitraum.',
              ),
            ],

            const SizedBox(height: 24),

            const _StatisticsSectionTitle(
              icon: Icons.map_outlined,
              title: 'Bezirke',
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _StatisticCard(
                    icon:
                        Icons.route_outlined,
                    title: 'Eigene Tage',
                    value:
                        '${workDays.length}',
                    subtitle:
                        'mit eigener Tour',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatisticCard(
                    icon:
                        Icons.map_outlined,
                    title: 'Bezirke',
                    value:
                        '${data.uniqueDistricts}',
                    subtitle:
                        'verschiedene',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            if (data.districtStatistics.isEmpty)
              _EmptyDistrictStatistics()
            else ...[
              Text(
                'Gefahrene Bezirke',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),

              const SizedBox(height: 6),

              Text(
                extendedAnalyticsEnabled
                    ? 'Tippe auf einen Bezirk, um die erweiterte Analyse zu öffnen.'
                    : 'Sortiert nach der Anzahl deiner Fahrten.',
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

              for (var index = 0;
                  index <
                      data.districtStatistics
                          .length;
                  index++) ...[
                _DistrictStatisticCard(
                  statistic: data.districtStatistics[index],
                  showAnalysis: extendedAnalyticsEnabled,
                  onTap: extendedAnalyticsEnabled
                      ? () {
                          final statistic = data.districtStatistics[index];
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (context) => DistrictAnalysisPage(
                                zspName: statistic.zspName,
                                district: statistic.district,
                                entries: statistic.entries,
                                workDays: workDays,
                                periodLabel: periodLabel,
                              ),
                            ),
                          );
                        }
                      : null,
                ),
                if (index <
                    data.districtStatistics
                            .length -
                        1)
                  const SizedBox(height: 12),
              ],
            ],
          ],
        );
      },
    );
  }

  Future<_PackageStatisticsData>
      _loadStatistics(
    WidgetRef ref,
  ) async {
    final notifier = ref.read(
      workDayProvider.notifier,
    );

    final locations = ref.read(zspProvider).value ?? const <ZspLocation>[];
    final zspNames = {for (final item in locations) item.id: item.name};

    final ownDistrictWorkDayIds = workDays
        .where(
          (workDay) =>
              workDay.assignmentType ==
              WorkAssignmentType.ownDistrict,
        )
        .map((workDay) => workDay.id)
        .toSet();

    final allOwnTourEntries =
        await notifier
            .getOwnTourEntriesForDateRange(
      startDate,
      endDate,
    );

    final ownTourEntries =
        allOwnTourEntries
            .where(
              (entry) =>
                  ownDistrictWorkDayIds
                      .contains(entry.workDayId),
            )
            .toList();

    final ownPackages =
        ownTourEntries.fold<int>(
      0,
      (sum, entry) =>
          sum + entry.deliveredPackageCount,
    );

    final cancelledPackages =
        ownTourEntries.fold<int>(
      0,
      (sum, entry) =>
          sum + entry.cancelledPackageCount,
    );

    final supportPackages =
        await notifier.getTotalSupportPackagesForDateRange(
      startDate,
      endDate,
    );

    final mondayDeliveryPackages =
        allWorkDays
            .where(
              (workDay) =>
                  workDay.assignmentType ==
                  WorkAssignmentType.mondayDelivery,
            )
            .fold<int>(
              0,
              (sum, workDay) =>
                  sum + workDay.mondayDeliveryPackageCount,
            );

    final packageDriverPackages =
        allWorkDays
            .where(
              (workDay) =>
                  workDay.assignmentType ==
                  WorkAssignmentType.packageDriver,
            )
            .fold<int>(
              0,
              (sum, workDay) =>
                  sum + workDay.packageDriverPackageCount,
            );

    final districtStatistics =
        _buildDistrictStatistics(
      ownTourEntries,
      zspNames,
    );

    return _PackageStatisticsData(
      ownPackages: ownPackages,
      mondayDeliveryPackages: mondayDeliveryPackages,
      packageDriverPackages: packageDriverPackages,
      supportPackages: supportPackages,
      cancelledPackages:
          cancelledPackages,
      totalTours: ownTourEntries.length,
      uniqueDistricts:
          districtStatistics.length,
      districtStatistics:
          districtStatistics,
    );
  }

  List<_DistrictStatistic> _buildDistrictStatistics(
    List<OwnTourEntry> entries,
    Map<String, String> zspNames,
  ) {
    final groupedEntries = <String, List<OwnTourEntry>>{};

    for (final entry in entries) {
      final district = entry.district.trim();
      if (district.isEmpty) continue;
      final key = '${entry.zspId}::$district';
      groupedEntries.putIfAbsent(key, () => <OwnTourEntry>[]).add(entry);
    }

    final statistics = groupedEntries.entries.map((group) {
      final entries = group.value;
      final first = entries.first;
      final totalPackages = entries.fold<int>(
        0,
        (sum, entry) => sum + entry.deliveredPackageCount,
      );
      final cancelledPackages = entries.fold<int>(
        0,
        (sum, entry) => sum + entry.cancelledPackageCount,
      );

      return _DistrictStatistic(
        zspId: first.zspId,
        zspName: zspNames[first.zspId] ??
            (first.zspId == ZspLocation.werneckId ? 'ZSP Werneck' : first.zspId),
        district: first.district.trim(),
        driveCount: entries.length,
        totalPackages: totalPackages,
        cancelledPackages: cancelledPackages,
        entries: List<OwnTourEntry>.unmodifiable(entries),
      );
    }).toList();

    statistics.sort((first, second) {
      final driveComparison = second.driveCount.compareTo(first.driveCount);
      if (driveComparison != 0) return driveComparison;
      final zspComparison = first.zspName.compareTo(second.zspName);
      if (zspComparison != 0) return zspComparison;
      return _compareDistricts(first.district, second.district);
    });

    return statistics;
  }

  int _compareDistricts(
    String first,
    String second,
  ) {
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

    if (firstNumber != null) {
      return -1;
    }

    if (secondNumber != null) {
      return 1;
    }

    return first.toLowerCase().compareTo(
          second.toLowerCase(),
        );
  }
}

class _EmptyDistrictStatistics
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.route_outlined,
              size: 40,
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'Noch keine eigenen Touren',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Für diesen Zeitraum wurden noch keine selbst gefahrenen Bezirke eingetragen.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
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
}

class _DistrictStatisticCard
    extends StatelessWidget {
  const _DistrictStatisticCard({
    required this.statistic,
    required this.showAnalysis,
    this.onTap,
  });

  final _DistrictStatistic statistic;
  final bool showAnalysis;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer,
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                  ),
                  child: Icon(
                    Icons.route_outlined,
                    color: Theme.of(context)
                        .colorScheme
                        .onPrimaryContainer,
                  ),
                ),

                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Text(
                        'Bezirk ${statistic.district}',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        statistic.zspName,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _driveCountLabel(
                          statistic.driveCount,
                        ),
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                              color: Theme.of(
                                context,
                              )
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            Row(
              children: [
                Expanded(
                  child: _DistrictValue(
                    label: 'Gesamt',
                    value:
                        '${statistic.totalPackages}',
                    suffix: 'Pakete',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DistrictValue(
                    label: 'Ø pro Fahrt',
                    value:
                        '${statistic.averagePackages}',
                    suffix: 'Pakete',
                  ),
                ),
              ],
            ),

            if (statistic.cancelledPackages >
                0) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(
                    Icons.cancel_outlined,
                    size: 18,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${statistic.cancelledPackages} abgebrochene Pakete',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                            color: Theme.of(
                              context,
                            )
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                  ),
                ],
              ),
            ],
            if (showAnalysis) ...[
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Analyse öffnen',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
            ],
          ],
        ),
        ),
      ),
    );
  }

  static String _driveCountLabel(
    int driveCount,
  ) {
    if (driveCount == 1) {
      return '1× gefahren';
    }

    return '$driveCount× gefahren';
  }
}

class _DistrictValue
    extends StatelessWidget {
  const _DistrictValue({
    required this.label,
    required this.value,
    required this.suffix,
  });

  final String label;
  final String value;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest,
        borderRadius: BorderRadius.circular(
          12,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant,
                ),
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
          Text(
            suffix,
            style: Theme.of(context)
                .textTheme
                .bodySmall,
          ),
        ],
      ),
    );
  }
}

class _PackageStatisticsData {
  const _PackageStatisticsData({
    required this.ownPackages,
    required this.mondayDeliveryPackages,
    required this.packageDriverPackages,
    required this.supportPackages,
    required this.cancelledPackages,
    required this.totalTours,
    required this.uniqueDistricts,
    required this.districtStatistics,
  });

  final int ownPackages;
  final int mondayDeliveryPackages;
  final int packageDriverPackages;
  final int supportPackages;
  final int cancelledPackages;
  final int totalTours;
  final int uniqueDistricts;

  final List<_DistrictStatistic>
      districtStatistics;

  int get totalDeliveredPackages =>
      ownPackages +
      mondayDeliveryPackages +
      packageDriverPackages +
      supportPackages;
}

class _DistrictStatistic {
  const _DistrictStatistic({
    required this.zspId,
    required this.zspName,
    required this.district,
    required this.driveCount,
    required this.totalPackages,
    required this.cancelledPackages,
    required this.entries,
  });

  final String zspId;
  final String zspName;
  final String district;
  final int driveCount;
  final int totalPackages;
  final int cancelledPackages;
  final List<OwnTourEntry> entries;

  int get averagePackages {
    if (driveCount <= 0) {
      return 0;
    }

    return (totalPackages / driveCount)
        .round();
  }
}

class _StatisticCard
    extends StatelessWidget {
  const _StatisticCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color:
                  Theme.of(context)
                      .colorScheme
                      .primary,
            ),

            const SizedBox(height: 14),

            Text(
              title,
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              style:
                  Theme.of(context)
                      .textTheme
                      .labelLarge,
            ),

            const SizedBox(height: 5),

            Text(
              value,
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              style:
                  Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                        fontWeight:
                            FontWeight.bold,
                      ),
            ),

            const SizedBox(height: 2),

            Text(
              subtitle,
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              style:
                  Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                        color:
                            Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatisticDetailCard
    extends StatelessWidget {
  const _StatisticDetailCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String value;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding:
            const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              alignment:
                  Alignment.center,
              decoration: BoxDecoration(
                color:
                    Theme.of(context)
                        .colorScheme
                        .primaryContainer,
                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
              ),
              child: Icon(
                icon,
                color:
                    Theme.of(context)
                        .colorScheme
                        .onPrimaryContainer,
              ),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style:
                        Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              fontWeight:
                                  FontWeight.w600,
                            ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    value,
                    style:
                        Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                              fontWeight:
                                  FontWeight.bold,
                            ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    description,
                    style:
                        Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                              color:
                                  Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                            ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateRange {
  const _DateRange({
    required this.start,
    required this.end,
  });

  final DateTime start;
  final DateTime end;
}

String _formatDuration(
  int minutes,
) {
  final hours = minutes ~/ 60;
  final remainingMinutes =
      minutes % 60;

  return '$hours h ${remainingMinutes.toString().padLeft(2, '0')} min';
}