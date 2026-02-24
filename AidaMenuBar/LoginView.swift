import SwiftUI
import AppKit

// MARK: - Login Window (DEPRECATED)
// Login is now handled inline in ContentView.
// This file is kept to avoid Xcode build errors until manually removed from the project.

// Legacy LoginWindowController – no longer called from anywhere
class LoginWindowController {
    static let shared = LoginWindowController()
    private var window: NSWindow?
    private init() {}
    
    @MainActor
    func showWindow(sessionManager: SessionManager) {
        // Deprecated: Login is now inline in the popover
        print("⚠️ LoginWindowController.showWindow() called – this is deprecated. Login is inline now.")
    }
    
    func closeWindow() {
        DispatchQueue.main.async {
            self.window?.close()
            self.window = nil
        }
    }
}
