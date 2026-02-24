import Foundation
import Combine
import UserNotifications
import Network

// MARK: - Notification Names
extension Notification.Name {
    static let sessionExpired = Notification.Name("sessionExpired")
}

// MARK: - App Version
struct AppVersion {
    static let version = "1.1.0"
    static let build = "2"
    static var fullVersion: String { "\(version) (\(build))" }
}

// MARK: - SSL Delegate

/// Trusts the BIKE24 self-signed certificate for all API calls
class Bike24SessionDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
    
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        handleChallenge(challenge, completionHandler: completionHandler)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        handleChallenge(challenge, completionHandler: completionHandler)
    }
    
    private func handleChallenge(_ challenge: URLAuthenticationChallenge,
                                 completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let serverTrust = challenge.protectionSpace.serverTrust,
           challenge.protectionSpace.host.contains("bike24") {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

// MARK: - Session Manager

@MainActor
class SessionManager: ObservableObject {
    
    // MARK: - Published State
    @Published var isAuthenticated = false
    @Published var isWorking = false
    @Published var isPaused = false
    @Published var userName = ""
    @Published var employeeNumber = ""
    @Published var todayWorkedMinutes: Int = 0
    @Published var todaySollMinutes: Int = 480
    @Published var saldoMinutes: Int = 0
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var statusMessage: String?
    @Published var recentBookings: [BookingEntry] = []
    @Published var needsLogin = false
    @Published var lastSessionRefresh: Date?
    
    // Pause tracking
    @Published var pauseStartTime: Date?
    
    // Notification tracking (reset daily)
    private var breakReminderFired = false
    private var endOfDayReminderFired = false
    private var lastReminderResetDay: Int = 0  // Day of month when reminders were last reset
    
    // Reference to settings (set by AppDelegate after init)
    weak var settingsManager: SettingsManager?
    
    // Network/VPN status
    @Published var isVPNConnected = true
    @Published var isReconnecting = false
    @Published var isDataStale = false  // true = show placeholder until fresh data arrives
    
    // MARK: - Internal State
    private var sessionId: String = ""
    private var clientId: String = ""
    private var serverWorkedMinutes: Int = 0
    private var lastKommenTime: Date?
    private var lastDataFetchTime: Date?  // When we last received data from server
    
    // MARK: - Configuration
    private let baseURL = "https://zeiterfassung.b24.bike24.net/06.25.10.25403"
    private let centralPath = "/rs/de.aidaorga.aida.ewas.central"
    private let taimsPath = "/rs/de.aidaorga.aida.ewas.taims"
    
    // MARK: - Timers
    private var keepAliveTimer: Timer?
    private var refreshTimer: Timer?
    private var liveTimeTimer: Timer?
    private var vpnRetryTimer: Timer?
    private let keepAliveInterval: TimeInterval = 20 * 60  // 20 min
    private let dataRefreshInterval: TimeInterval = 60      // 60 sec (server recalculates each time)
    private var isFetching = false  // Prevent overlapping fetch calls
    
    // MARK: - Network Monitor
    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "net.bike24.aida.networkmonitor")
    
    // MARK: - Networking
    private let sessionDelegate = Bike24SessionDelegate()
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config, delegate: sessionDelegate, delegateQueue: nil)
    }()
    
    // MARK: - Types
    
    enum BookingType: String {
        case kommen = "Kommen"
        case gehen = "Gehen"
        case pause = "Pause"
    }
    
    struct BookingEntry: Identifiable {
        let id = UUID()
        let date: Date
        let type: Int  // 1=Kommen, 2=Gehen, 0=Pause
        let typeLabel: String
    }
    
    // MARK: - Init
    
    init() {
        loadOrGenerateClientId()
        startNetworkMonitor()
        attemptAutoLogin()
    }
    
    /// Generates a persistent ClientID (like the browser does)
    private func loadOrGenerateClientId() {
        if let stored = UserDefaults.standard.string(forKey: "aida_clientId"), !stored.isEmpty {
            clientId = stored
        } else {
            clientId = UUID().uuidString.lowercased()
            UserDefaults.standard.set(clientId, forKey: "aida_clientId")
        }
    }
    
    /// Monitors network path changes to detect VPN connect/disconnect
    private func startNetworkMonitor() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                if path.status == .satisfied {
                    if self.isAuthenticated {
                        // Network changed (VPN toggle, WiFi switch, etc.) – check server
                        print("🌐 Network path changed – checking server reachability...")
                        let reachable = await self.isServerReachable()
                        
                        if reachable && !self.isVPNConnected {
                            // VPN came back
                            print("✅ Server reachable again!")
                            self.isVPNConnected = true
                            self.isReconnecting = false
                            self.errorMessage = nil
                            await self.handleWakeFromSleep()
                        } else if !reachable && self.isVPNConnected {
                            // VPN dropped
                            print("⚠️ Server unreachable – VPN likely disconnected")
                            self.isVPNConnected = false
                            self.isDataStale = true
                            self.lastDataFetchTime = nil
                            self.checkVPNAndReconnect()
                        }
                    }
                } else {
                    // Network completely gone
                    if self.isVPNConnected {
                        print("⚠️ Network lost")
                        self.isVPNConnected = false
                        self.isDataStale = true
                        self.lastDataFetchTime = nil
                    }
                }
            }
        }
        networkMonitor.start(queue: monitorQueue)
    }
    
    /// Tries to login with stored Keychain credentials on app start
    private func attemptAutoLogin() {
        guard let creds = KeychainService.shared.loadCredentials() else {
            needsLogin = true
            return
        }
        
        Task {
            await login(username: creds.username, password: creds.password, saveToKeychain: false)
        }
    }
    
    // MARK: - VPN Reconnection
    
    /// Checks if the AIDA server is reachable (= VPN is up) and reconnects
    private func checkVPNAndReconnect() {
        // Avoid duplicate retry loops
        guard vpnRetryTimer == nil else { return }
        
        isReconnecting = true
        var attempt = 0
        let maxAttempts = 15  // Try for ~45 seconds
        
        vpnRetryTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] timer in
            Task { @MainActor [weak self] in
                guard let self = self else { timer.invalidate(); return }
                
                attempt += 1
                print("🔄 VPN check attempt \(attempt)/\(maxAttempts)...")
                
                let reachable = await self.isServerReachable()
                
                if reachable {
                    print("✅ VPN connected! Refreshing data immediately...")
                    timer.invalidate()
                    self.vpnRetryTimer = nil
                    self.isReconnecting = false
                    self.errorMessage = nil
                    
                    // Re-login and fetch fresh data
                    // isDataStale stays true until fetchBookings succeeds
                    self.isVPNConnected = true
                    await self.handleWakeFromSleep()
                } else if attempt >= maxAttempts {
                    print("❌ VPN not available after \(maxAttempts) attempts")
                    timer.invalidate()
                    self.vpnRetryTimer = nil
                    self.isReconnecting = false
                    // Keep isVPNConnected = false, banner stays visible
                }
            }
        }
        
        if let timer = vpnRetryTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    /// Quick check if the AIDA server is reachable (VPN up)
    private func isServerReachable() async -> Bool {
        do {
            let url = URL(string: "\(baseURL)\(centralPath)/runtime/state")!
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = 5
            
            let (_, response) = try await urlSession.data(for: request)
            if let http = response as? HTTPURLResponse {
                return http.statusCode == 200
            }
            return false
        } catch {
            return false
        }
    }
    
    // MARK: - Login
    
    /// Authenticates with username/password against the AIDA API
    func login(username: String, password: String, saveToKeychain: Bool = true) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let url = URL(string: "\(baseURL)\(centralPath)/sessions/")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json;charset=utf-8", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("ClientID=\(clientId)", forHTTPHeaderField: "Cookie")
            
            let body: [String: String] = ["principalName": username, "password": password]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (data, response) = try await urlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AidaError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                    throw AidaError.invalidCredentials
                }
                throw AidaError.serverError(httpResponse.statusCode)
            }
            
            let json = try parseAidaResponse(data)
            
            guard let dataDict = json["Data"] as? [String: Any],
                  let newSessionId = dataDict["sessionId"] as? String else {
                throw AidaError.invalidResponse
            }
            
            // Success
            sessionId = newSessionId
            lastSessionRefresh = Date()
            isVPNConnected = true
            
            // Parse user info
            if let userData = dataDict["userDataEmployee"] as? [String: Any] {
                let given = userData["givenName"] as? String ?? ""
                let sure = userData["sureName"] as? String ?? ""
                userName = "\(given) \(sure)".trimmingCharacters(in: .whitespaces)
                employeeNumber = userData["employeeNumber"] as? String ?? ""
            }
            
            // Save credentials to Keychain
            if saveToKeychain {
                try? KeychainService.shared.saveCredentials(username: username, password: password)
            }
            
            isAuthenticated = true
            needsLogin = false
            
            print("✅ Logged in as \(userName) (Session: \(sessionId.prefix(8))...)")
            
            // Fetch initial data and start timers
            await fetchBookings()
            startTimers()
            
        } catch let error as URLError where error.code == .timedOut || error.code == .cannotConnectToHost || error.code == .notConnectedToInternet || error.code == .cannotFindHost {
            print("❌ Login failed (network): \(error)")
            isVPNConnected = false
            isDataStale = true
            errorMessage = "Keine Verbindung zum Server. VPN aktiv?"
            
            // If we have stored credentials, don't force re-login – just show VPN hint
            if !saveToKeychain && KeychainService.shared.hasStoredCredentials {
                needsLogin = false
                checkVPNAndReconnect()
            }
        } catch {
            print("❌ Login failed: \(error)")
            errorMessage = error.localizedDescription
            isAuthenticated = false
            
            if !saveToKeychain {
                needsLogin = true
            }
        }
        
        isLoading = false
    }
    
    /// Logs out and clears all stored data
    func logout() {
        stopAllTimers()
        vpnRetryTimer?.invalidate(); vpnRetryTimer = nil
        sessionId = ""
        isAuthenticated = false
        isWorking = false
        isPaused = false
        userName = ""
        employeeNumber = ""
        recentBookings = []
        todayWorkedMinutes = 0
        serverWorkedMinutes = 0
        lastDataFetchTime = nil
        saldoMinutes = 0
        needsLogin = true
        errorMessage = nil
        statusMessage = nil
        isVPNConnected = true
        isReconnecting = false
        isDataStale = false
        
        try? KeychainService.shared.deleteCredentials()
        print("👋 Logged out")
    }
    
    // MARK: - Auto Re-Login
    
    /// Called when a 401/403 is received - tries to re-authenticate silently
    private func autoRelogin() async -> Bool {
        guard let creds = KeychainService.shared.loadCredentials() else {
            needsLogin = true
            NotificationCenter.default.post(name: .sessionExpired, object: nil)
            return false
        }
        
        print("🔄 Auto re-login...")
        
        do {
            let url = URL(string: "\(baseURL)\(centralPath)/sessions/")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json;charset=utf-8", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("ClientID=\(clientId)", forHTTPHeaderField: "Cookie")
            
            let body: [String: String] = ["principalName": creds.username, "password": creds.password]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (data, response) = try await urlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw AidaError.invalidCredentials
            }
            
            let json = try parseAidaResponse(data)
            guard let dataDict = json["Data"] as? [String: Any],
                  let newSessionId = dataDict["sessionId"] as? String else {
                throw AidaError.invalidResponse
            }
            
            sessionId = newSessionId
            lastSessionRefresh = Date()
            isAuthenticated = true
            isVPNConnected = true
            needsLogin = false
            print("✅ Auto re-login successful (Session: \(sessionId.prefix(8))...)")
            return true
            
        } catch let error as URLError where error.code == .timedOut || error.code == .cannotConnectToHost || error.code == .notConnectedToInternet || error.code == .cannotFindHost {
            print("⚠️ Auto re-login failed (no VPN): \(error)")
            isVPNConnected = false
            checkVPNAndReconnect()
            return false
            
        } catch {
            print("❌ Auto re-login failed: \(error)")
            needsLogin = true
            NotificationCenter.default.post(name: .sessionExpired, object: nil)
            return false
        }
    }
    
    // MARK: - Authenticated Request Helper
    
    /// Makes an authenticated API request with automatic re-login on 401/403
    private func authenticatedRequest(path: String, method: String = "GET",
                                       body: [String: Any]? = nil) async throws -> [String: Any] {
        func makeRequest() throws -> URLRequest {
            let url = URL(string: "\(baseURL)\(path)")!
            var request = URLRequest(url: url)
            request.httpMethod = method
            request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
            request.setValue(sessionId, forHTTPHeaderField: "X-EWAS-SESSIONID")
            request.setValue("ClientID=\(clientId)", forHTTPHeaderField: "Cookie")
            
            if let body = body {
                request.setValue("application/json;charset=utf-8", forHTTPHeaderField: "Content-Type")
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            }
            return request
        }
        
        // First attempt
        do {
            let request = try makeRequest()
            let (data, response) = try await urlSession.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse,
               (httpResponse.statusCode == 401 || httpResponse.statusCode == 403) {
                // Session expired - try re-login
                let success = await autoRelogin()
                guard success else { throw AidaError.invalidSession }
                
                // Retry with new session
                let retryRequest = try makeRequest()
                let (retryData, retryResponse) = try await urlSession.data(for: retryRequest)
                
                guard let retryHttp = retryResponse as? HTTPURLResponse, retryHttp.statusCode == 200 else {
                    throw AidaError.invalidSession
                }
                
                isVPNConnected = true
                return try parseAidaResponse(retryData)
            }
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw AidaError.invalidResponse
            }
            
            // Success – VPN is working
            if !isVPNConnected {
                isVPNConnected = true
                errorMessage = nil
            }
            
            return try parseAidaResponse(data)
            
        } catch let error as URLError where error.code == .timedOut || error.code == .cannotConnectToHost || error.code == .notConnectedToInternet || error.code == .cannotFindHost {
            isVPNConnected = false
            isDataStale = true
            lastDataFetchTime = nil  // Don't tick up stale values
            throw AidaError.noConnection
        }
    }
    
    // MARK: - Time Booking
    
    func bookTime(type: BookingType, pauseReminderEnabled: Bool = false, pauseReminderMinutes: Int = 30) async {
        guard isAuthenticated else {
            errorMessage = "Nicht angemeldet"
            needsLogin = true
            return
        }
        
        isLoading = true
        errorMessage = nil
        statusMessage = nil
        
        do {
            var body: [String: Any]
            
            if type == .pause {
                body = ["knopf": "Dienstgang", "dienst_eingabe": "", "dienst_buchen": "PA"]
            } else {
                body = ["knopf": type.rawValue, "eingabe": ""]
            }
            
            let json = try await authenticatedRequest(
                path: "\(taimsPath)/rpc?&requesttype=OWN",
                method: "POST",
                body: body
            )
            
            if let dataDict = json["Data"] as? [String: Any] {
                let erfolg = dataDict["Erfolg"] as? Bool ?? false
                let text = dataDict["text"] as? String ?? ""
                
                if erfolg {
                    statusMessage = text.replacingOccurrences(of: "<br>", with: "\n")
                    
                    switch type {
                    case .kommen:
                        isWorking = true
                        isPaused = false
                        pauseStartTime = nil
                        cancelPauseReminder()
                    case .gehen:
                        isWorking = false
                        isPaused = false
                        pauseStartTime = nil
                        cancelPauseReminder()
                    case .pause:
                        if isPaused {
                            isPaused = false
                            pauseStartTime = nil
                            cancelPauseReminder()
                        } else {
                            isPaused = true
                            pauseStartTime = Date()
                            if pauseReminderEnabled {
                                schedulePauseReminder(minutes: pauseReminderMinutes)
                            }
                        }
                    }
                    
                    await fetchBookings()
                } else {
                    throw AidaError.bookingRejected(text)
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Fetch Bookings
    
    func fetchBookings() async {
        guard isAuthenticated else { return }
        guard !isFetching else { return }  // Prevent overlapping calls
        isFetching = true
        defer { isFetching = false }
        
        do {
            // Trigger server-side recalculation of time values
            // Without this, buchungen_7Tage returns cached/stale times
            _ = try? await authenticatedRequest(
                path: "\(taimsPath)/rpc?",
                method: "POST",
                body: ["__knopf": "RechneBisHeute"]
            )
            
            let json = try await authenticatedRequest(path: "\(taimsPath)/rpc/buchungen_7Tage")
            
            guard let dataDict = json["Data"] as? [String: Any] else { return }
            
            // Update working status
            if let present = dataDict["present"] as? Bool {
                isWorking = present
            }
            
            // Parse Soll/Ist from times array
            if let times = dataDict["times"] as? [[String: Any]] {
                let todayKey = formatDate(Date())
                
                for timeEntry in times {
                    if let values = timeEntry["values"] as? [String: [Int]] {
                        let todayValues = values[todayKey]
                            ?? values[formatDateAlt(Date())]
                            ?? values.first(where: { $0.key.contains(formatDateShort(Date())) })?.value
                        
                        if let vals = todayValues, vals.count >= 2 {
                            todaySollMinutes = vals[0]
                            serverWorkedMinutes = vals[1]
                        }
                    }
                }
            }
            
            // Parse Saldo from dailyAccValue
            if let dailyAccValue = dataDict["dailyAccValue"] as? [[String: Any]] {
                let todayKey = formatDate(Date())
                
                for accGroup in dailyAccValue {
                    if let accounts = accGroup["Accounts"] as? [[String: Any]] {
                        for account in accounts {
                            if let values = account["values"] as? [String: [Int]] {
                                let sortedDates = values.keys.sorted()
                                let targetDate = values[todayKey] != nil ? todayKey : (sortedDates.last ?? "")
                                
                                if let dayValues = values[targetDate], dayValues.count > 4 {
                                    saldoMinutes = dayValues[4]
                                }
                            }
                        }
                    }
                }
            }
            
            // Parse bookings for today
            if let bookings = dataDict["bookings"] as? [[String: Any]] {
                let today = Calendar.current.startOfDay(for: Date())
                
                recentBookings = bookings.compactMap { booking in
                    guard let dateString = booking["Date"] as? String,
                          let typeInfo = booking["TypeInfo"] as? Int,
                          let date = parseBookingDate(dateString) else { return nil }
                    
                    guard Calendar.current.startOfDay(for: date) == today else { return nil }
                    
                    let label: String
                    switch typeInfo {
                    case 1: label = "Kommen"
                    case 2: label = "Gehen"
                    case 0: label = "Pause"
                    default: label = "?"
                    }
                    
                    return BookingEntry(date: date, type: typeInfo, typeLabel: label)
                }
                .sorted { $0.date > $1.date }
                
                if let last = recentBookings.first {
                    isPaused = (last.type == 0)
                }
                
                var foundGehen = false
                lastKommenTime = nil
                for booking in recentBookings {
                    if booking.type == 2 { foundGehen = true }
                    else if booking.type == 1 && !foundGehen {
                        lastKommenTime = booking.date
                        break
                    }
                }
                
                todayWorkedMinutes = liveWorkedMinutes
            }
            
            // Fresh data received – record fetch time and clear stale flag
            lastDataFetchTime = Date()
            if isDataStale { isDataStale = false }  // Only publish change if actually stale
            
            print("✅ Data fetched: server=\(serverWorkedMinutes)min, live=\(liveWorkedMinutes)min")
            
        } catch {
            print("❌ Fetch bookings failed: \(error)")
        }
    }
    
    // MARK: - Live Time Calculation
    
    /// Uses server value as base truth, adds live elapsed time since last fetch.
    /// RechneBisHeute forces server recalculation every 60s, so serverWorkedMinutes
    /// is always near-accurate. We interpolate between fetches for smooth display.
    var liveWorkedMinutes: Int {
        guard isWorking, let fetchTime = lastDataFetchTime else {
            return serverWorkedMinutes
        }
        
        // Add minutes elapsed since we last got data from the server
        let elapsedSinceFetch = Int(Date().timeIntervalSince(fetchTime) / 60)
        
        // If paused, don't count time since pause started
        if isPaused, let pauseStart = pauseStartTime {
            let pauseMinutes = Int(Date().timeIntervalSince(pauseStart) / 60)
            return serverWorkedMinutes + max(0, elapsedSinceFetch - pauseMinutes)
        }
        
        return serverWorkedMinutes + elapsedSinceFetch
    }
    
    // MARK: - Pause Reminder
    
    func schedulePauseReminder(minutes: Int) {
        cancelPauseReminder()
        
        // Initial notification after the pause time
        let content = UNMutableNotificationContent()
        content.title = "⏰ Pause beenden"
        content.body = "Deine \(minutes)-Minuten-Pause ist vorbei. Vergiss nicht, die Pause zu beenden!"
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        content.categoryIdentifier = "PAUSE_REMINDER"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(minutes * 60), repeats: false)
        let request = UNNotificationRequest(identifier: "pauseReminder", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule pause reminder: \(error)")
            }
        }
        
        // Follow-up reminders every 5 minutes to stay persistent
        for i in 1...6 {
            let followUp = UNMutableNotificationContent()
            followUp.title = "⏰ Pause läuft noch!"
            followUp.body = "Du bist seit \(minutes + (i * 5)) Minuten in der Pause."
            followUp.sound = .default
            followUp.interruptionLevel = .timeSensitive
            followUp.categoryIdentifier = "PAUSE_REMINDER"
            
            let followUpTrigger = UNTimeIntervalNotificationTrigger(
                timeInterval: TimeInterval((minutes + (i * 5)) * 60), repeats: false
            )
            let followUpRequest = UNNotificationRequest(
                identifier: "pauseReminder_followup_\(i)", content: followUp, trigger: followUpTrigger
            )
            UNUserNotificationCenter.current().add(followUpRequest)
        }
        
        print("✅ Pause reminder scheduled: \(minutes)min + 6 follow-ups")
    }
    
    func cancelPauseReminder() {
        var ids = ["pauseReminder"]
        for i in 1...6 { ids.append("pauseReminder_followup_\(i)") }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ids)
    }
    
    // MARK: - Break Reminder (remind to take a break)
    
    /// Checks if a break reminder should fire based on current settings
    private func checkBreakReminder() {
        guard let settings = settingsManager, settings.breakReminderEnabled else { return }
        guard isWorking, !isPaused, !breakReminderFired else { return }
        
        var shouldFire = false
        
        switch settings.breakReminderMode {
        case "afterHours":
            let thresholdMinutes = Int(settings.breakReminderAfterHours * 60)
            if todayWorkedMinutes >= thresholdMinutes {
                shouldFire = true
            }
        case "atTime":
            let now = Calendar.current.dateComponents([.hour, .minute], from: Date())
            if let hour = now.hour, let minute = now.minute {
                // Fire once when we reach or pass the target time
                let nowMinutes = hour * 60 + minute
                let targetMinutes = settings.breakReminderAtHour * 60 + settings.breakReminderAtMinute
                if nowMinutes >= targetMinutes {
                    shouldFire = true
                }
            }
        default:
            break
        }
        
        if shouldFire {
            breakReminderFired = true
            
            let content = UNMutableNotificationContent()
            content.title = "☕ Zeit für eine Pause"
            if settings.breakReminderMode == "afterHours" {
                let hours = settings.breakReminderAfterHours
                let hoursText = hours == Double(Int(hours)) ? "\(Int(hours))" : String(format: "%.1f", hours)
                content.body = "Du arbeitest seit \(hoursText) Stunden. Gönn dir eine kurze Pause!"
            } else {
                content.body = "Geplante Erinnerung: Zeit für eine Pause!"
            }
            content.sound = .default
            content.interruptionLevel = .timeSensitive
            
            let request = UNNotificationRequest(identifier: "breakReminder", content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error { print("❌ Break reminder failed: \(error)") }
            }
            print("✅ Break reminder fired")
        }
    }
    
    // MARK: - End of Day Reminder (Feierabend)
    
    /// Checks if end-of-day notification should fire
    private func checkEndOfDayReminder() {
        guard let settings = settingsManager, settings.endOfDayReminderEnabled else { return }
        guard isWorking, !endOfDayReminderFired else { return }
        
        let thresholdMinutes = Int(settings.endOfDayReminderHours * 60)
        if todayWorkedMinutes >= thresholdMinutes {
            endOfDayReminderFired = true
            
            let hours = settings.endOfDayReminderHours
            let hoursText = hours == Double(Int(hours)) ? "\(Int(hours))" : String(format: "%.1f", hours)
            
            let content = UNMutableNotificationContent()
            content.title = "🏁 Feierabend!"
            content.body = "Du hast \(hoursText) Stunden erreicht. Zeit zum Ausstempeln!"
            content.sound = .default
            content.interruptionLevel = .timeSensitive
            
            let request = UNNotificationRequest(identifier: "endOfDayReminder", content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error { print("❌ End of day reminder failed: \(error)") }
            }
            print("✅ End of day reminder fired at \(todayWorkedMinutes) min")
        }
    }
    
    /// Reset reminder flags at the start of each new day
    private func resetDailyReminders() {
        let today = Calendar.current.component(.day, from: Date())
        if today != lastReminderResetDay {
            lastReminderResetDay = today
            breakReminderFired = false
            endOfDayReminderFired = false
            print("🔄 Daily reminder flags reset")
        }
    }
    
    func cancelWorkReminders() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["breakReminder", "endOfDayReminder"])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["breakReminder", "endOfDayReminder"])
    }
    
    // MARK: - Timer Management
    
    private func startTimers() {
        stopAllTimers()
        
        keepAliveTimer = Timer.scheduledTimer(withTimeInterval: keepAliveInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.keepSessionAlive()
            }
        }
        
        refreshTimer = Timer.scheduledTimer(withTimeInterval: dataRefreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.fetchBookings()
            }
        }
        
        liveTimeTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.isWorking, !self.isDataStale else { return }
                self.todayWorkedMinutes = self.liveWorkedMinutes
                
                // Check time-based notifications
                self.resetDailyReminders()
                self.checkBreakReminder()
                self.checkEndOfDayReminder()
            }
        }
        
        [keepAliveTimer, refreshTimer, liveTimeTimer].compactMap { $0 }.forEach {
            RunLoop.main.add($0, forMode: .common)
        }
        
        print("⏱️ Timers started")
    }
    
    func stopAllTimers() {
        keepAliveTimer?.invalidate(); keepAliveTimer = nil
        refreshTimer?.invalidate(); refreshTimer = nil
        liveTimeTimer?.invalidate(); liveTimeTimer = nil
        cancelPauseReminder()
        cancelWorkReminders()
    }
    
    // MARK: - Keep-Alive
    
    private func keepSessionAlive() async {
        guard isAuthenticated else { return }
        
        do {
            _ = try await authenticatedRequest(path: "\(centralPath)/sessions/\(sessionId)")
            lastSessionRefresh = Date()
            print("✅ Keep-alive OK")
        } catch {
            print("⚠️ Keep-alive failed: \(error)")
        }
    }
    
    // MARK: - Wake from Sleep
    
    func handleWakeFromSleep() async {
        stopAllTimers()
        
        guard KeychainService.shared.hasStoredCredentials else {
            needsLogin = true
            return
        }
        
        // Quick reachability check first
        let reachable = await isServerReachable()
        
        if !reachable {
            print("⚠️ Server not reachable after wake – VPN probably reconnecting...")
            isVPNConnected = false
            isDataStale = true
            checkVPNAndReconnect()
            return
        }
        
        // Server reachable – try to validate/re-login
        isVPNConnected = true
        
        if !sessionId.isEmpty {
            do {
                _ = try await authenticatedRequest(path: "\(centralPath)/sessions/\(sessionId)")
                lastSessionRefresh = Date()
                startTimers()
                await fetchBookings()
                print("✅ Session still valid after wake")
                return
            } catch {
                print("⚠️ Session expired after wake, re-logging in...")
            }
        }
        
        let success = await autoRelogin()
        if success {
            startTimers()
            await fetchBookings()
        }
    }
    
    /// Force retry VPN connection (called from UI "Erneut verbinden" button)
    func retryConnection() {
        vpnRetryTimer?.invalidate(); vpnRetryTimer = nil
        isDataStale = true
        checkVPNAndReconnect()
    }
    
    /// Manual refresh from UI
    func manualRefresh() async {
        await fetchBookings()
    }
    
    
    // MARK: - Session Display
    
    var sessionTimeRemaining: TimeInterval? {
        guard let lastRefresh = lastSessionRefresh else { return nil }
        let remaining = (30 * 60) - Date().timeIntervalSince(lastRefresh)
        return max(0, remaining)
    }
    
    var formattedSessionTimeRemaining: String {
        guard let remaining = sessionTimeRemaining else { return "—" }
        let minutes = Int(remaining / 60)
        let seconds = Int(remaining.truncatingRemainder(dividingBy: 60))
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var formattedPauseDuration: String {
        guard let start = pauseStartTime else { return "0:00" }
        let duration = Date().timeIntervalSince(start)
        return String(format: "%d:%02d", Int(duration / 60), Int(duration.truncatingRemainder(dividingBy: 60)))
    }
    
    // MARK: - Parsing Helpers
    
    private func parseAidaResponse(_ data: Data) throws -> [String: Any] {
        guard var jsonString = String(data: data, encoding: .utf8) else {
            throw AidaError.invalidResponse
        }
        if jsonString.hasPrefix("while(1);") {
            jsonString = String(jsonString.dropFirst(9))
        }
        guard let jsonData = jsonString.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw AidaError.invalidResponse
        }
        return json
    }
    
    private func parseBookingDate(_ string: String) -> Date? {
        for format in ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss.SSS"] {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "en_US_POSIX")
            if let date = formatter.date(from: string) { return date }
        }
        return nil
    }
    
    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: date)
    }
    
    private func formatDateAlt(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "dd.MM.yyyy"; return f.string(from: date)
    }
    
    private func formatDateShort(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "MM-dd"; return f.string(from: date)
    }
}

// MARK: - Errors

enum AidaError: LocalizedError {
    case invalidSession
    case invalidCredentials
    case invalidResponse
    case bookingFailed
    case bookingRejected(String)
    case serverError(Int)
    case noConnection
    
    var errorDescription: String? {
        switch self {
        case .invalidSession: return "Session abgelaufen."
        case .invalidCredentials: return "Anmeldekennung oder Passwort falsch."
        case .invalidResponse: return "Ungültige Server-Antwort."
        case .bookingFailed: return "Buchung fehlgeschlagen."
        case .bookingRejected(let msg): return "Buchung abgelehnt: \(msg)"
        case .serverError(let code): return "Server-Fehler (\(code))."
        case .noConnection: return "Keine Verbindung zum Server."
        }
    }
}
