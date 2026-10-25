import Foundation

/// `noblestools://design/<uuid>` links, which widgets open so a tap lands in that design's editor.
enum DeepLink {
    static let scheme = "noblestools"
    private static let designHost = "design"

    static func url(for designID: UUID) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = designHost
        components.path = "/" + designID.uuidString
        return components.url
    }

    /// The design a link points to, or `nil` if it isn't a design link.
    static func designID(from url: URL) -> UUID? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == scheme,
              components.host == designHost
        else { return nil }
        return UUID(uuidString: String(components.path.drop { $0 == "/" }))
    }
}
