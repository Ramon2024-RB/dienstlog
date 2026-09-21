import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/advertising.dart';
import '../../models/district.dart';
import '../../models/zsp_location.dart';
import '../../models/own_tour_entry.dart';
import '../../models/support_entry.dart';
import '../../models/work_day.dart';
import '../../services/advertising_provider.dart';
import '../../services/district_provider.dart';
import '../../services/zsp_provider.dart';
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
    final nextAction = _nextAction(currentWorkDay);
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  nextAction.icon,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    nextAction.heading,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: nextAction.enabled
                    ? () => _runNextAction(
                          context,
                          ref,
                          nextAction.action,
                        )
                    : null,
                icon: Icon(nextAction.buttonIcon),
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(nextAction.buttonLabel),
                ),
              ),
            ),
            if (currentWorkDay != null &&
                currentWorkDay.workEnd == null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _addSupport(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text('Unterstützung hinzufügen'),
                ),
              ),
            ],
            if (currentWorkDay?.workEnd != null) ...[
              const SizedBox(height: 8),
              Text(
                'Der Arbeitstag ist vollständig erfasst.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  _NextQuickAction _nextAction(WorkDay? current) {
    if (current == null || current.workStart == null) {
      return const _NextQuickAction(
        heading: 'Bereit für den Arbeitstag',
        buttonLabel: 'Dienst beginnen',
        icon: Icons.play_circle_outline,
        buttonIcon: Icons.login,
        action: QuickEntryExternalAction.workStart,
      );
    }

    if (current.departureTime == null) {
      return const _NextQuickAction(
        heading: 'Nächster Schritt',
        buttonLabel: 'Zustellung beginnen',
        icon: Icons.route_outlined,
        buttonIcon: Icons.local_shipping_outlined,
        action: QuickEntryExternalAction.deliveryStart,
      );
    }

    if (current.deliveryEnd == null) {
      return const _NextQuickAction(
        heading: 'Zustellung läuft',
        buttonLabel: 'Zustellung beenden',
        icon: Icons.local_shipping_outlined,
        buttonIcon: Icons.inventory_2_outlined,
        action: QuickEntryExternalAction.deliveryEnd,
      );
    }

    if (current.workEnd == null) {
      return const _NextQuickAction(
        heading: 'Zustellung abgeschlossen',
        buttonLabel: 'Dienst beenden',
        icon: Icons.schedule_outlined,
        buttonIcon: Icons.logout,
        action: QuickEntryExternalAction.workEnd,
      );
    }

    return const _NextQuickAction(
      heading: 'Arbeitstag abgeschlossen',
      buttonLabel: 'Arbeitstag vollständig erfasst',
      icon: Icons.check_circle_outline,
      buttonIcon: Icons.check,
      action: QuickEntryExternalAction.workEnd,
      enabled: false,
    );
  }

  Future<void> _runNextAction(
    BuildContext context,
    WidgetRef ref,
    QuickEntryExternalAction action,
  ) async {
    switch (action) {
      case QuickEntryExternalAction.workStart:
        await _saveSimpleTime(
          context: context,
          ref: ref,
          action: _QuickTimeAction.workStart,
        );
        break;
      case QuickEntryExternalAction.deliveryStart:
        await _startDelivery(context, ref);
        break;
      case QuickEntryExternalAction.deliveryEnd:
        await _endDelivery(context, ref);
        break;
      case QuickEntryExternalAction.workEnd:
        await _saveSimpleTime(
          context: context,
          ref: ref,
          action: _QuickTimeAction.workEnd,
        );
        break;
    }
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

    final advertisings =
        ref.read(advertisingProvider).value ?? const <Advertising>[];
    final zspLocations =
        ref.read(zspProvider).value ?? const <ZspLocation>[];
    final districts =
        ref.read(districtProvider).value ?? const <District>[];

    final activeZspLocations =
        zspLocations.where((item) => item.isActive).toList();

    ZspLocation? selectedZsp;
    final existingZspId = existing?.zspId;

    if (existingZspId != null) {
      for (final location in zspLocations) {
        if (location.id == existingZspId && location.isActive) {
          selectedZsp = location;
          break;
        }
      }
    }

    if (selectedZsp == null) {
      for (final location in activeZspLocations) {
        if (location.isDefault) {
          selectedZsp = location;
          break;
        }
      }
    }

    if (selectedZsp == null && activeZspLocations.isNotEmpty) {
      selectedZsp = activeZspLocations.first;
    }

    if (selectedZsp == null) {
      _showMessage(
        context,
        'Bitte zuerst unter „ZSP & Bezirke“ einen aktiven ZSP anlegen.',
      );
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
          initialZspId: selectedZsp!.id,
          zspLocations: activeZspLocations,
          districts: districts,
          initialDistrict: initialDistrict,
          initialPackages: initialPackages,
          initialPostPart:
              existing?.districtPart == DistrictPart.partA ||
                      existing?.districtPart == DistrictPart.partB
                  ? existing!.districtPart
                  : null,
          initialAdvertising:
              existing?.hasAdvertising ?? false,
          initialAdvertisingName:
              existing?.advertising,
          advertisingNames:
              advertisings.map((item) => item.name).toList(),
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

    final postText = result.postPart == DistrictPart.partA
        ? 'Post A-Teil'
        : 'Post B-Teil';

    String zspName = result.zspId;
    for (final location in zspLocations) {
      if (location.id == result.zspId) {
        zspName = location.displayName;
        break;
      }
    }

    final advertisingText =
        result.hasAdvertising
            ? (result.advertising?.trim().isNotEmpty == true
                ? 'Werbung: ${result.advertising!.trim()}'
                : 'Werbung dabei')
            : 'Keine Werbung';

    final confirmed = await _confirm(
      context,
      title: 'Zustellungsbeginn',
      message: existingTime == null
          ? '$zspName · Bezirk ${result.district} · '
              '${result.packages} Pakete · '
              '$postText · '
              '$advertisingText\n'
              '${_formatTime(previewMinutes)} Uhr'
          : '$zspName · Bezirk ${result.district} · '
              '${result.packages} Pakete · '
              '$postText · '
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
      zspId: result.zspId,
      districtId: result.district,
      districtPart: result.postPart,
      departureTime: minutes,
      packageCount: result.packages,
      cancelledPackageCount: 0,
      hasAdvertising: result.hasAdvertising,
      advertising: result.hasAdvertising
          ? result.advertising
          : null,
      clearAdvertising:
          !result.hasAdvertising,
    );

    final ownTour = OwnTourEntry(
      workDayId: updated.id,
      district: result.district,
      zspId: result.zspId,
      districtPart: result.postPart,
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

  Future<void> _addSupport(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final existing = workDay;

    if (existing == null) {
      _showMessage(
        context,
        'Bitte zuerst einen Arbeitstag bzw. Dienstbeginn erfassen.',
      );
      return;
    }

    final zspLocations =
        ref.read(zspProvider).value ?? const <ZspLocation>[];
    final districts =
        ref.read(districtProvider).value ?? const <District>[];

    final activeZspLocations =
        zspLocations.where((item) => item.isActive).toList();

    ZspLocation? selectedZsp;

    for (final location in activeZspLocations) {
      if (location.id == existing.zspId) {
        selectedZsp = location;
        break;
      }
    }

    if (selectedZsp == null) {
      for (final location in activeZspLocations) {
        if (location.isDefault) {
          selectedZsp = location;
          break;
        }
      }
    }

    if (selectedZsp == null && activeZspLocations.isNotEmpty) {
      selectedZsp = activeZspLocations.first;
    }

    if (selectedZsp == null) {
      _showMessage(
        context,
        'Bitte zuerst unter „ZSP & Bezirke“ einen aktiven ZSP anlegen.',
      );
      return;
    }

    final result =
        await showModalBottomSheet<_SupportResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return _SupportSheet(
          initialZspId: selectedZsp!.id,
          zspLocations: activeZspLocations,
          districts: districts,
        );
      },
    );

    if (result == null || !context.mounted) {
      return;
    }

    String zspName = result.zspId;
    for (final location in zspLocations) {
      if (location.id == result.zspId) {
        zspName = location.displayName;
        break;
      }
    }

    final noteText =
        result.note == null || result.note!.isEmpty
            ? ''
            : '\nNotiz: ${result.note}';

    final confirmed = await _confirm(
      context,
      title: 'Unterstützung hinzufügen',
      message:
          '$zspName · Bezirk ${result.district}\n'
          '${result.packagesTaken} Pakete übernommen'
          '$noteText',
    );

    if (!confirmed || !context.mounted) {
      return;
    }

    try {
      final notifier =
          ref.read(workDayProvider.notifier);

      final currentSupportEntries =
          await notifier.getSupportEntries(existing.id);

      final supportEntry = SupportEntry(
        workDayId: existing.id,
        zspId: result.zspId,
        district: result.district,
        packagesTaken: result.packagesTaken,
        note: result.note,
      );

      await notifier.updateWorkDay(
        workDay: existing,
        supportEntries: [
          ...currentSupportEntries,
          supportEntry,
        ],
      );

      if (!context.mounted) {
        return;
      }

      _showMessage(
        context,
        'Unterstützung gespeichert: Bezirk ${result.district} · '
        '${result.packagesTaken} Pakete',
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      _showMessage(
        context,
        'Die Unterstützung konnte nicht gespeichert werden.',
      );
    }
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

class _NextQuickAction {
  const _NextQuickAction({
    required this.heading,
    required this.buttonLabel,
    required this.icon,
    required this.buttonIcon,
    required this.action,
    this.enabled = true,
  });

  final String heading;
  final String buttonLabel;
  final IconData icon;
  final IconData buttonIcon;
  final QuickEntryExternalAction action;
  final bool enabled;
}

enum _QuickTimeAction {
  workStart,
  workEnd,
}

class _DeliveryStartSheet extends StatefulWidget {
  const _DeliveryStartSheet({
    required this.initialZspId,
    required this.zspLocations,
    required this.districts,
    required this.initialDistrict,
    required this.initialPackages,
    required this.initialPostPart,
    required this.initialAdvertising,
    required this.initialAdvertisingName,
    required this.advertisingNames,
  });

  final String initialZspId;
  final List<ZspLocation> zspLocations;
  final List<District> districts;
  final String? initialDistrict;
  final int initialPackages;
  final DistrictPart? initialPostPart;
  final bool initialAdvertising;
  final String? initialAdvertisingName;
  final List<String> advertisingNames;

  @override
  State<_DeliveryStartSheet> createState() =>
      _DeliveryStartSheetState();
}

class _DeliveryStartSheetState extends State<_DeliveryStartSheet> {
  static const _otherAdvertisingValue = '__other__';

  late String _selectedZspId;
  String? _selectedDistrict;
  late final TextEditingController _packageController;
  late final TextEditingController _customAdvertisingController;
  DistrictPart? _postPart;
  late bool _hasAdvertising;
  String? _selectedAdvertising;

  List<District> get _availableDistricts {
    final result = widget.districts
        .where(
          (item) =>
              item.zspId == _selectedZspId &&
              item.isActive,
        )
        .toList();

    result.sort(
      (a, b) => a.number.compareTo(b.number),
    );

    return result;
  }

  @override
  void initState() {
    super.initState();

    _selectedZspId = widget.initialZspId;

    final initialDistrict = widget.initialDistrict?.trim();
    if (initialDistrict != null &&
        initialDistrict.isNotEmpty &&
        widget.districts.any(
          (item) =>
              item.zspId == _selectedZspId &&
              item.number.toString() == initialDistrict &&
              item.isActive,
        )) {
      _selectedDistrict = initialDistrict;
    }

    _packageController = TextEditingController(
      text: widget.initialPackages > 0
          ? widget.initialPackages.toString()
          : '',
    );
    _customAdvertisingController = TextEditingController();
    _postPart = widget.initialPostPart;
    _hasAdvertising = widget.initialAdvertising;

    final name = widget.initialAdvertisingName?.trim();
    if (_hasAdvertising && name != null && name.isNotEmpty) {
      if (widget.advertisingNames.contains(name)) {
        _selectedAdvertising = name;
      } else {
        _selectedAdvertising = _otherAdvertisingValue;
        _customAdvertisingController.text = name;
      }
    }
  }

  @override
  void dispose() {
    _packageController.dispose();
    _customAdvertisingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final availableDistricts = _availableDistricts;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Zustellung starten',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Standort, Bezirk, Paketmenge, Post und Werbung eintragen. Die Uhrzeit wird erst beim endgültigen Speichern übernommen.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              initialValue: _selectedZspId,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'ZSP',
              ),
              items: widget.zspLocations
                  .map(
                    (location) => DropdownMenuItem<String>(
                      value: location.id,
                      child: Text(
                        location.isDefault
                            ? '${location.displayName} (Standard)'
                            : location.displayName,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  _selectedZspId = value;
                  _selectedDistrict = null;
                });
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: ValueKey(
                'quick-district-$_selectedZspId-$_selectedDistrict',
              ),
              initialValue: _selectedDistrict,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: 'Bezirk',
                helperText: availableDistricts.isEmpty
                    ? 'Für diesen ZSP sind keine aktiven Bezirke hinterlegt.'
                    : 'Nur aktive Bezirke dieses ZSP werden angezeigt.',
              ),
              items: availableDistricts
                  .map(
                    (district) => DropdownMenuItem<String>(
                      value: district.number.toString(),
                      child: Text('Bezirk ${district.number}'),
                    ),
                  )
                  .toList(),
              onChanged: availableDistricts.isEmpty
                  ? null
                  : (value) {
                      setState(() {
                        _selectedDistrict = value;
                      });
                    },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _packageController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Pakete',
                hintText: 'z. B. 126',
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<DistrictPart>(
              initialValue: _postPart,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Post',
                helperText: 'A- oder B-Teil für den gesamten Arbeitstag.',
              ),
              items: const [
                DropdownMenuItem(
                  value: DistrictPart.partA,
                  child: Text('A-Teil'),
                ),
                DropdownMenuItem(
                  value: DistrictPart.partB,
                  child: Text('B-Teil'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _postPart = value;
                });
              },
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Werbung mitgenommen'),
              subtitle: Text(
                _hasAdvertising
                    ? 'Werbung dabei'
                    : 'Keine Werbung',
              ),
              value: _hasAdvertising,
              onChanged: (value) {
                setState(() {
                  _hasAdvertising = value;

                  if (!value) {
                    _selectedAdvertising = null;
                    _customAdvertisingController.clear();
                  }
                });
              },
            ),
            if (_hasAdvertising) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                key: ValueKey(
                  'quick-advertising-$_selectedAdvertising-'
                  '${widget.advertisingNames.length}',
                ),
                initialValue: _selectedAdvertising,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Welche Werbung?',
                ),
                items: [
                  ...widget.advertisingNames.map(
                    (name) => DropdownMenuItem<String>(
                      value: name,
                      child: Text(name),
                    ),
                  ),
                  const DropdownMenuItem<String>(
                    value: _otherAdvertisingValue,
                    child: Text('+ Andere Werbung eingeben'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedAdvertising = value;

                    if (value != _otherAdvertisingValue) {
                      _customAdvertisingController.clear();
                    }
                  });
                },
              ),
              if (_selectedAdvertising == _otherAdvertisingValue) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _customAdvertisingController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Andere Werbung',
                    hintText: 'Name der Werbung',
                  ),
                ),
              ],
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _continue,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Weiter zur Bestätigung'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _continue() {
    final district = _selectedDistrict;
    final packages = int.tryParse(
      _packageController.text.trim(),
    );

    if (district == null || district.isEmpty) {
      _showError('Bitte einen Bezirk auswählen.');
      return;
    }

    if (packages == null || packages < 0) {
      _showError('Bitte eine gültige Paketanzahl eintragen.');
      return;
    }

    if (_postPart != DistrictPart.partA &&
        _postPart != DistrictPart.partB) {
      _showError('Bitte Post A-Teil oder B-Teil auswählen.');
      return;
    }

    String? advertising;

    if (_hasAdvertising) {
      if (_selectedAdvertising == null) {
        _showError(
          'Bitte wähle aus, welche Werbung du dabei hast.',
        );
        return;
      }

      if (_selectedAdvertising == _otherAdvertisingValue) {
        advertising = _customAdvertisingController.text.trim();

        if (advertising.isEmpty) {
          _showError('Bitte gib den Namen der Werbung ein.');
          return;
        }
      } else {
        advertising = _selectedAdvertising;
      }
    }

    Navigator.of(context).pop(
      _DeliveryStartResult(
        zspId: _selectedZspId,
        district: district,
        packages: packages,
        postPart: _postPart!,
        hasAdvertising: _hasAdvertising,
        advertising: advertising,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _DeliveryStartResult {
  const _DeliveryStartResult({
    required this.zspId,
    required this.district,
    required this.packages,
    required this.postPart,
    required this.hasAdvertising,
    required this.advertising,
  });

  final String zspId;
  final String district;
  final int packages;
  final DistrictPart postPart;
  final bool hasAdvertising;
  final String? advertising;
}

class _SupportSheet extends StatefulWidget {
  const _SupportSheet({
    required this.initialZspId,
    required this.zspLocations,
    required this.districts,
  });

  final String initialZspId;
  final List<ZspLocation> zspLocations;
  final List<District> districts;

  @override
  State<_SupportSheet> createState() => _SupportSheetState();
}

class _SupportSheetState extends State<_SupportSheet> {
  late String _selectedZspId;
  String? _selectedDistrict;
  late final TextEditingController _packageController;
  late final TextEditingController _noteController;

  List<District> get _availableDistricts {
    final result = widget.districts
        .where(
          (item) =>
              item.zspId == _selectedZspId &&
              item.isActive,
        )
        .toList();

    result.sort(
      (a, b) => a.number.compareTo(b.number),
    );

    return result;
  }

  @override
  void initState() {
    super.initState();
    _selectedZspId = widget.initialZspId;
    _packageController = TextEditingController();
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _packageController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset =
        MediaQuery.viewInsetsOf(context).bottom;
    final availableDistricts = _availableDistricts;

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
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Unterstützung erfassen',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Wähle den unterstützten Bezirk und trage die übernommenen Pakete ein.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              initialValue: _selectedZspId,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'ZSP',
              ),
              items: widget.zspLocations
                  .map(
                    (location) => DropdownMenuItem<String>(
                      value: location.id,
                      child: Text(
                        location.isDefault
                            ? '${location.displayName} (Standard)'
                            : location.displayName,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  _selectedZspId = value;
                  _selectedDistrict = null;
                });
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: ValueKey(
                'support-district-$_selectedZspId-$_selectedDistrict',
              ),
              initialValue: _selectedDistrict,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: 'Bezirk',
                helperText: availableDistricts.isEmpty
                    ? 'Für diesen ZSP sind keine aktiven Bezirke hinterlegt.'
                    : 'Nur aktive Bezirke dieses ZSP werden angezeigt.',
              ),
              items: availableDistricts
                  .map(
                    (district) => DropdownMenuItem<String>(
                      value: district.number.toString(),
                      child: Text('Bezirk ${district.number}'),
                    ),
                  )
                  .toList(),
              onChanged: availableDistricts.isEmpty
                  ? null
                  : (value) {
                      setState(() {
                        _selectedDistrict = value;
                      });
                    },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _packageController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Übernommene Pakete',
                hintText: 'z. B. 13',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _noteController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Notiz',
                hintText: 'Optional',
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _continue,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Weiter zur Bestätigung'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _continue() {
    final district = _selectedDistrict;
    final packagesTaken = int.tryParse(
      _packageController.text.trim(),
    );

    if (district == null || district.isEmpty) {
      _showError('Bitte einen Bezirk auswählen.');
      return;
    }

    if (packagesTaken == null || packagesTaken < 0) {
      _showError(
        'Bitte eine gültige Paketanzahl eintragen.',
      );
      return;
    }

    final note = _noteController.text.trim();

    Navigator.of(context).pop(
      _SupportResult(
        zspId: _selectedZspId,
        district: district,
        packagesTaken: packagesTaken,
        note: note.isEmpty ? null : note,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _SupportResult {
  const _SupportResult({
    required this.zspId,
    required this.district,
    required this.packagesTaken,
    required this.note,
  });

  final String zspId;
  final String district;
  final int packagesTaken;
  final String? note;
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