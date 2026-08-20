import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/own_tour_entry.dart';
import '../../models/work_day.dart';
import '../../services/work_day_provider.dart';

enum QuickEntryExternalAction {
  workStart,
  deliveryStart,
  deliveryEnd,
  workEnd,
}

class QuickEntryCard extends ConsumerStatefulWidget {
  const QuickEntryCard({
    super.key,
    required this.workDay,
    this.externalAction,
    this.onExternalActionHandled,
  });

  final WorkDay? workDay;
  final QuickEntryExternalAction? externalAction;
  final VoidCallback? onExternalActionHandled;

  @override
  ConsumerState<QuickEntryCard> createState() =>
      _QuickEntryCardState();
}

class _QuickEntryCardState
    extends ConsumerState<QuickEntryCard> {
  QuickEntryExternalAction? _lastHandledAction;

  WorkDay? get workDay => widget.workDay;

  @override
  void initState() {
    super.initState();
    _scheduleExternalActionIfNeeded();
  }

  @override
  void didUpdateWidget(
    covariant QuickEntryCard oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.externalAction !=
        widget.externalAction) {
      if (widget.externalAction == null) {
        _lastHandledAction = null;
      }

      _scheduleExternalActionIfNeeded();
    }
  }

  void _scheduleExternalActionIfNeeded() {
    final action = widget.externalAction;

    if (action == null ||
        action == _lastHandledAction) {
      return;
    }

    _lastHandledAction = action;

    WidgetsBinding.instance.addPostFrameCallback(
      (_) async {
        if (!mounted) {
          return;
        }

        switch (action) {
          case QuickEntryExternalAction.workStart:
            await _saveSimpleTime(
              context: context,
              ref: ref,
              action: _QuickTimeAction.workStart,
            );
            break;

          case QuickEntryExternalAction.deliveryStart:
            await _startDelivery(
              context,
              ref,
            );
            break;

          case QuickEntryExternalAction.deliveryEnd:
            await _endDelivery(
              context,
              ref,
            );
            break;

          case QuickEntryExternalAction.workEnd:
            await _saveSimpleTime(
              context: context,
              ref: ref,
              action: _QuickTimeAction.workEnd,
            );
            break;
        }

        if (mounted) {
          widget.onExternalActionHandled?.call();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentWorkDay = workDay;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.bolt_outlined,
                  color: Theme.of(context)
                      .colorScheme
                      .primary,
                ),
                const SizedBox(width: 10),
                Text(
                  'Schnellerfassung',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                        fontWeight:
                            FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Zeiten mit einem Tipp erfassen. Vor dem Speichern wird immer nachgefragt.',
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

            _QuickActionTile(
              icon: Icons.login,
              title: 'Dienstbeginn',
              value: _formatTime(
                currentWorkDay?.workStart,
              ),
              isDone:
                  currentWorkDay?.workStart != null,
              onTap: () => _saveSimpleTime(
                context: context,
                ref: ref,
                action: _QuickTimeAction.workStart,
              ),
            ),

            const SizedBox(height: 10),

            _QuickActionTile(
              icon: Icons.local_shipping_outlined,
              title: 'Zustellungsbeginn',
              value: _formatTime(
                currentWorkDay?.departureTime,
              ),
              isDone:
                  currentWorkDay?.departureTime !=
                      null,
              onTap: () => _startDelivery(
                context,
                ref,
              ),
            ),

            const SizedBox(height: 10),

            _QuickActionTile(
              icon: Icons.inventory_2_outlined,
              title: 'Zustellungsende',
              value: _formatTime(
                currentWorkDay?.deliveryEnd,
              ),
              isDone:
                  currentWorkDay?.deliveryEnd != null,
              onTap: () => _endDelivery(
                context,
                ref,
              ),
            ),

            const SizedBox(height: 10),

            _QuickActionTile(
              icon: Icons.logout,
              title: 'Dienstende',
              value: _formatTime(
                currentWorkDay?.workEnd,
              ),
              isDone:
                  currentWorkDay?.workEnd != null,
              onTap: () => _saveSimpleTime(
                context: context,
                ref: ref,
                action: _QuickTimeAction.workEnd,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveSimpleTime({
    required BuildContext context,
    required WidgetRef ref,
    required _QuickTimeAction action,
  }) async {
    final now = DateTime.now();
    final minutes = _minutesSinceMidnight(now);

    final existingValue = switch (action) {
      _QuickTimeAction.workStart =>
        workDay?.workStart,
      _QuickTimeAction.workEnd =>
        workDay?.workEnd,
    };

    final title = switch (action) {
      _QuickTimeAction.workStart =>
        'Dienstbeginn',
      _QuickTimeAction.workEnd =>
        'Dienstende',
    };

    if (action == _QuickTimeAction.workEnd) {
      final current = workDay;

      if (current?.deliveryEnd == null) {
        final continueWithoutDeliveryEnd =
            await _confirm(
          context,
          title: 'Zustellungsende fehlt',
          message:
              'Trotzdem Dienstende um ${_formatTime(minutes)} Uhr speichern?',
        );

        if (!continueWithoutDeliveryEnd ||
            !context.mounted) {
          return;
        }
      }
    }

    final question = existingValue == null
        ? '${_formatTime(minutes)} Uhr speichern?'
        : 'Bereits: ${_formatTime(existingValue)} Uhr\n'
            'Neu: ${_formatTime(minutes)} Uhr';

    final confirmed = await _confirm(
      context,
      title: title,
      message: question,
    );

    if (!confirmed || !context.mounted) {
      return;
    }

    final latestNow = DateTime.now();
    final latestMinutes =
        _minutesSinceMidnight(latestNow);

    WorkDay updated = _baseWorkDay(latestNow);

    if (action == _QuickTimeAction.workStart) {
      if (updated.departureTime != null &&
          latestMinutes >
              updated.departureTime!) {
        _showMessage(
          context,
          'Der Dienstbeginn kann nicht nach dem Zustellungsbeginn liegen.',
        );
        return;
      }

      updated = updated.copyWith(
        workStart: latestMinutes,
      );
    } else {
      if (updated.deliveryEnd != null &&
          latestMinutes <
              updated.deliveryEnd!) {
        _showMessage(
          context,
          'Das Dienstende kann nicht vor dem Zustellungsende liegen.',
        );
        return;
      }

      if (updated.deliveryEnd == null &&
          updated.departureTime != null &&
          latestMinutes <
              updated.departureTime!) {
        _showMessage(
          context,
          'Das Dienstende kann nicht vor dem Zustellungsbeginn liegen.',
        );
        return;
      }

      if (updated.workStart != null &&
          latestMinutes <
              updated.workStart!) {
        _showMessage(
          context,
          'Das Dienstende kann nicht vor dem Dienstbeginn liegen.',
        );
        return;
      }

      updated = updated.copyWith(
        workEnd: latestMinutes,
      );
    }

    await _saveWorkDay(
      context,
      ref,
      updated,
    );
  }

  Future<void> _startDelivery(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final existing = workDay;

    if (existing?.workStart == null) {
      final continueWithoutWorkStart =
          await _confirm(
        context,
        title: 'Kein Dienstbeginn',
        message:
            'Noch kein Dienstbeginn gespeichert.\nTrotzdem starten?',
      );

      if (!continueWithoutWorkStart ||
          !context.mounted) {
        return;
      }
    }

    final initialOwnTours = existing == null
        ? const <OwnTourEntry>[]
        : await ref
            .read(workDayProvider.notifier)
            .getOwnTourEntries(existing.id);

    if (!context.mounted) {
      return;
    }

    final initialDistrict =
        initialOwnTours.isNotEmpty
            ? initialOwnTours.first.district
            : existing?.districtId;

    final initialPackages =
        initialOwnTours.isNotEmpty
            ? initialOwnTours.first.packageCount
            : existing?.packageCount ?? 0;

    final result =
        await showModalBottomSheet<
            _DeliveryStartResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return _DeliveryStartSheet(
          initialDistrict: initialDistrict,
          initialPackages: initialPackages,
          initialAdvertising:
              existing?.hasAdvertising ?? false,
        );
      },
    );

    if (result == null || !context.mounted) {
      return;
    }

    final previewNow = DateTime.now();
    final previewMinutes =
        _minutesSinceMidnight(previewNow);

    final existingTime =
        existing?.departureTime;

    final advertisingText =
        result.hasAdvertising
            ? 'Werbung'
            : 'Keine Werbung';

    final confirmed = await _confirm(
      context,
      title: 'Zustellungsbeginn',
      message: existingTime == null
          ? 'Bezirk ${result.district} · '
              '${result.packages} Pakete · '
              '$advertisingText\n'
              '${_formatTime(previewMinutes)} Uhr'
          : 'Bezirk ${result.district} · '
              '${result.packages} Pakete · '
              '$advertisingText\n\n'
              'Bereits: ${_formatTime(existingTime)} Uhr\n'
              'Neu: ${_formatTime(previewMinutes)} Uhr',
    );

    if (!confirmed || !context.mounted) {
      return;
    }

    final now = DateTime.now();
    final minutes =
        _minutesSinceMidnight(now);
    final base = _baseWorkDay(now);

    if (base.workStart != null &&
        minutes < base.workStart!) {
      _showMessage(
        context,
        'Der Zustellungsbeginn kann nicht vor dem Dienstbeginn liegen.',
      );
      return;
    }

    if (base.deliveryEnd != null &&
        minutes > base.deliveryEnd!) {
      _showMessage(
        context,
        'Der Zustellungsbeginn kann nicht nach dem Zustellungsende liegen.',
      );
      return;
    }

    if (base.workEnd != null &&
        minutes > base.workEnd!) {
      _showMessage(
        context,
        'Der Zustellungsbeginn kann nicht nach dem Dienstende liegen.',
      );
      return;
    }

    final updated = base.copyWith(
      type: WorkDayType.work,
      assignmentType:
          WorkAssignmentType.ownDistrict,
      districtId: result.district,
      districtPart: DistrictPart.full,
      departureTime: minutes,
      packageCount: result.packages,
      cancelledPackageCount: 0,
      hasAdvertising: result.hasAdvertising,
      clearAdvertising:
          !result.hasAdvertising,
    );

    final ownTour = OwnTourEntry(
      workDayId: updated.id,
      district: result.district,
      districtPart: DistrictPart.full,
      packageCount: result.packages,
      cancelledPackageCount: 0,
    );

    await _saveWorkDay(
      context,
      ref,
      updated,
      ownTourEntries: [ownTour],
    );
  }

  Future<void> _endDelivery(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final existing = workDay;

    if (existing == null) {
      _showMessage(
        context,
        'Für heute gibt es noch keinen Arbeitstag.',
      );
      return;
    }

    if (existing.departureTime == null) {
      final continueWithoutStart =
          await _confirm(
        context,
        title: 'Kein Zustellungsbeginn',
        message:
            'Noch kein Zustellungsbeginn gespeichert.\nTrotzdem beenden?',
      );

      if (!continueWithoutStart ||
          !context.mounted) {
        return;
      }
    }

    final note =
        await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return const _DeliveryEndSheet();
      },
    );

    if (!context.mounted) {
      return;
    }

    if (note == null) {
      return;
    }

    final previewNow = DateTime.now();
    final previewMinutes =
        _minutesSinceMidnight(previewNow);

    final confirmed = await _confirm(
      context,
      title: 'Zustellungsende',
      message: existing.deliveryEnd == null
          ? '${_formatTime(previewMinutes)} Uhr speichern?'
          : 'Bereits: ${_formatTime(existing.deliveryEnd)} Uhr\n'
              'Neu: ${_formatTime(previewMinutes)} Uhr',
    );

    if (!confirmed || !context.mounted) {
      return;
    }

    final now = DateTime.now();
    final minutes =
        _minutesSinceMidnight(now);

    if (existing.departureTime != null &&
        minutes < existing.departureTime!) {
      _showMessage(
        context,
        'Das Zustellungsende kann nicht vor dem Zustellungsbeginn liegen.',
      );
      return;
    }

    if (existing.workStart != null &&
        minutes < existing.workStart!) {
      _showMessage(
        context,
        'Das Zustellungsende kann nicht vor dem Dienstbeginn liegen.',
      );
      return;
    }

    if (existing.workEnd != null &&
        minutes > existing.workEnd!) {
      _showMessage(
        context,
        'Das Zustellungsende kann nicht nach dem Dienstende liegen.',
      );
      return;
    }

    final trimmedNote = note.trim();

    final updated = existing.copyWith(
      deliveryEnd: minutes,
      notes: trimmedNote.isEmpty
          ? existing.notes
          : _mergeNotes(
              existing.notes,
              trimmedNote,
            ),
    );

    await _saveWorkDay(
      context,
      ref,
      updated,
    );
  }

  WorkDay _baseWorkDay(DateTime now) {
    if (workDay != null) {
      return workDay!;
    }

    final date = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final id =
        'workday_${date.year}_'
        '${date.month.toString().padLeft(2, '0')}_'
        '${date.day.toString().padLeft(2, '0')}';

    return WorkDay(
      id: id,
      date: date,
      type: WorkDayType.work,
    );
  }

  Future<void> _saveWorkDay(
    BuildContext context,
    WidgetRef ref,
    WorkDay updated, {
    List<OwnTourEntry>? ownTourEntries,
  }) async {
    try {
      final notifier =
          ref.read(workDayProvider.notifier);

      final existing =
          await notifier.getWorkDayByDate(
        updated.date,
      );

      if (existing == null) {
        await notifier.saveWorkDay(
          workDay: updated,
          ownTourEntries:
              ownTourEntries ??
                  const <OwnTourEntry>[],
        );
      } else {
        await notifier.updateWorkDay(
          workDay: updated,
          ownTourEntries: ownTourEntries,
        );
      }

      if (!context.mounted) {
        return;
      }

      _showMessage(
        context,
        'Gespeichert: ${_statusMessage(updated)}',
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      _showMessage(
        context,
        'Die Schnellerfassung konnte nicht gespeichert werden.',
      );
    }
  }

  static String _statusMessage(
    WorkDay workDay,
  ) {
    if (workDay.workEnd != null) {
      return 'Dienstende ${_formatTime(workDay.workEnd)}';
    }

    if (workDay.deliveryEnd != null) {
      return 'Zustellungsende ${_formatTime(workDay.deliveryEnd)}';
    }

    if (workDay.departureTime != null) {
      return 'Zustellungsbeginn ${_formatTime(workDay.departureTime)}';
    }

    if (workDay.workStart != null) {
      return 'Dienstbeginn ${_formatTime(workDay.workStart)}';
    }

    return 'Arbeitstag';
  }

  static Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('Speichern'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  static void _showMessage(
    BuildContext context,
    String message,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  static int _minutesSinceMidnight(
    DateTime dateTime,
  ) {
    return (dateTime.hour * 60) +
        dateTime.minute;
  }

  static String _formatTime(
    int? minutes,
  ) {
    if (minutes == null) {
      return 'Noch nicht erfasst';
    }

    final hours = minutes ~/ 60;
    final remainingMinutes =
        minutes % 60;

    return '${hours.toString().padLeft(2, '0')}:'
        '${remainingMinutes.toString().padLeft(2, '0')}';
  }

  static String _mergeNotes(
    String? existing,
    String newNote,
  ) {
    final current = existing?.trim();

    if (current == null || current.isEmpty) {
      return newNote;
    }

    return '$current\n$newNote';
  }
}

enum _QuickTimeAction {
  workStart,
  workEnd,
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.isDone,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final bool isDone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Material(
      color: isDone
          ? colorScheme.primaryContainer
              .withValues(alpha: 0.45)
          : colorScheme.surfaceContainerHighest
              .withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          child: Row(
            children: [
              Icon(
                isDone
                    ? Icons.check_circle
                    : icon,
                color: isDone
                    ? colorScheme.primary
                    : colorScheme
                        .onSurfaceVariant,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                            fontWeight:
                                FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                            color: colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeliveryStartSheet
    extends StatefulWidget {
  const _DeliveryStartSheet({
    required this.initialDistrict,
    required this.initialPackages,
    required this.initialAdvertising,
  });

  final String? initialDistrict;
  final int initialPackages;
  final bool initialAdvertising;

  @override
  State<_DeliveryStartSheet> createState() =>
      _DeliveryStartSheetState();
}

class _DeliveryStartSheetState
    extends State<_DeliveryStartSheet> {
  late final TextEditingController
      _districtController;

  late final TextEditingController
      _packageController;

  late bool _hasAdvertising;

  @override
  void initState() {
    super.initState();

    _districtController =
        TextEditingController(
      text: widget.initialDistrict ?? '',
    );

    _packageController =
        TextEditingController(
      text: widget.initialPackages > 0
          ? widget.initialPackages.toString()
          : '',
    );

    _hasAdvertising =
        widget.initialAdvertising;
  }

  @override
  void dispose() {
    _districtController.dispose();
    _packageController.dispose();
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
              'Zustellung starten',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Bezirk und Paketmenge eintragen. Die Uhrzeit wird erst beim endgültigen Speichern übernommen.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _districtController,
              keyboardType:
                  TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Bezirk',
                hintText: 'z. B. 19',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _packageController,
              keyboardType:
                  TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Pakete',
                hintText: 'z. B. 126',
              ),
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Werbung'),
              subtitle: Text(
                _hasAdvertising
                    ? 'Werbung dabei'
                    : 'Keine Werbung',
              ),
              value: _hasAdvertising,
              onChanged: (value) {
                setState(() {
                  _hasAdvertising = value;
                });
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _continue,
                icon: const Icon(
                  Icons.arrow_forward,
                ),
                label: const Text(
                  'Weiter zur Bestätigung',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _continue() {
    final district =
        _districtController.text.trim();

    final packages = int.tryParse(
      _packageController.text.trim(),
    );

    if (district.isEmpty) {
      _showError(
        'Bitte einen Bezirk eintragen.',
      );
      return;
    }

    if (packages == null || packages < 0) {
      _showError(
        'Bitte eine gültige Paketanzahl eintragen.',
      );
      return;
    }

    Navigator.of(context).pop(
      _DeliveryStartResult(
        district: district,
        packages: packages,
        hasAdvertising: _hasAdvertising,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }
}

class _DeliveryStartResult {
  const _DeliveryStartResult({
    required this.district,
    required this.packages,
    required this.hasAdvertising,
  });

  final String district;
  final int packages;
  final bool hasAdvertising;
}

class _DeliveryEndSheet
    extends StatefulWidget {
  const _DeliveryEndSheet();

  @override
  State<_DeliveryEndSheet> createState() =>
      _DeliveryEndSheetState();
}

class _DeliveryEndSheetState
    extends State<_DeliveryEndSheet> {
  final TextEditingController
      _notesController =
      TextEditingController();

  @override
  void dispose() {
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
              'Zustellung beenden',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Optional kannst du eine kurze Notiz hinzufügen.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _notesController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Notiz',
                hintText:
                    'Optional, z. B. Besonderheiten oder Abbruch',
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pop(
                    _notesController.text,
                  );
                },
                icon: const Icon(
                  Icons.arrow_forward,
                ),
                label: const Text(
                  'Weiter zur Bestätigung',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}