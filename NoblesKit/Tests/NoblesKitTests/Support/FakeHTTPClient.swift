import Foundation
@testable import NoblesKit

/// Serves canned responses by URL and records every request. Unknown URLs get a 404, as
/// Nutrislice answers for a menu type that doesn't exist.
actor FakeHTTPClient: HTTPClient {
    enum Response: Sendable {
        case data(Data)
        case failure(any Error)
    }

    private var responses: [URL: Response]
    private(set) var requests: [URL] = []
    /// The headers of the most recent request to each URL, for tests that check them.
    private(set) var lastHeaders: [URL: [String: String]] = [:]

    init(_ responses: [URL: Response] = [:]) {
        self.responses = responses
    }

    func respond(to url: URL, with response: Response) {
        responses[url] = response
    }

    func requestCount(for url: URL) -> Int {
        requests.filter { $0 == url }.count
    }

    /// The headers of the last request to `url`, if any.
    func headers(for url: URL) -> [String: String]? {
        lastHeaders[url]
    }

    func data(from url: URL, headers: [String: String]) async throws -> Data {
        requests.append(url)
        lastHeaders[url] = headers
        switch responses[url] {
        case .data(let data): return data
        case .failure(let error): throw error
        case nil: throw HTTPError.status(404)
        }
    }
}

/// A connection failure, as when the device is offline.
struct Offline: Error {}
