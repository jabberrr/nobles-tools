import SwiftUI
import NoblesKit

/// The Settings section that connects, shows and disconnects the user's Nobles account, which the
/// spending widget uses. Signing in happens in a web view, so the password never reaches the app.
struct StoreAccountSection: View {
    @State private var account = StoreAccount()
    @State private var isSigningIn = false

    var body: some View {
        Section {
            switch account.status {
            case .disconnected:
                connectButton("Connect Nobles Account", systemImage: "person.badge.key")
            case .verifying:
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Verifying…")
                        .foregroundStyle(.secondary)
                }
            case .connected(let name, let since):
                LabeledContent("Connected", value: name ?? "Nobles Account")
                LabeledContent("Since", value: since.formatted(date: .abbreviated, time: .omitted))
                Button("Disconnect", role: .destructive) { account.disconnect() }
            case .error(let message):
                Label(message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.secondary)
                connectButton("Try Again", systemImage: "arrow.clockwise")
            }
        } header: {
            Text("Nobles Account")
        } footer: {
            Text(footer)
        }
        .sheet(isPresented: $isSigningIn) {
            StoreLoginView { session in
                Task { await account.connect(session) }
            }
        }
    }

    private func connectButton(_ title: String, systemImage: String) -> some View {
        Button {
            isSigningIn = true
        } label: {
            Label(title, systemImage: systemImage)
        }
    }

    private var footer: String {
        if account.isConnected {
            return "Your cafe and store spending stays on your device. Disconnecting removes the saved sign-in."
        }
        return "Sign in with Veracross to show your own cafe and store spending. Your login and data stay on your device."
    }
}
