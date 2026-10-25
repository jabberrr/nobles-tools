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

    @Test func prunesEntriesOlderThanThirtyDaysOnTheFirstStore() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let day: TimeInterval = 24 * 60 * 60
        let earlier = ResponseCache(directory: directory)
        await earlier.store(Data("old".utf8), for: "old", savedAt: .now - 31 * day)
        await earlier.store(Data("recent".utf8), for: "recent", savedAt: .now - 29 * day)
        #expect(await earlier.data(for: "old") != nil)

        let cache = ResponseCache(directory: directory)
        await cache.store(Data("new".utf8), for: "new")

        #expect(await cache.data(for: "old") == nil)
        #expect(await cache.data(for: "recent")?.data == Data("recent".utf8))
        #expect(await cache.data(for: "new")?.data == Data("new".utf8))
    }
}
