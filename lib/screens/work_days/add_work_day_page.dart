import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../models/district.dart';
import '../../models/support_entry.dart';
import '../../models/work_day.dart';
import '../../services/district_provider.dart';
import '../../services/work_day_provider.dart';

class AddWorkDayPage extends ConsumerStatefulWidget {
  const AddWorkDayPage({
    super.key,
    this.initialDate,
    this.existingWorkDay,
    this.initialSupportEntries = const [],
  });

  final DateTime? initialDate;
  final WorkDay? existingWorkDay;
  final List<SupportEntry> initialSupportEntries;

  @override
  ConsumerState<AddWorkDayPage> createState() => _AddWorkDayPageState();
}

class _AddWorkDayPageState extends ConsumerState<AddWorkDayPage> {
  late DateTime _date;

  WorkDayType _type = WorkDayType.work;
  WorkAssignmentType _assignmentType = WorkAssignmentType.ownDistrict;
  DistrictPart _districtPart = DistrictPart.full;

  int? _districtNumber;

  TimeOfDay? _workStart;
  TimeOfDay? _departureTime;
  TimeOfDay? _deliveryEnd;
  TimeOfDay? _workEnd;

  int _breakMinutes = 0;

  final TextEditingController _packageCountController =
      TextEditingController();

  final TextEditingController _cancelledPackageCountController =
      TextEditingController();

  final TextEditingController _advertisingController =
      TextEditingController();

  final TextEditingController _notesController =
      TextEditingController();

  final List<_SupportDraft> _supportDrafts = [];

  bool _hasAdvertising = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    final existingWorkDay = widget.existingWorkDay;

    if (existingWorkDay != null) {
      _date = DateTime(
        existingWorkDay.date.year,
        existingWorkDay.date.month,
        existingWorkDay.date.day,
      );

      _type = existingWorkDay.type;
      _assignmentType = existingWorkDay.assignmentType;
      _districtPart = existingWorkDay.districtPart;
      _districtNumber = int.tryParse(existingWorkDay.districtId ?? '');

      _workStart = _minutesToTime(existingWorkDay.workStart);
      _departureTime = _minutesToTime(existingWorkDay.departureTime);
      _deliveryEnd = _minutesToTime(existingWorkDay.deliveryEnd);
      _workEnd = _minutesToTime(existingWorkDay.workEnd);

      _breakMinutes = existingWorkDay.breakMinutes;

      _packageCountController.text =
          '${existingWorkDay.packageCount}';

      _cancelledPackageCountController.text =
          '${existingWorkDay.cancelledPackageCount}';

      _hasAdvertising = existingWorkDay.hasAdvertising;

      _advertisingController.text =
          existingWorkDay.advertising ?? '';

      _notesController.text =
          existingWorkDay.notes ?? '';

      for (final entry in widget.initialSupportEntries) {
        _supportDrafts.add(
          _SupportDraft.fromEntry(entry),
        );
      }
    } else {
      final initialDate =
          widget.initialDate ?? DateTime.now();

      _date = DateTime(
        initialDate.year,
        initialDate.month,
        initialDate.day,
      );
    }
  }

  @override
  void dispose() {
    _packageCountController.dispose();
    _cancelledPackageCountController.dispose();
    _advertisingController.dispose();
    _notesController.dispose();

    for (final draft in _supportDrafts) {
      draft.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final districtsAsync =
        ref.watch(districtProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existingWorkDay == null
              ? 'Arbeitstag eintragen'
              : 'Arbeitstag bearbeiten',
          style: const TextStyle(
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
                    'Die Bezirke konnten nicht geladen werden.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () {
                      ref.invalidate(districtProvider);
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
        data: (districts) {
          final activeDistricts =
              districts
                  .where(
                    (district) =>
                        district.isActive,
                  )
                  .toList();

          return _buildForm(
            context,
            activeDistricts,
          );
        },
      ),
    );
  }

  Widget _buildForm(
    BuildContext context,
    List<District> districts,
  ) {
    final isWorkDay =
        _type == WorkDayType.work;

    final hasOwnDistrict =
        _assignmentType ==
            WorkAssignmentType.ownDistrict;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        16,
        16,
        16,
        40,
      ),
      children: [
        _SectionCard(
          title: 'Tag',
          icon:
              Icons.calendar_today_outlined,
          child: Column(
            children: [
              ListTile(
                contentPadding:
                    EdgeInsets.zero,
                title:
                    const Text('Datum'),
                subtitle:
                    Text(_formatDate(_date)),
                trailing:
                    const Icon(
                  Icons.chevron_right,
                ),
                onTap: _selectDate,
              ),
              const Divider(),
              DropdownButtonFormField<
                  WorkDayType>(
                initialValue: _type,
                decoration:
                    const InputDecoration(
                  labelText: 'Tagesart',
                  border:
                      OutlineInputBorder(),
                ),
                items: WorkDayType.values
                    .map(
                      (type) =>
                          DropdownMenuItem(
                        value: type,
                        child: Text(
                          _workDayTypeLabel(
                            type,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    _type = value;
                  });
                },
              ),
            ],
          ),
        ),
        if (isWorkDay) ...[
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Einsatz',
            icon: Icons.badge_outlined,
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                SegmentedButton<
                    WorkAssignmentType>(
                  segments: const [
                    ButtonSegment(
                      value:
                          WorkAssignmentType
                              .ownDistrict,
                      label: Text(
                        'Eigener Bezirk',
                      ),
                      icon: Icon(
                        Icons.route_outlined,
                      ),
                    ),
                    ButtonSegment(
                      value:
                          WorkAssignmentType
                              .packageDriver,
                      label: Text(
                        'Paketfahrer',
                      ),
                      icon: Icon(
                        Icons
                            .local_shipping_outlined,
                      ),
                    ),
                  ],
                  selected: {
                    _assignmentType,
                  },
                  onSelectionChanged:
                      (selection) {
                    setState(() {
                      _assignmentType =
                          selection.first;

                      if (_assignmentType ==
                          WorkAssignmentType
                              .packageDriver) {
                        _districtNumber =
                            null;
                      }
                    });
                  },
                ),
                if (hasOwnDistrict) ...[
                  const SizedBox(
                    height: 20,
                  ),
                  DropdownButtonFormField<
                      int>(
                    initialValue:
                        _districtNumber,
                    decoration:
                        const InputDecoration(
                      labelText: 'Bezirk',
                      border:
                          OutlineInputBorder(),
                    ),
                    hint: const Text(
                      'Bezirk auswählen',
                    ),
                    items: districts
                        .map(
                          (district) =>
                              DropdownMenuItem<
                                  int>(
                            value:
                                district.number,
                            child: Text(
                              'Bezirk ${district.number}',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _districtNumber =
                            value;
                      });
                    },
                  ),
                  const SizedBox(
                    height: 16,
                  ),
                  DropdownButtonFormField<
                      DistrictPart>(
                    initialValue:
                        _districtPart,
                    decoration:
                        const InputDecoration(
                      labelText:
                          'Bezirksteil',
                      border:
                          OutlineInputBorder(),
                    ),
                    items:
                        DistrictPart.values
                            .map(
                              (part) =>
                                  DropdownMenuItem(
                                value: part,
                                child: Text(
                                  _districtPartLabel(
                                    part,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }

                      setState(() {
                        _districtPart =
                            value;
                      });
                    },
                  ),
                ] else ...[
                  const SizedBox(
                    height: 16,
                  ),
                  Text(
                    'Du bist an diesem Tag zusätzliche Unterstützung '
                    'und übernimmst Pakete von regulär besetzten Bezirken.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(
                          color:
                              Theme.of(
                                context,
                              )
                                  .colorScheme
                                  .onSurfaceVariant,
                        ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Zeiten',
            icon:
                Icons.schedule_outlined,
            child: Column(
              children: [
                _TimeRow(
                  label:
                      'Arbeitsbeginn',
                  value: _workStart,
                  onTap: () async {
                    final time =
                        await _pickTime(
                      _workStart,
                    );

                    if (time != null) {
                      setState(() {
                        _workStart =
                            time;
                      });
                    }
                  },
                ),
                const Divider(),
                _TimeRow(
                  label: 'Abfahrt',
                  value:
                      _departureTime,
                  onTap: () async {
                    final time =
                        await _pickTime(
                      _departureTime,
                    );

                    if (time != null) {
                      setState(() {
                        _departureTime =
                            time;
                      });
                    }
                  },
                ),
                const Divider(),
                _TimeRow(
                  label:
                      'Zustellende',
                  value: _deliveryEnd,
                  onTap: () async {
                    final time =
                        await _pickTime(
                      _deliveryEnd,
                    );

                    if (time != null) {
                      setState(() {
                        _deliveryEnd =
                            time;
                      });
                    }
                  },
                ),
                const Divider(),
                _TimeRow(
                  label:
                      'Arbeitsende',
                  value: _workEnd,
                  onTap: () async {
                    final time =
                        await _pickTime(
                      _workEnd,
                    );

                    if (time != null) {
                      setState(() {
                        _workEnd = time;
                      });
                    }
                  },
                ),
                const SizedBox(
                  height: 12,
                ),
                DropdownButtonFormField<
                    int>(
                  initialValue:
                      _breakMinutes,
                  decoration:
                      const InputDecoration(
                    labelText: 'Pause',
                    border:
                        OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 0,
                      child: Text(
                        'Keine Pause',
                      ),
                    ),
                    DropdownMenuItem(
                      value: 15,
                      child: Text(
                        '15 Minuten',
                      ),
                    ),
                    DropdownMenuItem(
                      value: 30,
                      child: Text(
                        '30 Minuten',
                      ),
                    ),
                    DropdownMenuItem(
                      value: 45,
                      child: Text(
                        '45 Minuten',
                      ),
                    ),
                    DropdownMenuItem(
                      value: 60,
                      child: Text(
                        '60 Minuten',
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }

                    setState(() {
                      _breakMinutes =
                          value;
                    });
                  },
                ),
              ],
            ),
          ),
          if (hasOwnDistrict) ...[
            const SizedBox(
              height: 16,
            ),
            _SectionCard(
              title: 'Eigene Tour',
              icon: Icons
                  .inventory_2_outlined,
              child: Column(
                children: [
                  TextField(
                    controller:
                        _packageCountController,
                    keyboardType:
                        TextInputType
                            .number,
                    decoration:
                        const InputDecoration(
                      labelText:
                          'Pakete',
                      hintText:
                          'z. B. 85',
                      border:
                          OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(
                    height: 16,
                  ),
                  TextField(
                    controller:
                        _cancelledPackageCountController,
                    keyboardType:
                        TextInputType
                            .number,
                    decoration:
                        const InputDecoration(
                      labelText:
                          'Abgebrochene Pakete',
                      hintText:
                          'z. B. 2',
                      border:
                          OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          _buildSupportSection(
            context,
            districts,
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Werbung',
            icon:
                Icons.campaign_outlined,
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding:
                      EdgeInsets.zero,
                  title: const Text(
                    'Werbung mitgenommen',
                  ),
                  value:
                      _hasAdvertising,
                  onChanged: (value) {
                    setState(() {
                      _hasAdvertising =
                          value;

                      if (!value) {
                        _advertisingController
                            .clear();
                      }
                    });
                  },
                ),
                if (_hasAdvertising) ...[
                  const SizedBox(
                    height: 8,
                  ),
                  TextField(
                    controller:
                        _advertisingController,
                    decoration:
                        const InputDecoration(
                      labelText:
                          'Welche Werbung?',
                      hintText:
                          'z. B. Einkauf Aktuell',
                      border:
                          OutlineInputBorder(),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Bemerkungen',
            icon:
                Icons.notes_outlined,
            child: TextField(
              controller:
                  _notesController,
              minLines: 3,
              maxLines: 6,
              decoration:
                  const InputDecoration(
                hintText:
                    'Optionale Bemerkungen zum Arbeitstag',
                border:
                    OutlineInputBorder(),
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _isSaving
              ? null
              : () {
                  _save(districts);
                },
          icon: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child:
                      CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : const Icon(
                  Icons.save_outlined,
                ),
          label: Text(
            _isSaving
                ? 'Wird gespeichert...'
                : widget.existingWorkDay ==
                        null
                    ? 'Arbeitstag speichern'
                    : 'Änderungen speichern',
          ),
        ),
      ],
    );
  }

  Widget _buildSupportSection(
    BuildContext context,
    List<District> districts,
  ) {
    return _SectionCard(
      title: 'Unterstützungen',
      icon: Icons.group_outlined,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            _assignmentType ==
                    WorkAssignmentType
                        .packageDriver
                ? 'Trage hier die Bezirke ein, von denen du Pakete '
                    'übernommen hast.'
                : 'Wenn du nach deiner eigenen Tour noch Kollegen '
                    'unterstützt hast, kannst du diese hier eintragen.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant,
                ),
          ),
          if (_supportDrafts
              .isNotEmpty) ...[
            const SizedBox(
              height: 16,
            ),
            for (var index = 0;
                index <
                    _supportDrafts.length;
                index++) ...[
              _SupportEditor(
                key: ValueKey(
                  _supportDrafts[index]
                      .key,
                ),
                draft:
                    _supportDrafts[index],
                districts: districts,
                onDelete: () {
                  setState(() {
                    final draft =
                        _supportDrafts
                            .removeAt(
                      index,
                    );

                    draft.dispose();
                  });
                },
              ),
              if (index !=
                  _supportDrafts
                          .length -
                      1)
                const SizedBox(
                  height: 16,
                ),
            ],
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _supportDrafts.add(
                  _SupportDraft(),
                );
              });
            },
            icon:
                const Icon(Icons.add),
            label: const Text(
              'Unterstützung hinzufügen',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate() async {
    final selectedDate =
        await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (selectedDate == null) {
      return;
    }

    setState(() {
      _date = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
      );
    });
  }

  Future<TimeOfDay?> _pickTime(
    TimeOfDay? currentValue,
  ) {
    return showTimePicker(
      context: context,
      initialTime:
          currentValue ??
              TimeOfDay.now(),
    );
  }

  Future<void> _save(
    List<District> districts,
  ) async {
    if (_type ==
            WorkDayType.work &&
        _assignmentType ==
            WorkAssignmentType
                .ownDistrict &&
        _districtNumber == null) {
      _showMessage(
        'Bitte wähle deinen Bezirk aus.',
      );
      return;
    }

    if (_type ==
        WorkDayType.work) {
      for (final draft
          in _supportDrafts) {
        if (draft.districtNumber ==
            null) {
          _showMessage(
            'Bitte wähle bei jeder Unterstützung einen Bezirk aus.',
          );
          return;
        }

        final packages =
            int.tryParse(
                  draft
                      .packageController
                      .text
                      .trim(),
                ) ??
                0;

        if (packages <= 0) {
          _showMessage(
            'Bitte trage bei jeder Unterstützung die '
            'übernommenen Pakete ein.',
          );
          return;
        }
      }

      if (_assignmentType ==
              WorkAssignmentType
                  .packageDriver &&
          _supportDrafts.isEmpty) {
        _showMessage(
          'Bitte füge mindestens eine Unterstützung hinzu.',
        );
        return;
      }
    }

    final packageCount =
        int.tryParse(
              _packageCountController
                  .text
                  .trim(),
            ) ??
            0;

    final cancelledPackageCount =
        int.tryParse(
              _cancelledPackageCountController
                  .text
                  .trim(),
            ) ??
            0;

    if (cancelledPackageCount >
        packageCount) {
      _showMessage(
        'Abgebrochene Pakete können nicht höher als die '
        'gesamte Paketmenge sein.',
      );
      return;
    }

    final id =
        widget.existingWorkDay?.id ??
            const Uuid().v4();

    final workDay = WorkDay(
      id: id,
      date: _date,
      type: _type,
      assignmentType:
          _assignmentType,
      districtId:
          _type ==
                      WorkDayType.work &&
                  _assignmentType ==
                      WorkAssignmentType
                          .ownDistrict
              ? _districtNumber
                  ?.toString()
              : null,
      districtPart:
          _districtPart,
      workStart:
          _type ==
                  WorkDayType.work
              ? _timeToMinutes(
                  _workStart,
                )
              : null,
      departureTime:
          _type ==
                  WorkDayType.work
              ? _timeToMinutes(
                  _departureTime,
                )
              : null,
      deliveryEnd:
          _type ==
                  WorkDayType.work
              ? _timeToMinutes(
                  _deliveryEnd,
                )
              : null,
      workEnd:
          _type ==
                  WorkDayType.work
              ? _timeToMinutes(
                  _workEnd,
                )
              : null,
      breakMinutes:
          _type ==
                  WorkDayType.work
              ? _breakMinutes
              : 0,
      packageCount:
          _type ==
                      WorkDayType.work &&
                  _assignmentType ==
                      WorkAssignmentType
                          .ownDistrict
              ? packageCount
              : 0,
      cancelledPackageCount:
          _type ==
                      WorkDayType.work &&
                  _assignmentType ==
                      WorkAssignmentType
                          .ownDistrict
              ? cancelledPackageCount
              : 0,
      hasAdvertising:
          _type ==
                  WorkDayType.work &&
              _hasAdvertising,
      advertising:
          _type ==
                      WorkDayType.work &&
                  _hasAdvertising
              ? _nullIfEmpty(
                  _advertisingController
                      .text,
                )
              : null,
      notes: _nullIfEmpty(
        _notesController.text,
      ),
    );

    final supportEntries =
        _type ==
                WorkDayType.work
            ? _supportDrafts
                .map(
                  (draft) =>
                      SupportEntry(
                    workDayId: id,
                    district: draft
                        .districtNumber
                        .toString(),
                    packagesTaken:
                        int.tryParse(
                              draft
                                  .packageController
                                  .text
                                  .trim(),
                            ) ??
                            0,
                    note:
                        _nullIfEmpty(
                      draft
                          .noteController
                          .text,
                    ),
                  ),
                )
                .toList()
            : <SupportEntry>[];

    setState(() {
      _isSaving = true;
    });

    try {
      final notifier = ref.read(
        workDayProvider.notifier,
      );

      if (widget.existingWorkDay ==
          null) {
        await notifier.saveWorkDay(
          workDay: workDay,
          supportEntries:
              supportEntries,
        );
      } else {
        await notifier.updateWorkDay(
          workDay: workDay,
          supportEntries:
              supportEntries,
        );
      }

      if (!mounted) {
        return;
      }

      Navigator.of(context)
          .pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Der Arbeitstag konnte nicht gespeichert werden.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showMessage(
    String message,
  ) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  static int? _timeToMinutes(
    TimeOfDay? time,
  ) {
    if (time == null) {
      return null;
    }

    return (time.hour * 60) +
        time.minute;
  }

  static TimeOfDay? _minutesToTime(
    int? minutes,
  ) {
    if (minutes == null) {
      return null;
    }

    return TimeOfDay(
      hour: minutes ~/ 60,
      minute: minutes % 60,
    );
  }

  static String? _nullIfEmpty(
    String value,
  ) {
    final trimmed =
        value.trim();

    if (trimmed.isEmpty) {
      return null;
    }

    return trimmed;
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
}

class _SectionCard
    extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding:
            const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color:
                      Theme.of(context)
                          .colorScheme
                          .primary,
                ),
                const SizedBox(
                  width: 10,
                ),
                Text(
                  title,
                  style:
                      Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                ),
              ],
            ),
            const SizedBox(
              height: 18,
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class _TimeRow
    extends StatelessWidget {
  const _TimeRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final TimeOfDay? value;
  final VoidCallback onTap;

  @override
  Widget build(
    BuildContext context,
  ) {
    return ListTile(
      contentPadding:
          EdgeInsets.zero,
      title: Text(label),
      trailing: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Text(
            value?.format(context) ??
                '--:--',
            style:
                Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(
                      fontWeight:
                          FontWeight
                              .w600,
                    ),
          ),
          const SizedBox(
            width: 8,
          ),
          const Icon(
            Icons.chevron_right,
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _SupportEditor
    extends StatefulWidget {
  const _SupportEditor({
    super.key,
    required this.draft,
    required this.districts,
    required this.onDelete,
  });

  final _SupportDraft draft;
  final List<District> districts;
  final VoidCallback onDelete;

  @override
  State<_SupportEditor>
      createState() =>
          _SupportEditorState();
}

class _SupportEditorState
    extends State<_SupportEditor> {
  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant,
        ),
        borderRadius:
            BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Unterstützung',
                  style:
                      Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                            fontWeight:
                                FontWeight
                                    .w600,
                          ),
                ),
              ),
              IconButton(
                tooltip: 'Entfernen',
                onPressed:
                    widget.onDelete,
                icon: const Icon(
                  Icons
                      .delete_outline,
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 8,
          ),
          DropdownButtonFormField<
              int>(
            initialValue:
                widget.draft
                    .districtNumber,
            decoration:
                const InputDecoration(
              labelText: 'Bezirk',
              border:
                  OutlineInputBorder(),
            ),
            hint: const Text(
              'Bezirk auswählen',
            ),
            items: widget.districts
                .map(
                  (district) =>
                      DropdownMenuItem<
                          int>(
                    value:
                        district.number,
                    child: Text(
                      'Bezirk ${district.number}',
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() {
                widget.draft
                        .districtNumber =
                    value;
              });
            },
          ),
          const SizedBox(
            height: 12,
          ),
          TextField(
            controller: widget.draft
                .packageController,
            keyboardType:
                TextInputType.number,
            decoration:
                const InputDecoration(
              labelText:
                  'Übernommene Pakete',
              hintText:
                  'z. B. 20',
              border:
                  OutlineInputBorder(),
            ),
          ),
          const SizedBox(
            height: 12,
          ),
          TextField(
            controller:
                widget.draft
                    .noteController,
            decoration:
                const InputDecoration(
              labelText:
                  'Bemerkung',
              hintText: 'Optional',
              border:
                  OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportDraft {
  _SupportDraft()
      : key = UniqueKey(),
        packageController =
            TextEditingController(),
        noteController =
            TextEditingController();

  _SupportDraft.fromEntry(
    SupportEntry entry,
  )   : key = UniqueKey(),
        districtNumber =
            int.tryParse(
          entry.district,
        ),
        packageController =
            TextEditingController(
          text:
              '${entry.packagesTaken}',
        ),
        noteController =
            TextEditingController(
          text: entry.note ?? '',
        );

  final Key key;

  int? districtNumber;

  final TextEditingController
      packageController;

  final TextEditingController
      noteController;

  void dispose() {
    packageController.dispose();
    noteController.dispose();
  }
}