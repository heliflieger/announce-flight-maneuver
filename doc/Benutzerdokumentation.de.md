# Flight Announcer - Benutzerdokumentation (Deutsch)

Diese Anleitung beschreibt Installation, Bedienung und typische Workflows fuer das ETHOS-Tool **Flight Announcer**.

## Zweck

Flight Announcer spielt WAV-Dateien in einer definierten Reihenfolge ab, sobald dein konfigurierter Ausloeser (z. B. Schalter) aktiv wird. Das eignet sich fuer Flugphasen, Manoever-Ansagen oder Trainingsablaeufe.

## Voraussetzungen

- FrSky ETHOS (Sender oder Simulator)
- WAV-Dateien im Ordner `SCRIPTS:/FlightAnnouncer.user/audio`
- Der Flight-Announcer-Background-Task muss aktiviert/laufend sein, damit Ansagen abgespielt werden
- Sprache wird automatisch aus der ETHOS-Systemsprache gewaehlt (`Deutsch`/`Englisch`, Fallback: `Englisch`)
- Installierte Script-Ordner:
  - `SCRIPTS:/FlightAnnouncer`
  - `SCRIPTS:/FlightAnnouncer.user`

## Installation auf dem Sender

1. Kopiere `scripts/FlightAnnouncer` nach `SCRIPTS:/FlightAnnouncer`.
2. Kopiere `scripts/FlightAnnouncer.user` nach `SCRIPTS:/FlightAnnouncer.user`.
3. Oeffne in ETHOS: **System Tools -> Flight Announcer**.

## Schnellstart

1. Tool starten.
2. Unter **Ausloeser (Schalter/Taster/Slider)** die gewuenschte Quelle waehlen.
3. Mit **Leeren Slot hinzufuegen** WAV-Zeilen anlegen.
4. In jeder Zeile unter **WAV** eine Datei aus `SCRIPTS:/FlightAnnouncer.user/audio` auswaehlen.
5. Mit **Speichern** sichern.
6. Sicherstellen, dass der **Background Task** aktiv ist.
7. Ausloeser betaetigen: Bei jeder neuen Aktivierung wird die naechste WAV abgespielt.

## Benutzeroberflaeche

### 1) Aktives Set

- Auswahl des aktuellen Profils (`*.user`)
- Button **Loeschen** entfernt das aktive Set

![Startansicht](img/image1.png)

### 2) Name und Ausloeser

- Feld **Name**: Anzeigename des Sets
- Feld **Ausloeser**: Globale Quelle fuer alle Sets
- Die UI-Sprache wird automatisch aus der Systemeinstellung uebernommen (kein manueller Sprachschalter im Tool)

![Name und Ausloeser](img/image2.png)

### 3) WAV Reihenfolge

- **Leeren Slot hinzufuegen**: Neue WAV-Zeile
- **Leere Slots loeschen**: Unbelegte Zeilen entfernen
- **Menu** pro WAV-Zeile:
  - `Up`: Nach oben verschieben
  - `Down`: Nach unten verschieben
  - `Dup`: Eintrag duplizieren
  - `Delete`: Eintrag entfernen

![WAV Reihenfolge](img/image3.png)

### 4) Speichern und Status

- **Speichern** schreibt Profil und globalen Ausloeser
- **Neu Laden** aktualisiert Set-Liste von der SD-Struktur
- **Status** zeigt letzte Meldung und WAV-Anzahl

![Statusbereich](img/image4.png)

## Profile und Dateien

Profile liegen unter:

- `SCRIPTS:/FlightAnnouncer.user/<name>.user`

Wichtig:

- `default.user` wird automatisch erzeugt, falls kein Profil existiert.
- Der Ausloeser wird global gespeichert (nicht pro Profil).
- Sprachtexte liegen in `SCRIPTS:/FlightAnnouncer/i18n` (`de.lua`, `en.lua`).

## Betrieb im Simulator

Im VS Code Workspace:

- Task `Deploy & Launch [SIM]` ausfuehren

Damit werden Scripts in den Simulator kopiert und die ETHOS-Kette neu gestartet.

## Typische Fehlerbilder

- WAV-Liste leer:
  - Pruefen, ob Dateien in `SCRIPTS:/FlightAnnouncer.user/audio` liegen.
- Keine Wiedergabe:
  - Triggerquelle kontrollieren (richtiger Schalter, Richtung, Position).
- Aenderungen nicht sichtbar:
  - **Speichern** und danach **Neu Laden**.

## Tipps

- Verwende kurze, klar benannte WAV-Dateien (z. B. `phase_start.wav`).
- Sortiere die Reihenfolge so, wie sie im Flug aufgerufen wird.
- Nutze Profile fuer unterschiedliche Programme (z. B. Training, Wettbewerb).
