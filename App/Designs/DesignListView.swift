import SwiftUI
import WidgetKit
import NoblesKit

/// The home screen: the user's designs grouped by kind, each with a live thumbnail.
struct DesignListView: View {
    @Binding var path: [UUID]

    @Environment(DesignLibrary.self) private var library
    @State private var isShowingSettings = false

    var body: some View {
        NavigationStack(path: $path) {
            List {
                ForEach(WidgetKind.allCases) { kind in
                    let designs = library.designs(of: kind)
                    if !designs.isEmpty {
                        Section {
                            ForEach(designs) { design in
                                NavigationLink(value: design.id) {
                                    DesignRow(design: design)
                                }
                            }
                            .onDelete { library.delete(kind, at: $0) }
                            .onMove { library.move(kind, from: $0, to: $1) }
                        } header: {
                            Label(kind.displayName, systemImage: kind.symbolName)
                        }
                    }
                }
                if !library.designs.isEmpty {
                    Section {
                    } footer: {
                        Text("To use a design, add a Nobles Tools widget to your Home Screen or Lock Screen, then touch and hold it and choose Edit Widget.")
                    }
                }
            }
            .overlay {
                if library.designs.isEmpty {
                    emptyState
                }
            }
            .navigationTitle("Nobles Tools")
            .navigationDestination(for: UUID.self) { id in
                DesignEditorView(designID: id)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isShowingSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if library.designs.count > 1 {
                        EditButton()
                    }
                    newDesignMenu {
                        Label("New Design", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView()
                    .environment(library)
            }
            .onChange(of: path) {
                // A widget tap opened a design; don't leave Settings covering it.
                isShowingSettings = false
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Designs", systemImage: "square.grid.2x2")
        } description: {
            Text("Design a menu, countdown or scores widget here, then add Nobles Tools to your Home Screen or Lock Screen.")
        } actions: {
            newDesignMenu {
                Text("New Design")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func newDesignMenu<MenuLabel: View>(@ViewBuilder label: () -> MenuLabel) -> some View {
        Menu {
            ForEach(WidgetKind.allCases) { kind in
                Button {
                    let design = library.add(kind)
                    path.append(design.id)
                } label: {
                    Label(kind.displayName, systemImage: kind.symbolName)
                }
            }
        } label: {
            label()
        }
    }
}

/// A design's row in the list: a small live thumbnail, its name and a summary of its settings.
private struct DesignRow: View {
    let design: WidgetDesign

    @ScaledMetric(relativeTo: .body) private var thumbnailSize: CGFloat = 58

    var body: some View {
        HStack(spacing: 14) {
            FittedPreview(size: WidgetFamily.systemSmall.previewSize) {
                DesignPreview(design: design, family: .systemSmall)
            }
            .frame(width: thumbnailSize, height: thumbnailSize)
            .allowsHitTesting(false)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(design.name.isEmpty ? "Untitled" : design.name)
                    .font(.headline)
                Text(design.detailText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

extension WidgetDesign {
    /// A one-line summary of the design's settings, e.g. "Lunch · Just Entrées".
    var detailText: String {
        switch content {
        case .menu(let configuration):
            "\(configuration.meal.displayName) · \(configuration.filter.summaryText)"
        case .countdown(let configuration):
            "\(configuration.target.displayName) · \(configuration.counting.displayName)"
        case .scores(let configuration):
            configuration.summaryText
        }
    }
}
