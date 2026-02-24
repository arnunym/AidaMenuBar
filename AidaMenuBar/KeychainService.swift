import Foundation
import Security

/// Secure credential storage using macOS Keychain
final class KeychainService {
    static let shared = KeychainService()
    
    private let serviceName = "net.bike24.AidaMenuBar"
    private let accountKey = "aida-credentials"
    
    private init() {}
    
    // MARK: - Public API
    
    func saveCredentials(username: String, password: String) throws {
        let credentials = "\(username):\(password)"
        guard let data = credentials.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }
        
        // Delete existing entry first
        try? deleteCredentials()
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountKey,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
        
        print("✅ Credentials saved to Keychain")
    }
    
    func loadCredentials() -> (username: String, password: String)? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let credentials = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        let parts = credentials.split(separator: ":", maxSplits: 1)
        guard parts.count == 2 else { return nil }
        
        return (username: String(parts[0]), password: String(parts[1]))
    }
    
    func deleteCredentials() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountKey
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
        
        print("🗑️ Credentials removed from Keychain")
    }
    
    var hasStoredCredentials: Bool {
        return loadCredentials() != nil
    }
}

// MARK: - Errors

enum KeychainError: LocalizedError {
    case encodingFailed
    case saveFailed(OSStatus)
    case deleteFailed(OSStatus)
    
    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Fehler beim Encodieren der Zugangsdaten."
        case .saveFailed(let status):
            return "Keychain-Speicherfehler: \(status)"
        case .deleteFailed(let status):
            return "Keychain-Löschfehler: \(status)"
        }
    }
}
