import Foundation
import Security
import LocalAuthentication

/// A secret stored the *correct* way: the bytes live in the Keychain behind a biometric access control, so retrieval is gated by the Secure Enclave, not by a boolean the app hands to itself.
enum KeychainVault {
    static let account = "vault_master_secret"
    static let service = "com.bellaposa.faceidvaultdemo"

    enum VaultError: Error, CustomStringConvertible {
        case accessControl
        case store(OSStatus)
        case read(OSStatus)

        var description: String {
            switch self {
            case .accessControl: "Could not create access control"
            case .store(let s): "Store failed (OSStatus \(s))"
            case .read(let s): "Read failed (OSStatus \(s))"
            }
        }
    }

    /// Seed the protected secret. Deletes any previous copy first.
    static func store(_ secret: String) throws(VaultError) {
        delete()

        guard let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
            .biometryCurrentSet,
            nil
        ) else {
            throw VaultError.accessControl
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: Data(secret.utf8),
            kSecAttrAccessControl as String: access
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw VaultError.store(status) }
    }

    /// Read the protected secret. This call itself triggers biometric evaluation; the Secure Enclave only releases the bytes on a real match.
    static func read(reason: String) throws(VaultError) -> String {
        let context = LAContext()
        context.localizedReason = reason

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationContext as String: context
        ]

        var out: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &out)
        guard status == errSecSuccess,
              let data = out as? Data,
              let secret = String(data: data, encoding: .utf8)
        else {
            throw VaultError.read(status)
        }
        return secret
    }

    @discardableResult
    static func delete() -> OSStatus {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        return SecItemDelete(query as CFDictionary)
    }
}
