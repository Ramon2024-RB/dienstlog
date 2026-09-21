import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../models/advertising.dart';
import '../../services/advertising_provider.dart';

class AdvertisingPage extends ConsumerWidget {
  const AdvertisingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final advertisingsAsync = ref.watch(advertisingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Werbung',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAdvertisingDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Werbung'),
      ),
      body: advertisingsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 44,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 14),
                const Text(
                  'Werbungen konnten nicht geladen werden.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    ref.read(advertisingProvider.notifier).reload();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Erneut versuchen'),
                ),
              ],
            ),
          ),
        ),
        data: (advertisings) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color:
                      theme.colorScheme.primaryContainer.withValues(alpha: 0.42),
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
                        Icons.campaign_outlined,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Deine Werbungen',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Verwalte Werbungen, die du bei der Zustellung schnell auswählen kannst.',
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
                    Icons.campaign_outlined,
                    size: 21,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Gespeicherte Werbung',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (advertisings.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${advertisings.length}',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Diese Einträge stehen dir beim Erfassen eines Arbeitstags und beim Zustellungsbeginn zur Auswahl.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              if (advertisings.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                    child: Column(
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer
                                .withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(
                            Icons.campaign_outlined,
                            color: theme.colorScheme.onPrimaryContainer,
                            size: 30,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Noch keine Werbung gespeichert',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 7),
                        Text(
                          'Lege Werbungen an, damit du sie später mit wenigen Fingertipps auswählen kannst.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: () =>
                              _showAdvertisingDialog(context, ref),
                          icon: const Icon(Icons.add),
                          label: const Text('Werbung hinzufügen'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Card(
                  child: Column(
                    children: [
                      for (var index = 0;
                          index < advertisings.length;
                          index++) ...[
                        _AdvertisingTile(
                          advertising: advertisings[index],
                          onEdit: () => _showAdvertisingDialog(
                            context,
                            ref,
                            advertising: advertisings[index],
                          ),
                          onDelete: () => _deleteAdvertising(
                            context,
                            ref,
                            advertisings[index],
                          ),
                        ),
                        if (index != advertisings.length - 1)
                          const Divider(height: 1),
                      ],
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showAdvertisingDialog(
    BuildContext context,
    WidgetRef ref, {
    Advertising? advertising,
  }) async {
    final controller = TextEditingController(
      text: advertising?.name ?? '',
    );

    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            advertising == null
                ? 'Werbung hinzufügen'
                : 'Werbung bearbeiten',
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'z. B. Einkauf Aktuell',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (value) {
              final trimmed = value.trim();
              if (trimmed.isNotEmpty) {
                Navigator.pop(context, trimmed);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () {
                final trimmed = controller.text.trim();
                if (trimmed.isNotEmpty) {
                  Navigator.pop(context, trimmed);
                }
              },
              child: const Text('Speichern'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (name == null || !context.mounted) {
      return;
    }

    try {
      if (advertising == null) {
        await ref.read(advertisingProvider.notifier).addAdvertising(
              Advertising(
                id: const Uuid().v4(),
                name: name,
              ),
            );
      } else {
        await ref.read(advertisingProvider.notifier).updateAdvertising(
              advertising.copyWith(name: name),
            );
      }
    } catch (_) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Diese Werbung ist bereits vorhanden oder konnte nicht gespeichert werden.',
          ),
        ),
      );
    }
  }

  Future<void> _deleteAdvertising(
    BuildContext context,
    WidgetRef ref,
    Advertising advertising,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Werbung löschen?'),
          content: Text(
            '„${advertising.name}“ wird aus deiner Werbungs-Liste gelöscht. '
            'Bereits gespeicherte Arbeitstage bleiben unverändert.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Löschen'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await ref
        .read(advertisingProvider.notifier)
        .deleteAdvertising(advertising.id);
  }
}

class _AdvertisingTile extends StatelessWidget {
  const _AdvertisingTile({
    required this.advertising,
    required this.onEdit,
    required this.onDelete,
  });

  final Advertising advertising;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(16, 9, 8, 9),
      leading: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          Icons.campaign_outlined,
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
      title: Text(
        advertising.name,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        'Für die Schnellauswahl gespeichert',
        style: TextStyle(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: PopupMenuButton<String>(
        tooltip: 'Werbung verwalten',
        onSelected: (value) {
          if (value == 'edit') {
            onEdit();
          } else if (value == 'delete') {
            onDelete();
          }
        },
        itemBuilder: (context) => const [
          PopupMenuItem(
            value: 'edit',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.edit_outlined),
              title: Text('Bearbeiten'),
            ),
          ),
          PopupMenuItem(
            value: 'delete',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.delete_outline),
              title: Text('Löschen'),
            ),
          ),
        ],
      ),
      onTap: onEdit,
    );
  }
}
