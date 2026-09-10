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
    final locationsAsync = ref.watch(zspProvider);
    final districtsAsync = ref.watch(districtProvider);

    if (locationsAsync.isLoading || districtsAsync.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (locationsAsync.hasError || districtsAsync.hasError) {
      return Scaffold(
        appBar: AppBar(title: const Text('ZSP & Bezirke')),
        body: Center(
          child: FilledButton.icon(
            onPressed: () {
              ref.invalidate(zspProvider);
              ref.invalidate(districtProvider);
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Erneut versuchen'),
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
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          DropdownButtonFormField<String>(
            initialValue: selectedLocation?.id,
            decoration: const InputDecoration(
              labelText: 'ZSP auswählen',
              border: OutlineInputBorder(),
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
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.location_on_outlined),
                    title: Text(selectedLocation.name),
                    subtitle: Text(
                      selectedLocation.isDefault
                          ? 'Dein Standard-ZSP'
                          : selectedLocation.isActive
                              ? 'Aktiver Standort'
                              : 'Deaktivierter Standort',
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'default') {
                          await ref.read(zspProvider.notifier).setDefault(selectedLocation.id);
                        } else if (value == 'toggle') {
                          if (selectedLocation.isDefault && selectedLocation.isActive) {
                            _message('Das Standard-ZSP kann nicht deaktiviert werden. Wähle zuerst ein anderes Standard-ZSP.');
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
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Bezirke',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Text('${selectedDistricts.where((d) => d.isActive).length} aktiv'),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Deaktivierte Bezirke bleiben in alten Statistiken erhalten und werden nur bei neuen Einträgen nicht mehr angeboten.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            if (selectedDistricts.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Für dieses ZSP sind noch keine Bezirke angelegt.'),
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
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Text('${district.number}')),
        title: Text(
          'Bezirk ${district.number}',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            decoration: district.isActive ? null : TextDecoration.lineThrough,
          ),
        ),
        subtitle: Text(
          district.note?.isNotEmpty == true
              ? district.note!
              : district.isActive
                  ? district.canDriveSafely
                      ? 'Aktiv · sicher fahrbar'
                      : 'Aktiv'
                  : 'Deaktiviert · alte Daten bleiben erhalten',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(value: district.canDriveSafely, onChanged: district.isActive ? onSafeChanged : null),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') onEdit();
                if (value == 'toggle') onToggleActive();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Bearbeiten')),
                PopupMenuItem(
                  value: 'toggle',
                  child: Text(district.isActive ? 'Deaktivieren' : 'Aktivieren'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
