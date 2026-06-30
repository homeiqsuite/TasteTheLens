import Foundation
import Security

/// A stable, per-install identifier for unauthenticated ("guest") users so the
/// backend can enforce the free-tier generation limit server-side.
///
/// Stored in the Keychain rather than `UserDefaults` so it survives the user
/// clearing the app's data/cache — raising the bar on free-tier abuse (a full
/// reinstall is required to mint a new identity, and a determined attacker would
/// need to bypass App Attest, a possible future hardening). Sent as the
/// `x-guest-id` header on edge-function calls only when the user is NOT
/// authenticated; signed-in users are tracked by their real user id instead.
enum GuestIdentity {
    private static let service = "com.eightgates.TasteTheLens.guest"
    private static let account = "guest-id"

    /// The stable guest UUID, creating and persisting one on first access.
    static var id: String {
        if let existing = read() { return existing }
        let newId = UUID().uuidString.lowercased()
        store(newId)
        return newId
    }

    private static func read() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else { return nil }
        return value
    }

    private static func store(_ value: String) {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        // Remove any stale entry first, then add fresh.
        SecItemDelete(base as CFDictionary)
        var add = base
        add[kSecValueData as String] = Data(value.utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(add as CFDictionary, nil)
    }
}
