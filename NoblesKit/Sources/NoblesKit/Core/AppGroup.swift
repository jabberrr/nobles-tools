import Foundation

/// The app group shared by the app and its widget extension.
public enum AppGroup {
    public static let identifier = "group.app.dabora.noblestools"

    /// The group's shared defaults, or standard defaults if the suite can't be opened.
    public static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }

    /// `Library/Caches/NoblesKit` in the group container, or a temporary folder where there's
    /// no container (Linux, or a build without the app group entitlement).
    public static var cacheDirectory: URL {
        #if canImport(Darwin)
        if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) {
            return container.appending(path: "Library/Caches/NoblesKit", directoryHint: .isDirectory)
        }
        #endif
        return FileManager.default.temporaryDirectory.appending(path: "NoblesKit", directoryHint: .isDirectory)
    }
}
