import SwiftUI

private struct WrappedIsStaticKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// True while rendering still snapshots: Wrapped views draw their finished state at once.
    var wrappedIsStatic: Bool {
        get { self[WrappedIsStaticKey.self] }
        set { self[WrappedIsStaticKey.self] = newValue }
    }
}
