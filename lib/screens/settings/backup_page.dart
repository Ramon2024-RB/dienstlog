import 'package:flutter/material.dart';

import '../../services/backup_service.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  bool _isExportingBackup = false;
  bool _isImportingBackup = false;

  Future<void> _exportBackup() async {
    setState(() {
      _isExportingBackup = true;
    });

    try {
      final box = context.findRenderObject() as RenderBox?;

      final sharePositionOrigin = box == null
          ? const Rect.fromLTWH(1, 1, 1, 1)
          : box.localToGlobal(Offset.zero) & box.size;

      await BackupService.instance.shareBackup(
        sharePositionOrigin: sharePositionOrigin,
      );

      if (!mounted) {
        return;
      }

      _showMessage('Backup wurde erstellt.');
    } catch (error, stackTrace) {
      debugPrint('BACKUP EXPORT ERROR: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Backup-Fehler'),
            content: SelectableText(error.toString()),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    } finally {
      if (mounted) {
        setState(() {
          _isExportingBackup = false;
        });
      }
    }
  }

  Future<void> _importBackup() async {
    final path = await BackupService.instance.pickBackupFile();

    if (path == null || !mounted) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Backup importieren?'),
          content: const Text(
            'Beim Import werden die aktuell in TourLog gespeicherten Daten '
            'vollständig durch die Daten aus dem Backup ersetzt.\n\n'
            'Erstelle vorher ein Backup, wenn du die aktuellen Daten behalten möchtest.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Importieren'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isImportingBackup = true;
    });

    try {
      await BackupService.instance.importBackupFile(path);

      if (!mounted) {
        return;
      }

      _showMessage('Backup erfolgreich importiert.');
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Backup konnte nicht importiert werden. '
        'Bitte prüfe, ob es eine gültige TourLog-Backup-Datei ist.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isImportingBackup = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isBusy = _isExportingBackup || _isImportingBackup;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Daten & Backup',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
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
                    Icons.backup_outlined,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Deine TourLog-Daten',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Sichere deine Daten als Datei und stelle sie bei Bedarf wieder her.',
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
                Icons.shield_outlined,
                size: 21,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 9),
              Text(
                'Datensicherung',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            'Ein Backup enthält deine in TourLog gespeicherten Daten und kann später wieder importiert werden.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Column(
              children: [
                _BackupTile(
                  icon: Icons.ios_share_outlined,
                  title: 'Backup exportieren',
                  subtitle: 'Aktuelle TourLog-Daten als Backup-Datei sichern',
                  isLoading: _isExportingBackup,
                  onTap: isBusy ? null : _exportBackup,
                ),
                const Divider(height: 1),
                _BackupTile(
                  icon: Icons.settings_backup_restore_outlined,
                  title: 'Backup importieren',
                  subtitle: 'Gesicherte TourLog-Daten wiederherstellen',
                  isLoading: _isImportingBackup,
                  onTap: isBusy ? null : _importBackup,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.38),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 21,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    'Beim Import werden die aktuell gespeicherten TourLog-Daten vollständig durch das ausgewählte Backup ersetzt. Erstelle deshalb vor einem Import am besten zuerst ein aktuelles Backup.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BackupTile extends StatelessWidget {
  const _BackupTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isLoading,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
      enabled: onTap != null || isLoading,
      leading: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          icon,
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Text(subtitle),
      ),
      trailing: isLoading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
