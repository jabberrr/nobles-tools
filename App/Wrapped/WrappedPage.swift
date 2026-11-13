import SwiftUI
import NoblesKit

/// One page of the Cafe Wrapped story, in the order they're told.
enum WrappedPage: Int, CaseIterable {
    case intro, total, cafes, topItems, favorite, times, days, records, persona, summary

    /// The pages `wrapped` has something to say on, in order.
    static func pages(for wrapped: CafeWrapped) -> [WrappedPage] {
        allCases.filter { $0.hasContent(in: wrapped) }
    }

    private func hasContent(in wrapped: CafeWrapped) -> Bool {
        switch self {
        case .intro, .total, .records, .persona, .summary: true
        case .cafes: !wrapped.cafes.isEmpty
        // With a single item, the favorite page tells the whole story.
        case .topItems: wrapped.topItems.count > 1
        case .favorite: wrapped.favorite != nil
        case .times: wrapped.peakHour != nil
        case .days: wrapped.favoriteWeekday != nil
        }
    }

    /// The page's backdrop: vivid, but dark enough for white text. White and
    /// `WrappedStyle.secondary` are at least 4.5:1 on every color and blend of them, and on
    /// `WrappedStyle.tileFill` tiles drawn over them.
    var colors: [Color] {
        let hexes: [UInt32] = switch self {
        case .intro: [0x2A0A5E, 0x6B1FA0, 0x1A1360]
        case .total: [0x065F46, 0x0F5F8A, 0x14532D]
        case .cafes: [0xB42318, 0xA3330D, 0x7A1238]
        case .topItems: [0xA3145A, 0x5B21B6, 0x86198F]
        case .favorite: [0x2E1A87, 0x6D28D9, 0x1E1B4B]
        case .times: [0xA62F17, 0xA3123F, 0x6B21A8]
        case .days: [0x1D4ED8, 0x0B5A8F, 0x3730A3]
        case .records: [0x0F6B63, 0x166534, 0x0E5E7A]
        case .persona: [0x9D174D, 0x6D28D9, 0xA21CAF]
        case .summary: [0x14112B, 0x4C1D95, 0x831843]
        }
        return hexes.map { Color(hex: $0) }
    }

    /// For file names: "03-cafes".
    var galleryName: String {
        let slug: String = switch self {
        case .intro: "intro"
        case .total: "total"
        case .cafes: "cafes"
        case .topItems: "top-items"
        case .favorite: "favorite"
        case .times: "times"
        case .days: "days"
        case .records: "records"
        case .persona: "persona"
        case .summary: "summary"
        }
        return "\(rawValue < 9 ? "0" : "")\(rawValue + 1)-\(slug)"
    }
}
