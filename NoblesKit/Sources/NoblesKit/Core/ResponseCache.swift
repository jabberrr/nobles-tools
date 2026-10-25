import Foundation

/// The last good response for each key, kept on disk so widgets still render offline.
/// Writing is best-effort: if a write fails there is simply no offline copy.
public actor ResponseCache {
    /// The cache in the app group, shared by the app and its widgets.
    public static let shared = ResponseCache(directory: AppGroup.cacheDirectory)

    /// Entries older than this are deleted, so responses for URLs that are no longer requested
    /// (such as past weeks' menus) don't pile up.
    static let maxAge: TimeInterval = 30 * 24 * 60 * 60

    private let directory: URL
    private var hasPruned = false

    public init(directory: URL) {
        self.directory = directory
    }

    /// The stored response for `key` and when it was saved, if there is one.
    public func data(for key: String) -> (data: Data, savedAt: Date)? {
        let file = fileURL(for: key)
        guard let data = try? Data(contentsOf: file), let savedAt = Self.modificationDate(of: file) else { return nil }
        return (data, savedAt)
    }

    /// Replaces the response stored for `key`.
    public func store(_ data: Data, for key: String) {
        store(data, for: key, savedAt: .now)
    }

    /// `store(_:for:)` with an explicit save time, so tests can age entries.
    func store(_ data: Data, for key: String, savedAt: Date) {
        let file = fileURL(for: key)
        let fileManager = FileManager.default
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        pruneIfNeeded()
        guard (try? data.write(to: file, options: .atomic)) != nil else { return }
        try? fileManager.setAttributes([.modificationDate: savedAt], ofItemAtPath: file.path(percentEncoded: false))
    }

    /// Deletes entries older than `maxAge`. Runs once per instance, on the first store, which
    /// keeps it cheap: `shared` prunes at most once per launch.
    private func pruneIfNeeded() {
        guard !hasPruned else { return }
        hasPruned = true
        let fileManager = FileManager.default
        let cutoff = Date.now - Self.maxAge
        let files = (try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        for file in files where file.pathExtension == "cache" {
            if let savedAt = Self.modificationDate(of: file), savedAt < cutoff {
                try? fileManager.removeItem(at: file)
            }
        }
    }

    private static func modificationDate(of file: URL) -> Date? {
        let attributes = try? FileManager.default.attributesOfItem(atPath: file.path(percentEncoded: false))
        return attributes?[.modificationDate] as? Date
    }

    /// Keys are often long URLs, so files are named by the key's 64-bit FNV-1a hash, which,
    /// unlike `hashValue`, is the same on every launch.
    private func fileURL(for key: String) -> URL {
        let hash = key.utf8.reduce(UInt64(0xCBF2_9CE4_8422_2325)) { ($0 ^ UInt64($1)) &* 0x100_0000_01B3 }
        return directory.appending(path: String(hash, radix: 16) + ".cache", directoryHint: .notDirectory)
    }
}
