import SwiftUI
import NoblesKit

@main
struct NoblesToolsApp: App {
    @State private var library: DesignLibrary
    @State private var previewData = PreviewData()
    /// The design list's navigation path: the IDs of the designs being edited.
    @State private var path: [UUID] = []

    @Environment(\.scenePhase) private var scenePhase

    init() {
        let store = DesignStore()
        store.seedDefaultsIfNeeded()
        _library = State(initialValue: DesignLibrary(store: store))
    }

    var body: some Scene {
        WindowGroup {
            DesignListView(path: $path)
                .environment(library)
                .environment(previewData)
                .onOpenURL { openDesign(from: $0) }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                library.saveNow()
            }
        }
    }

    /// Opens `noblestools://design/<id>` links from widgets in that design's editor.
    private func openDesign(from url: URL) {
        guard let id = DeepLink.designID(from: url), library.design(id: id) != nil else { return }
        path = [id]
    }
}
