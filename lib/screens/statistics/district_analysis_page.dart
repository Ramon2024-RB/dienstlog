import 'package:flutter/material.dart';

import '../../models/own_tour_entry.dart';
import '../../models/work_day.dart';

class DistrictAnalysisPage extends StatelessWidget {
  const DistrictAnalysisPage({
    super.key,
    required this.zspName,
    required this.district,
    required this.entries,
    required this.workDays,
    required this.periodLabel,
  });

  final String zspName;
  final String district;
  final List<OwnTourEntry> entries;
  final List<WorkDay> workDays;
  final String periodLabel;

  @override
  Widget build(BuildContext context) {
    final workDayById = {
      for (final workDay in workDays) workDay.id: workDay,
    };

    final sortedEntries = [...entries]
      ..sort((a, b) {
        final aDate = workDayById[a.workDayId]?.date;
        final bDate = workDayById[b.workDayId]?.date;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });

    final totalPackages = entries.fold<int>(
      0,
      (sum, entry) => sum + entry.deliveredPackageCount,
    );
    final cancelledPackages = entries.fold<int>(
      0,
      (sum, entry) => sum + entry.cancelledPackageCount,
    );
    final averagePackages = entries.isEmpty
        ? 0
        : (totalPackages / entries.length).round();

    final unspecifiedPostCount = entries
        .where((entry) => entry.districtPart == DistrictPart.full)
        .length;
    final partACount = entries
        .where((entry) => entry.districtPart == DistrictPart.partA)
        .length;
    final partBCount = entries
        .where((entry) => entry.districtPart == DistrictPart.partB)
        .length;

    final partAEntries = entries
        .where((entry) => entry.districtPart == DistrictPart.partA)
        .toList();
    final partBEntries = entries
        .where((entry) => entry.districtPart == DistrictPart.partB)
        .toList();

    final partADeliveredPackages = partAEntries.fold<int>(
      0,
      (sum, entry) => sum + entry.deliveredPackageCount,
    );
    final partBDeliveredPackages = partBEntries.fold<int>(
      0,
      (sum, entry) => sum + entry.deliveredPackageCount,
    );

    final partAAveragePackages = partAEntries.isEmpty
        ? null
        : (partADeliveredPackages / partAEntries.length).round();
    final partBAveragePackages = partBEntries.isEmpty
        ? null
        : (partBDeliveredPackages / partBEntries.length).round();

    return Scaffold(
      appBar: AppBar(
        title: Text('Bezirk $district'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          _AnalysisHero(
            zspName: zspName,
            district: district,
            periodLabel: periodLabel,
          ),
          const SizedBox(height: 16),
          const _SafetyNotice(),
          const SizedBox(height: 24),
          const _SectionTitle('Übersicht'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  label: 'Touren',
                  value: '${entries.length}',
                  suffix: 'im Zeitraum',
                  icon: Icons.route_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  label: 'Ø Pakete',
                  value: '$averagePackages',
                  suffix: 'pro Tour',
                  icon: Icons.inventory_2_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  label: 'Zugestellt',
                  value: '$totalPackages',
                  suffix: 'Pakete gesamt',
                  icon: Icons.done_all_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  label: 'Abgebrochen',
                  value: '$cancelledPackages',
                  suffix: 'Pakete gesamt',
                  icon: Icons.cancel_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _SectionTitle('Post-Auswertung'),
          const SizedBox(height: 6),
          Text(
            'Welcher Postteil bei den ausgewerteten Touren eingetragen wurde.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  _StructureRow(label: 'A-Teil', value: partACount),
                  const Divider(height: 24),
                  _StructureRow(label: 'B-Teil', value: partBCount),
                  if (unspecifiedPostCount > 0) ...[
                    const Divider(height: 24),
                    _StructureRow(
                      label: 'Post nicht angegeben',
                      value: unspecifiedPostCount,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const _SectionTitle('A-/B-Vergleich'),
          const SizedBox(height: 6),
          Text(
            'Neutrale Gegenüberstellung der gespeicherten Paketmengen je Postteil.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _PostPartAnalysisCard(
                  label: 'A-Teil',
                  tourCount: partAEntries.length,
                  averagePackages: partAAveragePackages,
                  deliveredPackages: partADeliveredPackages,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PostPartAnalysisCard(
                  label: 'B-Teil',
                  tourCount: partBEntries.length,
                  averagePackages: partBAveragePackages,
                  deliveredPackages: partBDeliveredPackages,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Die Werte dienen nur der Übersicht. Unterschiedliche Tage, Mengen und Rahmenbedingungen sind nicht direkt als Leistung miteinander vergleichbar.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),
          const _SectionTitle('Tourverlauf'),
          const SizedBox(height: 6),
          Text(
            'Chronologische Übersicht der gespeicherten Touren – ohne Bewertung oder Rangfolge.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          if (sortedEntries.isEmpty)
            const Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('Für diesen Zeitraum liegen keine Tourdaten vor.'),
              ),
            )
          else
            for (var index = 0; index < sortedEntries.length; index++) ...[
              _TourHistoryCard(
                entry: sortedEntries[index],
                date: workDayById[sortedEntries[index].workDayId]?.date,
              ),
              if (index < sortedEntries.length - 1)
                const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _AnalysisHero extends StatelessWidget {
  const _AnalysisHero({
    required this.zspName,
    required this.district,
    required this.periodLabel,
  });

  final String zspName;
  final String district;
  final String periodLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
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
              Icons.analytics_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bezirk $district',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 3),
                Text(zspName),
                const SizedBox(height: 6),
                Text(
                  periodLabel,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SafetyNotice extends StatelessWidget {
  const _SafetyNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.shield_outlined,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Die Analyse dient der persönlichen Übersicht. Sicherheit und eine ordnungsgemäße Zustellung haben immer Vorrang vor Zeit- oder Leistungswerten.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.suffix,
    required this.icon,
  });

  final String label;
  final String value;
  final String suffix;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 14),
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              suffix,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StructureRow extends StatelessWidget {
  const _StructureRow({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        Text(
          '$value×',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }
}

class _PostPartAnalysisCard extends StatelessWidget {
  const _PostPartAnalysisCard({
    required this.label,
    required this.tourCount,
    required this.averagePackages,
    required this.deliveredPackages,
  });

  final String label;
  final int tourCount;
  final int? averagePackages;
  final int deliveredPackages;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.mail_outline,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _PostPartValueRow(
              label: 'Touren',
              value: '$tourCount',
            ),
            const SizedBox(height: 10),
            _PostPartValueRow(
              label: 'Ø Pakete',
              value: averagePackages == null ? '–' : '$averagePackages',
            ),
            const SizedBox(height: 10),
            _PostPartValueRow(
              label: 'Zugestellt',
              value: '$deliveredPackages',
            ),
          ],
        ),
      ),
    );
  }
}

class _PostPartValueRow extends StatelessWidget {
  const _PostPartValueRow({
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
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

class _TourHistoryCard extends StatelessWidget {
  const _TourHistoryCard({required this.entry, required this.date});

  final OwnTourEntry entry;
  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    final part = switch (entry.districtPart) {
      DistrictPart.full => 'Post nicht angegeben',
      DistrictPart.partA => 'Post: A-Teil',
      DistrictPart.partB => 'Post: B-Teil',
    };

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: const Icon(Icons.route_outlined),
        title: Text(date == null ? 'Tour' : _formatDate(date!)),
        subtitle: Text(
          entry.cancelledPackageCount > 0
              ? '$part · ${entry.cancelledPackageCount} abgebrochen'
              : part,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${entry.deliveredPackageCount}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text('Pakete', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day.$month.${date.year}';
  }
}
