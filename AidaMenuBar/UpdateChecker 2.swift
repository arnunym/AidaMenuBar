import Foundation

/// Checks GitHub Releases for newer versions of the app
class UpdateChecker: ObservableObject {
    @Published var updateAvailable = false
    @Published var latestVersion: String = ""
    @Published var downloadURL: String = ""
    @Published var releaseNotes: String = ""
    @Published var isChecking = false
    
    private let githubRepo = "arnunym/AidaMenuBar"
    private let checkInterval: TimeInterval = 6 * 60 * 60  // 6 hours
    private var checkTimer: Timer?
    
    init() {
        // Check on launch (with small delay to not block startup)
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.checkForUpdates()
        }
        startPeriodicCheck()
    }
    
    /// Starts a timer to check periodically
    private func startPeriodicCheck() {
        checkTimer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            self?.checkForUpdates()
        }
        if let timer = checkTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    /// Fetches the latest release from GitHub API
    func checkForUpdates() {
        guard !isChecking else { return }
        isChecking = true
        
        let urlString = "https://api.github.com/repos/\(githubRepo)/releases/latest"
        guard let url = URL(string: urlString) else {
            isChecking = false
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isChecking = false
                
                guard let data = data, error == nil,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    print("⚠️ Update check failed: \(error?.localizedDescription ?? "unknown")")
                    return
                }
                
                guard let tagName = json["tag_name"] as? String else { return }
                
                // Strip "v" prefix for comparison (v1.2.0 → 1.2.0)
                let remoteVersion = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
                let localVersion = AppVersion.version
                
                if self.isNewerVersion(remote: remoteVersion, local: localVersion) {
                    self.updateAvailable = true
                    self.latestVersion = remoteVersion
                    self.releaseNotes = json["body"] as? String ?? ""
                    
                    // Find the .zip asset download URL
                    if let assets = json["assets"] as? [[String: Any]],
                       let zipAsset = assets.first(where: { ($0["name"] as? String)?.hasSuffix(".zip") == true }),
                       let browserURL = zipAsset["browser_download_url"] as? String {
                        self.downloadURL = browserURL
                    } else {
                        // Fallback to release page
                        self.downloadURL = json["html_url"] as? String ?? "https://github.com/\(self.githubRepo)/releases/latest"
                    }
                    
                    print("✅ Update available: \(localVersion) → \(remoteVersion)")
                } else {
                    self.updateAvailable = false
                    print("✅ App is up to date (\(localVersion))")
                }
            }
        }.resume()
    }
    
    /// Semantic version comparison: returns true if remote > local
    private func isNewerVersion(remote: String, local: String) -> Bool {
        let remoteParts = remote.split(separator: ".").compactMap { Int($0) }
        let localParts = local.split(separator: ".").compactMap { Int($0) }
        
        for i in 0..<max(remoteParts.count, localParts.count) {
            let r = i < remoteParts.count ? remoteParts[i] : 0
            let l = i < localParts.count ? localParts[i] : 0
            if r > l { return true }
            if r < l { return false }
        }
        return false
    }
    
    /// Opens the download URL in the browser
    func openDownloadPage() {
        let urlString = downloadURL.isEmpty
            ? "https://github.com/\(githubRepo)/releases/latest"
            : downloadURL
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
