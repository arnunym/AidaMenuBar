# AIDA MenuBar

Native macOS MenuBar-App für die AIDA Zeiterfassung bei Bike24.

## Features

- **Live-Zeitanzeige** in der Menüleiste (optional)
- **Kommen/Gehen/Pause** buchen mit einem Klick
- **Tagesübersicht** mit Soll/Ist, Fortschrittsbalken und Flexzeit-Saldo
- **Heutige Buchungen** als Verlauf
- **Automatische Synchronisierung** alle 60 Sekunden
- **VPN-Erkennung** mit Auto-Reconnect
- **Pause-Erinnerung** als persistente Benachrichtigung
- **Dark Mode** Support

## Systemanforderungen

- macOS 13.0 (Ventura) oder neuer
- Bike24 VPN-Verbindung (OpenVPN)
- AIDA-Zugangsdaten (Bike24-Kennung)

## Installation

### Für Nutzer (vorkompilierte App)

1. `AidaMenuBar.app` in den **Applications**-Ordner ziehen
2. Beim ersten Öffnen: **Rechtsklick → Öffnen → Bestätigen** (unsignierte App)
3. Die App erscheint als Uhr-Icon in der Menüleiste
4. VPN verbinden und mit Bike24-Kennung anmelden

### Für Entwickler (aus Xcode)

```bash
open AidaMenuBar.xcodeproj
```

1. Target **"My Mac"** auswählen
2. `Cmd+R` zum Builden & Starten
3. Für Release: `Product → Archive → Distribute App → Copy App`

## Einrichtung

1. **Bike24 VPN verbinden** (OpenVPN)
2. App aus der Menüleiste öffnen (Uhr-Icon)
3. Mit **Bike24-Kennung** anmelden (gleiche Daten wie AIDA im Browser)
4. Optional: "Angemeldet bleiben" aktivieren (speichert Credentials im Keychain)

Die App meldet sich automatisch an wenn sie gespeicherte Credentials findet.

## Bedienung

### MenuBar

| Icon | Bedeutung |
|------|-----------|
| 🕐 `clock` | Idle (nicht eingestempelt) |
| 🕐 `clock.fill` | Anwesend (eingestempelt) |
| ⚠️ `clock.badge.exclamationmark` | Keine VPN-Verbindung |

Optional wird die aktuelle Arbeitszeit neben dem Icon angezeigt (in Einstellungen aktivierbar).

### Popover

- **Status-Badge** zeigt: Anwesend (grün), Abwesend (grau), Pause (blau), Offline (orange)
- **Kommen/Gehen** Buttons zum Ein-/Ausstempeln
- **Pause starten/beenden** für Pausenbuchung
- **Heutige Buchungen** als chronologische Liste
- **↻ Refresh** erzwingt sofortige Datenaktualisierung
- **⏻ Beenden** schließt die App (mit Bestätigungsdialog)

### Einstellungen (⚙️)

- **Arbeitszeit in Menüleiste**: Zeit neben Icon anzeigen
- **Pause-Erinnerung**: Benachrichtigung nach konfigurierbarer Zeit
- **Abmelden**: Credentials löschen und ausloggen

## Architektur

```
AidaMenuBar/
├── AidaMenuBarApp.swift      # App Entry, MenuBar Setup, AppDelegate
├── ContentView.swift         # Popover UI (Main View, Settings, Login, Logo)
├── SessionManager.swift      # API, Auth, Timer, VPN, State Management
├── KeychainService.swift     # macOS Keychain Integration
├── SettingsManager.swift     # UserDefaults für App-Einstellungen
├── LoginView.swift           # Legacy (deprecated, unused)
├── SettingsView.swift        # Legacy (minimal, für macOS Settings Scene)
└── Assets.xcassets/          # App Icon, AIDA Favicon, Colors
```

### Data Fetch Flow

```
Timer (60 sec)
  ↓
fetchBookings()
  ↓
POST RechneBisHeute     → Server recalculates Ist-Zeit (empty response)
  ↓
GET buchungen_7Tage     → Fresh: times, bookings, dailyAccValue
  ↓
serverWorkedMinutes = times[today][1]
lastDataFetchTime = now
  ↓
Live Timer (1 sec):
  todayWorkedMinutes = serverWorkedMinutes + minutesSince(lastDataFetchTime)
```

> **Wichtig:** Ohne den `RechneBisHeute`-Aufruf liefert `buchungen_7Tage` gecachte Werte.
> Dieser Trigger zwingt den Server, die aktuelle Ist-Zeit neu zu berechnen.

### Timer-Konfiguration

| Timer | Intervall | Zweck |
|-------|-----------|-------|
| Keep-Alive | 20 min | Session-Timeout verhindern |
| Data Refresh | 60 sec | RechneBisHeute + buchungen_7Tage |
| Live Time | 1 sec | Interpolation zwischen Server-Fetches |
| VPN Retry | 3 sec | Server-Erreichbarkeit prüfen (max. 15×) |

### API-Endpoints

| Endpoint | Methode | Beschreibung |
|----------|---------|--------------|
| `central/sessions/` | POST | Login (principalName + password) |
| `central/sessions/{id}` | GET | Session validieren / Keep-Alive |
| `taims/rpc?` | POST | Buchung (Kommen/Gehen/Pause) |
| `taims/rpc?` | POST | `{"__knopf": "RechneBisHeute"}` – Server-Recalc |
| `taims/rpc/buchungen_7Tage` | GET | Buchungen, Zeiten, Saldo |

### VPN-Erkennung

Die App nutzt `NWPathMonitor` um Netzwerkänderungen zu erkennen. Bei jeder Änderung wird ein Server-Reachability-Check durchgeführt:

- **VPN deaktiviert** → Server nicht erreichbar → Banner + Platzhalter + Auto-Retry
- **VPN aktiviert** → Server erreichbar → Auto-Login + Daten laden
- **Sleep/Wake** → Session validieren, ggf. Re-Login

## Fehlerbehebung

### "Keine VPN-Verbindung"
→ Bike24 VPN (OpenVPN) verbinden. Die App erkennt die Verbindung automatisch.

### "Session abgelaufen"
→ Login-Formular erscheint automatisch. Bei gespeicherten Credentials erfolgt Re-Login im Hintergrund.

### App lässt sich nicht öffnen ("nicht verifizierter Entwickler")
→ Rechtsklick auf App → "Öffnen" → Bestätigen. Nur beim ersten Mal nötig.

### Zeit stimmt nicht mit AIDA Dashboard überein
→ Refresh-Button (↻) klicken. Die App erzwingt dann eine Server-Neuberechnung.

### Buchung wird abgelehnt
→ Status prüfen (bereits eingestempelt?). AIDA erlaubt keine doppelten Kommen/Gehen-Buchungen.

## Verteilung an Kollegen

Die App ist generisch – keine persönlichen Daten sind eingebacken. Jeder Bike24-Mitarbeiter mit VPN-Zugang und AIDA-Credentials kann die App nutzen.

1. In Xcode: `Product → Archive → Distribute App → Copy App`
2. `.app`-Datei per Slack, Mail oder SharePoint teilen
3. Empfänger: App in Applications-Ordner ziehen, Rechtsklick → Öffnen

## Changelog

Siehe [CHANGELOG.md](CHANGELOG.md)

## Lizenz

Internes Tool für Bike24.
