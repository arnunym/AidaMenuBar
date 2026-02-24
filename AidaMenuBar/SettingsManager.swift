import Foundation
import Combine

class SettingsManager: ObservableObject {
    // MARK: - Display
    @Published var showTimeInMenuBar: Bool {
        didSet { UserDefaults.standard.set(showTimeInMenuBar, forKey: "showTimeInMenuBar") }
    }
    
    // MARK: - Pause Reminder (during active pause)
    @Published var pauseReminderEnabled: Bool {
        didSet { UserDefaults.standard.set(pauseReminderEnabled, forKey: "pauseReminderEnabled") }
    }
    @Published var pauseReminderMinutes: Int {
        didSet { UserDefaults.standard.set(pauseReminderMinutes, forKey: "pauseReminderMinutes") }
    }
    
    // MARK: - Break Reminder (remind to take a break)
    @Published var breakReminderEnabled: Bool {
        didSet { UserDefaults.standard.set(breakReminderEnabled, forKey: "breakReminderEnabled") }
    }
    /// Mode: "afterHours" = after X hours worked, "atTime" = at specific time
    @Published var breakReminderMode: String {
        didSet { UserDefaults.standard.set(breakReminderMode, forKey: "breakReminderMode") }
    }
    /// Hours after which to remind (e.g. 4.0 = after 4 hours)
    @Published var breakReminderAfterHours: Double {
        didSet { UserDefaults.standard.set(breakReminderAfterHours, forKey: "breakReminderAfterHours") }
    }
    /// Fixed time to remind (hour of day, e.g. 12 = 12:00)
    @Published var breakReminderAtHour: Int {
        didSet { UserDefaults.standard.set(breakReminderAtHour, forKey: "breakReminderAtHour") }
    }
    @Published var breakReminderAtMinute: Int {
        didSet { UserDefaults.standard.set(breakReminderAtMinute, forKey: "breakReminderAtMinute") }
    }
    
    // MARK: - End of Day Reminder (Feierabend)
    @Published var endOfDayReminderEnabled: Bool {
        didSet { UserDefaults.standard.set(endOfDayReminderEnabled, forKey: "endOfDayReminderEnabled") }
    }
    /// Hours after which to remind (e.g. 8.0 = after 8 hours)
    @Published var endOfDayReminderHours: Double {
        didSet { UserDefaults.standard.set(endOfDayReminderHours, forKey: "endOfDayReminderHours") }
    }
    
    init() {
        // Display
        self.showTimeInMenuBar = UserDefaults.standard.object(forKey: "showTimeInMenuBar") as? Bool ?? true
        
        // Pause reminder (during pause)
        self.pauseReminderEnabled = UserDefaults.standard.object(forKey: "pauseReminderEnabled") as? Bool ?? true
        self.pauseReminderMinutes = UserDefaults.standard.object(forKey: "pauseReminderMinutes") as? Int ?? 30
        
        // Break reminder (take a break)
        self.breakReminderEnabled = UserDefaults.standard.object(forKey: "breakReminderEnabled") as? Bool ?? false
        self.breakReminderMode = UserDefaults.standard.string(forKey: "breakReminderMode") ?? "afterHours"
        self.breakReminderAfterHours = UserDefaults.standard.object(forKey: "breakReminderAfterHours") as? Double ?? 4.0
        self.breakReminderAtHour = UserDefaults.standard.object(forKey: "breakReminderAtHour") as? Int ?? 12
        self.breakReminderAtMinute = UserDefaults.standard.object(forKey: "breakReminderAtMinute") as? Int ?? 0
        
        // End of day reminder
        self.endOfDayReminderEnabled = UserDefaults.standard.object(forKey: "endOfDayReminderEnabled") as? Bool ?? false
        self.endOfDayReminderHours = UserDefaults.standard.object(forKey: "endOfDayReminderHours") as? Double ?? 8.0
    }
}
