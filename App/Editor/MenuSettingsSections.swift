import SwiftUI
import NoblesKit

/// The menu-specific part of the design editor.
struct MenuSettingsSections: View {
    @Binding var configuration: MenuConfiguration

    @Environment(PreviewData.self) private var previewData

    var body: some View {
        Section {
            Picker("Meal", selection: $configuration.meal) {
                ForEach(mealChoices) { selection in
                    Text(selection.displayName).tag(selection)
                }
            }
            .task { await previewData.load(.meals) }

            Picker("Show", selection: $configuration.filterStyle) {
                ForEach(MenuFilter.Style.allCases) { style in
                    Text(style.displayName).tag(style)
                }
            }
            Toggle("Station Names", isOn: $configuration.showsSectionHeaders)
            Toggle("Descriptions", isOn: $configuration.showsDescriptions)
        } header: {
            Text("Menu")
        } footer: {
            if let meal = configuration.meal.meal, !previewData.availableMeals.contains(meal) {
                Text("Flik doesn't publish a \(meal.displayName.lowercased()) menu for Nobles, so this design won't show any dishes.")
            } else {
                Text("Next Meal moves on as each meal ends. Descriptions appear on the large size when Flik includes them.")
            }
        }

        switch configuration.filterStyle {
        case .only, .excluding:
            StationPickerSection(
                meal: configuration.meal.meal,
                style: configuration.filterStyle,
                selection: $configuration.filterSections
            )
        case .everything, .entreesOnly, .withoutSaladsAndSoups:
            EmptyView()
        }
    }

    /// Next Meal and the meals Flik publishes, plus the current choice if it isn't one of them
    /// (an older design set to breakfast, say), so the picker never loses its selection.
    private var mealChoices: [MealSelection] {
        let published = previewData.availableMeals.compactMap { MealSelection(rawValue: $0.rawValue) }
        let choices = [MealSelection.upcoming, configuration.meal] + published
        return MealSelection.allCases.filter { choices.contains($0) }
    }
}

/// Picks the stations for "Just…" or "Everything Except…" from this week's menus.
private struct StationPickerSection: View {
    let meal: Meal?
    let style: MenuFilter.Style
    @Binding var selection: [String]

    private enum Phase {
        case loading
        case loaded([String])
        case failed
    }

    @State private var phase = Phase.loading

    var body: some View {
        Section {
            switch phase {
            case .loading:
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Loading stations…")
                        .foregroundStyle(.secondary)
                }
            case .failed:
                Label("Couldn't load this week's stations.", systemImage: "wifi.slash")
                    .foregroundStyle(.secondary)
            case .loaded(let titles) where titles.isEmpty:
                Text("No stations on this week's menus yet.")
                    .foregroundStyle(.secondary)
            case .loaded:
                EmptyView()
            }

            ForEach(choices, id: \.self) { name in
                CheckmarkRow(title: name, isSelected: selection.containsIgnoringCase(name)) {
                    selection.toggle(name)
                }
            }

            AddNameRow(placeholder: "Add a station by name") { name in
                if !selection.containsIgnoringCase(name) {
                    selection.append(name)
                }
            }
            .task(id: meal) { await loadStations() }
        } header: {
            Text(style == .only ? "Show Only" : "Hide")
        } footer: {
            Text("Stations come from this week's menus. If one isn't listed (on a weekend, say), add it by name.")
        }
    }

    /// This week's stations, then any chosen ones that aren't on it.
    private var choices: [String] {
        guard case .loaded(let titles) = phase else { return selection }
        return titles.merged(with: selection)
    }

    private func loadStations() async {
        phase = .loading
        let result: Phase
        do {
            result = .loaded(try await MenuService().sectionTitles(for: meal, around: .today()))
        } catch {
            result = .failed
        }
        // A cancelled load was superseded by one for another meal.
        if !Task.isCancelled {
            phase = result
        }
    }
}
