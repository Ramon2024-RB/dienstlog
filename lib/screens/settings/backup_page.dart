import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../services/app_database.dart';
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
    if (_isExportingBackup || _isImportingBackup) return;

    setState(() => _isExportingBackup = true);

    try {
      final box = context.findRenderObject() as RenderBox?;
      final sharePositionOrigin = box == null
          ? const Rect.fromLTWH(1, 1, 1, 1)
          : box.localToGlobal(Offset.zero) & box.size;

      await BackupService.instance.shareBackup(
        sharePositionOrigin: sharePositionOrigin,
      );

      if (!mounted) return;
      _showMessage(
        'Backup-Datei erstellt. Bitte prüfe, ob du sie in „Dateien“ '
        'oder an einem anderen sicheren Ort gespeichert hast.',
      );
    } catch (error, stackTrace) {
      debugPrint('BACKUP EXPORT ERROR: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Backup-Fehler'),
          content: SelectableText(error.toString()),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _isExportingBackup = false);
    }
  }

  Future<void> _importBackup() async {
    if (_isImportingBackup || _isExportingBackup) return;
    setState(() => _isImportingBackup = true);

    try {
      final path = await BackupService.instance.pickBackupFile();
      if (path == null || !mounted) return;

      // Nur lesen: Bis zur ausdrücklichen Bestätigung wird nichts importiert.
      final preview = await _readBackupPreview(path);
      if (!mounted) return;

      final confirmed = await _confirmImport(preview);
      if (confirmed != true || !mounted) return;

      // Die tiefergehende Datenprüfung erfolgt zusätzlich im Datenbank-Import.
      await BackupService.instance.importBackupFile(path);
      if (!mounted) return;

      _showMessage('Backup erfolgreich importiert.');
    } on FormatException catch (error) {
      if (!mounted) return;
      await _showImportError(error.message);
    } catch (error, stackTrace) {
      debugPrint('BACKUP IMPORT ERROR: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      await _showImportError(
        'Das Backup konnte nicht importiert werden. '
        'Deine Daten sollten bei einem Datenbankfehler durch die '
        'Transaktion geschützt sein. Bitte prüfe die Datei.',
      );
    } finally {
      if (mounted) setState(() => _isImportingBackup = false);
    }
  }

  Future<_BackupPreview> _readBackupPreview(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw const FormatException(
        'Die ausgewählte Datei wurde nicht gefunden.',
      );
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(await file.readAsString());
    } on FormatException {
      throw const FormatException('Die Datei enthält kein gültiges JSON.');
    }

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Dies ist keine gültige TourLog-Backup-Datei.',
      );
    }
    // Genau dieselbe vollständige, rein lesende Prüfung wie beim Import.
    // Sie verändert keine gespeicherten TourLog-Daten.
    final backup = Map<String, Object?>.from(decoded);
    final counts = AppDatabase.instance.inspectBackupData(backup);
    final databaseVersion = backup['database_version'];

    DateTime? createdAt;
    if (decoded['created_at'] is String) {
      createdAt = DateTime.tryParse(decoded['created_at'] as String)?.toLocal();
    }

    return _BackupPreview(
      createdAt: createdAt,
      databaseVersion: databaseVersion is int ? databaseVersion : null,
      counts: counts,
    );
  }

  Future<bool?> _confirmImport(_BackupPreview preview) async {
    var acknowledged = false;

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, updateDialog) => AlertDialog(
          title: const Text('Backup überprüfen'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Inhalt der ausgewählten Sicherung:',
                  style: Theme.of(dialogContext).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                _PreviewDetail(label: 'Erstellt', value: preview.createdAtText),
                _PreviewDetail(
                  label: 'Datenbankversion',
                  value: preview.databaseVersion?.toString() ?? 'Unbekannt',
                ),
                _PreviewDetail(
                  label: 'Arbeitstage',
                  value: '${preview.count('work_days')}',
                ),
                _PreviewDetail(
                  label: 'Bezirke',
                  value: '${preview.count('districts')}',
                ),
                _PreviewDetail(
                  label: 'Dienstplaneinträge',
                  value: '${preview.count('work_schedule_entries')}',
                ),
                _PreviewDetail(
                  label: 'Eigene Touren',
                  value: '${preview.count('own_tour_entries')}',
                ),
                _PreviewDetail(
                  label: 'Unterstützungseinträge',
                  value: '${preview.count('support_entries')}',
                ),
                const SizedBox(height: 14),
                if (preview.count('work_days') == 0) ...[
                  Text(
                    'Achtung: Diese Sicherung enthält keine Arbeitstage.',
                    style: TextStyle(
                      color: Theme.of(dialogContext).colorScheme.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                Text(
                  'ACHTUNG: Beim Import werden ALLE aktuell gespeicherten '
                  'TourLog-Daten vollständig durch dieses Backup ersetzt. '
                  'Das lässt sich nicht rückgängig machen.',
                  style: TextStyle(
                    color: Theme.of(dialogContext).colorScheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sichere deine aktuellen Daten zuerst separat. '
                  'Die Vorschau ist eine erste Prüfung, kein vollständiger '
                  'Wiederherstellungstest.',
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: acknowledged,
                  onChanged: (value) =>
                      updateDialog(() => acknowledged = value ?? false),
                  title: const Text(
                    'Ich verstehe, dass alle bisherigen Daten ersetzt werden.',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: acknowledged
                  ? () => Navigator.pop(dialogContext, true)
                  : null,
              child: const Text('Daten ersetzen'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showImportError(String message) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Backup konnte nicht importiert werden'),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
            'Ein Backup enthält die in der TourLog-Datenbank gespeicherten '
            'Arbeits- und Planungsdaten.',
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
                  subtitle:
                      'Backup zuerst ansehen, dann Wiederherstellung bestätigen',
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
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.38,
              ),
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
                const Expanded(
                  child: Text(
                    'Beim Import werden alle aktuell gespeicherten '
                    'TourLog-Daten ersetzt. Erstelle zuvor ein neues Backup '
                    'und bewahre es außerhalb der App auf.',
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

class _BackupPreview {
  const _BackupPreview({
    required this.createdAt,
    required this.databaseVersion,
    required this.counts,
  });

  final DateTime? createdAt;
  final int? databaseVersion;
  final Map<String, int> counts;

  int count(String table) => counts[table] ?? 0;

  String get createdAtText {
    final value = createdAt;
    if (value == null) return 'Unbekannt';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(value.day)}.${two(value.month)}.${value.year}, '
        '${two(value.hour)}:${two(value.minute)}';
  }
}

class _PreviewDetail extends StatelessWidget {
  const _PreviewDetail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
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
        child: Icon(icon, color: theme.colorScheme.onPrimaryContainer),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
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
