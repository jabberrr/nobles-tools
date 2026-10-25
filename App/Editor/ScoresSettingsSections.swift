import SwiftUI
import NoblesKit

/// The scores-specific part of the design editor.
struct ScoresSettingsSections: View {
    @Binding var configuration: ScoresConfiguration

    @Environment(PreviewData.self) private var previewData

    var body: some View {
        Section {
            Toggle("Varsity Only", isOn: $configuration.varsityOnly)
            Toggle("Upcoming Games", isOn: $configuration.showsUpcoming)
        } header: {
            Text("Scores")
        } footer: {
            Text("Nobles Athletics posts final scores only, often a week or so after each game.")
        }

        Section {
            CheckmarkRow(title: "All Sports", systemImage: "sportscourt", isSelected: configuration.sports.isEmpty) {
                configuration.sports = []
            }
            ForEach(sportChoices, id: \.self) { sport in
                CheckmarkRow(
                    title: sport,
                    systemImage: SportSymbol.name(for: sport),
                    isSelected: configuration.sports.containsIgnoringCase(sport)
                ) {
                    configuration.sports.toggle(sport)
                }
            }
            AddNameRow(placeholder: "Add a sport by name") { sport in
                if !configuration.sports.containsIgnoringCase(sport) {
                    configuration.sports.append(sport)
                }
            }
            .task { await previewData.load(.scores) }
        } header: {
            Text("Sports")
        } footer: {
            Text("Listed sports have recent or upcoming games. Add another by name, like “Girls Hockey”.")
        }
    }

    /// Sports with games in the feed, then any chosen ones that aren't among them.
    private var sportChoices: [String] {
        (previewData.feed.value?.sports ?? []).merged(with: configuration.sports)
    }
}
