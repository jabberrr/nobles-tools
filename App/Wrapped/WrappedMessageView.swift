import SwiftUI
import NoblesKit

/// What the launcher says when there's no recap to show, or before one that's missing days.
struct WrappedMessage: Equatable {
    /// The way forward offered above Close.
    enum Action: Equatable {
        /// Opens the sample recap instead.
        case seeSample
        /// Opens the recap as far as it goes.
        case showAnyway

        var title: String {
            switch self {
            case .seeSample: "See a Sample"
            case .showAnyway: "Show It Anyway"
            }
        }
    }

    let symbol: String
    let title: String
    let detail: String
    var action = Action.seeSample

    static let notConnected = WrappedMessage(
        symbol: "person.crop.circle.badge.exclamationmark",
        title: "Connect your Nobles account",
        detail: "Connect your Nobles account in Settings to see your own Cafe Wrapped."
    )

    static let unavailable = WrappedMessage(
        symbol: "wifi.exclamationmark",
        title: "Couldn't load your purchases",
        detail: "Check your connection and try again. If it keeps happening, reconnect your Nobles account in Settings."
    )

    static let noSemester = WrappedMessage(
        symbol: "calendar.badge.exclamationmark",
        title: "No semesters in your calendar",
        detail: "Add your semester dates in Settings → School Calendar to see your Cafe Wrapped."
    )

    static func noPurchases(in periodName: String) -> WrappedMessage {
        WrappedMessage(
            symbol: "cup.and.saucer.fill",
            title: "No cafe purchases in \(periodName) yet",
            detail: "Your recap fills in as you buy things at the cafes. Check back at the end of the semester."
        )
    }

    /// The account's purchases are a saved copy from `day`: its sign-in has expired, or Nobles
    /// couldn't be reached.
    static func stopsEarly(at day: LocalDate, isSignedOut: Bool) -> WrappedMessage {
        let date = WrappedFormat.shortDay(day)
        return WrappedMessage(
            symbol: isSignedOut ? "person.crop.circle.badge.exclamationmark" : "wifi.exclamationmark",
            title: "Your recap stops at \(date)",
            detail: isSignedOut
                ? "Your Nobles sign-in has expired, so purchases after \(date) aren't in it. Reconnect your account in Settings to include everything since."
                : "Nobles couldn't be reached, so purchases after \(date) aren't in it. Try again once you're online to include everything since.",
            action: .showAnyway
        )
    }
}

/// A full-screen note in the Wrapped look, with the message's way forward and Close.
struct WrappedMessageView: View {
    let message: WrappedMessage
    /// Runs `.seeSample`.
    let onSample: () -> Void
    /// Runs `.showAnyway`, for the messages that offer it.
    var onShowAnyway: () -> Void = {}
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: message.symbol)
                .font(.system(size: 54, weight: .bold))
                .foregroundStyle(WrappedStyle.highlight)
                .accessibilityHidden(true)
            Text(message.title)
                .font(WrappedStyle.title(28))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(message.detail)
                .font(WrappedStyle.body)
                .foregroundStyle(WrappedStyle.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            VStack(spacing: 12) {
                Button(message.action.title) { perform() }
                    .buttonStyle(WrappedButtonStyle())
                Button("Close", action: onClose)
                    .buttonStyle(WrappedButtonStyle(isProminent: false))
            }
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 16)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            WrappedBackground(colors: WrappedPage.intro.colors)
                .ignoresSafeArea()
        }
    }

    /// Runs the closure for the message's action.
    private func perform() {
        switch message.action {
        case .seeSample: onSample()
        case .showAnyway: onShowAnyway()
        }
    }
}

/// Shown while the account's purchases load.
struct WrappedLoadingView: View {
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            ProgressView()
                .controlSize(.large)
                .tint(.white)
            Text("Unwrapping your semester…")
                .font(WrappedStyle.lead)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .topTrailing) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .frame(width: 34, height: 34)
                    .background(Color.white.opacity(0.18), in: Circle())
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .accessibilityLabel("Close")
            .padding(.horizontal, 16)
        }
        .background {
            WrappedBackground(colors: WrappedPage.intro.colors)
                .ignoresSafeArea()
        }
    }
}

#Preview("No purchases") {
    WrappedMessageView(message: .noPurchases(in: "Fall 2026"), onSample: {}, onClose: {})
}

#Preview("Stops early") {
    WrappedMessageView(
        message: .stopsEarly(at: LocalDate(year: 2026, month: 11, day: 10), isSignedOut: true),
        onSample: {},
        onClose: {}
    )
}

#Preview("Loading") {
    WrappedLoadingView {}
}
