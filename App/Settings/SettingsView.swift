import SwiftUI
import NoblesKit

struct SettingsView: View {
    @Environment(DesignLibrary.self) private var library
    @Environment(PreviewData.self) private var previewData
    @Environment(\.dismiss) private var dismiss
    @State private var storeAccount = StoreAccount()
    @State private var isConnectingStore = false
    @State private var wrappedSource: CafeWrappedLauncher.Source?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink {
                        CalendarEditorView()
                    } label: {
                        LabeledContent("School Calendar", value: library.hasCustomCalendar ? "Edited" : library.calendar.name)
                    }
                } footer: {
                    Text("Countdowns use these term dates and breaks.")
                }

                StoreAccountSection(account: storeAccount) { isConnectingStore = true }

                Section {
                    Button {
                        wrappedSource = .account
                    } label: {
                        Label("Open Cafe Wrapped", systemImage: "gift")
                    }
                    Button {
                        wrappedSource = .sample
                    } label: {
                        Label("Open with Sample Data", systemImage: "sparkles")
                    }
                } header: {
                    Text("Cafe Wrapped")
                } footer: {
                    Text("These buttons are for testing. Connect your Nobles account above to see your own recap. At the end of each semester, it also shows at the top of your designs.")
                }

                Section {
                    ForEach(Array(Self.homeScreenSteps.enumerated()), id: \.offset) { index, step in
                        Label(step, systemImage: "\(index + 1).circle")
                    }
                } header: {
                    Text("Adding Widgets")
                } footer: {
                    Text("For the Lock Screen, touch and hold it, tap Customize, choose the Lock Screen, then tap the area under the clock to add a Nobles Tools widget.")
                }

                Section {
                    LabeledContent("Dining", value: "Flik Dining (Nutrislice)")
                    LabeledContent("Athletics", value: ScoresService.nobles.sourceName)
                } header: {
                    Text("Data Sources")
                } footer: {
                    Text("Scores are final results only (there's no live scoring) and can appear a week or so after a game. Menus are as Flik publishes them; Nobles has lunch and dinner menus, but no breakfast menu.")
                }

                Section {
                    LabeledContent("Product photos", value: "Open Food Facts")
                    LabeledContent("Foil photo", value: "Kevin M. Gill")
                } header: {
                    Text("Photo Credits")
                } footer: {
                    Text("Cafe Wrapped's product photos are by Open Food Facts contributors (CC BY-SA 3.0). Its foil is cropped from \u{201C}Crumpled Tin Foil\u{201D} by Kevin M. Gill (CC BY 4.0).")
                }

                Section {
                    LabeledContent("Version", value: Self.version)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        // Presented from here rather than from a Form row, which would dismiss them.
        .sheet(isPresented: $isConnectingStore) {
            StoreLoginView { session in
                Task { await storeAccount.connect(session) }
            }
        }
        .fullScreenCover(item: $wrappedSource) { source in
            CafeWrappedLauncher(source: source)
                .environment(library)
                .environment(previewData)
        }
    }

    private static let homeScreenSteps = [
        "Touch and hold an empty spot on your Home Screen until the apps jiggle.",
        "Tap Edit or + at the top of the screen, then add a Nobles Tools widget in any size.",
        "Touch and hold the new widget, tap Edit Widget, and choose one of your designs.",
    ]

    /// "1.0 (1)"
    private static var version: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}
