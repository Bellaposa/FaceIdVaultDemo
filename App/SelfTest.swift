import Foundation
import Security
import LocalAuthentication

/// Headless proof of the article's thesis. Run with `-selftest`.
///
/// It exercises both code paths without any UI so the difference shows up in
/// the console:
///   - Naive path: call evaluatePolicy and print the boolean we get back.
///     With the dylib injected this prints `success=true` even though no sensor
///     was ever consulted.
///   - Secure path: seed a biometric-gated Keychain item, then try to read it
///     with `kSecUseAuthenticationUIFail`. The Secure Enclave refuses to release
///     the bytes regardless of what we forged on LAContext.
enum SelfTest {
    static func run() {
        NSLog("[SelfTest] ===== START =====")
        naivePath()
        securePath()
    }

    private static func naivePath() {
        let ctx = LAContext()
        let sem = DispatchSemaphore(value: 0)
        ctx.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "self-test"
        ) { success, error in
            NSLog("[SelfTest] NAIVE evaluatePolicy -> success=\(success) error=\(error?.localizedDescription ?? "nil")")
            if success {
                NSLog("[SelfTest] NAIVE VAULT: secret would be revealed. Boolean gate defeated.")
            } else {
                NSLog("[SelfTest] NAIVE VAULT: locked.")
            }
            sem.signal()
        }
        _ = sem.wait(timeout: .now() + 5)
    }

    private static func securePath() {
        try? KeychainVault.store("SUPER-SECRET-42-SECURE")

        // Ask for the item but forbid any UI, so instead of hanging on a prompt
        // we get an immediate verdict from the security machinery.
        let context = LAContext()
        context.interactionNotAllowed = true

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: KeychainVault.service,
            kSecAttrAccount as String: KeychainVault.account,
            kSecReturnData as String: true,
            kSecUseAuthenticationContext as String: context
        ]
        var out: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &out)

        if status == errSecSuccess {
            #if targetEnvironment(simulator)
            NSLog("[SelfTest] SECURE VAULT: released on the SIMULATOR (status=0).")
            NSLog("[SelfTest] NOTE: the Simulator has no Secure Enclave, so biometric")
            NSLog("[SelfTest] access control is NOT enforced here. On a real device this")
            NSLog("[SelfTest] same call returns errSecInteractionNotAllowed (\(errSecInteractionNotAllowed)).")
            #else
            NSLog("[SelfTest] SECURE VAULT: released WITHOUT a real match?! Investigate.")
            #endif
        } else {
            NSLog("[SelfTest] SECURE VAULT: blocked, OSStatus=\(status) (errSecInteractionNotAllowed=\(errSecInteractionNotAllowed)). Forged boolean did nothing.")
        }
        NSLog("[SelfTest] ===== END =====")
    }
}
