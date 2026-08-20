import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../models/advertising.dart';
import '../../services/advertising_provider.dart';

class AdvertisingPage extends ConsumerWidget {
  const AdvertisingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final advertisingsAsync = ref.watch(advertisingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Werbung'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAdvertisingDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Hinzufügen'),
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
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 12),
                const Text(
                  'Werbungen konnten nicht geladen werden.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () {
                    ref.read(advertisingProvider.notifier).reload();
                  },
                  child: const Text('Erneut versuchen'),
                ),
              ],
            ),
          ),
        ),
        data: (advertisings) {
          if (advertisings.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.campaign_outlined,
                      size: 64,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Noch keine Werbung gespeichert',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Lege Werbungen an, die du bei einem Arbeitstag schnell auswählen kannst.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: advertisings.length,
            separatorBuilder: (context, index) =>
                const Divider(height: 1),
            itemBuilder: (context, index) {
              final advertising = advertisings[index];

              return ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.campaign_outlined),
                ),
                title: Text(advertising.name),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showAdvertisingDialog(
                        context,
                        ref,
                        advertising: advertising,
                      );
                    } else if (value == 'delete') {
                      _deleteAdvertising(
                        context,
                        ref,
                        advertising,
                      );
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
                onTap: () => _showAdvertisingDialog(
                  context,
                  ref,
                  advertising: advertising,
                ),
              );
            },
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
