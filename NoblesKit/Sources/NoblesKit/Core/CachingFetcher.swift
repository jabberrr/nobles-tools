import Foundation

/// Fetches and decodes URLs, saving each response that decodes and falling back to the saved
/// copy when the request itself fails (offline, timeout, HTTP error). A fresh response that
/// doesn't decode is an error and never replaces the saved copy.
struct CachingFetcher: Sendable {
    let http: any HTTPClient
    let cache: ResponseCache?

    func fetch<Value>(_ url: URL, decode: (Data) throws -> Value) async throws -> Value {
        let key = url.absoluteString
        let data: Data
        do {
            data = try await http.data(from: url)
        } catch {
            guard let cached = await cache?.data(for: key), let value = try? decode(cached.data) else { throw error }
            return value
        }
        let value = try decode(data)
        await cache?.store(data, for: key)
        return value
    }
}
