import Foundation

/// Why a spending refresh couldn't produce fresh data.
public enum StoreError: Error, Equatable {
    /// The saved sign-in was rejected or has expired (HTTP 401/403, or a sign-in page instead of
    /// charge JSON). The user re-connects in the app; the widget shows cached data meanwhile.
    case notAuthenticated
    /// The network was unreachable or the response couldn't be read. The widget shows cached data.
    case unavailable
}

/// Fetches a student's own school-store spending from the Nobles charges endpoint, using the session
/// cookie the app captured at sign-in. The endpoint is per-account, so there is one session at a
/// time; the last good response is cached so the widget renders while offline or signed out.
public struct StoreService: Sendable {
    /// The charges endpoint; `child_id` selects the signed-in student.
    static let chargesEndpoint = URL(string: "https://nobilis.nobles.edu/SchoolStoreNew/get_charges.php")!
    /// One cache slot: the account is the signed-in student's, so a fresh response replaces the last.
    static let cacheKey = "store.charges.v1"

    private let http: any HTTPClient
    private let cache: ResponseCache?

    public init(http: any HTTPClient = URLSessionHTTPClient(), cache: ResponseCache? = .shared) {
        self.http = http
        self.cache = cache
    }

    /// The live Nobles school-store service.
    public static let nobles = StoreService()

    /// This student's current statement. Caches the raw response on success. Throws
    /// `.notAuthenticated` when the session is rejected, `.unavailable` on any network or parse
    /// failure — in both cases the caller falls back to `cachedStatement()`.
    public func statement(for session: StoreSession, now: Date = .now) async throws -> StoreStatement {
        let url = Self.chargesURL(personID: session.personID)
        let data: Data
        do {
            data = try await http.data(from: url, headers: ["Cookie": session.cookie])
        } catch let HTTPError.status(code) where code == 401 || code == 403 {
            throw StoreError.notAuthenticated
        } catch {
            throw StoreError.unavailable
        }
        let statement = try Self.parse(data, fetchedAt: now)
        await cache?.store(data, for: Self.cacheKey)
        return statement
    }

    /// The last cached statement, stamped with when it was saved, or `nil` if none is stored.
    public func cachedStatement() async -> StoreStatement? {
        guard let cached = await cache?.data(for: Self.cacheKey) else { return nil }
        return try? Self.parse(cached.data, fetchedAt: cached.savedAt)
    }

    /// Deletes the cached statement. Call it when an account is disconnected or rejected, so its
    /// purchases neither linger on the device nor show under the next account connected.
    public func forgetCachedStatement() async {
        await cache?.remove(for: Self.cacheKey)
    }

    /// Parses a `get_charges.php` body, stamping it `fetchedAt`. Throws `.notAuthenticated` for a
    /// sign-in wall (a not-`ok` or charge-less JSON body, or a Veracross login page) and
    /// `.unavailable` for an otherwise unreadable body.
    public static func parse(_ data: Data, fetchedAt: Date) throws -> StoreStatement {
        guard let response = try? JSONDecoder().decode(StoreChargesResponse.self, from: data) else {
            throw looksLikeSignIn(data) ? StoreError.notAuthenticated : StoreError.unavailable
        }
        guard response.ok, let charges = response.charges else {
            throw StoreError.notAuthenticated
        }
        return StoreStatement(
            charges: charges,
            totalsByStore: response.totalsByStore,
            grandTotal: response.grandTotal,
            fetchedAt: fetchedAt
        )
    }

    static func chargesURL(personID: String) -> URL {
        var components = URLComponents(url: chargesEndpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "child_id", value: personID)]
        return components.url!
    }

    /// Whether a non-JSON body is the Veracross sign-in page the endpoint serves when signed out.
    private static func looksLikeSignIn(_ data: Data) -> Bool {
        let text = String(decoding: data.prefix(4096), as: UTF8.self).lowercased()
        return ["veracross", "oauth", "<html", "<!doctype"].contains { text.contains($0) }
    }
}
