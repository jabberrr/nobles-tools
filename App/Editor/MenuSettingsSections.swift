import SwiftUI
import NoblesKit

/// The menu-specific part of the design editor.
struct MenuSettingsSections: View {
    @Binding var configuration: MenuConfiguration

    @Environment(PreviewData.self) private var previewData
    @State private var stations = StationList.loading

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
        } header: {
            Text("Menu")
        } footer: {
            if let meal = configuration.meal.meal, !previewData.availableMeals.contains(meal) {
                Text("Flik doesn't publish a \(meal.displayName.lowercased()) menu for Nobles, so this design won't show any dishes.")
            } else {
                Text("Next Meal moves on as each meal ends.")
            }
        }

        switch configuration.filterStyle {
        case .only, .excluding:
            StationPickerSection(stations: stations, style: configuration.filterStyle, selection: $configuration.filterSections)
        case .everything, .entreesOnly, .withoutSaladsAndSoups:
            EmptyView()
        }

        FeaturedDishSection(stations: stations, selection: $configuration.featuredStation)
            .task(id: configuration.meal.meal) { await loadStations() }
    }

    /// Next Meal and the meals Flik publishes, plus the current choice if it isn't one of them
    /// (an older design set to breakfast, say), so the picker never loses its selection.
    private var mealChoices: [MealSelection] {
        let published = previewData.availableMeals.compactMap { MealSelection(rawValue: $0.rawValue) }
        let choices = [MealSelection.upcoming, configuration.meal] + published
        return MealSelection.allCases.filter { choices.contains($0) }
    }

    private func loadStations() async {
        stations = .loading
        let result = await StationList.load(for: configuration.meal.meal)
        // A cancelled load was superseded by one for another meal.
        if !Task.isCancelled {
            stations = result
        }
    }
}

/// This week's stations for a meal, as the station pickers load them.
private enum StationList {
    case loading
    case loaded([String])
    case failed

    /// The stations on this week's and next week's menus for `meal` (every meal when `nil`).
    static func load(for meal: Meal?) async -> StationList {
        do {
            return .loaded(try await MenuService().sectionTitles(for: meal, around: .today()))
        } catch {
            return .failed
        }
    }

    /// The loaded stations, then any of `chosen` that aren't among them.
    func titles(including chosen: [String]) -> [String] {
        guard case .loaded(let titles) = self else { return chosen }
        return titles.merged(with: chosen)
    }
}

/// Picks the stations for "Just…" or "Everything Except…".
private struct StationPickerSection: View {
    let stations: StationList
    let style: MenuFilter.Style
    @Binding var selection: [String]

    var body: some View {
        Section {
            switch stations {
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

            ForEach(stations.titles(including: selection), id: \.self) { name in
                CheckmarkRow(title: name, isSelected: selection.containsIgnoringCase(name)) {
                    selection.toggle(name)
                }
            }

            AddNameRow(placeholder: "Add a station by name") { name in
                if !selection.containsIgnoringCase(name) {
                    selection.append(name)
                }
            }
        } header: {
            Text(style == .only ? "Show Only" : "Hide")
        } footer: {
            Text(footerText)
        }
    }

    /// Asks for a choice while there's none (until then the widget shows every station).
    private var footerText: String {
        let source = "Stations come from this week's menus. If one isn't listed (on a weekend, say), add it by name."
        guard selection.isEmpty else { return source }
        return "Choose the stations to \(style == .only ? "show" : "hide"); until you do, every station is shown. \(source)"
    }
}

/// Picks the station whose dish the design features: alone on the Lock Screen, and first on the
/// Home Screen.
private struct FeaturedDishSection: View {
    let stations: StationList
    @Binding var selection: String?

    var body: some View {
        Section {
            Picker("Station", selection: $selection) {
                Text("Automatic").tag(String?.none)
                ForEach(stations.titles(including: selection.map { [$0] } ?? []), id: \.self) { name in
                    Text(name).tag(String?.some(name))
                }
            }
        } header: {
            Text("Featured Dish")
        } footer: {
            Text("Lock Screen widgets show one dish from this station, and Home Screen widgets lead with it. Automatic picks the first entrée.")
        }
    }
}
