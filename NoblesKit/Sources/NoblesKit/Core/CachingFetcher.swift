import Foundation

/// Fetches and decodes URLs, saving each response that decodes and falling back to the saved
/// copy when the request itself fails (offline, timeout, HTTP error). A fresh response that
/// doesn't decode is an error and never replaces the saved copy.
struct CachingFetcher: Sendable {
    /// A decoded response, and when it was saved if it came from the cache.
    struct Fetched<Value> {
        var value: Value
        var cachedAt: Date?
    }

    let http: any HTTPClient
    let cache: ResponseCache?

    func fetch<Value>(_ url: URL, decode: (Data) throws -> Value) async throws -> Fetched<Value> {
        let key = url.absoluteString
        let data: Data
        do {
            data = try await http.data(from: url)
        } catch {
            guard let cached = await cache?.data(for: key), let value = try? decode(cached.data) else { throw error }
            return Fetched(value: value, cachedAt: cached.savedAt)
        }
        let value = try decode(data)
        await cache?.store(data, for: key)
        return Fetched(value: value)
    }
}
