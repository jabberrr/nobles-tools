import SwiftUI
import NoblesKit

/// The Settings section that shows, connects and disconnects the user's Nobles account, which the
/// spending widget uses. Signing in happens in a web view, so the password never reaches the app.
///
/// The sign-in sheet is presented by the screen that owns this section (`onConnect`), not from
/// here: a sheet attached inside a `Form` row is dismissed as soon as the list refreshes that row.
struct StoreAccountSection: View {
    let account: StoreAccount
    /// Asks the owning screen to present the sign-in sheet.
    let onConnect: () -> Void

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
                // Renews an expired session. The sign-in page keeps its Veracross login (Disconnect
                // clears it), so while that's still valid no typing is needed.
                connectButton("Reconnect", systemImage: "arrow.clockwise")
                Button("Disconnect", role: .destructive) {
                    Task { await account.disconnect() }
                }
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
    }

    private func connectButton(_ title: String, systemImage: String) -> some View {
        Button(action: onConnect) {
            Label(title, systemImage: systemImage)
        }
    }

    private var footer: String {
        if account.isConnected {
            return "If the widget asks you to sign in, tap Reconnect. Your spending stays on your device. With Compare My Streak on, only your longest cafe streak is shared, with no name attached. Disconnecting removes the saved sign-in, your spending and any shared streak."
        }
        return "Sign in with Veracross to show your own cafe and store spending. Your login and spending stay on your device. With Compare My Streak on under Cafe Wrapped, only your longest cafe streak is shared, with no name attached, to compare with other students."
    }
}
