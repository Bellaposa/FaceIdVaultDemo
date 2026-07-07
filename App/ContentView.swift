import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            VaultTab { NaiveVaultView() }
                .tabItem { Label("Naive Vault", systemImage: "lock.open.trianglebadge.exclamationmark") }
            VaultTab { SecureVaultView() }
                .tabItem { Label("Secure Vault", systemImage: "lock.shield") }
        }
    }
}

#if EMBEDDED_BYPASS
/// Wraps a vault screen with the "Attacker mode" switch that installs the LAContext bypass in-process.
///
/// Only compiled when EMBEDDED_BYPASS is defined; the Sideloadly IPA is built WITHOUT it so injection is the only story.
struct VaultTab<Content: View>: View {
    @State private var attackerMode = CommandLine.arguments.contains("-bypass")
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
            Divider()
            Toggle(isOn: $attackerMode) {
                Label("Attacker mode (bypass Face ID)", systemImage: "ant.fill")
                    .font(.footnote)
            }
            .tint(.red)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .onChange(of: attackerMode) { _, on in
                if on { InstallFaceIDBypass() }
            }
        }
    }
}
#else
/// Clean build: no embedded bypass, no toggle.
struct VaultTab<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View { content }
}
#endif

#Preview {
    ContentView()
}
