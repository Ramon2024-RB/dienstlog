import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/district_provider.dart';
import '../../services/zsp_provider.dart';
import '../districts/districts_page.dart';
import '../settings/backup_page.dart';
import '../settings/work_times_page.dart';

// Only demo state lives on this screen. Nothing in the preview writes to SQLite.
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key, this.helpMode = false, this.onFinish});

  final bool helpMode;
  final Future<void> Function()? onFinish;

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  static const _gold = Color(0xFFE6B85C);
  static const _background = Color(0xFF101216);
  static const _surface = Color(0xFF1D222A);
  static const _muted = Color(0xFFADB1BA);
  static const _steps = 11; // 8 guide pages + ZSP, districts, work times
  static const _guideCount = 8;

  int _page = 0;
  bool _busy = false;
  bool _initialized = false;
  final List<bool> _demoTimes = [true, true, false, false];
  int _selectedDelivery = 0;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _restoreProgress();
  }

  Future<void> _restoreProgress() async {
    if (widget.helpMode) {
      if (mounted) setState(() => _initialized = true);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _page = (prefs.getInt('tourlog_onboarding_step_v1') ?? 0)
          .clamp(0, _steps - 1);
      _initialized = true;
    });
  }

  Future<void> _go(int target) async {
    if (_busy) return;
    final next = target.clamp(0, _steps - 1);
    if (!widget.helpMode) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('tourlog_onboarding_step_v1', next);
    }
    if (!mounted) return;
    setState(() {
      _page = next;
      _expanded = false;
    });
  }

  Future<void> _finish() async {
    if (widget.helpMode) {
      Navigator.of(context).pop();
      return;
    }
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onFinish?.call();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => page),
    );
    ref.invalidate(zspProvider);
    ref.invalidate(districtProvider);
    if (mounted) setState(() {});
  }

  Widget _card({required Widget child, EdgeInsetsGeometry? padding}) =>
      Container(
        width: double.infinity,
        padding: padding ?? const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: child,
      );

  Widget _heading(String eyebrow, String title, String description) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(eyebrow, style: const TextStyle(color: _gold, fontSize: 11,
              fontWeight: FontWeight.w800, letterSpacing: 1.8)),
          const SizedBox(height: 9),
          Text(title, style: const TextStyle(fontSize: 28, height: 1.14,
              fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 12),
          Text(description, style: const TextStyle(fontSize: 14,
              height: 1.5, color: _muted)),
        ],
      );

  Widget _detail(String text) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(text, style: const TextStyle(color: _muted,
            fontSize: 13, height: 1.55)),
      );

  Widget _more(String text) => _card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(children: [
              const Icon(Icons.info_outline, color: _gold, size: 19),
              const SizedBox(width: 9),
              const Expanded(child: Text('Mehr erfahren', style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700))),
              Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: _gold),
            ]),
          ),
          AnimatedSize(duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: _expanded ? _detail(text) : const SizedBox.shrink()),
        ]),
      );

  Widget _featureTile(IconData icon, String title, String subtitle) =>
      _card(child: Row(children: [
        Container(padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: _gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: _gold)),
        const SizedBox(width: 13),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text(title, style: const TextStyle(color: Colors.white,
              fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(subtitle, style: const TextStyle(color: _muted, fontSize: 12)),
        ])),
      ]));

  Widget _welcome() => Column(children: [
        _card(child: Column(children: [
          const SizedBox(height: 12),
          Container(width: 88, height: 88,
              decoration: BoxDecoration(color: _gold.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(27)),
              child: const Icon(Icons.local_shipping_outlined,
                  size: 47, color: _gold)),
          const SizedBox(height: 22),
          const Text('Willkommen bei TourLog', textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 26,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          const Text('Dein digitaler Begleiter für den Zustellalltag.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, height: 1.45)),
          const SizedBox(height: 22),
          Wrap(spacing: 9, runSpacing: 9, alignment: WrapAlignment.center,
              children: [
            _chip(Icons.access_time, 'Arbeitszeiten'),
            _chip(Icons.map_outlined, 'Bezirke'),
            _chip(Icons.calendar_month_outlined, 'Kalender'),
            _chip(Icons.bar_chart_outlined, 'Statistik'),
          ]),
          const SizedBox(height: 12),
        ])),
        const SizedBox(height: 14),
        _more('TourLog ist eine unabhängige, nicht offizielle App für '
            'Zusteller der Deutschen Post. Deine Einträge werden lokal '
            'gespeichert. Du kannst sie später exportieren und sichern.'),
        if (!widget.helpMode) ...[
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () => _open(const BackupPage()),
            icon: const Icon(Icons.settings_backup_restore),
            label: const Text('Vorhandenes Backup importieren'),
          ),
        ],
      ]);

  Widget _chip(IconData icon, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: const Color(0xFF2B3038),
            borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: _gold),
          const SizedBox(width: 7),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ]),
      );

  Widget _workTimes() {
    const labels = ['Dienstbeginn', 'Zustellbeginn', 'Zustellende', 'Feierabend'];
    const values = ['07:15', '08:10', '14:25', '15:10'];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _heading('DEIN ARBEITSTAG', 'Jede Minute im Blick.',
          'Tippe auf einen Eintrag, um eine Beispielbuchung zu setzen '
          'oder zu entfernen.'),
      const SizedBox(height: 22),
      _card(child: Column(children: [
        for (var i = 0; i < labels.length; i++) ...[
          InkWell(
            borderRadius: BorderRadius.circular(13),
            onTap: () => setState(() => _demoTimes[i] = !_demoTimes[i]),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 230),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _demoTimes[i] ? const Color(0xFF332D22) :
                    const Color(0xFF292E36),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Row(children: [
                Icon(_demoTimes[i] ? Icons.check_circle_outline :
                    Icons.radio_button_unchecked,
                    color: _demoTimes[i] ? _gold : _muted),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(labels[i], style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.w700)),
                  Text(_demoTimes[i] ? 'Beispielzeit erfasst' : 'Noch nicht erfasst',
                      style: const TextStyle(color: _muted, fontSize: 11)),
                ])),
                Text(_demoTimes[i] ? values[i] : '–:–',
                    style: TextStyle(color: _demoTimes[i] ? _gold : _muted,
                        fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
          if (i < labels.length - 1) const SizedBox(height: 9),
        ],
      ])),
      const SizedBox(height: 14),
      _more('Die vier Zeitpunkte bilden deinen Arbeitstag. '
          'Du kannst sie in TourLog nachtragen und korrigieren. '
          'Die interaktiven Zeiten hier sind nur Beispiele und werden '
          'niemals in deiner Datenbank gespeichert.'),
    ]);
  }

  Widget _delivery() {
    const names = ['Eigene Zustellung', 'Montagszustellung',
        'Paketfahrer', 'Unterstützung'];
    const descriptions = [
      'Erfasse ZSP, Bezirke, Pakete und bei Bedarf deinen A-/B-Teil.',
      'Dokumentiere die Montagszustellung mit deinen Bezirken und '
          'der gesamten Paketmenge.',
      'Halte Paketfahrertage mit Bezirken und Gesamtpaketmenge fest.',
      'Erfasse zusätzlich, wann und in welchen Bezirken du '
          'Kollegen unterstützt hast.',
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _heading('FLEXIBEL IM EINSATZ', 'Für deinen Zustellalltag.',
          'Wähle eine Zustellart und entdecke, was du damit erfassen kannst.'),
      const SizedBox(height: 20),
      for (var i = 0; i < names.length; i++) ...[
        InkWell(onTap: () => setState(() => _selectedDelivery = i),
          borderRadius: BorderRadius.circular(15),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 230),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: i == _selectedDelivery ? const Color(0xFF352D20) : _surface,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: i == _selectedDelivery ? _gold :
                  Colors.white.withValues(alpha: 0.06)),
            ),
            child: Row(children: [
              Expanded(child: Text(names[i], style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700))),
              Icon(i == _selectedDelivery ? Icons.check_circle_outline :
                  Icons.radio_button_unchecked,
                  color: i == _selectedDelivery ? _gold : _muted),
            ]),
          ),
        ),
        const SizedBox(height: 9),
      ],
      AnimatedSwitcher(duration: const Duration(milliseconds: 250),
        child: Padding(key: ValueKey(_selectedDelivery),
          padding: const EdgeInsets.only(top: 12),
          child: _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(names[_selectedDelivery], style: const TextStyle(
                color: _gold, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(descriptions[_selectedDelivery],
                style: const TextStyle(color: _muted, height: 1.5)),
          ])),
        ),
      ),
    ]);
  }

  Widget _support() => Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading('MEHR ALS NUR DIE TOUR', 'Alles dokumentiert.',
              'Auch Unterstützung und Werbung gehören zu deinem Arbeitsalltag.'),
          const SizedBox(height: 20),
          _featureTile(Icons.handshake_outlined, 'Unterstützung',
              'Zusätzliche Hilfe für andere Bezirke erfassen'),
          const SizedBox(height: 12),
          _featureTile(Icons.layers_outlined, 'Werbung',
              'Werbemengen und Einträge dokumentieren'),
          const SizedBox(height: 14),
          _more('Unterstützung wird getrennt von deiner eigenen Zustellung '
              'geführt. So bleiben deine Auswertungen nachvollziehbar. '
              'Werbung kannst du unabhängig davon verwalten.'),
        ]);

  Widget _planning() => Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading('PLANUNG & RÜCKBLICK', 'Deine Woche im Griff.',
              'Arbeitsplan und Kalender ergänzen deine tatsächliche Zeiterfassung.'),
          const SizedBox(height: 20),
          _card(child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
              const Text('BEISPIELWOCHE', style: TextStyle(color: _muted,
                  fontSize: 11, letterSpacing: 1.3)),
              Text('OKTOBER', style: TextStyle(color: _gold,
                  fontSize: 11, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 17),
            Row(children: [
              for (var i = 0; i < 5; i++)
                Expanded(child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Container(padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: i == 2 ? _gold.withValues(alpha: 0.18) :
                          const Color(0xFF292E36),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: i == 2 ? _gold :
                          Colors.transparent),
                    ),
                    child: Column(children: [
                      Text(['MO', 'DI', 'MI', 'DO', 'FR'][i],
                          style: const TextStyle(color: _muted, fontSize: 10)),
                      const SizedBox(height: 8),
                      Text('${12 + i}', style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Icon(i == 2 ? Icons.circle : Icons.circle_outlined,
                          color: _gold, size: 9),
                    ]),
                  ),
                )),
            ]),
          ])),
          const SizedBox(height: 14),
          _more('Der Arbeitsplan zeigt geplante Einsätze. '
              'Im Kalender findest du vergangene Einträge wieder. '
              'Geplante und tatsächlich erfasste Zeiten bleiben getrennt.'),
        ]);

  Widget _stats() {
    const metrics = [('18', 'Arbeitstage'), ('142 h', 'Arbeitszeit'),
      ('1.248', 'Pakete'), ('6', 'Bezirke')];
    const heights = [0.55, 0.81, 0.64, 0.98, 0.85];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _heading('DEINE AUSWERTUNG', 'Deine Leistung im Überblick.',
          'Beispieldaten zeigen dir, wie deine Statistiken aussehen können.'),
      const SizedBox(height: 18),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, childAspectRatio: 1.9,
            mainAxisSpacing: 10, crossAxisSpacing: 10),
        itemCount: metrics.length,
        itemBuilder: (context, i) => _card(padding: const EdgeInsets.all(13),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(metrics[i].$1, style: const TextStyle(color: _gold,
                fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(metrics[i].$2, style: const TextStyle(
                color: _muted, fontSize: 11)),
          ])),
      ),
      const SizedBox(height: 12),
      _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        const Text('Beispiel: Paketmengen pro Woche',
            style: TextStyle(color: Colors.white,
                fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 18),
        SizedBox(height: 135, child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < heights.length; i++)
              Expanded(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                  Expanded(child: Align(alignment: Alignment.bottomCenter,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: heights[i]),
                      duration: Duration(milliseconds: 550 + i * 120),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) => FractionallySizedBox(
                        heightFactor: value.clamp(0.01, 1.0),
                        child: Container(decoration: BoxDecoration(
                          color: i == 3 ? _gold : const Color(0xFF80683F),
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(7)),
                        )),
                      ),
                    ),
                  )),
                  const SizedBox(height: 9),
                  Text(['Mo', 'Di', 'Mi', 'Do', 'Fr'][i],
                      style: const TextStyle(color: _muted, fontSize: 11)),
                ]),
              )),
          ],
        )),
      ])),
      const SizedBox(height: 12),
      _more('TourLog wertet Arbeitszeiten, Paketmengen und Bezirke aus. '
          'Die verschiedenen Zustellarten werden getrennt betrachtet. '
          'Die Werte auf dieser Seite sind ausschließlich Beispieldaten.'),
    ]);
  }

  Widget _backup() => Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading('DEINE DATEN', 'Sicher ist sicher.',
              'Deine Einträge gehören dir. Exportiere sie regelmäßig '
              'und bewahre eine Sicherung außerhalb der App auf.'),
          const SizedBox(height: 20),
          _featureTile(Icons.phone_iphone, 'Lokal gespeichert',
              'Keine Anmeldung für die Nutzung erforderlich'),
          const SizedBox(height: 12),
          _featureTile(Icons.ios_share, 'Backup exportieren',
              'Sicherung über „Mehr → Daten & Backup“ erstellen'),
          const SizedBox(height: 12),
          _featureTile(Icons.settings_backup_restore, 'Wiederherstellen',
              'Vorhandene Daten aus einer Sicherung importieren'),
          const SizedBox(height: 14),
          _more('Eine Deinstallation kann lokale Daten löschen. '
              'Bewahre deine Sicherungsdatei deshalb außerhalb der App auf, '
              'zum Beispiel in iCloud Drive oder auf deinem Computer.'),
        ]);

  Widget _widgetGuide() => Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          _heading('DIREKT VOM HOMEBILDSCHIRM', 'Schneller mit dem Widget.',
              'Die wichtigsten Zeitpunkte kannst du bequem vom '
              'iPhone-Home-Bildschirm aus erfassen.'),
          const SizedBox(height: 20),
          _card(child: Column(children: [
            for (final entry in [
              ('Dienst beginnen', 'Direkt vormerken', Icons.play_arrow),
              ('Zustellung beginnen', 'Öffnet die Eingabemaske', Icons.route),
              ('Zustellung beenden', 'Direkt vormerken', Icons.check),
              ('Feierabend', 'Direkt vormerken', Icons.home_outlined),
            ]) ...[
              Row(children: [
                Icon(entry.$3, color: _gold, size: 22),
                const SizedBox(width: 12),
                Expanded(child: Text(entry.$1, style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700))),
                Flexible(child: Text(entry.$2, textAlign: TextAlign.end,
                    style: const TextStyle(color: _muted, fontSize: 11))),
              ]),
              const SizedBox(height: 18),
            ],
          ])),
          const SizedBox(height: 14),
          _more('Füge das TourLog-Widget über die Widget-Galerie von iOS '
              'hinzu. Direkt gebuchte Zeiten werden zunächst vorgemerkt '
              'und beim nächsten Öffnen der App übernommen.'),
        ]);

  Widget _setup(int index, bool hasZsp, bool hasDistrict,
      int zspCount, int districtCount) {
    final isZsp = index == 0;
    final isDistrict = index == 1;
    final title = isZsp ? 'Deinen ZSP einrichten.' :
        isDistrict ? 'Deine Bezirke hinzufügen.' : 'Deine Arbeitszeiten festlegen.';
    final description = isZsp
        ? 'Lege deinen Zustellstützpunkt an. Du kannst später weitere ZSP ergänzen.'
        : isDistrict
            ? 'Trage deine Zustellbezirke ein. Du kannst mehrere Bezirke verwalten.'
            : 'Hinterlege deine üblichen Sollarbeitszeiten und Pausen.';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _heading('DEINE EINRICHTUNG · 0${index + 1}/03', title, description),
      const SizedBox(height: 20),
      _card(child: Column(children: [
        Container(width: 70, height: 70,
          decoration: BoxDecoration(color: _gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(22)),
          child: Icon(isZsp ? Icons.location_on_outlined :
              isDistrict ? Icons.map_outlined : Icons.schedule_outlined,
              size: 36, color: _gold)),
        const SizedBox(height: 18),
        Text(isZsp
            ? (hasZsp ? '$zspCount ZSP vorhanden' : 'Noch kein ZSP eingerichtet')
            : isDistrict
                ? (hasDistrict ? '$districtCount Bezirke vorhanden' :
                    'Noch keine Bezirke eingerichtet')
                : 'Arbeitszeiten und Pausen einrichten',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white,
              fontWeight: FontWeight.w700)),
        const SizedBox(height: 17),
        SizedBox(width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _open(isZsp || isDistrict
                ? const DistrictsPage() : const WorkTimesPage()),
            icon: const Icon(Icons.edit_outlined),
            label: Text(isZsp || isDistrict ? 'ZSP & Bezirke öffnen' :
                'Arbeitszeiten öffnen'),
          ),
        ),
      ])),
      const SizedBox(height: 14),
      _more(isZsp
          ? 'Ein ZSP ist notwendig, bevor du die Ersteinrichtung fortsetzen '
              'kannst. Bereits vorhandene ZSP werden nicht verändert.'
          : isDistrict
              ? 'Mindestens ein Bezirk ist erforderlich. Bereits gespeicherte '
                  'Bezirke werden nicht verändert.'
              : 'Die Arbeitszeiten kannst du später jederzeit in den '
                  'Einstellungen ändern.'),
    ]);
  }

  Widget _content(bool hasZsp, bool hasDistrict,
      int zspCount, int districtCount) {
    switch (_page) {
      case 0: return _welcome();
      case 1: return _workTimes();
      case 2: return _delivery();
      case 3: return _support();
      case 4: return _planning();
      case 5: return _stats();
      case 6: return _backup();
      case 7: return _widgetGuide();
      default: return _setup(_page - _guideCount,
          hasZsp, hasDistrict, zspCount, districtCount);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final locations = ref.watch(zspProvider).value ?? [];
    final districts = ref.watch(districtProvider).value ?? [];
    final hasZsp = locations.isNotEmpty;
    final hasDistrict = districts.isNotEmpty;
    final isZsp = _page == _guideCount;
    final isDistrict = _page == _guideCount + 1;
    final isLast = _page == _steps - 1;
    final canContinue = !_busy &&
        (widget.helpMode || (!isZsp || hasZsp) && (!isDistrict || hasDistrict));
    return Theme(
      data: Theme.of(context).copyWith(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(primary: _gold,
            surface: _background, onPrimary: Color(0xFF171717)),
        scaffoldBackgroundColor: _background,
      ),
      child: Scaffold(
        backgroundColor: _background,
        body: SafeArea(child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Column(children: [
              Row(children: [
                Container(padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: _gold.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(11)),
                    child: const Icon(Icons.route, color: _gold, size: 20)),
                const SizedBox(width: 9),
                const Text('TourLog', style: TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w800, fontSize: 17)),
                const Spacer(),
                if (widget.helpMode)
                  IconButton(tooltip: 'Schließen',
                      onPressed: _finish,
                      icon: const Icon(Icons.close, color: Colors.white)),
                Text('${_page + 1} / $_steps',
                    style: const TextStyle(color: _muted, fontSize: 12)),
              ]),
              const SizedBox(height: 15),
              Row(children: [
                for (var i = 0; i < _steps; i++)
                  Expanded(child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 260),
                      height: 4,
                      decoration: BoxDecoration(
                        color: i <= _page ? _gold : const Color(0xFF373A40),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  )),
              ]),
            ]),
          ),
          Expanded(child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0.055, 0),
                    end: Offset.zero).animate(animation),
                child: child,
              ),
            ),
            child: ListView(
              key: ValueKey(_page),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              children: [_content(hasZsp, hasDistrict,
                  locations.length, districts.length)],
            ),
          )),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
            decoration: const BoxDecoration(
              color: _background,
              border: Border(top: BorderSide(color: Color(0xFF2A2D34))),
            ),
            child: Column(children: [
              if (!widget.helpMode && _page < _guideCount)
                Align(alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => _go(_guideCount),
                    child: const Text('Einführung überspringen',
                        style: TextStyle(color: _muted, fontSize: 12)),
                  ),
                ),
              Row(children: [
                OutlinedButton(
                  onPressed: _busy || _page == 0 ? null : () => _go(_page - 1),
                  child: const Text('Zurück'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: canContinue ? (isLast ? _finish : () => _go(_page + 1)) : null,
                  icon: Icon(isLast ? Icons.check : Icons.arrow_forward, size: 18),
                  label: Text(isLast ?
                      (widget.helpMode ? 'Schließen' : 'TourLog starten') : 'Weiter'),
                ),
              ]),
            ]),
          ),
        ])),
      ),
    );
  }
}
