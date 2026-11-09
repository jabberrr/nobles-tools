import Foundation
import Testing
@testable import NoblesKit

struct StoreServiceTests {
    private let session = StoreSession(cookie: "PHPSESSID=abc123", personID: "98765", personName: "Student")
    private let now = LocalDate(2026, 11, 9).at(hour: 15)

    private var chargesURL: URL { StoreService.chargesURL(personID: session.personID) }

    // MARK: Success and caching

    @Test func fetchesCachesAndReturnsAFreshStatement() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = ResponseCache(directory: directory)
        let http = FakeHTTPClient([chargesURL: .data(try Fixture.data("real-store-charges.json"))])
        let service = StoreService(http: http, cache: cache)

        let statement = try await service.statement(for: session, now: now)
        #expect(statement.charges.count == 26)
        #expect(statement.fetchedAt == now)
        #expect(statement.grandTotal == Decimal(string: "136.75"))
        #expect(await http.headers(for: chargesURL) == ["Cookie": "PHPSESSID=abc123"])

        // The raw body was cached and parses back, stamped with when it was saved.
        let cached = try #require(await service.cachedStatement())
        #expect(cached.charges.count == 26)
        #expect(abs(cached.fetchedAt.timeIntervalSinceNow) < 60)
    }

    // MARK: Classification

    @Test func rejectedSessionIsNotAuthenticated() async {
        let http = FakeHTTPClient([chargesURL: .failure(HTTPError.status(401))])
        let service = StoreService(http: http, cache: nil)

        await #expect(throws: StoreError.notAuthenticated) {
            try await service.statement(for: session, now: now)
        }
    }

    @Test func signInPageIsNotAuthenticated() async {
        let html = """
        <!DOCTYPE html><html><head><title>Sign in</title></head>
        <body>Redirecting to accounts.veracross.com/nobles/oauth/authorize…</body></html>
        """
        let http = FakeHTTPClient([chargesURL: .data(Data(html.utf8))])
        let service = StoreService(http: http, cache: nil)

        await #expect(throws: StoreError.notAuthenticated) {
            try await service.statement(for: session, now: now)
        }
    }

    @Test func notOkJSONIsNotAuthenticated() {
        #expect(throws: StoreError.notAuthenticated) {
            try StoreService.parse(Data(#"{"ok":false,"error":"expired"}"#.utf8), fetchedAt: now)
        }
    }

    @Test func networkFailureIsUnavailable() async {
        let http = FakeHTTPClient([chargesURL: .failure(Offline())])
        let service = StoreService(http: http, cache: nil)

        await #expect(throws: StoreError.unavailable) {
            try await service.statement(for: session, now: now)
        }
    }

    @Test func unreadableBodyIsUnavailable() {
        #expect(throws: StoreError.unavailable) {
            try StoreService.parse(Data("not json, not html".utf8), fetchedAt: now)
        }
    }

    @Test func aRejectedResponseIsNotCached() async {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = ResponseCache(directory: directory)
        let http = FakeHTTPClient([chargesURL: .failure(HTTPError.status(403))])
        let service = StoreService(http: http, cache: cache)

        _ = try? await service.statement(for: session, now: now)
        #expect(await service.cachedStatement() == nil)
    }
}
