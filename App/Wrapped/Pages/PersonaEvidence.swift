import Foundation
import NoblesKit

/// The figure behind a persona and what it counts: "45%" over "After 5 PM".
struct PersonaEvidence {
    let figure: String
    let label: String
    /// Both, as VoiceOver reads them.
    let spoken: String

    /// `nil` for a superfan with no favorite, which the persona rules never pick.
    init?(_ wrapped: CafeWrapped) {
        switch wrapped.persona {
        case .loyalist:
            guard let favorite = wrapped.favorite else { return nil }
            figure = "×\(favorite.count.formatted())"
            label = favorite.name
            spoken = "\(favorite.name), \(WrappedFormat.count(favorite.count, "time"))"
        case .nightOwl:
            figure = WrappedFormat.percent(wrapped.share(ofHours: 17...23))
            label = "After 5 PM"
            spoken = "\(figure) of purchases after 5 PM"
        case .earlyBird:
            figure = WrappedFormat.percent(wrapped.share(ofHours: 0...9))
            label = "Before 10 AM"
            spoken = "\(figure) of purchases before 10 AM"
        case .regular:
            figure = WrappedFormat.count(wrapped.dayCount, "day")
            label = "At least every other school day"
            spoken = "\(figure), at least every other school day"
        case .explorer:
            figure = wrapped.distinctItemCount.formatted()
            label = "Different items"
            spoken = "\(figure) different items"
        case .dropIn:
            figure = WrappedFormat.count(wrapped.purchaseCount, "time")
            label = "No set routine"
            spoken = "\(figure), no set routine"
        }
    }
}
