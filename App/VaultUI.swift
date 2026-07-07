import SwiftUI

/// Shared chrome for both vault screens: shield icon, title/subtitle, and a
/// content slot for the vault-specific controls.
struct VaultScaffold<Content: View>: View {
    let title: String
    let subtitle: String
    let tint: Color
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 64))
                .foregroundStyle(tint)
            Text(title).font(.largeTitle.bold())
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            content
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// The revealed-secret card shown once a vault hands over its secret.
struct SecretCard: View {
    let secret: String
    let tint: Color

    var body: some View {
        VStack(spacing: 8) {
            Text("SECRET REVEALED").font(.caption.bold()).foregroundStyle(.secondary)
            Text(secret)
                .font(.system(.title2, design: .monospaced).bold())
        }
        .padding()
        .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(tint, lineWidth: 1))
    }
}
