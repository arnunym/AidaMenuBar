import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        Text("Einstellungen")
            .padding()
    }
}
