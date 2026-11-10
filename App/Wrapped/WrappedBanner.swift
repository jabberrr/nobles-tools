import SwiftUI

/// The design list's invitation to open the semester's Cafe Wrapped once it's ready.
struct WrappedBanner: View {
    /// e.g. "Fall 2026".
    let periodName: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "gift.fill")
                .font(WrappedStyle.symbol(22))
                .symbolEffect(.pulse)
                .frame(width: 46, height: 46)
                .background(Color.white.opacity(0.2), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Your \(periodName) Cafe Wrapped is ready")
                    .font(WrappedStyle.bannerTitle)
                Text("See your semester at the cafes.")
                    .font(WrappedStyle.bannerDetail)
                    .foregroundStyle(WrappedStyle.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(WrappedStyle.bannerDetail.weight(.semibold))
                .accessibilityHidden(true)
        }
        .foregroundStyle(.white)
        .padding(.vertical, 6)
    }

    /// The row's backdrop, for `listRowBackground`. White text is at least 4.5:1 across it.
    static var background: some View {
        LinearGradient(colors: [Color(hex: 0x6B1FA0), Color(hex: 0xA3145A)], startPoint: .leading, endPoint: .trailing)
    }
}

#Preview {
    List {
        Button {} label: {
            WrappedBanner(periodName: "Fall 2026")
        }
        .listRowBackground(WrappedBanner.background)
    }
}
