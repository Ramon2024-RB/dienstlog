import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../models/advertising.dart';
import '../../models/district.dart';
import '../../models/own_tour_entry.dart';
import '../../models/monday_delivery_entry.dart';
import '../../models/package_driver_entry.dart';
import '../../models/support_entry.dart';
import '../../models/work_day.dart';
import '../../models/zsp_location.dart';
import '../../services/advertising_provider.dart';
import '../../services/district_provider.dart';
import '../../services/work_day_provider.dart';
import '../../services/zsp_provider.dart';

class AddWorkDayPage extends ConsumerStatefulWidget {
  const AddWorkDayPage({
    super.key,
    this.initialDate,
    this.existingWorkDay,
    this.initialOwnTourEntries = const [],
    this.initialSupportEntries = const [],
    this.initialPackageDriverEntries = const [],
    this.initialMondayDeliveryEntries = const [],
  });

  final DateTime? initialDate;
  final WorkDay? existingWorkDay;
  final List<OwnTourEntry> initialOwnTourEntries;
  final List<SupportEntry> initialSupportEntries;
  final List<PackageDriverEntry> initialPackageDriverEntries;
  final List<MondayDeliveryEntry> initialMondayDeliveryEntries;

  @override
  ConsumerState<AddWorkDayPage> createState() =>
      _AddWorkDayPageState();
}

class _AddWorkDayPageState extends ConsumerState<AddWorkDayPage> {
  late DateTime _date;

  WorkDayType _type = WorkDayType.work;
  WorkAssignmentType _assignmentType =
      WorkAssignmentType.ownDistrict;
  DistrictPart? _dayPostPart;

  String? _selectedZspId;

  TimeOfDay? _workStart;
  TimeOfDay? _departureTime;
  TimeOfDay? _deliveryEnd;
  TimeOfDay? _workEnd;

  int _breakMinutes = 0;

  final TextEditingController _advertisingController =
      TextEditingController();

  final TextEditingController _notesController =
      TextEditingController();

  final List<_OwnTourDraft> _ownTourDrafts = [];
  final List<_SupportDraft> _supportDrafts = [];
  final List<_PackageDriverDistrictDraft> _packageDriverDistrictDrafts = [];
  final TextEditingController _packageDriverPackageController =
      TextEditingController();
  final List<_MondayDeliveryDistrictDraft> _mondayDeliveryDistrictDrafts = [];
  final TextEditingController _mondayDeliveryPackageController =
      TextEditingController();

  bool _hasAdvertising = false;
  bool _saveCustomAdvertising = false;
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
      _dayPostPart =
          existingWorkDay.districtPart == DistrictPart.partA ||
                  existingWorkDay.districtPart == DistrictPart.partB
              ? existingWorkDay.districtPart
              : null;
      _selectedZspId = existingWorkDay.zspId;

      _workStart = _minutesToTime(
        existingWorkDay.workStart,
      );

      _departureTime = _minutesToTime(
        existingWorkDay.departureTime,
      );

      _deliveryEnd = _minutesToTime(
        existingWorkDay.deliveryEnd,
      );

      _workEnd = _minutesToTime(
        existingWorkDay.workEnd,
      );

      _breakMinutes = existingWorkDay.breakMinutes;

      _hasAdvertising =
          existingWorkDay.hasAdvertising;

      _advertisingController.text =
          existingWorkDay.advertising ?? '';

      _notesController.text =
          existingWorkDay.notes ?? '';

      _packageDriverPackageController.text =
          existingWorkDay.packageDriverPackageCount > 0
              ? '${existingWorkDay.packageDriverPackageCount}'
              : '';

      _mondayDeliveryPackageController.text =
          existingWorkDay.mondayDeliveryPackageCount > 0
              ? '${existingWorkDay.mondayDeliveryPackageCount}'
              : '';

      for (final entry in widget.initialPackageDriverEntries) {
        _packageDriverDistrictDrafts.add(
          _PackageDriverDistrictDraft.fromEntry(entry),
        );
      }

      for (final entry in widget.initialMondayDeliveryEntries) {
        _mondayDeliveryDistrictDrafts.add(
          _MondayDeliveryDistrictDraft.fromEntry(entry),
        );
      }

      if (widget.initialOwnTourEntries.isNotEmpty) {
        for (final entry in widget.initialOwnTourEntries) {
          _ownTourDrafts.add(
            _OwnTourDraft.fromEntry(entry),
          );
        }
      }

      if (_dayPostPart == null && _ownTourDrafts.isNotEmpty) {
        final legacyPart = _ownTourDrafts.first.districtPart;
        if (legacyPart == DistrictPart.partA ||
            legacyPart == DistrictPart.partB) {
          _dayPostPart = legacyPart;
        }
      } else if (existingWorkDay.type == WorkDayType.work &&
          existingWorkDay.assignmentType ==
              WorkAssignmentType.ownDistrict &&
          existingWorkDay.districtId != null) {
        _ownTourDrafts.add(
          _OwnTourDraft.fromLegacyWorkDay(
            existingWorkDay,
          ),
        );
      }

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

      _ownTourDrafts.add(
        _OwnTourDraft(),
      );
    }
  }

  @override
  void dispose() {
    _advertisingController.dispose();
    _notesController.dispose();
    _packageDriverPackageController.dispose();
    _mondayDeliveryPackageController.dispose();

    for (final draft in _ownTourDrafts) {
      draft.dispose();
    }

    for (final draft in _supportDrafts) {
      draft.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final districtsAsync = ref.watch(districtProvider);
    final zspAsync = ref.watch(zspProvider);

    if (districtsAsync.isLoading || zspAsync.isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            widget.existingWorkDay == null
                ? 'Arbeitstag eintragen'
                : 'Arbeitstag bearbeiten',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (districtsAsync.hasError || zspAsync.hasError) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            widget.existingWorkDay == null
                ? 'Arbeitstag eintragen'
                : 'Arbeitstag bearbeiten',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Standorte oder Bezirke konnten nicht geladen werden.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    ref.invalidate(districtProvider);
                    ref.invalidate(zspProvider);
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Erneut versuchen'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final districts = districtsAsync.value ?? const <District>[];
    final locations = zspAsync.value ?? const <ZspLocation>[];
    final activeLocations = locations.where((item) => item.isActive).toList();

    final defaultLocation = locations.cast<ZspLocation?>().firstWhere(
          (item) => item?.isDefault == true,
          orElse: () => activeLocations.isEmpty ? null : activeLocations.first,
        );

    final effectiveZspId = _selectedZspId ??
        widget.existingWorkDay?.zspId ??
        defaultLocation?.id ??
        ZspLocation.werneckId;

    final activeDistricts = districts
        .where((district) =>
            district.isActive && district.zspId == effectiveZspId)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existingWorkDay == null
              ? 'Arbeitstag eintragen'
              : 'Arbeitstag bearbeiten',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _buildForm(
        context,
        activeDistricts,
        activeLocations,
        effectiveZspId,
      ),
    );
  }

  Widget _buildForm(
    BuildContext context,
    List<District> districts,
    List<ZspLocation> locations,
    String effectiveZspId,
  ) {
    final advertisingsAsync =
        ref.watch(advertisingProvider);

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
          icon: Icons.calendar_today_outlined,
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Datum'),
                subtitle: Text(
                  _formatDate(_date),
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                ),
                onTap: _selectDate,
              ),
              const Divider(),
              DropdownButtonFormField<WorkDayType>(
                initialValue: _type,
                decoration: const InputDecoration(
                  labelText: 'Tagesart',
                  border: OutlineInputBorder(),
                ),
                items: WorkDayType.values
                    .map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(
                          _workDayTypeLabel(type),
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
            title: 'Standort',
            icon: Icons.location_on_outlined,
            child: DropdownButtonFormField<String>(
              initialValue: effectiveZspId,
              decoration: const InputDecoration(
                labelText: 'ZSP',
                border: OutlineInputBorder(),
              ),
              items: locations
                  .map(
                    (location) => DropdownMenuItem<String>(
                      value: location.id,
                      child: Text(
                        location.isDefault
                            ? '${location.name} · Standard'
                            : location.name,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null || value == effectiveZspId) return;
                setState(() {
                  _selectedZspId = value;
                  for (final draft in _ownTourDrafts) {
                    draft.districtNumber = null;
                  }
                  for (final draft in _supportDrafts) {
                    draft.districtNumber = null;
                  }
                  for (final draft in _packageDriverDistrictDrafts) {
                    draft.districtNumber = null;
                  }
                  for (final draft in _mondayDeliveryDistrictDrafts) {
                    draft.districtNumber = null;
                  }
                });
              },
            ),
          ),

          const SizedBox(height: 16),

          _SectionCard(
            title: 'Einsatz',
            icon: Icons.badge_outlined,
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                SegmentedButton<WorkAssignmentType>(
                  segments: const [
                    ButtonSegment(
                      value:
                          WorkAssignmentType.ownDistrict,
                      label: Text(
                        'Eigene Zustellung',
                      ),
                      icon: Icon(
                        Icons.route_outlined,
                      ),
                    ),
                    ButtonSegment(
                      value:
                          WorkAssignmentType.mondayDelivery,
                      label: Text(
                        'Montagszustellung',
                      ),
                      icon: Icon(
                        Icons.calendar_view_week_outlined,
                      ),
                    ),
                    ButtonSegment(
                      value:
                          WorkAssignmentType.packageDriver,
                      label: Text(
                        'Paketfahrer',
                      ),
                      icon: Icon(
                        Icons.local_shipping_outlined,
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
                                  .ownDistrict &&
                          _ownTourDrafts.isEmpty) {
                        _ownTourDrafts.add(
                          _OwnTourDraft(),
                        );
                      }
                    });
                  },
                ),

                const SizedBox(height: 16),

                Text(
                  hasOwnDistrict
                      ? 'Trage alle Bezirke ein, die du an diesem Tag selbst gefahren bist.'
                      : _assignmentType == WorkAssignmentType.mondayDelivery
                          ? 'Trage alle Bezirke der Montagszustellung ein. Es gibt dabei keine A-/B-Sortierung und die Paketmenge wird nur einmal insgesamt erfasst.'
                          : 'Trage alle Bezirke ein, aus denen du als Paketfahrer Pakete gefahren hast. Die Paketmenge gibst du nur einmal als Gesamtmenge ein.',
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

          const SizedBox(height: 16),

          _SectionCard(
            title: 'Zeiten',
            icon: Icons.schedule_outlined,
            child: Column(
              children: [
                _TimeRow(
                  label: 'Arbeitsbeginn',
                  value: _workStart,
                  onTap: () async {
                    final time =
                        await _pickTime(
                      _workStart,
                    );

                    if (time != null) {
                      setState(() {
                        _workStart = time;
                      });
                    }
                  },
                ),
                const Divider(),

                _TimeRow(
                  label: 'Abfahrt',
                  value: _departureTime,
                  onTap: () async {
                    final time =
                        await _pickTime(
                      _departureTime,
                    );

                    if (time != null) {
                      setState(() {
                        _departureTime = time;
                      });
                    }
                  },
                ),
                const Divider(),

                _TimeRow(
                  label: 'Zustellende',
                  value: _deliveryEnd,
                  onTap: () async {
                    final time =
                        await _pickTime(
                      _deliveryEnd,
                    );

                    if (time != null) {
                      setState(() {
                        _deliveryEnd = time;
                      });
                    }
                  },
                ),
                const Divider(),

                _TimeRow(
                  label: 'Arbeitsende',
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

                const SizedBox(height: 12),

                DropdownButtonFormField<int>(
                  initialValue:
                      _breakMinutes,
                  decoration: const InputDecoration(
                    labelText: 'Pause',
                    border: OutlineInputBorder(),
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
            const SizedBox(height: 16),
            _buildOwnTourSection(
              context,
              districts,
            ),
            const SizedBox(height: 16),
            _buildSupportSection(
              context,
              districts,
            ),
          ] else if (_assignmentType ==
              WorkAssignmentType.mondayDelivery) ...[
            const SizedBox(height: 16),
            _buildMondayDeliverySection(
              context,
              districts,
            ),
            const SizedBox(height: 16),
            _buildSupportSection(
              context,
              districts,
            ),
          ] else ...[
            const SizedBox(height: 16),
            _buildPackageDriverSection(
              context,
              districts,
            ),
          ],

          const SizedBox(height: 16),

          _SectionCard(
            title: 'Werbung',
            icon: Icons.campaign_outlined,
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding:
                      EdgeInsets.zero,
                  title: const Text(
                    'Werbung mitgenommen',
                  ),
                  value: _hasAdvertising,
                  onChanged: (value) {
                    setState(() {
                      _hasAdvertising =
                          value;

                      if (!value) {
                        _advertisingController
                            .clear();
                        _saveCustomAdvertising = false;
                      }
                    });
                  },
                ),

                if (_hasAdvertising) ...[
                  const SizedBox(height: 8),

                  advertisingsAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (error, stackTrace) => TextField(
                      controller: _advertisingController,
                      decoration: const InputDecoration(
                        labelText: 'Welche Werbung?',
                        hintText: 'z. B. Einkauf Aktuell',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    data: (advertisings) {
                      const otherValue = '__other__';
                      final currentText =
                          _advertisingController.text.trim();
                      final savedNames = advertisings
                          .map((item) => item.name)
                          .toList();

                      final isCustomAdvertising =
                          !savedNames.contains(currentText) &&
                              (currentText.isNotEmpty ||
                                  _saveCustomAdvertising);

                      final selectedValue =
                          savedNames.contains(currentText)
                              ? currentText
                              : isCustomAdvertising ||
                                      savedNames.isEmpty
                                  ? otherValue
                                  : null;

                      return Column(
                        children: [
                          DropdownButtonFormField<String>(
                            key: ValueKey(
                              'advertising-$selectedValue-${savedNames.length}',
                            ),
                            initialValue: selectedValue,
                            decoration: const InputDecoration(
                              labelText: 'Welche Werbung?',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              ...savedNames.map(
                                (name) => DropdownMenuItem<String>(
                                  value: name,
                                  child: Text(name),
                                ),
                              ),
                              const DropdownMenuItem<String>(
                                value: otherValue,
                                child: Text(
                                  '+ Andere Werbung eingeben',
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                if (value == null) {
                                  _advertisingController.clear();
                                  _saveCustomAdvertising = false;
                                } else if (value == otherValue) {
                                  _advertisingController.clear();
                                  _saveCustomAdvertising = true;
                                } else {
                                  _advertisingController.text = value;
                                  _saveCustomAdvertising = false;
                                }
                              });
                            },
                          ),
                          if (selectedValue == otherValue) ...[
                            const SizedBox(height: 12),
                            TextField(
                              controller: _advertisingController,
                              decoration: const InputDecoration(
                                labelText: 'Andere Werbung',
                                hintText: 'Name der Werbung',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 4),
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              controlAffinity:
                                  ListTileControlAffinity.leading,
                              title: const Text(
                                'Für zukünftige Auswahl speichern',
                              ),
                              subtitle: const Text(
                                'Die Werbung wird unter „Mehr → Werbung“ gespeichert.',
                              ),
                              value: _saveCustomAdvertising,
                              onChanged: (value) {
                                setState(() {
                                  _saveCustomAdvertising =
                                      value ?? false;
                                });
                              },
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          _SectionCard(
            title: 'Bemerkungen',
            icon: Icons.notes_outlined,
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
                  _save(
                    districts,
                    locations,
                    effectiveZspId,
                  );
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

  Widget _buildOwnTourSection(
    BuildContext context,
    List<District> districts,
  ) {
    return _SectionCard(
      title: 'Gefahrene Bezirke',
      icon: Icons.route_outlined,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            'Hier siehst du deine selbst gefahrenen Bezirke auf einen Blick.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant,
                ),
          ),

          const SizedBox(height: 16),

          DropdownButtonFormField<DistrictPart>(
            initialValue: _dayPostPart,
            decoration: const InputDecoration(
              labelText: 'Post',
              helperText: 'Gilt einmal für den gesamten Arbeitstag.',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem<DistrictPart>(
                value: DistrictPart.partA,
                child: Text('A-Teil'),
              ),
              DropdownMenuItem<DistrictPart>(
                value: DistrictPart.partB,
                child: Text('B-Teil'),
              ),
            ],
            onChanged: (value) {
              setState(() {
                _dayPostPart = value;
              });
            },
          ),

          if (_ownTourDrafts.isNotEmpty) ...[
            const SizedBox(height: 16),

            for (var index = 0;
                index < _ownTourDrafts.length;
                index++) ...[
              _OwnTourCompactCard(
                draft:
                    _ownTourDrafts[index],
                canDelete:
                    _ownTourDrafts.length > 1,
                onEdit: () async {
                  await _editOwnTour(
                    _ownTourDrafts[index],
                    districts,
                  );
                },
                onDelete: () {
                  setState(() {
                    final draft =
                        _ownTourDrafts.removeAt(
                      index,
                    );

                    draft.dispose();
                  });
                },
              ),

              if (index !=
                  _ownTourDrafts.length - 1)
                const SizedBox(
                  height: 10,
                ),
            ],
          ],

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                await _addOwnTour(
                  districts,
                );
              },
              icon: const Icon(
                Icons.add,
              ),
              label: const Text(
                'Weiteren Bezirk hinzufügen',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addOwnTour(
    List<District> districts,
  ) async {
    final draft = _OwnTourDraft();

    final saved =
        await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return _OwnTourFormSheet(
          title: 'Bezirk hinzufügen',
          draft: draft,
          districts: districts,
        );
      },
    );

    if (!mounted) {
      draft.dispose();
      return;
    }

    if (saved == true) {
      setState(() {
        _ownTourDrafts.add(
          draft,
        );
      });
    } else {
      draft.dispose();
    }
  }

  Future<void> _editOwnTour(
    _OwnTourDraft original,
    List<District> districts,
  ) async {
    final draft =
        _OwnTourDraft.copyOf(
      original,
    );

    final saved =
        await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return _OwnTourFormSheet(
          title:
              original.districtNumber == null
                  ? 'Bezirk bearbeiten'
                  : 'Bezirk ${original.districtNumber} bearbeiten',
          draft: draft,
          districts: districts,
        );
      },
    );

    if (!mounted) {
      draft.dispose();
      return;
    }

    if (saved == true) {
      setState(() {
        original.applyFrom(
          draft,
        );
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      draft.dispose();
    });
  }

  Widget _buildMondayDeliverySection(
    BuildContext context,
    List<District> districts,
  ) {
    return _SectionCard(
      title: 'Montagszustellung',
      icon: Icons.calendar_view_week_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Wähle alle Bezirke aus, die du in der Montagszustellung gefahren bist. Es gibt keine A-/B-Sortierung. Die Paketmenge wird nur einmal insgesamt gespeichert und nicht auf die Bezirke verteilt.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          if (_mondayDeliveryDistrictDrafts.isNotEmpty) ...[
            const SizedBox(height: 16),
            for (var index = 0;
                index < _mondayDeliveryDistrictDrafts.length;
                index++) ...[
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      key: ValueKey(_mondayDeliveryDistrictDrafts[index].key),
                      initialValue:
                          _mondayDeliveryDistrictDrafts[index].districtNumber,
                      decoration: InputDecoration(
                        labelText: 'Bezirk ${index + 1}',
                        border: const OutlineInputBorder(),
                      ),
                      items: districts
                          .map(
                            (district) => DropdownMenuItem<int>(
                              value: district.number,
                              child: Text('Bezirk ${district.number}'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _mondayDeliveryDistrictDrafts[index].districtNumber =
                              value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Bezirk entfernen',
                    onPressed: () {
                      setState(() {
                        _mondayDeliveryDistrictDrafts.removeAt(index);
                      });
                    },
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
              if (index != _mondayDeliveryDistrictDrafts.length - 1)
                const SizedBox(height: 12),
            ],
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _mondayDeliveryDistrictDrafts.add(
                    _MondayDeliveryDistrictDraft(),
                  );
                });
              },
              icon: const Icon(Icons.add),
              label: const Text('Bezirk hinzufügen'),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _mondayDeliveryPackageController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Pakete gesamt',
              hintText: 'z. B. 80',
              helperText:
                  'Einmalige Gesamtmenge für alle Bezirke der Montagszustellung.',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageDriverSection(
    BuildContext context,
    List<District> districts,
  ) {
    return _SectionCard(
      title: 'Paketfahrer',
      icon: Icons.local_shipping_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Wähle alle Bezirke aus, aus denen du Pakete gefahren hast. Die Gesamtmenge wird nicht auf die einzelnen Bezirke verteilt.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          if (_packageDriverDistrictDrafts.isNotEmpty) ...[
            const SizedBox(height: 16),
            for (var index = 0;
                index < _packageDriverDistrictDrafts.length;
                index++) ...[
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      key: ValueKey(_packageDriverDistrictDrafts[index].key),
                      initialValue:
                          _packageDriverDistrictDrafts[index].districtNumber,
                      decoration: InputDecoration(
                        labelText: 'Bezirk ${index + 1}',
                        border: const OutlineInputBorder(),
                      ),
                      items: districts
                          .map(
                            (district) => DropdownMenuItem<int>(
                              value: district.number,
                              child: Text('Bezirk ${district.number}'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _packageDriverDistrictDrafts[index].districtNumber =
                              value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Bezirk entfernen',
                    onPressed: () {
                      setState(() {
                        _packageDriverDistrictDrafts.removeAt(index);
                      });
                    },
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
              if (index != _packageDriverDistrictDrafts.length - 1)
                const SizedBox(height: 12),
            ],
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _packageDriverDistrictDrafts.add(
                    _PackageDriverDistrictDraft(),
                  );
                });
              },
              icon: const Icon(Icons.add),
              label: const Text('Bezirk hinzufügen'),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _packageDriverPackageController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Pakete gesamt',
              hintText: 'z. B. 180',
              helperText:
                  'Einmalige Gesamtmenge für alle oben eingetragenen Bezirke.',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
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
            _assignmentType == WorkAssignmentType.mondayDelivery
                ? 'Wenn du nach der Montagszustellung noch Kollegen unterstützt hast, kannst du diese hier separat eintragen.'
                : 'Wenn du nach deiner eigenen Zustellung noch Kollegen unterstützt hast, kannst du diese hier eintragen.',
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
            const SizedBox(height: 16),

            for (var index = 0;
                index <
                    _supportDrafts.length;
                index++) ...[
              _SupportEditor(
                key: ValueKey(
                  _supportDrafts[index].key,
                ),
                draft:
                    _supportDrafts[index],
                districts: districts,
                onDelete: () {
                  setState(() {
                    final draft =
                        _supportDrafts.removeAt(
                      index,
                    );

                    draft.dispose();
                  });
                },
              ),

              if (index !=
                  _supportDrafts.length - 1)
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
            icon: const Icon(
              Icons.add,
            ),
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
    List<ZspLocation> locations,
    String effectiveZspId,
  ) async {
    final isWorkDay =
        _type == WorkDayType.work;

    final hasOwnDistrict =
        _assignmentType ==
            WorkAssignmentType.ownDistrict;

    final isMondayDelivery =
        _assignmentType ==
            WorkAssignmentType.mondayDelivery;

    if (isWorkDay) {
      final workStartMinutes =
          _timeToMinutes(_workStart);
      final departureMinutes =
          _timeToMinutes(_departureTime);
      final deliveryEndMinutes =
          _timeToMinutes(_deliveryEnd);
      final workEndMinutes =
          _timeToMinutes(_workEnd);

      if (workStartMinutes != null &&
          departureMinutes != null &&
          departureMinutes < workStartMinutes) {
        _showMessage(
          'Die Abfahrt kann nicht vor dem Arbeitsbeginn liegen.',
        );
        return;
      }

      if (departureMinutes != null &&
          deliveryEndMinutes != null &&
          deliveryEndMinutes < departureMinutes) {
        _showMessage(
          'Das Zustellende kann nicht vor der Abfahrt liegen.',
        );
        return;
      }

      if (deliveryEndMinutes != null &&
          workEndMinutes != null &&
          workEndMinutes < deliveryEndMinutes) {
        _showMessage(
          'Das Arbeitsende kann nicht vor dem Zustellende liegen.',
        );
        return;
      }

      if (workStartMinutes != null &&
          workEndMinutes != null &&
          workEndMinutes < workStartMinutes) {
        _showMessage(
          'Das Arbeitsende kann nicht vor dem Arbeitsbeginn liegen.',
        );
        return;
      }
    }

    if (isWorkDay &&
        hasOwnDistrict &&
        _dayPostPart != DistrictPart.partA &&
        _dayPostPart != DistrictPart.partB) {
      _showMessage(
        'Bitte wähle für den Arbeitstag Post A-Teil oder B-Teil aus.',
      );
      return;
    }

    if (isWorkDay &&
        hasOwnDistrict &&
        _ownTourDrafts.isEmpty) {
      _showMessage(
        'Bitte füge mindestens eine eigene Tour hinzu.',
      );
      return;
    }

    if (isWorkDay &&
        hasOwnDistrict) {
      for (var index = 0;
          index <
              _ownTourDrafts.length;
          index++) {
        final draft =
            _ownTourDrafts[index];

        if (draft.districtNumber ==
            null) {
          _showMessage(
            'Bitte wähle bei eigener Tour ${index + 1} einen Bezirk aus.',
          );
          return;
        }

        final packageCount =
            _parseCount(
          draft.packageController,
        );

        final cancelledPackageCount =
            _parseCount(
          draft
              .cancelledPackageController,
        );

        if (packageCount < 0 ||
            cancelledPackageCount < 0) {
          _showMessage(
            'Paketmengen dürfen nicht negativ sein.',
          );
          return;
        }

        if (cancelledPackageCount >
            packageCount) {
          _showMessage(
            'Bei eigener Tour ${index + 1} können abgebrochene Pakete nicht höher als die gesamte Paketmenge sein.',
          );
          return;
        }
      }
    }

    if (isWorkDay && (hasOwnDistrict || isMondayDelivery)) {
      for (var index = 0;
          index <
              _supportDrafts.length;
          index++) {
        final draft =
            _supportDrafts[index];

        if (draft.districtNumber ==
            null) {
          _showMessage(
            'Bitte wähle bei Unterstützung ${index + 1} einen Bezirk aus.',
          );
          return;
        }

        final packages =
            _parseCount(
          draft.packageController,
        );

        if (packages <= 0) {
          _showMessage(
            'Bitte trage bei Unterstützung ${index + 1} die übernommenen Pakete ein.',
          );
          return;
        }
      }

    }

    if (isWorkDay && isMondayDelivery) {
      if (_mondayDeliveryDistrictDrafts.isEmpty) {
        _showMessage(
          'Bitte füge mindestens einen Bezirk für die Montagszustellung hinzu.',
        );
        return;
      }

      for (var index = 0;
          index < _mondayDeliveryDistrictDrafts.length;
          index++) {
        if (_mondayDeliveryDistrictDrafts[index].districtNumber == null) {
          _showMessage(
            'Bitte wähle bei Montagszustellung-Bezirk ${index + 1} einen Bezirk aus.',
          );
          return;
        }
      }

      if (_parseCount(_mondayDeliveryPackageController) <= 0) {
        _showMessage(
          'Bitte trage die gesamte Paketmenge für die Montagszustellung ein.',
        );
        return;
      }
    }

    if (isWorkDay &&
        _assignmentType == WorkAssignmentType.packageDriver) {
      if (_packageDriverDistrictDrafts.isEmpty) {
        _showMessage('Bitte füge mindestens einen Paketfahrer-Bezirk hinzu.');
        return;
      }

      for (var index = 0;
          index < _packageDriverDistrictDrafts.length;
          index++) {
        if (_packageDriverDistrictDrafts[index].districtNumber == null) {
          _showMessage(
            'Bitte wähle bei Paketfahrer-Bezirk ${index + 1} einen Bezirk aus.',
          );
          return;
        }
      }

      if (_parseCount(_packageDriverPackageController) <= 0) {
        _showMessage(
          'Bitte trage die gesamte Paketmenge für den Paketfahrer-Tag ein.',
        );
        return;
      }
    }

    final id =
        widget.existingWorkDay?.id ??
            const Uuid().v4();

    final ownTourEntries =
        isWorkDay &&
                hasOwnDistrict
            ? _ownTourDrafts
                .map(
                  (draft) =>
                      OwnTourEntry(
                    workDayId: id,
                    district: draft
                        .districtNumber
                        .toString(),
                    zspId: effectiveZspId,
                    districtPart:
                        _dayPostPart ?? DistrictPart.full,
                    packageCount:
                        _parseCount(
                      draft
                          .packageController,
                    ),
                    cancelledPackageCount:
                        _parseCount(
                      draft
                          .cancelledPackageController,
                    ),
                  ),
                )
                .toList()
            : <OwnTourEntry>[];

    final supportEntries =
        isWorkDay && (hasOwnDistrict || isMondayDelivery)
            ? _supportDrafts
                .map(
                  (draft) =>
                      SupportEntry(
                    workDayId: id,
                    district: draft
                        .districtNumber
                        .toString(),
                    zspId: effectiveZspId,
                    packagesTaken:
                        _parseCount(
                      draft
                          .packageController,
                    ),
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

    final packageDriverEntries =
        isWorkDay &&
                _assignmentType == WorkAssignmentType.packageDriver
            ? _packageDriverDistrictDrafts
                .map(
                  (draft) => PackageDriverEntry(
                    workDayId: id,
                    district: draft.districtNumber.toString(),
                    zspId: effectiveZspId,
                  ),
                )
                .toList()
            : <PackageDriverEntry>[];

    final mondayDeliveryEntries =
        isWorkDay && isMondayDelivery
            ? _mondayDeliveryDistrictDrafts
                .map(
                  (draft) => MondayDeliveryEntry(
                    workDayId: id,
                    district: draft.districtNumber.toString(),
                    zspId: effectiveZspId,
                  ),
                )
                .toList()
            : <MondayDeliveryEntry>[];

    final firstOwnTour =
        ownTourEntries.isEmpty
            ? null
            : ownTourEntries.first;

    final totalOwnPackageCount =
        ownTourEntries.fold<int>(
      0,
      (sum, entry) =>
          sum + entry.packageCount,
    );

    final totalOwnCancelledPackageCount =
        ownTourEntries.fold<int>(
      0,
      (sum, entry) =>
          sum +
          entry.cancelledPackageCount,
    );

    final workDay = WorkDay(
      id: id,
      date: _date,
      type: _type,
      zspId: effectiveZspId,
      assignmentType:
          _assignmentType,
      districtId:
          firstOwnTour?.district,
      districtPart:
          isWorkDay && hasOwnDistrict
              ? (_dayPostPart ?? DistrictPart.full)
              : DistrictPart.full,
      workStart:
          isWorkDay
              ? _timeToMinutes(
                  _workStart,
                )
              : null,
      departureTime:
          isWorkDay
              ? _timeToMinutes(
                  _departureTime,
                )
              : null,
      deliveryEnd:
          isWorkDay
              ? _timeToMinutes(
                  _deliveryEnd,
                )
              : null,
      workEnd:
          isWorkDay
              ? _timeToMinutes(
                  _workEnd,
                )
              : null,
      breakMinutes:
          isWorkDay
              ? _breakMinutes
              : 0,
      packageCount:
          isWorkDay &&
                  hasOwnDistrict
              ? totalOwnPackageCount
              : 0,
      cancelledPackageCount:
          isWorkDay &&
                  hasOwnDistrict
              ? totalOwnCancelledPackageCount
              : 0,
      packageDriverPackageCount:
          isWorkDay &&
                  _assignmentType == WorkAssignmentType.packageDriver
              ? _parseCount(_packageDriverPackageController)
              : 0,
      mondayDeliveryPackageCount:
          isWorkDay && isMondayDelivery
              ? _parseCount(_mondayDeliveryPackageController)
              : 0,
      hasAdvertising:
          isWorkDay &&
              _hasAdvertising,
      advertising:
          isWorkDay &&
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

    setState(() {
      _isSaving = true;
    });

    try {
      if (isWorkDay &&
          _hasAdvertising &&
          _saveCustomAdvertising) {
        final customAdvertisingName =
            _advertisingController.text.trim();

        if (customAdvertisingName.isEmpty) {
          _showMessage(
            'Bitte gib den Namen der Werbung ein.',
          );
          return;
        }

        final currentAdvertisings =
            ref.read(advertisingProvider).value ?? const <Advertising>[];

        final alreadyExists = currentAdvertisings.any(
          (item) =>
              item.name.trim().toLowerCase() ==
              customAdvertisingName.toLowerCase(),
        );

        if (!alreadyExists) {
          await ref
              .read(advertisingProvider.notifier)
              .addAdvertising(
                Advertising(
                  id: const Uuid().v4(),
                  name: customAdvertisingName,
                ),
              );
        }
      }

      final notifier = ref.read(
        workDayProvider.notifier,
      );

      if (widget.existingWorkDay ==
          null) {
        await notifier.saveWorkDay(
          workDay: workDay,
          ownTourEntries:
              ownTourEntries,
          supportEntries:
              supportEntries,
          packageDriverEntries:
              packageDriverEntries,
          mondayDeliveryEntries:
              mondayDeliveryEntries,
        );
      } else {
        await notifier.updateWorkDay(
          workDay: workDay,
          ownTourEntries:
              ownTourEntries,
          supportEntries:
              supportEntries,
          packageDriverEntries:
              packageDriverEntries,
          mondayDeliveryEntries:
              mondayDeliveryEntries,
        );
      }

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(
        true,
      );
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

  static int _parseCount(
    TextEditingController controller,
  ) {
    return int.tryParse(
          controller.text.trim(),
        ) ??
        0;
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
}

class _SectionCard extends StatelessWidget {
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
                Expanded(
                  child: Text(
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

class _TimeRow extends StatelessWidget {
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

class _OwnTourCompactCard
    extends StatelessWidget {
  const _OwnTourCompactCard({
    required this.draft,
    required this.canDelete,
    required this.onEdit,
    required this.onDelete,
  });

  final _OwnTourDraft draft;
  final bool canDelete;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(
    BuildContext context,
  ) {
    final packageCount =
        int.tryParse(
              draft.packageController
                  .text
                  .trim(),
            ) ??
            0;

    final cancelledPackageCount =
        int.tryParse(
              draft
                  .cancelledPackageController
                  .text
                  .trim(),
            ) ??
            0;

    final deliveredPackageCount =
        (packageCount -
                cancelledPackageCount)
            .clamp(
      0,
      packageCount,
    );

    final districtTitle =
        draft.districtNumber == null
            ? 'Bezirk auswählen'
            : 'Bezirk ${draft.districtNumber}';

    return Material(
      color: Theme.of(context)
          .colorScheme
          .surfaceContainerLow,
      borderRadius:
          BorderRadius.circular(16),
      child: InkWell(
        onTap: onEdit,
        borderRadius:
            BorderRadius.circular(16),
        child: Padding(
          padding:
              const EdgeInsets.fromLTRB(
            16,
            14,
            8,
            14,
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
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
                  Icons.route_outlined,
                  color:
                      Theme.of(context)
                          .colorScheme
                          .onPrimaryContainer,
                ),
              ),
              const SizedBox(
                width: 14,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      districtTitle,
                      style:
                          Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight:
                                    FontWeight
                                        .w700,
                              ),
                    ),
                    const SizedBox(
                      height: 3,
                    ),
                    Text(
                      _postPartLabel(
                        draft
                            .districtPart,
                      ),
                      style:
                          Theme.of(context)
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
                    const SizedBox(
                      height: 6,
                    ),
                    Text(
                      '$packageCount Pakete · $deliveredPackageCount zugestellt',
                      style:
                          Theme.of(context)
                              .textTheme
                              .bodyMedium,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Bearbeiten',
                onPressed: onEdit,
                icon: const Icon(
                  Icons.edit_outlined,
                ),
              ),
              if (canDelete)
                IconButton(
                  tooltip:
                      'Bezirk entfernen',
                  onPressed:
                      onDelete,
                  icon: const Icon(
                    Icons
                        .delete_outline,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _postPartLabel(
    DistrictPart part,
  ) {
    switch (part) {
      case DistrictPart.full:
        return 'Post: nicht angegeben';

      case DistrictPart.partA:
        return 'Post: A-Teil';

      case DistrictPart.partB:
        return 'Post: B-Teil';
    }
  }
}

class _OwnTourFormSheet
    extends StatefulWidget {
  const _OwnTourFormSheet({
    required this.title,
    required this.draft,
    required this.districts,
  });

  final String title;
  final _OwnTourDraft draft;
  final List<District> districts;

  @override
  State<_OwnTourFormSheet>
      createState() =>
          _OwnTourFormSheetState();
}

class _OwnTourFormSheetState
    extends State<_OwnTourFormSheet> {
  @override
  Widget build(
    BuildContext context,
  ) {
    final bottomInset =
        MediaQuery.viewInsetsOf(
      context,
    ).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + bottomInset,
        ),
        child:
            SingleChildScrollView(
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment
                    .start,
            children: [
              Text(
                widget.title,
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

              const SizedBox(
                height: 20,
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
                height: 14,
              ),

              Row(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Expanded(
                    child: TextField(
                      controller:
                          widget.draft
                              .packageController,
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
                  ),
                  const SizedBox(
                    width: 12,
                  ),
                  Expanded(
                    child: TextField(
                      controller:
                          widget.draft
                              .cancelledPackageController,
                      keyboardType:
                          TextInputType
                              .number,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Abgebrochen',
                        hintText:
                            'z. B. 2',
                        border:
                            OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: 22,
              ),

              Row(
                children: [
                  Expanded(
                    child:
                        OutlinedButton(
                      onPressed: () {
                        Navigator.of(
                          context,
                        ).pop(false);
                      },
                      child: const Text(
                        'Abbrechen',
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 12,
                  ),
                  Expanded(
                    child:
                        FilledButton(
                      onPressed: () {
                        if (widget
                                .draft
                                .districtNumber ==
                            null) {
                          ScaffoldMessenger
                                  .of(
                            context,
                          ).showSnackBar(
                            const SnackBar(
                              content:
                                  Text(
                                'Bitte wähle einen Bezirk aus.',
                              ),
                            ),
                          );
                          return;
                        }

                        Navigator.of(
                          context,
                        ).pop(true);
                      },
                      child: const Text(
                        'Übernehmen',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
            controller:
                widget.draft
                    .packageController,
            keyboardType:
                TextInputType.number,
            decoration:
                const InputDecoration(
              labelText:
                  'Übernommene Pakete',
              hintText: 'z. B. 20',
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

class _OwnTourDraft {
  _OwnTourDraft()
      : key = UniqueKey(),
        packageController =
            TextEditingController(),
        cancelledPackageController =
            TextEditingController();

  _OwnTourDraft.fromEntry(
    OwnTourEntry entry,
  )   : key = UniqueKey(),
        districtNumber =
            int.tryParse(
          entry.district,
        ),
        districtPart =
            entry.districtPart,
        packageController =
            TextEditingController(
          text:
              '${entry.packageCount}',
        ),
        cancelledPackageController =
            TextEditingController(
          text:
              '${entry.cancelledPackageCount}',
        );

  _OwnTourDraft.fromLegacyWorkDay(
    WorkDay workDay,
  )   : key = UniqueKey(),
        districtNumber =
            int.tryParse(
          workDay.districtId ?? '',
        ),
        districtPart =
            workDay.districtPart,
        packageController =
            TextEditingController(
          text:
              '${workDay.packageCount}',
        ),
        cancelledPackageController =
            TextEditingController(
          text:
              '${workDay.cancelledPackageCount}',
        );

  _OwnTourDraft.copyOf(
    _OwnTourDraft other,
  )   : key = UniqueKey(),
        districtNumber =
            other.districtNumber,
        districtPart =
            other.districtPart,
        packageController =
            TextEditingController(
          text: other
              .packageController.text,
        ),
        cancelledPackageController =
            TextEditingController(
          text: other
              .cancelledPackageController
              .text,
        );

  void applyFrom(
    _OwnTourDraft other,
  ) {
    districtNumber =
        other.districtNumber;

    districtPart =
        other.districtPart;

    packageController.text =
        other.packageController.text;

    cancelledPackageController
            .text =
        other
            .cancelledPackageController
            .text;
  }

  final Key key;

  int? districtNumber;

  DistrictPart districtPart =
      DistrictPart.full;

  final TextEditingController
      packageController;

  final TextEditingController
      cancelledPackageController;

  void dispose() {
    packageController.dispose();

    cancelledPackageController
        .dispose();
  }
}

class _PackageDriverDistrictDraft {
  _PackageDriverDistrictDraft() : key = UniqueKey();

  _PackageDriverDistrictDraft.fromEntry(
    PackageDriverEntry entry,
  )   : key = UniqueKey(),
        districtNumber = int.tryParse(entry.district);

  final Key key;
  int? districtNumber;
}

class _MondayDeliveryDistrictDraft {
  _MondayDeliveryDistrictDraft() : key = UniqueKey();

  _MondayDeliveryDistrictDraft.fromEntry(
    MondayDeliveryEntry entry,
  )   : key = UniqueKey(),
        districtNumber = int.tryParse(entry.district);

  final Key key;
  int? districtNumber;
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