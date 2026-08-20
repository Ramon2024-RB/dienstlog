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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daten & Backup'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(
            'Datensicherung',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Sichere deine TourLog-Daten als Datei oder stelle sie aus einem Backup wieder her.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.ios_share_outlined),
                  title: const Text('Backup exportieren'),
                  subtitle: const Text(
                    'Alle TourLog-Daten als Backup-Datei sichern',
                  ),
                  trailing: _isExportingBackup
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: _isExportingBackup || _isImportingBackup
                      ? null
                      : _exportBackup,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.settings_backup_restore_outlined),
                  title: const Text('Backup importieren'),
                  subtitle: const Text(
                    'Gesicherte TourLog-Daten wiederherstellen',
                  ),
                  trailing: _isImportingBackup
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: _isExportingBackup || _isImportingBackup
                      ? null
                      : _importBackup,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
