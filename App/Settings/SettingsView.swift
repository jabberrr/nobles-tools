import SwiftUI
import NoblesKit

struct SettingsView: View {
    @Environment(DesignLibrary.self) private var library
    @Environment(\.dismiss) private var dismiss

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
    }

    private static let homeScreenSteps = [
        "Touch and hold an empty spot on your Home Screen until the apps jiggle.",
        "Tap Edit, then Add Widget, and choose Nobles Tools.",
        "Pick Dining Menu, Countdown or Scores, choose a size, and tap Add Widget.",
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
