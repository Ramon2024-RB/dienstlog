import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/calendar/calendar_page.dart';
import 'screens/home/home_page.dart';
import 'screens/quick_entry/quick_entry_card.dart';
import 'screens/districts/districts_page.dart';
import 'screens/statistics/statistics_page.dart';
import 'screens/settings/advertising_page.dart';
import 'screens/settings/settings_page.dart';
import 'screens/settings/work_times_page.dart';
import 'screens/settings/backup_page.dart';
import 'screens/work_schedule/work_schedule_page.dart';

void main() {
  runApp(
    const ProviderScope(
      child: TourLogApp(),
    ),
  );
}

class TourLogApp extends StatelessWidget {
  const TourLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TourLog',
      debugShowCheckedModeBanner: false,
      locale: const Locale('de', 'DE'),
      supportedLocales: const [
        Locale('de', 'DE'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFCC00),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        cardTheme: const CardThemeData(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFCC00),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        cardTheme: const CardThemeData(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      themeMode: ThemeMode.system,
      home: const MainNavigationPage(),
    );
  }
}

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() =>
      _MainNavigationPageState();
}

class _MainNavigationPageState
    extends State<MainNavigationPage> {
  int _selectedIndex = 0;
  QuickEntryExternalAction? _externalQuickAction;

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initializeDeepLinks();
  }

  Future<void> _initializeDeepLinks() async {
    try {
      final initialLink = await _appLinks.getInitialLink();

      if (initialLink != null && mounted) {
        _handleDeepLink(initialLink);
      }
    } catch (_) {
      // TourLog startet normal weiter, falls kein
      // Initial-Link verfügbar ist.
    }

    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        if (mounted) {
          _handleDeepLink(uri);
        }
      },
    );
  }

  void _handleDeepLink(Uri uri) {
    if (uri.scheme != 'tourlog') {
      return;
    }

    final command =
        uri.host == 'quick' && uri.pathSegments.isNotEmpty
        ? uri.pathSegments.first
        : uri.pathSegments.isNotEmpty
        ? uri.pathSegments.last
        : null;

    QuickEntryExternalAction? action;

    switch (command) {
      case 'work-start':
        action = QuickEntryExternalAction.workStart;
        break;
      case 'delivery-start':
        action = QuickEntryExternalAction.deliveryStart;
        break;
      case 'delivery-end':
        action = QuickEntryExternalAction.deliveryEnd;
        break;
      case 'work-end':
        action = QuickEntryExternalAction.workEnd;
        break;
    }

    if (action == null) {
      return;
    }

    setState(() {
      _selectedIndex = 0;
      _externalQuickAction = action;
    });
  }

  void _onExternalQuickActionHandled() {
    if (!mounted) {
      return;
    }

    setState(() {
      _externalQuickAction = null;
    });
  }

  void _onDestinationSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomePage(
        externalQuickAction: _externalQuickAction,
        onExternalQuickActionHandled:
            _onExternalQuickActionHandled,
      ),
      const WorkSchedulePage(),
      const CalendarPage(),
      const StatisticsPage(),
      const _MorePage(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Startseite',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(Icons.event_note),
            label: 'Arbeitsplan',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Kalender',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Statistik',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz),
            selectedIcon: Icon(Icons.more_horiz),
            label: 'Mehr',
          ),
        ],
      ),
    );
  }
}

class _MorePage extends StatelessWidget {
  const _MorePage();

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mehr',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          20,
          16,
          20,
          32,
        ),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.route_outlined,
                  ),
                  title: const Text(
                    'ZSP & Bezirke',
                  ),
                  subtitle: const Text(
                    'Standorte und Bezirke verwalten',
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) =>
                            const DistrictsPage(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.campaign_outlined,
                  ),
                  title: const Text(
                    'Werbung',
                  ),
                  subtitle: const Text(
                    'Gespeicherte Werbungen verwalten',
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) =>
                            const AdvertisingPage(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.schedule_outlined,
                  ),
                  title: const Text(
                    'Arbeitszeiten',
                  ),
                  subtitle: const Text(
                    'Sollzeiten und Pausen verwalten',
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) =>
                            const WorkTimesPage(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.backup_outlined,
                  ),
                  title: const Text(
                    'Daten & Backup',
                  ),
                  subtitle: const Text(
                    'Daten exportieren und wiederherstellen',
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) =>
                            const BackupPage(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.settings_outlined,
                  ),
                  title: const Text(
                    'Einstellungen',
                  ),
                  subtitle: const Text(
                    'Allgemeine App-Einstellungen',
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) =>
                            const SettingsPage(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
