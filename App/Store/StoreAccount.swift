import Foundation
import Observation
import WidgetKit
import NoblesKit

/// The app's connection to a student's Nobles account: holds the saved sign-in's state and connects
/// or disconnects it. The session itself (cookie + person id, never a password) lives in the app
/// group via `StoreSessionStore`, so the widget reads the same connection.
@MainActor @Observable
final class StoreAccount {
    /// Whether an account is connected, and any in-progress or failed attempt.
    enum Status: Equatable {
        case disconnected
        /// Checking a freshly captured sign-in against the server.
        case verifying
        case connected(name: String?, since: Date)
        /// The sign-in couldn't be verified; the message explains why.
        case error(String)
    }

    private(set) var status: Status

    private let sessionStore: StoreSessionStore
    private let service: StoreService

    init(sessionStore: StoreSessionStore = StoreSessionStore(), service: StoreService = .nobles) {
        self.sessionStore = sessionStore
        self.service = service
        if let session = sessionStore.load() {
            status = .connected(name: session.personName, since: session.connectedAt)
        } else {
            status = .disconnected
        }
    }

    var isConnected: Bool {
        if case .connected = status { return true }
        return false
    }

    /// Saves a freshly captured session and checks it against the server. A rejected sign-in is
    /// cleared and reported; a verified one (or one that merely couldn't be reached right now) stays
    /// connected and reloads the widget.
    func connect(_ session: StoreSession) async {
        status = .verifying
        sessionStore.save(session)
        do {
            _ = try await service.statement(for: session)
            markConnected(session)
        } catch StoreError.notAuthenticated {
            sessionStore.clear()
            status = .error("That sign-in couldn't be verified. Please connect again.")
        } catch {
            // A network hiccup right after signing in: keep the session (it's probably fine) and let
            // the widget fall back to cached data until the next refresh.
            markConnected(session)
        }
    }

    /// Forgets the saved sign-in and refreshes the widget so it prompts to reconnect.
    func disconnect() {
        sessionStore.clear()
        status = .disconnected
        reloadWidgets()
    }

    private func markConnected(_ session: StoreSession) {
        status = .connected(name: session.personName, since: session.connectedAt)
        reloadWidgets()
    }

    private func reloadWidgets() {
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind.spending.timelineKind)
    }
}
