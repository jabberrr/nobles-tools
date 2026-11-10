import SwiftUI

/// What the launcher says when there's no recap to show.
struct WrappedMessage: Equatable {
    let symbol: String
    let title: String
    let detail: String

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
}

/// A full-screen note in the Wrapped look, offering the sample instead.
struct WrappedMessageView: View {
    let message: WrappedMessage
    let onSample: () -> Void
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
                Button("See a Sample", action: onSample)
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

#Preview("Loading") {
    WrappedLoadingView {}
}
