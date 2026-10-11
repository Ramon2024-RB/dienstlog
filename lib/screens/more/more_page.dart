import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../districts/districts_page.dart';
import '../onboarding/onboarding_page.dart';
import '../settings/advertising_page.dart';
import '../settings/backup_page.dart';
import '../settings/settings_page.dart';
import '../settings/work_times_page.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  static final Uri _supportEmail = Uri(
    scheme: 'mailto',
    path: 'logworks.support@gmail.com',
    query: _encodeQueryParameters({
      'subject': 'TourLog – Supportanfrage',
      'body': 'Hallo LogWorks-Team,\n\n'
          'Ich habe eine Frage oder ein Problem mit TourLog:\n\n'
          '[Bitte beschreibe dein Anliegen hier.]\n\n'
          'Vielen Dank!\n',
    }),
  );

  static String _encodeQueryParameters(Map<String, String> params) => params.entries
      .map((entry) =>
          '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value)}')
      .join('&');

  Future<void> _contactSupport(BuildContext context) async {
    try {
      final launched = await launchUrl(
        _supportEmail,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        _showEmailFallback(context);
      }
    } catch (_) {
      if (context.mounted) _showEmailFallback(context);
    }
  }

  void _showEmailFallback(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Keine E-Mail-App verfügbar'),
        content: const SelectableText(
          'Bitte richte eine E-Mail-App auf deinem iPhone ein oder schreibe direkt an:\n\n'
          'logworks.support@gmail.com',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Schließen'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mehr',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const _MoreHeader(),
          const SizedBox(height: 24),
          const _SectionTitle(
            icon: Icons.route_outlined,
            title: 'Zustellung',
          ),
          const SizedBox(height: 10),
          _SettingsGroup(
            children: [
              _MoreTile(
                icon: Icons.route_outlined,
                title: 'ZSP & Bezirke',
                subtitle: 'Standorte und Bezirke verwalten',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => const DistrictsPage(),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              _MoreTile(
                icon: Icons.campaign_outlined,
                title: 'Werbung',
                subtitle: 'Gespeicherte Werbungen verwalten',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => const AdvertisingPage(),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              _MoreTile(
                icon: Icons.schedule_outlined,
                title: 'Arbeitszeiten',
                subtitle: 'Sollzeiten und Pausen verwalten',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => const WorkTimesPage(),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _SectionTitle(
            icon: Icons.help_outline,
            title: 'Hilfe & Support',
          ),
          const SizedBox(height: 10),
          _SettingsGroup(
            children: [
              _MoreTile(
                icon: Icons.help_outline,
                title: 'Hilfe & Einführung',
                subtitle: 'TourLog kennenlernen und Einrichtung ansehen',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const OnboardingPage(helpMode: true),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              _MoreTile(
                icon: Icons.mail_outline,
                title: 'Kontakt zum Entwickler',
                subtitle: 'Fragen, Fehler melden oder Feedback senden',
                onTap: () => _contactSupport(context),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'Deine Arbeitsdaten und Backups werden nicht automatisch mitgesendet.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          const SizedBox(height: 24),
          const _SectionTitle(
            icon: Icons.tune_outlined,
            title: 'App & Daten',
          ),
          const SizedBox(height: 10),
          _SettingsGroup(
            children: [
              _MoreTile(
                icon: Icons.backup_outlined,
                title: 'Daten & Backup',
                subtitle: 'Daten exportieren und wiederherstellen',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => const BackupPage(),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              _MoreTile(
                icon: Icons.settings_outlined,
                title: 'Einstellungen',
                subtitle: 'Analysen und allgemeine App-Einstellungen',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => const SettingsPage(),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MoreHeader extends StatelessWidget {
  const _MoreHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
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
              Icons.tune_outlined,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TourLog verwalten',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Passe Zustellung, Arbeitszeiten, Daten und Analysen an.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(
          icon,
          size: 21,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 9),
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(children: children),
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(16, 8, 10, 8),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(13),
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
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
