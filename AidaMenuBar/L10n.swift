import Foundation

/// Centralized localization keys for AIDA MenuBar
/// All translations are in Localizable.xcstrings
/// Supports manual language override via `languageOverride`
enum L10n {
    
    // MARK: - Language Override
    
    /// Set to "de" or "en" to override system language, nil = follow system
    static var languageOverride: String?
    
    /// Resolves a localized string, respecting manual override
    private static func s(_ key: String.LocalizationValue) -> String {
        if let override = languageOverride,
           let bundlePath = Bundle.main.path(forResource: override, ofType: "lproj"),
           let bundle = Bundle(path: bundlePath) {
            return String(localized: key, bundle: bundle)
        }
        return String(localized: key)
    }
    
    /// Language display name for the picker
    static var languageAutoLabel: String { s("language.auto") }
    
    // MARK: - Header
    static var appTitle: String { s("app.title") }
    static var settings: String { s("settings") }
    
    // MARK: - Status
    static var statusOnline: String { s("status.present") }
    static var statusOffline: String { s("status.offline") }
    static var statusPause: String { s("status.break") }
    static var statusAbsent: String { s("status.absent") }
    static var statusUpdating: String { s("status.updating") }
    
    // MARK: - Time Summary
    static var today: String { s("today") }
    static var flextimeAccount: String { s("flextime.account") }
    static func pauseDuration(_ time: String) -> String {
        s("pause.duration \(time)")
    }
    
    // MARK: - Booking Buttons
    static var clockIn: String { s("booking.clockIn") }
    static var clockOut: String { s("booking.clockOut") }
    static var startBreak: String { s("booking.startBreak") }
    static var endBreak: String { s("booking.endBreak") }
    
    // MARK: - Bookings
    static var todayBookings: String { s("bookings.today") }
    static var noBookingsToday: String { s("bookings.none") }
    static var pastDays: String { s("bookings.pastDays") }
    
    static var bookingKommen: String { s("booking.kommen") }
    static var bookingGehen: String { s("booking.gehen") }
    static var bookingPause: String { s("booking.pause") }
    
    // MARK: - Login
    static var loginUsername: String { s("login.username") }
    static var loginPassword: String { s("login.password") }
    static var loginButton: String { s("login.signIn") }
    static var loginRememberMe: String { s("login.rememberMe") }
    static var loginVPNRequired: String { s("login.vpnRequired") }
    
    // MARK: - VPN Banner
    static var vpnDisconnected: String { s("vpn.disconnected") }
    static var vpnConnecting: String { s("vpn.connecting") }
    static var vpnConnectHint: String { s("vpn.connectHint") }
    
    // MARK: - Settings
    static var settingsDisplay: String { s("settings.display") }
    static var settingsShowTime: String { s("settings.showTime") }
    static var settingsLanguage: String { s("settings.language") }
    static var settingsDuringPause: String { s("settings.duringPause") }
    static var settingsPauseReminder: String { s("settings.pauseReminder") }
    static var settingsReminderAfter: String { s("settings.reminderAfter") }
    static var settingsBreakReminder: String { s("settings.breakReminder") }
    static var settingsRemindBreak: String { s("settings.remindBreak") }
    static var settingsMode: String { s("settings.mode") }
    static var settingsModeAfterHours: String { s("settings.modeAfterHours") }
    static var settingsModeAtTime: String { s("settings.modeAtTime") }
    static var settingsAfter: String { s("settings.after") }
    static var settingsTime: String { s("settings.time") }
    static var settingsEndOfDay: String { s("settings.endOfDay") }
    static var settingsEndOfDayReminder: String { s("settings.endOfDayReminder") }
    static var settingsNotificationHint: String { s("settings.notificationHint") }
    static var settingsAccount: String { s("settings.account") }
    static func settingsLoggedInAs(_ name: String) -> String {
        s("settings.loggedInAs \(name)")
    }
    static var settingsLogout: String { s("settings.logout") }
    static var settingsVersion: String { "Version" }
    static var settingsCheckUpdates: String { s("settings.checkUpdates") }
    static func settingsUpdateAvailable(_ version: String) -> String {
        s("settings.updateAvailable \(version)")
    }
    static var settingsClickToDownload: String { s("settings.clickToDownload") }
    static var settingsUpToDate: String { s("settings.upToDate") }
    
    // MARK: - Hours/Minutes formatting
    static func hours(_ count: Double) -> String {
        let intCount = Int(count)
        if count == Double(intCount) {
            return s("\(intCount) hours")
        } else {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.minimumFractionDigits = 1
            formatter.maximumFractionDigits = 1
            let formatted = formatter.string(from: NSNumber(value: count)) ?? String(format: "%.1f", count)
            return s("\(formatted) hours")
        }
    }
    
    static func minutes(_ count: Int) -> String {
        s("\(count) min")
    }
    
    // MARK: - Footer / Quit
    static var refreshData: String { s("footer.refresh") }
    static var quitApp: String { s("footer.quit") }
    static var quitConfirmTitle: String { s("footer.quitConfirm") }
    static var cancel: String { s("cancel") }
    static var quit: String { s("quit") }
    
    // MARK: - Errors
    static var errorSessionExpired: String { s("error.sessionExpired") }
    static var errorInvalidCredentials: String { s("error.invalidCredentials") }
    static var errorInvalidResponse: String { s("error.invalidResponse") }
    static var errorBookingFailed: String { s("error.bookingFailed") }
    static func errorBookingRejected(_ msg: String) -> String {
        s("error.bookingRejected \(msg)")
    }
    static func errorServerError(_ code: Int) -> String {
        s("error.server \(code)")
    }
    static var errorNoConnection: String { s("error.noConnection") }
    static var errorNotLoggedIn: String { s("error.notLoggedIn") }
    static var errorNoVPN: String { s("error.noVPN") }
    
    // MARK: - Notifications
    static var notifPauseEnd: String { s("notif.pauseEnd") }
    static func notifPauseBody(_ minutes: Int) -> String {
        s("notif.pauseBody \(minutes)")
    }
    static var notifPauseStillRunning: String { s("notif.pauseStillRunning") }
    static func notifPauseStillBody(_ minutes: Int) -> String {
        s("notif.pauseStillBody \(minutes)")
    }
    static var notifBreakTime: String { s("notif.breakTime") }
    static func notifBreakAfterHours(_ hours: String) -> String {
        s("notif.breakAfterHours \(hours)")
    }
    static var notifBreakScheduled: String { s("notif.breakScheduled") }
    static var notifEndOfDay: String { s("notif.endOfDay") }
    static func notifEndOfDayBody(_ hours: String) -> String {
        s("notif.endOfDayBody \(hours)")
    }
}
