import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../models/district.dart';
import '../../models/zsp_location.dart';
import '../../services/district_provider.dart';
import '../../services/zsp_provider.dart';

class DistrictsPage extends ConsumerStatefulWidget {
  const DistrictsPage({super.key});

  @override
  ConsumerState<DistrictsPage> createState() => _DistrictsPageState();
}

class _DistrictsPageState extends ConsumerState<DistrictsPage> {
  String? _selectedZspId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locationsAsync = ref.watch(zspProvider);
    final districtsAsync = ref.watch(districtProvider);

    if (locationsAsync.isLoading || districtsAsync.isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'ZSP & Bezirke',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (locationsAsync.hasError || districtsAsync.hasError) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'ZSP & Bezirke',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off_outlined,
                  size: 42,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 14),
                const Text(
                  'Die Standorte und Bezirke konnten nicht geladen werden.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    ref.invalidate(zspProvider);
                    ref.invalidate(districtProvider);
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

    final locations = locationsAsync.value ?? const <ZspLocation>[];
    final districts = districtsAsync.value ?? const <District>[];
    final defaultLocation = locations.cast<ZspLocation?>().firstWhere(
          (item) => item?.isDefault == true,
          orElse: () => locations.isEmpty ? null : locations.first,
        );
    final selectedId = _selectedZspId ?? defaultLocation?.id;
    final selectedLocation = locations.cast<ZspLocation?>().firstWhere(
          (item) => item?.id == selectedId,
          orElse: () => defaultLocation,
        );
    final selectedDistricts = districts
        .where((district) => district.zspId == selectedLocation?.id)
        .toList();
    final activeDistrictCount =
        selectedDistricts.where((district) => district.isActive).length;
    final safeDistrictCount = selectedDistricts
        .where((district) => district.isActive && district.canDriveSafely)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ZSP & Bezirke',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'ZSP hinzufügen',
            onPressed: () => _addZsp(context),
            icon: const Icon(Icons.add_location_alt_outlined),
          ),
        ],
      ),
      floatingActionButton: selectedLocation == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _addDistrict(context, selectedLocation),
              icon: const Icon(Icons.add),
              label: const Text('Bezirk'),
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.42),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.14),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    Icons.route_outlined,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Deine Zustellbereiche',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Verwalte Standorte und die zugehörigen Bezirke.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 21,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 9),
              Text(
                'Standort',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (locations.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      Icons.add_location_alt_outlined,
                      size: 36,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Noch kein ZSP angelegt',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Lege zuerst einen Standort an. Danach kannst du Bezirke hinzufügen.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: () => _addZsp(context),
                      icon: const Icon(Icons.add),
                      label: const Text('ZSP hinzufügen'),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            DropdownButtonFormField<String>(
              initialValue: selectedLocation?.id,
              decoration: InputDecoration(
                labelText: 'ZSP auswählen',
                prefixIcon: const Icon(Icons.location_on_outlined),
                filled: true,
                fillColor:
                    theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
              ),
              items: locations
                  .map(
                    (location) => DropdownMenuItem<String>(
                      value: location.id,
                      child: Text(
                        location.isDefault
                            ? '${location.name} · Standard'
                            : location.isActive
                                ? location.name
                                : '${location.name} · deaktiviert',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() => _selectedZspId = value);
              },
            ),
            if (selectedLocation != null) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer
                              .withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          selectedLocation.isDefault
                              ? Icons.home_work_outlined
                              : Icons.location_on_outlined,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selectedLocation.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              selectedLocation.isDefault
                                  ? 'Standard-ZSP'
                                  : selectedLocation.isActive
                                      ? 'Aktiver Standort'
                                      : 'Deaktivierter Standort',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (selectedLocation.isDefault)
                        Padding(
                          padding: const EdgeInsets.only(right: 2),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Standard',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ),
                      PopupMenuButton<String>(
                        tooltip: 'Standort verwalten',
                        onSelected: (value) async {
                          if (value == 'default') {
                            await ref
                                .read(zspProvider.notifier)
                                .setDefault(selectedLocation.id);
                          } else if (value == 'toggle') {
                            if (selectedLocation.isDefault &&
                                selectedLocation.isActive) {
                              _message(
                                'Das Standard-ZSP kann nicht deaktiviert werden. Wähle zuerst ein anderes Standard-ZSP.',
                              );
                              return;
                            }
                            await ref.read(zspProvider.notifier).setActive(
                                  selectedLocation,
                                  !selectedLocation.isActive,
                                );
                          }
                        },
                        itemBuilder: (context) => [
                          if (!selectedLocation.isDefault)
                            const PopupMenuItem(
                              value: 'default',
                              child: Text('Als Standard festlegen'),
                            ),
                          PopupMenuItem(
                            value: 'toggle',
                            child: Text(
                              selectedLocation.isActive
                                  ? 'ZSP deaktivieren'
                                  : 'ZSP aktivieren',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
          if (selectedLocation != null) ...[
            const SizedBox(height: 26),
            Row(
              children: [
                Icon(
                  Icons.grid_view_rounded,
                  size: 21,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Bezirke',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '$activeDistrictCount aktiv',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    icon: Icons.route_outlined,
                    value: '${selectedDistricts.length}',
                    label: 'Gesamt',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MiniStat(
                    icon: Icons.check_circle_outline,
                    value: '$activeDistrictCount',
                    label: 'Aktiv',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MiniStat(
                    icon: Icons.shield_outlined,
                    value: '$safeDistrictCount',
                    label: 'Sicher',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Deaktivierte Bezirke bleiben in alten Statistiken erhalten und werden bei neuen Einträgen nicht mehr angeboten.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            if (selectedDistricts.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    children: [
                      Icon(
                        Icons.route_outlined,
                        size: 34,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Noch keine Bezirke',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Füge den ersten Bezirk für ${selectedLocation.name} hinzu.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              for (final district in selectedDistricts) ...[
                _DistrictCard(
                  district: district,
                  onSafeChanged: (value) => ref
                      .read(districtProvider.notifier)
                      .setCanDriveSafely(district, value),
                  onEdit: () => _editDistrict(context, district),
                  onToggleActive: () => ref
                      .read(districtProvider.notifier)
                      .setActive(district, !district.isActive),
                ),
                const SizedBox(height: 10),
              ],
          ],
        ],
      ),
    );
  }

  Future<void> _addZsp(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ZSP hinzufügen'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'z. B. ZSP Schweinfurt'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Hinzufügen'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    try {
      final location = ZspLocation(id: const Uuid().v4(), name: name);
      await ref.read(zspProvider.notifier).addLocation(location);
      if (mounted) setState(() => _selectedZspId = location.id);
    } catch (_) {
      _message('Das ZSP konnte nicht hinzugefügt werden. Möglicherweise gibt es den Namen schon.');
    }
  }

  Future<void> _addDistrict(BuildContext context, ZspLocation location) async {
    final numberController = TextEditingController();
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Bezirk zu ${location.name} hinzufügen'),
        content: TextField(
          controller: numberController,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Bezirksnummer'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
          FilledButton(
            onPressed: () => Navigator.pop(context, int.tryParse(numberController.text.trim())),
            child: const Text('Hinzufügen'),
          ),
        ],
      ),
    );
    numberController.dispose();
    if (result == null || result <= 0) return;
    try {
      await ref.read(districtProvider.notifier).addDistrict(
            District(number: result, zspId: location.id),
          );
    } catch (_) {
      _message('Bezirk $result existiert in diesem ZSP bereits.');
    }
  }

  Future<void> _editDistrict(BuildContext context, District district) async {
    final numberController = TextEditingController(text: '${district.number}');
    final noteController = TextEditingController(text: district.note ?? '');
    var canDriveSafely = district.canDriveSafely;

    final replacement = await showDialog<District>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Bezirk ${district.number} bearbeiten'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: numberController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Bezirksnummer'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Notiz'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Sicher fahrbar'),
                value: canDriveSafely,
                onChanged: (value) => setDialogState(() => canDriveSafely = value),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
            FilledButton(
              onPressed: () {
                final number = int.tryParse(numberController.text.trim());
                if (number == null || number <= 0) return;
                Navigator.pop(
                  context,
                  District(
                    number: number,
                    zspId: district.zspId,
                    isActive: district.isActive,
                    canDriveSafely: canDriveSafely,
                    note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                  ),
                );
              },
              child: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );
    numberController.dispose();
    noteController.dispose();
    if (replacement == null) return;
    try {
      await ref.read(districtProvider.notifier).replaceDistrictDefinition(
            original: district,
            replacement: replacement,
          );
    } catch (_) {
      _message('Die Änderung konnte nicht gespeichert werden. Die Bezirksnummer ist möglicherweise bereits vergeben.');
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 19,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _DistrictCard extends StatelessWidget {
  const _DistrictCard({
    required this.district,
    required this.onSafeChanged,
    required this.onEdit,
    required this.onToggleActive,
  });

  final District district;
  final ValueChanged<bool> onSafeChanged;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusText = district.isActive
        ? district.canDriveSafely
            ? 'Aktiv · sicher fahrbar'
            : 'Aktiv'
        : 'Deaktiviert · alte Daten bleiben erhalten';

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 13, 6, 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: district.isActive
                    ? theme.colorScheme.primaryContainer.withValues(alpha: 0.78)
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                '${district.number}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: district.isActive
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bezirk ${district.number}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      decoration:
                          district.isActive ? null : TextDecoration.lineThrough,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    district.note?.isNotEmpty == true
                        ? district.note!
                        : statusText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (district.note?.isNotEmpty == true) ...[
                    const SizedBox(height: 5),
                    Text(
                      statusText,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tooltip(
              message: 'Sicher fahrbar',
              child: Switch.adaptive(
                value: district.canDriveSafely,
                onChanged: district.isActive ? onSafeChanged : null,
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Bezirk verwalten',
              onSelected: (value) {
                if (value == 'edit') onEdit();
                if (value == 'toggle') onToggleActive();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Text('Bearbeiten'),
                ),
                PopupMenuItem(
                  value: 'toggle',
                  child: Text(
                    district.isActive ? 'Deaktivieren' : 'Aktivieren',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
