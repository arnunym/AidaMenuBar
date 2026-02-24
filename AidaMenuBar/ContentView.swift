import SwiftUI

struct ContentView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var showingSettings = false
    
    // Inline login state
    @State private var loginUsername = ""
    @State private var loginPassword = ""
    @State private var loginRememberMe = true
    
    // Footer state
    @State private var refreshState: RefreshButtonState = .idle
    @State private var showQuitConfirm = false
    
    enum RefreshButtonState {
        case idle, refreshing, success
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            
            if showingSettings {
                settingsInlineView
            } else {
                // VPN warning banner
                if !sessionManager.isVPNConnected {
                    vpnBannerView
                }
                
                if sessionManager.isAuthenticated || (!sessionManager.isVPNConnected && !sessionManager.needsLogin) {
                    authenticatedView
                } else {
                    loginView
                }
                
                footerView
            }
        }
        .frame(width: 320)
        .onAppear {
            if let creds = KeychainService.shared.loadCredentials() {
                loginUsername = creds.username
            }
        }
    }
    
    // MARK: - Header
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var headerView: some View {
        HStack(spacing: 8) {
            if showingSettings {
                Button(action: { withAnimation(.easeInOut(duration: 0.15)) { showingSettings = false } }) {
                    HStack(spacing: 3) {
                        Image(systemName: "chevron.backward")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Einstellungen")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.accentColor)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                AidaLogoView(size: 22, color: colorScheme == .dark ? .white : Color(red: 0, green: 0.271, blue: 0.514))
                
                Text("AIDA Zeiterfassung")
                    .font(.system(size: 13, weight: .semibold))
            }
            
            Spacer()
            
            if !showingSettings {
                Button(action: { withAnimation(.easeInOut(duration: 0.15)) { showingSettings = true } }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }
    
    // MARK: - VPN Banner
    
    private var vpnBannerView: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.exclamationmark")
                .foregroundColor(.white)
                .font(.caption)
            
            VStack(alignment: .leading, spacing: 1) {
                Text("Keine VPN-Verbindung")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Text(sessionManager.isReconnecting ? "Verbinde..." : "VPN verbinden um fortzufahren")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
            
            if sessionManager.isReconnecting {
                ProgressView()
                    .scaleEffect(0.5)
                    .colorScheme(.dark)
            } else {
                Button(action: { sessionManager.retryConnection() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.orange)
    }
    
    // MARK: - Login View
    
    private var loginView: some View {
        VStack(spacing: 14) {
            VStack(spacing: 10) {
                TextField("Anmeldekennung", text: $loginUsername)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.username)
                    .font(.system(size: 13))
                
                SecureField("Passwort", text: $loginPassword)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.password)
                    .font(.system(size: 13))
                    .onSubmit { attemptInlineLogin() }
            }
            
            HStack {
                Toggle("Angemeldet bleiben", isOn: $loginRememberMe)
                    .font(.caption)
                    .toggleStyle(.checkbox)
                
                Spacer()
                
                Button(action: attemptInlineLogin) {
                    Group {
                        if sessionManager.isLoading {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Text("Anmelden")
                        }
                    }
                    .frame(width: 80, height: 24)
                }
                .buttonStyle(.borderedProminent)
                .disabled(loginUsername.isEmpty || loginPassword.isEmpty || sessionManager.isLoading)
            }
            
            if let error = sessionManager.errorMessage {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                    Text(error)
                        .font(.caption2)
                }
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
            }
            
            HStack(spacing: 4) {
                Image(systemName: "lock.shield")
                    .font(.caption2)
                Text("VPN-Verbindung erforderlich")
                    .font(.caption2)
            }
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }
    
    private func attemptInlineLogin() {
        guard !loginUsername.isEmpty, !loginPassword.isEmpty else { return }
        Task {
            await sessionManager.login(username: loginUsername, password: loginPassword, saveToKeychain: loginRememberMe)
        }
    }
    
    // MARK: - Authenticated View
    
    private var authenticatedView: some View {
        ScrollView {
            VStack(spacing: 12) {
                userInfoView
                timeSummaryView
                bookingButtonsView
                
                if let status = sessionManager.statusMessage {
                    Text(status)
                        .font(.caption)
                        .foregroundColor(.green)
                        .padding(.horizontal)
                        .multilineTextAlignment(.center)
                }
                
                if let error = sessionManager.errorMessage, sessionManager.isVPNConnected {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                        .multilineTextAlignment(.center)
                }
                
                recentBookingsView
            }
            .padding(.vertical, 12)
        }
    }
    
    // MARK: - User Info
    
    private var userInfoView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(sessionManager.userName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("Nr. \(sessionManager.employeeNumber)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 7, height: 7)
                Text(statusLabel)
                    .font(.caption2)
                    .foregroundColor(statusColor)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(statusColor.opacity(0.1))
            )
        }
        .padding(.horizontal, 16)
    }
    
    private var statusColor: Color {
        if !sessionManager.isVPNConnected || sessionManager.isDataStale { return .orange }
        if sessionManager.isPaused { return .blue }
        if sessionManager.isWorking { return .green }
        return .gray
    }
    
    private var statusLabel: String {
        if !sessionManager.isVPNConnected { return "Offline" }
        if sessionManager.isDataStale { return "Aktualisiere..." }
        if sessionManager.isPaused { return "Pause" }
        if sessionManager.isWorking { return "Anwesend" }
        return "Abwesend"
    }
    
    // MARK: - Time Summary
    
    /// Whether to show placeholder dashes instead of real values
    private var showPlaceholders: Bool {
        sessionManager.isDataStale || !sessionManager.isVPNConnected
    }
    
    private var timeSummaryView: some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Heute")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                if showPlaceholders {
                    Text("–:––")
                        .font(.system(.title2, design: .monospaced))
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                } else {
                    Text(formatMinutes(sessionManager.todayWorkedMinutes))
                        .font(.system(.title2, design: .monospaced))
                        .fontWeight(.semibold)
                }
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(progressColor)
                        .frame(width: progressWidth(for: geo.size.width), height: 6)
                }
            }
            .frame(height: 6)
            
            HStack {
                Text("/ \(formatMinutes(sessionManager.todaySollMinutes))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text("Saldo")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if showPlaceholders {
                        Text("–:–– h")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.secondary)
                    } else {
                        Text(formatSaldo(sessionManager.saldoMinutes))
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(sessionManager.saldoMinutes >= 0 ? .green : .red)
                    }
                }
            }
            
            if sessionManager.isPaused {
                HStack(spacing: 4) {
                    Image(systemName: "pause.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.blue)
                    Text("Pause: \(sessionManager.formattedPauseDuration)")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
                .padding(.top, 2)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .padding(.horizontal, 16)
    }
    
    private var progressColor: Color {
        sessionManager.todayWorkedMinutes >= sessionManager.todaySollMinutes ? .green : .accentColor
    }
    
    private func formatMinutes(_ minutes: Int) -> String {
        String(format: "%d:%02d", minutes / 60, minutes % 60)
    }
    
    private func formatSaldo(_ minutes: Int) -> String {
        let sign = minutes >= 0 ? "+" : ""
        return String(format: "%@%d:%02d h", sign, abs(minutes) / 60, abs(minutes) % 60)
    }
    
    private func progressWidth(for totalWidth: CGFloat) -> CGFloat {
        let progress = Double(sessionManager.todayWorkedMinutes) / Double(max(sessionManager.todaySollMinutes, 1))
        return min(CGFloat(progress) * totalWidth, totalWidth)
    }
    
    // MARK: - Booking Buttons
    
    private var bookingButtonsView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Button(action: {
                    Task { await sessionManager.bookTime(type: .kommen) }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                            .font(.caption)
                        Text("Kommen")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(sessionManager.isLoading || sessionManager.isWorking || !sessionManager.isVPNConnected)
                
                Button(action: {
                    Task { await sessionManager.bookTime(type: .gehen) }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "stop.fill")
                            .font(.caption)
                        Text("Gehen")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(sessionManager.isLoading || !sessionManager.isWorking || !sessionManager.isVPNConnected)
            }
            
            Button(action: {
                Task {
                    await sessionManager.bookTime(
                        type: .pause,
                        pauseReminderEnabled: settingsManager.pauseReminderEnabled,
                        pauseReminderMinutes: settingsManager.pauseReminderMinutes
                    )
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: sessionManager.isPaused ? "play.circle.fill" : "pause.circle.fill")
                        .font(.caption)
                    Text(sessionManager.isPaused ? "Pause beenden" : "Pause starten")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .disabled(sessionManager.isLoading || !sessionManager.isWorking || !sessionManager.isVPNConnected)
            
            if sessionManager.isLoading {
                ProgressView()
                    .scaleEffect(0.7)
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Recent Bookings
    
    private var recentBookingsView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Heutige Buchungen")
                .font(.caption2)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 16)
            
            if sessionManager.recentBookings.isEmpty {
                Text("Keine Buchungen heute")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
            } else {
                ForEach(Array(sessionManager.recentBookings.prefix(6))) { booking in
                    HStack(spacing: 8) {
                        Image(systemName: iconForBookingType(booking.type))
                            .font(.caption2)
                            .foregroundColor(colorForBookingType(booking.type))
                            .frame(width: 16)
                        
                        Text(booking.typeLabel)
                            .font(.caption)
                        
                        Spacer()
                        
                        Text(formatBookingTime(booking.date))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 1)
                }
            }
        }
    }
    
    private func iconForBookingType(_ type: Int) -> String {
        switch type {
        case 1: return "arrow.right.circle.fill"
        case 2: return "arrow.left.circle.fill"
        case 0: return "pause.circle.fill"
        default: return "questionmark.circle"
        }
    }
    
    private func colorForBookingType(_ type: Int) -> Color {
        switch type {
        case 1: return .green
        case 2: return .red
        case 0: return .blue
        default: return .gray
        }
    }
    
    private func formatBookingTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH : mm"
        return formatter.string(from: date)
    }
    
    // MARK: - Footer
    
    private var footerView: some View {
        HStack {
            // Refresh button with state feedback
            Button(action: performRefresh) {
                Group {
                    switch refreshState {
                    case .idle:
                        Image(systemName: "arrow.clockwise")
                    case .refreshing:
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(width: 14, height: 14)
                    case .success:
                        Image(systemName: "checkmark")
                            .foregroundColor(.green)
                    }
                }
                .font(.system(size: 13))
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .disabled(refreshState != .idle || !sessionManager.isVPNConnected)
            .help("Daten aktualisieren")
            
            Spacer()
            
            // Quit button with confirmation
            Button(action: { showQuitConfirm = true }) {
                Image(systemName: "power")
                    .font(.system(size: 13))
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .help("App beenden")
            .popover(isPresented: $showQuitConfirm, arrowEdge: .bottom) {
                VStack(spacing: 10) {
                    Text("App beenden?")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack(spacing: 8) {
                        Button("Abbrechen") {
                            showQuitConfirm = false
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Button("Beenden") {
                            NSApp.terminate(nil)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .controlSize(.small)
                    }
                }
                .padding(12)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    private func performRefresh() {
        guard refreshState == .idle else { return }
        refreshState = .refreshing
        
        Task {
            await sessionManager.manualRefresh()
            
            withAnimation(.easeInOut(duration: 0.2)) {
                refreshState = .success
            }
            
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            
            withAnimation(.easeInOut(duration: 0.2)) {
                refreshState = .idle
            }
        }
    }
    
    // MARK: - Inline Settings
    
    private var settingsInlineView: some View {
        VStack(spacing: 0) {
            Form {
                Section("Anzeige") {
                    Toggle("Arbeitszeit in Menüleiste", isOn: $settingsManager.showTimeInMenuBar)
                        .font(.system(size: 13))
                }
                
                Section("Während Pause") {
                    Toggle("Pause-Ende erinnern", isOn: $settingsManager.pauseReminderEnabled)
                        .font(.system(size: 13))
                    
                    if settingsManager.pauseReminderEnabled {
                        Picker("Erinnerung nach", selection: $settingsManager.pauseReminderMinutes) {
                            Text("15 Min").tag(15)
                            Text("30 Min").tag(30)
                            Text("45 Min").tag(45)
                            Text("60 Min").tag(60)
                        }
                        .font(.system(size: 13))
                    }
                }
                
                Section("Pause-Erinnerung") {
                    Toggle("An Pause erinnern", isOn: $settingsManager.breakReminderEnabled)
                        .font(.system(size: 13))
                    
                    if settingsManager.breakReminderEnabled {
                        Picker("Modus", selection: $settingsManager.breakReminderMode) {
                            Text("Nach Arbeitszeit").tag("afterHours")
                            Text("Zu fester Uhrzeit").tag("atTime")
                        }
                        .font(.system(size: 13))
                        
                        if settingsManager.breakReminderMode == "afterHours" {
                            Picker("Nach", selection: $settingsManager.breakReminderAfterHours) {
                                Text("3 Stunden").tag(3.0)
                                Text("3,5 Stunden").tag(3.5)
                                Text("4 Stunden").tag(4.0)
                                Text("4,5 Stunden").tag(4.5)
                                Text("5 Stunden").tag(5.0)
                            }
                            .font(.system(size: 13))
                        } else {
                            HStack {
                                Text("Uhrzeit")
                                    .font(.system(size: 13))
                                Spacer()
                                Picker("", selection: $settingsManager.breakReminderAtHour) {
                                    ForEach(8..<18) { h in
                                        Text(String(format: "%02d", h)).tag(h)
                                    }
                                }
                                .frame(width: 60)
                                Text(":")
                                Picker("", selection: $settingsManager.breakReminderAtMinute) {
                                    Text("00").tag(0)
                                    Text("15").tag(15)
                                    Text("30").tag(30)
                                    Text("45").tag(45)
                                }
                                .frame(width: 60)
                            }
                        }
                    }
                }
                
                Section("Feierabend") {
                    Toggle("Feierabend erinnern", isOn: $settingsManager.endOfDayReminderEnabled)
                        .font(.system(size: 13))
                    
                    if settingsManager.endOfDayReminderEnabled {
                        Picker("Nach", selection: $settingsManager.endOfDayReminderHours) {
                            Text("7 Stunden").tag(7.0)
                            Text("7,5 Stunden").tag(7.5)
                            Text("8 Stunden").tag(8.0)
                            Text("8,5 Stunden").tag(8.5)
                            Text("9 Stunden").tag(9.0)
                            Text("10 Stunden").tag(10.0)
                        }
                        .font(.system(size: 13))
                    }
                }
                
                Section {
                    Button(action: openNotificationSettings) {
                        HStack(spacing: 4) {
                            Image(systemName: "info.circle")
                            Text("Hinweise-Stil für persistente Erinnerungen")
                        }
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                
                Section("Konto") {
                    if sessionManager.isAuthenticated {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            Text("Angemeldet als \(sessionManager.userName)")
                                .font(.system(size: 13))
                        }
                    }
                    
                    Button("Abmelden") {
                        sessionManager.logout()
                        withAnimation(.easeInOut(duration: 0.15)) { showingSettings = false }
                    }
                    .foregroundColor(.red)
                    .font(.system(size: 13))
                    .disabled(!sessionManager.isAuthenticated)
                }
                
                Section {
                    HStack {
                        Text("Version")
                            .font(.system(size: 13))
                        Spacer()
                        Text(AppVersion.fullVersion)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .formStyle(.grouped)
        }
    }
    
    private func openNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - AIDA Pyramid Logo

/// AIDA Pyramid Logo rendered from the official SVG favicon
/// Original SVG viewBox: 0 0 24 24, fill: #004583
struct AidaLogoView: View {
    var size: CGFloat = 24
    var color: Color = Color(red: 0, green: 0.271, blue: 0.514) // #004583
    
    var body: some View {
        Canvas { context, canvasSize in
            let scale = canvasSize.width / 24.0
            
            let bottom = Path { p in
                p.move(to: CGPoint(x: 22.33 * scale, y: 19.2586 * scale))
                p.addLine(to: CGPoint(x: 2.0 * scale, y: 19.2586 * scale))
                p.addLine(to: CGPoint(x: 4.97553 * scale, y: 14.4778 * scale))
                p.addLine(to: CGPoint(x: 19.3502 * scale, y: 14.4778 * scale))
                p.closeSubpath()
                p.move(to: CGPoint(x: 8.06256 * scale, y: 19.0591 * scale))
                p.addLine(to: CGPoint(x: 9.12664 * scale, y: 14.6689 * scale))
                p.addLine(to: CGPoint(x: 5.08751 * scale, y: 14.6705 * scale))
                p.addLine(to: CGPoint(x: 2.34268 * scale, y: 19.0627 * scale))
                p.closeSubpath()
            }
            
            let middle = Path { p in
                p.move(to: CGPoint(x: 18.4471 * scale, y: 13.0559 * scale))
                p.addLine(to: CGPoint(x: 5.86981 * scale, y: 13.0627 * scale))
                p.addLine(to: CGPoint(x: 8.88288 * scale, y: 8.23553 * scale))
                p.addLine(to: CGPoint(x: 15.4418 * scale, y: 8.23553 * scale))
                p.closeSubpath()
                p.move(to: CGPoint(x: 9.57508 * scale, y: 12.8601 * scale))
                p.addLine(to: CGPoint(x: 10.6543 * scale, y: 8.43554 * scale))
                p.addLine(to: CGPoint(x: 8.98705 * scale, y: 8.43345 * scale))
                p.addLine(to: CGPoint(x: 6.22711 * scale, y: 12.8538 * scale))
                p.closeSubpath()
            }
            
            let top = Path { p in
                p.move(to: CGPoint(x: 14.5767 * scale, y: 6.85527 * scale))
                p.addLine(to: CGPoint(x: 9.74646 * scale, y: 6.85891 * scale))
                p.addLine(to: CGPoint(x: 12.1679 * scale, y: 3.0 * scale))
                p.closeSubpath()
                p.move(to: CGPoint(x: 11.0965 * scale, y: 6.65474 * scale))
                p.addLine(to: CGPoint(x: 11.6882 * scale, y: 4.14689 * scale))
                p.addLine(to: CGPoint(x: 10.1006 * scale, y: 6.66203 * scale))
                p.closeSubpath()
            }
            
            context.fill(bottom, with: .color(color))
            context.fill(middle, with: .color(color))
            context.fill(top, with: .color(color))
        }
        .frame(width: size, height: size)
    }
}
