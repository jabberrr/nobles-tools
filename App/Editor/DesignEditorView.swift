import SwiftUI
import WidgetKit
import NoblesKit

/// Edits one design: live previews at every size on top, settings below. Changes apply and save
/// as they're made.
struct DesignEditorView: View {
    let designID: UUID

    @Environment(DesignLibrary.self) private var library

    var body: some View {
        if let design = library.design(id: designID) {
            DesignEditorForm(design: Binding(
                get: { library.design(id: designID) ?? design },
                set: { library.update($0) }
            ))
        } else {
            ContentUnavailableView(
                "Design Deleted",
                systemImage: "trash",
                description: Text("This design no longer exists.")
            )
        }
    }
}

private struct DesignEditorForm: View {
    @Binding var design: WidgetDesign

    @Environment(DesignLibrary.self) private var library
    @Environment(PreviewData.self) private var previewData
    @Environment(\.dismiss) private var dismiss
    @State private var isConfirmingDelete = false

    var body: some View {
        Form {
            Section {
                PreviewCarousel(design: design)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            } footer: {
                if previewData.isShowingSample(for: design) {
                    Label("Showing sample data: \(sourceName) couldn't be reached.", systemImage: "wifi.slash")
                        .frame(maxWidth: .infinity)
                }
            }

            Section("Name") {
                TextField("Name", text: $design.name)
                    .submitLabel(.done)
            }

            if let menu = Binding($design.menuConfiguration) {
                MenuSettingsSections(configuration: menu)
            }
            if let countdown = Binding($design.countdownConfiguration) {
                CountdownSettingsSection(configuration: countdown)
            }
            if let scores = Binding($design.scoresConfiguration) {
                ScoresSettingsSections(configuration: scores)
            }

            AppearanceSection(theme: $design.theme)

            Section {
                Button("Delete Design", role: .destructive) {
                    isConfirmingDelete = true
                }
            }
        }
        .navigationTitle(design.name.isEmpty ? design.kind.displayName : design.name)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Delete this design?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete Design", role: .destructive) {
                let id = design.id
                dismiss()
                library.delete(id: id)
            }
        } message: {
            Text("Widgets showing it will switch to another \(design.kind.displayName.lowercased()) design.")
        }
    }

    private var sourceName: String {
        switch design.kind {
        case .menu: "the dining menu"
        case .scores: "Nobles Athletics"
        case .countdown: "the calendar"
        }
    }
}

/// Swipeable live previews of a design at each size its widget offers.
private struct PreviewCarousel: View {
    let design: WidgetDesign

    var body: some View {
        TabView {
            ForEach(design.kind.widgetFamilies, id: \.self) { family in
                VStack(spacing: 12) {
                    FittedPreview(size: family.previewSize) {
                        DesignPreview(design: design, family: family)
                    }
                    Text(family.previewName)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 48)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .frame(height: 420)
    }
}
