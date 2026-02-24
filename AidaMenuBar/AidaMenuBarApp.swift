import SwiftUI
import UserNotifications
import Combine

@main
struct AidaMenuBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(appDelegate.sessionManager)
                .environmentObject(appDelegate.settingsManager)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, @unchecked Sendable, UNUserNotificationCenterDelegate {
    @MainActor var statusItem: NSStatusItem!
    @MainActor var popover: NSPopover!
    @MainActor let sessionManager = SessionManager()
    @MainActor let settingsManager = SettingsManager()
    
    @MainActor private var cancellables = Set<AnyCancellable>()
    @MainActor private var eventMonitor: Any?
    
    @MainActor func applicationDidFinishLaunching(_ notification: Notification) {
        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✅ Notification permission granted")
            } else if let error = error {
                print("❌ Notification permission error: \(error)")
            }
        }
        UNUserNotificationCenter.current().delegate = self
        
        // Connect settings to session manager for notification checks
        sessionManager.settingsManager = settingsManager
        
        setupMenuBar()
        setupObservers()
        setupEventMonitor()
        setupWakeNotification()
        
        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)
        
        // CRITICAL: Prevent macOS from auto-terminating this background app
        // Without this, macOS may silently kill the app under memory pressure
        // or when it thinks the app is "inactive" (no visible windows)
        ProcessInfo.processInfo.disableSuddenTermination()
        ProcessInfo.processInfo.disableAutomaticTermination("AIDA MenuBar is a persistent menu bar app")
        
        print("✅ AIDA MenuBar v\(AppVersion.fullVersion) launched")
    }
    
    /// Prevent accidental termination – only allow explicit quit via UI
    @MainActor func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        print("⚠️ applicationShouldTerminate called")
        // Allow termination (we rely on the quit confirmation in the UI)
        return .terminateNow
    }
    
    @MainActor func setupWakeNotification() {
        // Listen for system wake from sleep
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleWakeFromSleep),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        
        // Also listen for screen unlock (in case session expired during lock)
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleScreenUnlock),
            name: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil
        )
        
        // Listen for session expired notification to auto-open login
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSessionExpired),
            name: .sessionExpired,
            object: nil
        )
        
        print("✅ Wake/unlock/session observers registered")
    }
    
    @MainActor @objc func handleSessionExpired() {
        print("🔐 Session expired - showing inline login")
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            // Open the popover – inline login form will show automatically
            if let button = statusItem.button, !popover.isShown {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                if let window = popover.contentViewController?.view.window {
                    window.makeKeyAndOrderFront(nil)
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
        }
    }
    
    @MainActor @objc func handleWakeFromSleep() {
        print("🌅 System woke from sleep - refreshing session...")
        Task { @MainActor in
            // Small delay to let network reconnect
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
            // Restart timers and validate session
            await sessionManager.handleWakeFromSleep()
            updateMenuBarDisplay()
        }
    }
    
    @MainActor @objc func handleScreenUnlock() {
        print("🔓 Screen unlocked - checking session...")
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            await sessionManager.handleWakeFromSleep()
            updateMenuBarDisplay()
        }
    }
    
    @MainActor func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            updateMenuBarDisplay()
            button.action = #selector(togglePopover)
            button.target = self
        }
        
        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 450)
        popover.behavior = .transient // Closes when clicking outside
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: ContentView()
                .environmentObject(sessionManager)
                .environmentObject(settingsManager)
        )
    }
    
    @MainActor func setupEventMonitor() {
        // Additional monitor to ensure popover closes on any click outside
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self = self else { return }
            if self.popover.isShown {
                self.popover.performClose(nil)
            }
        }
    }
    
    @MainActor func setupObservers() {
        // Observe worked minutes
        sessionManager.$todayWorkedMinutes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateMenuBarDisplay() }
            .store(in: &cancellables)
        
        // Observe working status
        sessionManager.$isWorking
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateMenuBarDisplay() }
            .store(in: &cancellables)
        
        // Observe authenticated status
        sessionManager.$isAuthenticated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateMenuBarDisplay() }
            .store(in: &cancellables)
        
        // Observe VPN status
        sessionManager.$isVPNConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateMenuBarDisplay() }
            .store(in: &cancellables)
        
        // Observe pause status
        sessionManager.$isPaused
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateMenuBarDisplay() }
            .store(in: &cancellables)
        
        // Observe data stale status
        sessionManager.$isDataStale
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateMenuBarDisplay() }
            .store(in: &cancellables)
        
        // Observe settings
        settingsManager.$showTimeInMenuBar
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateMenuBarDisplay() }
            .store(in: &cancellables)
    }
    
    @MainActor func updateMenuBarDisplay() {
        guard let button = statusItem.button else { return }
        
        let isWorking = sessionManager.isWorking
        let isConnected = sessionManager.isVPNConnected
        
        let isStale = sessionManager.isDataStale
        
        let isPaused = sessionManager.isPaused
        
        // Choose icon based on state
        let iconName: String
        if !isConnected {
            iconName = "clock.badge.exclamationmark"  // Disconnected
        } else if isStale {
            iconName = "clock.badge.exclamationmark"  // Reconnecting, waiting for data
        } else if isPaused {
            iconName = "pause.circle"                  // On break
        } else if isWorking {
            iconName = "clock.fill"                    // Working
        } else {
            iconName = "clock"                         // Idle
        }
        
        // Create properly sized image for menu bar
        let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        let image = NSImage(systemSymbolName: iconName, accessibilityDescription: "AIDA")?
            .withSymbolConfiguration(config)
        image?.isTemplate = true  // Adapts to light/dark menu bar
        button.image = image
        
        if settingsManager.showTimeInMenuBar && sessionManager.isAuthenticated {
            let hours = sessionManager.todayWorkedMinutes / 60
            let minutes = sessionManager.todayWorkedMinutes % 60
            
            let timeText: String
            if !isConnected || isStale {
                timeText = "\u{2009}–:––"  // Thin space + placeholder
            } else {
                timeText = String(format: "\u{2009}%d:%02d", hours, minutes)  // Thin space before time
            }
            
            // Use attributed string to vertically center the text with the icon
            let font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
            let attrString = NSAttributedString(
                string: timeText,
                attributes: [
                    .font: font,
                    .baselineOffset: -0.5
                ]
            )
            button.attributedTitle = attrString
            button.imagePosition = .imageLeading
        } else {
            button.title = ""
            button.imagePosition = .imageOnly
        }
    }
    
    @MainActor @objc func togglePopover() {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                // Show popover
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                
                // Make the popover window key and front immediately
                if let window = popover.contentViewController?.view.window {
                    window.makeKeyAndOrderFront(nil)
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
        }
    }
    
    // Handle notifications when app is in foreground - show as persistent alert
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show as banner with sound - the notification will stay in notification center
        completionHandler([.banner, .sound, .list])
    }
    
    // Handle notification interaction
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // User tapped on notification - open the app on main thread
        Task { @MainActor in
            if let button = statusItem.button {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                if let window = popover.contentViewController?.view.window {
                    window.makeKeyAndOrderFront(nil)
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
        }
        completionHandler()
    }
    
    deinit {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
