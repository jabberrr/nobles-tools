import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Fetches the body at a URL. Services take one so tests can serve canned responses.
public protocol HTTPClient: Sendable {
    func data(from url: URL) async throws -> Data
}

public enum HTTPError: Error, Equatable {
    /// The server answered with this non-2xx status code.
    case status(Int)
}

/// `HTTPClient` backed by `URLSession`.
public struct URLSessionHTTPClient: HTTPClient {
    /// Widgets get little time to refresh, so give up well before URLSession's 60-second default.
    private static let timeout: TimeInterval = 15

    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    /// The response body; throws `HTTPError.status` for a non-2xx response.
    public func data(from url: URL) async throws -> Data {
        let request = URLRequest(url: url, timeoutInterval: Self.timeout)
        let (data, response) = try await session.data(for: request)
        if let response = response as? HTTPURLResponse, !(200..<300).contains(response.statusCode) {
            throw HTTPError.status(response.statusCode)
        }
        return data
    }
}
