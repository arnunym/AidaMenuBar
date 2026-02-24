# AIDA MenuBar – Changelog

## v1.1.0 (2026-02-24)

### Neue Features

- **Pause-Icon in der Menüleiste:** Wenn eine Pause aktiv ist, wechselt das Icon zu ⏸ (`pause.circle`) – so sieht man auf einen Blick den Pause-Status
- **Feierabend-Erinnerung:** Benachrichtigung nach konfigurierbarer Arbeitszeit (7–10 Stunden). Einstellbar unter ⚙️ → Feierabend
- **Pause-Erinnerung (Pause einlegen):** Erinnerung, eine Pause zu machen – entweder nach X Stunden Arbeit (3–5h) oder zu einer festen Uhrzeit. Einstellbar unter ⚙️ → Pause-Erinnerung
- **Verbesserte VPN-Erkennung:** Sofortige Reaktion auf VPN-Disconnect über proaktiven Server-Reachability-Check bei jeder Netzwerkänderung (statt bis zu 60 Sek Verzögerung)

### Bugfixes

- **App schließt sich nicht mehr von selbst:** `disableSuddenTermination` und `disableAutomaticTermination` verhindern, dass macOS die App als "inaktiv" beendet
- **VPN-Platzhalter korrekt:** Zeit und Saldo zeigen jetzt sofort "–:––" wenn VPN getrennt wird

### Einstellungen erweitert

- Einstellungen-Bereich neu strukturiert: "Während Pause", "Pause-Erinnerung", "Feierabend" als eigene Sektionen
- Pause-Erinnerung mit zwei Modi: "Nach Arbeitszeit" oder "Zu fester Uhrzeit" mit Stunden/Minuten-Auswahl

---

## v1.0.0 – Erster Release (2026-02-12)

Die erste öffentliche Version der AIDA MenuBar App – eine native macOS MenuBar-App für die Bike24-Zeiterfassung.

### Features

**Zeiterfassung**
- Live-Zeitanzeige in der macOS-Menüleiste (optional)
- Kommen/Gehen/Pause buchen direkt aus der MenuBar
- Tagesübersicht mit Soll/Ist-Vergleich und Fortschrittsbalken
- Saldo-Anzeige (Flexzeit-Konto)
- Heutige Buchungen als Liste
- Automatische Synchronisierung alle 60 Sekunden

**Anmeldung & Sicherheit**
- Native Login mit Bike24-Kennung (kein WebView)
- Credentials sicher im macOS Keychain gespeichert
- Automatische Anmeldung beim App-Start
- Session Keep-Alive (kein Timeout bei Inaktivität)
- Automatische Re-Authentifizierung bei Session-Ablauf

**VPN-Handling**
- Automatische Erkennung von VPN-Verbindungsstatus
- Sofortige Reaktion auf VPN-Änderungen (connect/disconnect)
- Platzhalter-Anzeige bei fehlender VPN-Verbindung
- Auto-Reconnect mit Retry-Mechanismus (max. 15 Versuche)
- VPN-Banner mit Status-Information

**Pause-Erinnerung**
- Konfigurierbare Erinnerung nach 15/30/45/60 Minuten
- Persistente Benachrichtigungen (Follow-ups alle 5 Min)
- Automatische Stornierung bei Pause-Ende

**UI & UX**
- AIDA Pyramid Logo (offizielles Favicon)
- Dark Mode Support (Logo wechselt zu Weiß)
- Inline-Einstellungen (kein separates Fenster)
- Refresh-Button mit visuellem Feedback (Spinner → Häkchen)
- Quit-Bestätigung zum Schutz vor versehentlichem Schließen
- Kompaktes, natives macOS-Design
- Status-Badge: Anwesend/Abwesend/Pause/Offline

**Technisch**
- Server-Cache-Workaround via `RechneBisHeute` Trigger
- Live-Timer interpoliert zwischen Server-Fetches
- Wake-from-Sleep & Screen-Unlock Handling
- Self-Signed Certificate Support (Bike24 intern)

### Systemanforderungen

- macOS 13.0 (Ventura) oder neuer
- Bike24 VPN-Verbindung (OpenVPN)
- AIDA-Zugangsdaten (Bike24-Kennung)

### Bekannte Einschränkungen

- Keine Kostenstelle-Auswahl bei Buchungen (nutzt Standard-Kostenstelle)
- Keine Wochen-/Monatsübersicht
- App muss bei macOS-Updates ggf. neu gestartet werden
