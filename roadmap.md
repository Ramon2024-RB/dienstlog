# DienstLog

## Persönliche Arbeitszeit-, Zustell- und Leistungsdokumentation

DienstLog ist eine eigenständige Flutter-App zur persönlichen Dokumentation meiner Arbeit bei der Deutschen Post.

Die App ersetzt meine bisherige Numbers-Tabelle und soll die tägliche Erfassung deutlich einfacher und schneller machen.

Neben Arbeitszeiten werden insbesondere Bezirke, Paketmengen, Zustellzeiten, Werbung und die Unterstützung anderer Zusteller dokumentiert.

---

# 1. Technische Grundlage

- Flutter
- Dart
- VS Code
- Riverpod
- SQLite / sqflite
- Material 3
- Git
- zunächst lokale/offline Speicherung
- iPhone als primäres Testgerät

DienstLog ist ein vollständig eigenständiges Projekt und unabhängig von MotorLog.

---

# 2. Hauptnavigation

Die App erhält zunächst vier Hauptbereiche:

1. Übersicht
2. Kalender
3. Statistik
4. Mehr

---

# 3. Übersicht / Dashboard

Die Startseite zeigt den aktuellen Arbeitstag sowie wichtige Informationen zur aktuellen Woche und zum aktuellen Monat.

## Heute

Beispiel:

Montag, 17. August 2026

Bezirk 18  
A-Teil

Arbeitszeit:
8 h 50 min

Eigene Pakete:
112

Zusätzlich übernommen:
33

Gesamt zugestellt:
145

## Aktuelle Woche

Anzeige von:

- Arbeitszeit
- Zustellzeit
- Arbeitstagen
- eigenen Paketen
- übernommenen Paketen
- Gesamtpaketen
- abgebrochenen Paketen
- ausgelieferten Paketen
- Plus-/Minusstunden

## Aktueller Monat

Anzeige von:

- Arbeitszeit
- Zustellzeit
- Arbeitstagen
- freien Tagen
- Urlaubstagen
- Feiertagen
- eigenen Paketen
- übernommenen Paketen
- Gesamtpaketen
- abgebrochenen Paketen
- ausgelieferten Paketen
- Plus-/Minusstunden

---

# 4. Tagesstatus

Jeder Kalendertag kann einen Status erhalten.

Geplante Status:

- Arbeit
- Frei
- Urlaub
- Feiertag
- Krankheit

Weitere Status sollen später ergänzt werden können.

Bei Frei, Urlaub, Feiertag usw. müssen keine normalen Arbeitsdaten eingetragen werden.

---

# 5. Arbeitstag

Für jeden Arbeitstag werden folgende Daten gespeichert:

- Datum
- Wochentag
- Tagesstatus
- Arbeitsbeginn laut Plan
- Arbeitsende laut Plan
- tatsächlicher Arbeitsbeginn
- Abfahrt zur Zustellung
- tatsächliches Arbeitsende
- eigener Bezirk / eigene Bezirke
- A-Teil / B-Teil
- eigene Pakete
- abgebrochene Pakete
- Werbung
- Bemerkungen
- Unterstützungen anderer Bezirke

---

# 6. Automatische Zeitberechnung

DienstLog soll möglichst viele Werte automatisch berechnen.

## Arbeitszeit

Berechnung aus:

tatsächlicher Arbeitsbeginn → tatsächliches Arbeitsende

Beispiel:

07:10 – 16:00

Ergebnis:

8 h 50 min

## Zustellzeit

Berechnung aus:

Abfahrt → Arbeitsende

Beispiel:

09:32 – 16:00

Ergebnis:

6 h 28 min

## Soll-/Ist-Vergleich

Die App soll berechnen:

- geplante Arbeitszeit
- tatsächliche Arbeitszeit
- Pluszeit
- Minuszeit
- Wochenbilanz
- Monatsbilanz
- Jahresbilanz

Die genaue Behandlung von Pausen wird vor Umsetzung der Arbeitszeitberechnung festgelegt.

---

# 7. Bezirke

Es gibt 25 reguläre Touren / Bezirke.

Diese werden in einer eigenen Bezirksverwaltung gespeichert.

Pro Bezirk:

- Bezirksnummer
- aktiv / nicht aktiv
- sicher selbstständig fahrbar
- optionale persönliche Notiz

Beispiele:

Bezirk 16
Sicher fahrbar: Ja

Bezirk 25
Sicher fahrbar: Nein

Ich kann aktuell mindestens 13 der 25 Bezirke sicher fahren.

---

# 8. Eigener Bezirk

An einem normalen Zustelltag wird der eigene Bezirk bzw. werden die eigenen Bezirke ausgewählt.

Mehrere Bezirke müssen möglich sein.

Beispiele:

16

oder:

11, 16, 17

Zusätzlich:

- A-Teil
- B-Teil

---

# 9. Eigene Pakete

Für die eigene Tour wird die Paketmenge gespeichert.

Beispiel:

Eigener Bezirk: 18

Eigene Pakete: 112

Abgebrochene Pakete: 0

Die App berechnet automatisch die tatsächlich ausgelieferten Pakete.

---

# 10. Unterstützung anderer Zusteller

Die Unterstützung anderer Bezirke ist ein zentraler Bestandteil von DienstLog.

Unterstützungen werden NICHT nur als Bemerkung gespeichert.

Jede einzelne Unterstützung erhält einen eigenen Datensatz.

Pro Unterstützung:

- unterstützter Bezirk
- Anzahl übernommener Pakete
- optional Bemerkung

Beispiel:

Bezirk 16
14 Pakete übernommen

Bezirk 23
11 Pakete übernommen

Bezirk 7
8 Pakete übernommen

Automatische Summe:

33 zusätzliche Pakete

---

# 11. Unterstützung während eigener Tour

Unterstützungen können auch stattfinden, wenn ich selbst einen regulären Bezirk fahre.

Beispiel:

Eigener Bezirk:
18

Eigene Pakete:
112

Unterstützung:

Bezirk 16:
14 Pakete

Bezirk 23:
11 Pakete

Bezirk 7:
8 Pakete

Automatische Berechnung:

Eigene Pakete: 112

Zusätzlich übernommen: 33

Gesamt: 145 Pakete

---

# 12. Zusätzlicher Paketfahrer / Unterstützungstag

Es gibt Tage, an denen die 25 regulären Touren bereits von 25 Zustellern gefahren werden und ich als zusätzliche Unterstützung eingesetzt werde.

Das bedeutet NICHT, dass ich eine eigene Paket-Tour fahre.

Ich unterstütze stattdessen mehrere bereits besetzte Bezirke und nehme den dortigen Zustellern Pakete ab.

An einem solchen Tag ist kein eigener regulärer Bezirk notwendig.

Beispiel:

Unterstützte Bezirke:

Bezirk 15:
25 Pakete

Bezirk 16:
31 Pakete

Bezirk 21:
27 Pakete

Automatisch:

3 Bezirke unterstützt

83 Pakete übernommen

83 Pakete zugestellt

---

# 13. Unterstützung hinzufügen

In der Tagesansicht gibt es:

+ Unterstützung hinzufügen

Danach:

Bezirk auswählen

Pakete übernommen:
[ Anzahl ]

Weitere Unterstützungen können beliebig hinzugefügt werden.

Unterstützungen können:

- hinzugefügt
- bearbeitet
- gelöscht

werden.

---

# 14. Paketberechnungen

## Pro Tag

Automatisch berechnen:

- eigene Pakete
- zusätzliche Pakete
- Gesamtpakete
- abgebrochene Pakete
- ausgelieferte Pakete

## Pro Woche

Automatisch:

- eigene Pakete
- zusätzlich übernommene Pakete
- Gesamtpakete
- abgebrochene Pakete
- ausgelieferte Pakete

## Pro Monat

Automatisch:

- eigene Pakete
- Unterstützungspakete
- Gesamtpakete
- abgebrochene Pakete
- ausgelieferte Pakete
- Durchschnitt pro Arbeitstag

## Pro Jahr

Automatisch:

- gesamte Paketmenge
- eigene Pakete
- Unterstützungspakete
- abgebrochene Pakete
- ausgelieferte Pakete

---

# 15. Werbung

Werbung wird separat vom Bemerkungsfeld gespeichert.

Mehrere Werbungen pro Arbeitstag sind möglich.

Beispiele:

- Aktion Mensch
- Matt
- Enpal
- Tagespost
- Steuerberater
- Üz

Es soll eine eigene Werbeverwaltung geben.

Häufig verwendete Werbung kann gespeichert und anschließend beim Arbeitstag einfach ausgewählt werden.

Button:

+ Werbung hinzufügen

---

# 16. Bemerkungen

Jeder Tag erhält ein freies Bemerkungsfeld.

Dort können besondere Ereignisse dokumentiert werden.

Beispiele:

- Kollegen zusätzlich geholfen
- besondere Aufteilung
- Pakete eines Kollegen übernommen
- Kontrolle
- Zustellung wegen Hitze abgebrochen
- Änderungen während der Zustellung
- sonstige Besonderheiten

Strukturiert erfassbare Daten wie Paketunterstützungen werden trotzdem separat gespeichert.

---

# 17. Kalender

DienstLog erhält eine Monatsansicht.

Oben:

< August 2026 >

Darunter:

Monatskalender

Tage werden abhängig vom Status optisch unterschieden:

- Arbeit
- Frei
- Urlaub
- Feiertag
- Krankheit

Ein Arbeitstag mit Unterstützung kann zusätzlich markiert werden.

Beim Antippen eines Tages öffnet sich der entsprechende Eintrag.

---

# 18. Bezirksverwaltung

Unter:

Mehr → Bezirke

werden die 25 Bezirke verwaltet.

Möglichkeiten:

- Bezirk aktivieren/deaktivieren
- als sicher fahrbar markieren
- persönliche Notiz speichern

Bei der täglichen Eingabe werden Bezirke aus dieser Liste ausgewählt.

---

# 19. Bezirksstatistik

Jeder Bezirk erhält langfristig eine eigene Statistik.

Beispiel:

Bezirk 18

Selbst gefahren:
14-mal

Eigene Pakete:
1.628

Durchschnitt:
116 Pakete

Durchschnittliche Zustellzeit:
5 h 52 min

Als Unterstützung geholfen:
7-mal

Dabei übernommen:
94 Pakete

---

# 20. Unterstützungsstatistik

Eigener Statistikbereich für Unterstützungen.

Auswertungen:

- Anzahl der Unterstützungstage
- Anzahl einzelner Unterstützungen
- Anzahl unterschiedlicher unterstützter Bezirke
- insgesamt übernommene Pakete
- durchschnittlich übernommene Pakete
- meistunterstützter Bezirk
- Pakete pro unterstütztem Bezirk

Beispiel:

August 2026

17 Unterstützungen

9 unterschiedliche Bezirke

286 zusätzliche Pakete

Ø 16,8 Pakete pro Unterstützung

---

# 21. Monatsstatistik

Beispiel:

August 2026

Arbeitstage:
18

Arbeitszeit:
151 h 34 min

Zustellzeit:
112 h 18 min

Eigene Pakete:
1.942

Zusätzlich übernommen:
286

Gesamt:
2.228

Abgebrochen:
12

Plus-/Minusstunden:
+7 h 14 min

---

# 22. Jahresstatistik

Jahresübersicht mit:

- Arbeitstagen
- freien Tagen
- Urlaubstagen
- Feiertagen
- Krankheitstagen
- Arbeitszeit
- Zustellzeit
- Plus-/Minusstunden
- eigenen Paketen
- Unterstützungspaketen
- Gesamtpaketen
- abgebrochenen Paketen
- ausgelieferten Paketen

Zusätzlich sollen Monate miteinander verglichen werden können.

---

# 23. Schnelle tägliche Eingabe

Die tägliche Eingabe muss möglichst schnell funktionieren.

Automatisch vorausgefüllt werden können:

- aktuelles Datum
- Wochentag
- Standard-Arbeitsbeginn
- Standard-Arbeitsende laut Plan

Schnellauswahl für:

- Bezirke
- A-Teil / B-Teil
- Werbung
- Unterstützung

Ziel:

Ein normaler Arbeitstag soll innerhalb weniger Sekunden eingetragen werden können.

---

# 24. Standardarbeitszeiten

Unter Einstellungen können Standardzeiten hinterlegt werden.

Beispiel:

Arbeitsbeginn:
07:10

Arbeitsende laut Plan:
16:05

Diese Werte werden bei einem neuen Arbeitstag automatisch vorgeschlagen.

Sie können für jeden einzelnen Tag geändert werden.

---

# 25. Einstellungen

Unter Mehr → Einstellungen:

- Standard-Arbeitsbeginn
- Standard-Arbeitsende
- Bezirke verwalten
- sicher fahrbare Bezirke festlegen
- Werbung verwalten
- Tagesstatus verwalten
- weitere App-Einstellungen

---

# 26. Export

Spätere Exportmöglichkeiten:

- CSV
- Excel-/Numbers-kompatibler Export
- PDF-Monatsübersicht
- Jahresübersicht

Dadurch sollen die Daten auch außerhalb von DienstLog ausgewertet werden können.

---

# 27. Backup

Geplant:

- Datenbank-Backup
- Backup wiederherstellen
- optional später Cloud-Backup

Die App funktioniert grundsätzlich ohne Cloud und ohne Internet.

---

# 28. Komfortfunktionen

Nach Fertigstellung der Kernfunktionen:

- Vortag duplizieren
- häufige Bezirke als Favoriten
- zuletzt verwendete Bezirke
- häufig unterstützte Bezirke
- Suche in Bemerkungen
- Filter nach Bezirk
- Filter nach Zeitraum
- Filter nach Unterstützung
- Diagramme
- Monatsvergleiche
- Jahresvergleiche

---

# 29. Datenschutz

Version 1 arbeitet vollständig lokal.

Keine Anmeldung notwendig.

Kein Benutzerkonto notwendig.

Keine zwingende Internetverbindung.

Arbeitsdaten werden lokal auf dem Gerät gespeichert.

---

# 30. Datenbankplanung

Geplante zentrale Datenbereiche:

## work_days

Arbeitstage und Tagesstatus

## districts

25 Bezirke

## support_entries

Einzelne Unterstützungen mit:

- Arbeitstag
- Bezirk
- Paketanzahl

## advertisements

Gespeicherte Werbungen

## work_day_advertisements

Zuordnung mehrerer Werbungen zu einem Arbeitstag

## settings

Persönliche App-Einstellungen

Die genaue SQL-Struktur wird vor Implementierung festgelegt.

---

# 31. Entwicklungsphasen

## Phase 1 – Grundgerüst

- [ ] Flutter-Projekt erstellen
- [ ] Projekt separat von MotorLog anlegen
- [ ] roadmap.md erstellen
- [ ] Git initialisieren
- [ ] ersten Commit erstellen
- [ ] Riverpod installieren
- [ ] SQLite / sqflite installieren
- [ ] Ordnerstruktur erstellen
- [ ] Material-3-Grunddesign erstellen

## Phase 2 – Navigation

- [ ] Übersicht
- [ ] Kalender
- [ ] Statistik
- [ ] Mehr
- [ ] NavigationBar

## Phase 3 – Datenbank

- [ ] AppDatabase
- [ ] Arbeitstage
- [ ] Bezirke
- [ ] Unterstützungen
- [ ] Werbung
- [ ] Einstellungen
- [ ] Datenbankmethoden

## Phase 4 – Bezirke

- [ ] 25 Bezirke anlegen
- [ ] Bezirksverwaltung
- [ ] sicher fahrbar markieren
- [ ] Bezirksauswahl

## Phase 5 – Arbeitstage

- [ ] neuen Arbeitstag erstellen
- [ ] Status auswählen
- [ ] Zeiten eingeben
- [ ] Bezirk auswählen
- [ ] A-/B-Teil
- [ ] Pakete
- [ ] Bemerkungen
- [ ] Arbeitstag bearbeiten
- [ ] Arbeitstag löschen

## Phase 6 – Berechnungen

- [ ] Arbeitszeit
- [ ] Zustellzeit
- [ ] Sollzeit
- [ ] Istzeit
- [ ] Plus-/Minusstunden
- [ ] ausgelieferte Pakete

## Phase 7 – Unterstützungssystem

- [ ] Unterstützung hinzufügen
- [ ] Bezirk auswählen
- [ ] Paketanzahl eingeben
- [ ] mehrere Unterstützungen pro Tag
- [ ] Unterstützung bearbeiten
- [ ] Unterstützung löschen
- [ ] automatische Summe
- [ ] Unterstützung trotz eigener Tour
- [ ] reiner Unterstützungstag

## Phase 8 – Werbung

- [ ] Werbung speichern
- [ ] Werbung verwalten
- [ ] mehrere Werbungen pro Tag
- [ ] Werbung bearbeiten
- [ ] Werbung löschen

## Phase 9 – Kalender

- [ ] Monatsansicht
- [ ] Statusfarben
- [ ] Arbeitstage anzeigen
- [ ] Unterstützungen markieren
- [ ] Tag öffnen
- [ ] Monat wechseln

## Phase 10 – Dashboard

- [ ] heutiger Arbeitstag
- [ ] heutige Arbeitszeit
- [ ] heutige Pakete
- [ ] heutige Unterstützung
- [ ] Wochenübersicht
- [ ] Monatsübersicht

## Phase 11 – Statistik

- [ ] Wochenstatistik
- [ ] Monatsstatistik
- [ ] Jahresstatistik
- [ ] Bezirksstatistik
- [ ] Unterstützungsstatistik
- [ ] Paketstatistik
- [ ] Arbeitszeitstatistik
- [ ] Zustellzeitstatistik

## Phase 12 – Einstellungen

- [ ] Standardarbeitszeiten
- [ ] Bezirksverwaltung
- [ ] Werbeverwaltung
- [ ] Tagesstatus
- [ ] weitere Einstellungen

## Phase 13 – Export & Backup

- [ ] CSV
- [ ] Excel-/Numbers-kompatibel
- [ ] PDF
- [ ] Datenbank-Backup
- [ ] Wiederherstellung

## Phase 14 – Feinschliff

- [ ] Alltagstests
- [ ] Fehlerbehebung
- [ ] Bedienung optimieren
- [ ] Performance
- [ ] Design
- [ ] Statistiken verbessern
- [ ] iPhone-Test

---

# 32. Aktueller Entwicklungsstand

Stand: 17.08.2026

- [x] Grundidee festgelegt
- [x] bestehende Numbers-Lösung analysiert
- [x] Paketunterstützungen als eigenes System festgelegt
- [x] DienstLog als eigenständige App festgelegt
- [x] Flutter-Projekt `dienstlog` separat von MotorLog erstellt
- [x] Projekt in VS Code geöffnet
- [x] roadmap.md erstellt
- [ ] roadmap.md gespeichert
- [ ] Git-Grundstand speichern
- [ ] technische App-Struktur beginnen

---

# Grundprinzip von DienstLog

DienstLog soll keine einfache Kopie der bisherigen Numbers-Tabelle werden.

Die Daten aus Numbers bilden die Grundlage, die Bedienung wird aber speziell für das Smartphone entwickelt.

So wenig wie möglich soll manuell berechnet werden.

Insbesondere Paketunterstützungen sollen detailliert dokumentiert werden.

Für jede Unterstützung soll nachvollziehbar sein:

- Wann habe ich geholfen?
- Welchen Bezirk habe ich unterstützt?
- Wie viele Pakete habe ich übernommen?
- Hatte ich gleichzeitig eine eigene Tour?
- Wie viele Pakete habe ich insgesamt zugestellt?

Langfristig soll DienstLog dadurch nicht nur eine Arbeitszeiterfassung, sondern eine vollständige persönliche Dokumentation von Arbeitszeit, Zustellung, Bezirken, Paketmengen und zusätzlicher Unterstützung sein.