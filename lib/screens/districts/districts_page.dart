import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/district.dart';
import '../../services/district_provider.dart';

class DistrictsPage extends ConsumerWidget {
  const DistrictsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final districtsAsync = ref.watch(districtProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Bezirke',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: districtsAsync.when(
        loading: () {
          return const Center(
            child: CircularProgressIndicator(),
          );
        },
        error: (error, stackTrace) {
          return _DistrictErrorView(
            error: error,
            onRetry: () {
              ref.invalidate(districtProvider);
            },
          );
        },
        data: (districts) {
          return _DistrictList(
            districts: districts,
          );
        },
      ),
    );
  }
}

class _DistrictList extends ConsumerWidget {
  const _DistrictList({
    required this.districts,
  });

  final List<District> districts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeDistricts = districts
        .where((district) => district.isActive)
        .toList();

    final safeDistrictCount = activeDistricts
        .where((district) => district.canDriveSafely)
        .length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _DistrictSummaryCard(
          totalDistricts: activeDistricts.length,
          safeDistricts: safeDistrictCount,
        ),
        const SizedBox(height: 24),
        Text(
          'Alle Bezirke',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'Markiere die Bezirke, die du selbstständig und sicher fahren kannst.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 16),
        ...activeDistricts.map(
          (district) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _DistrictCard(
              district: district,
              onChanged: (value) async {
                await ref
                    .read(districtProvider.notifier)
                    .setCanDriveSafely(
                      district,
                      value,
                    );
              },
              onNotePressed: () {
                _showNoteDialog(
                  context,
                  ref,
                  district,
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showNoteDialog(
    BuildContext context,
    WidgetRef ref,
    District district,
  ) async {
    final note = await showDialog<String?>(
      context: context,
      builder: (dialogContext) {
        return _DistrictNoteDialog(
          districtNumber: district.number,
          initialNote: district.note ?? '',
        );
      },
    );

    if (note == null) {
      return;
    }

    await ref
        .read(districtProvider.notifier)
        .updateNote(
          district,
          note,
        );
  }
}

class _DistrictNoteDialog extends StatefulWidget {
  const _DistrictNoteDialog({
    required this.districtNumber,
    required this.initialNote,
  });

  final int districtNumber;
  final String initialNote;

  @override
  State<_DistrictNoteDialog> createState() => _DistrictNoteDialogState();
}

class _DistrictNoteDialogState extends State<_DistrictNoteDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();

    _controller = TextEditingController(
      text: widget.initialNote,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Notiz – Bezirk ${widget.districtNumber}',
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        minLines: 2,
        maxLines: 5,
        decoration: const InputDecoration(
          hintText: 'Optionale Notiz zum Bezirk',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(
              _controller.text,
            );
          },
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}

class _DistrictSummaryCard extends StatelessWidget {
  const _DistrictSummaryCard({
    required this.totalDistricts,
    required this.safeDistricts,
  });

  final int totalDistricts;
  final int safeDistricts;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.route_outlined,
                color: Theme.of(context)
                    .colorScheme
                    .onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$safeDistricts von $totalDistricts',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Bezirke sicher fahrbar',
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
          ],
        ),
      ),
    );
  }
}

class _DistrictCard extends StatelessWidget {
  const _DistrictCard({
    required this.district,
    required this.onChanged,
    required this.onNotePressed,
  });

  final District district;
  final ValueChanged<bool> onChanged;
  final VoidCallback onNotePressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          16,
          10,
          8,
          10,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: district.canDriveSafely
                    ? Theme.of(context)
                        .colorScheme
                        .primaryContainer
                    : Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                '${district.number}',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bezirk ${district.number}',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    district.note?.isNotEmpty == true
                        ? district.note!
                        : district.canDriveSafely
                            ? 'Sicher fahrbar'
                            : 'Noch nicht markiert',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Notiz',
              onPressed: onNotePressed,
              icon: Icon(
                district.note?.isNotEmpty == true
                    ? Icons.notes
                    : Icons.note_add_outlined,
              ),
            ),
            Switch(
              value: district.canDriveSafely,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _DistrictErrorView extends StatelessWidget {
  const _DistrictErrorView({
    required this.error,
    required this.onRetry,
  });

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
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
            Text(
              'Die Bezirke konnten nicht geladen werden.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '$error',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Erneut versuchen'),
            ),
          ],
        ),
      ),
    );
  }
}