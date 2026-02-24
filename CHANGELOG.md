# AIDA MenuBar – Changelog

## v1.2.0 (2026-02-24)

### New Features

- **Real-time flextime balance:** Cumulative flextime account now calculated correctly using `trafficlightstatus` (Flexzeit Vortag) + today's live saldo — instead of the misleading single-day value from `dailyAccValue`
- **7-day timeline:** New "Past Days" section showing recent workdays in reverse chronological order with compact inline bookings (→08:42 ⏸13:40 ←17:27). Always visible, no collapse needed
- **Full localization (DE/EN):** Complete German and English translations using Xcode String Catalog (`.xcstrings`). All UI text, error messages, and notifications are bilingual
- **In-app language switcher:** Choose between System Language, Deutsch, or English in Settings → Display. Also available as 🌐 globe icon on the login screen — no app restart required

### Improvements

- **Simplified timeline:** Replaced collapsible week overview with flat, scrollable layout — today's bookings on top, past days below
- **Weekday formatting** now follows system/app language instead of hardcoded German locale
- **README** rewritten in English with centered app icon, badges, and clean project structure

### Technical

- New `L10n.swift` wrapper with `String(localized:)` and manual language override via Bundle
- `Localizable.xcstrings` with ~60 translation keys
- `SettingsManager.appLanguage` persisted in UserDefaults
- `AidaError` cases now use localized strings
- Flextime refresh timer (5 min) for `trafficlightstatus` endpoint

---

## v1.1.0 (2026-02-24)

### New Features

- **Pause icon in menu bar:** When a break is active, the icon switches to ⏸ (`pause.circle`) for at-a-glance status
- **End of day reminder:** Notification after configurable work hours (7–10 hours). Configurable under ⚙️ → End of Day
- **Break reminder:** Reminder to take a break – either after X hours of work (3–5h) or at a fixed time of day. Configurable under ⚙️ → Break Reminder
- **Improved VPN detection:** Instant response to VPN disconnect via proactive server reachability check on every network change (instead of up to 60 sec delay)

### Bug Fixes

- **App no longer quits silently:** `disableSuddenTermination` and `disableAutomaticTermination` prevent macOS from killing the app as "inactive"
- **VPN placeholders fixed:** Time and balance now immediately show "–:––" when VPN disconnects

### Settings

- Settings reorganized into separate sections: "During Break", "Break Reminder", "End of Day"
- Break reminder with two modes: "After work hours" or "At fixed time" with hour/minute picker

---

## v1.0.0 – Initial Release (2026-02-12)

First public version of the AIDA MenuBar app – a native macOS menu bar app for AIDA time tracking.

### Features

**Time Tracking**
- Live time display in the macOS menu bar (optional)
- Clock in/out/pause directly from the menu bar
- Daily overview with target/actual comparison and progress bar
- Balance display (flextime account)
- Today's bookings as a list
- Automatic sync every 60 seconds

**Authentication & Security**
- Native login with company credentials (no WebView)
- Credentials securely stored in macOS Keychain
- Automatic login on app start
- Session keep-alive (no timeout during inactivity)
- Automatic re-authentication on session expiry

**VPN Handling**
- Automatic VPN connection status detection
- Instant response to VPN changes (connect/disconnect)
- Placeholder display when VPN is disconnected
- Auto-reconnect with retry mechanism (max 15 attempts)
- VPN warning banner with status info

**Break Reminder**
- Configurable reminder after 15/30/45/60 minutes
- Persistent notifications (follow-ups every 5 min)
- Automatic cancellation when break ends

**UI & UX**
- AIDA Pyramid logo (official favicon)
- Dark Mode support (logo switches to white)
- Inline settings (no separate window)
- Refresh button with visual feedback (spinner → checkmark)
- Quit confirmation to prevent accidental closure
- Compact, native macOS design
- Status badge: Present/Absent/Break/Offline

**Technical**
- Server cache workaround via `RechneBisHeute` trigger
- Live timer interpolates between server fetches
- Wake-from-sleep & screen unlock handling
- Self-signed certificate support

### System Requirements

- macOS 13.0 (Ventura) or later
- VPN connection to AIDA server
- AIDA credentials

### Known Limitations

- No cost center selection for bookings (uses default)
- No weekly/monthly overview
- App may need restart after macOS updates
