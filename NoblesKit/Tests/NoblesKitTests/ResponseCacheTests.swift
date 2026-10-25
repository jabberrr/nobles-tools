import Foundation
import Testing
@testable import NoblesKit

struct ResponseCacheTests {
    @Test func storesAndReplacesResponses() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = ResponseCache(directory: directory)
        let key = "https://example.com/" + String(repeating: "long/path/", count: 40)

        #expect(await cache.data(for: key) == nil)
        await cache.store(Data("first".utf8), for: key)
        await cache.store(Data("other".utf8), for: "other")
        await cache.store(Data("second".utf8), for: key)

        let entry = try #require(await cache.data(for: key))
        #expect(entry.data == Data("second".utf8))
        #expect(abs(entry.savedAt.timeIntervalSinceNow) < 60)
        #expect(await cache.data(for: "other")?.data == Data("other".utf8))
    }

    @Test func persistsAcrossInstances() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let savedAt = Date(timeIntervalSince1970: 1_790_000_000)
        await ResponseCache(directory: directory).store(Data("saved".utf8), for: "key", savedAt: savedAt)

        let entry = try #require(await ResponseCache(directory: directory).data(for: "key"))
        #expect(entry.data == Data("saved".utf8))
        #expect(abs(entry.savedAt.timeIntervalSince(savedAt)) < 1)
    }
}
