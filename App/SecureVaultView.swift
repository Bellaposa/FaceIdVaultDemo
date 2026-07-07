import SwiftUI

/// The secret lives in the Keychain behind a biometric access control. The app
/// never branches on a boolean; it just asks the Keychain for the bytes and the
/// Secure Enclave decides. Forging the LAContext boolean does nothing here.
struct SecureVaultView: View {
    @State private var revealed: String?
    @State private var status = "Seed the secret, then try to read it."

    var body: some View {
        VaultScaffold(
            title: "Secure Vault",
            subtitle: "Gate = Secure Enclave releasing the key",
            tint: .green
        ) {
            if let revealed {
                SecretCard(secret: revealed, tint: .green)
            }

            HStack {
                Button("Seed secret") { seed() }
                    .buttonStyle(.bordered)
                Button {
                    read()
                } label: {
                    Label("Read with Face ID", systemImage: "faceid")
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }

            Text(status).font(.footnote).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

private extension SecureVaultView {
    func seed() {
        do {
            try KeychainVault.store("SUPER-SECRET-42-SECURE")
            status = "Secret stored behind .biometryCurrentSet."
            revealed = nil
        } catch {
            status = "Seed error: \(error)"
        }
    }

    func read() {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let secret = try KeychainVault.read(reason: "Unlock your secure vault")
                DispatchQueue.main.async {
                    revealed = secret
                    status = "Secure Enclave released the key."
                }
            } catch {
                DispatchQueue.main.async {
                    revealed = nil
                    status = "Blocked: \(error)"
                }
            }
        }
    }
}

#Preview {
    SecureVaultView()
}
