import SwiftUI
import LocalAuthentication

/// The secret is a plain string in memory. Face ID is used purely as a UI gate:
/// if `evaluatePolicy` reports success, we reveal it. Hooking that boolean owns
/// this screen completely.
struct NaiveVaultView: View {
    @State private var unlocked = false
    @State private var status = ""

    private let secret = "SUPER-SECRET-42-NAIVE"

    var body: some View {
        VaultScaffold(
            title: "Naive Vault",
            subtitle: "Gate = the Bool from evaluatePolicy",
            tint: .orange
        ) {
            if unlocked {
                SecretCard(secret: secret, tint: .orange)
            } else {
                Button {
                    authenticate()
                } label: {
                    Label("Unlock with Face ID", systemImage: "faceid")
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
            if !status.isEmpty {
                Text(status).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}

private extension NaiveVaultView {
    func authenticate() {
        let context = LAContext()
        context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "Unlock your naive vault"
        ) { success, error in
            DispatchQueue.main.async {
                if success {
                    unlocked = true
                    status = ""
                } else {
                    status = "Denied: \(error?.localizedDescription ?? "unknown")"
                }
            }
        }
    }
}

#Preview {
    NaiveVaultView()
}
